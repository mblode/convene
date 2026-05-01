import Foundation

/// Continuous transcription stream over the OpenAI Realtime API in transcription-only mode
/// with server-side VAD enabled. Unlike `RealtimeTranscriptionClient` (one-shot commit), this
/// stream stays connected for the lifetime of a meeting and surfaces server-segmented utterances
/// via `onSegmentStarted` / `onSegmentDelta` / `onSegmentCompleted` callbacks.
final class LiveTranscriptionStream: NSObject, URLSessionWebSocketDelegate {
    enum State {
        case disconnected
        case connecting
        case ready
        case failed(Error)
    }

    enum StreamError: Error, CustomStringConvertible, LocalizedError {
        case invalidURL
        case notConnected
        case server(String)

        var description: String {
            switch self {
            case .invalidURL: return "Invalid Realtime API URL"
            case .notConnected: return "WebSocket not connected"
            case .server(let msg): return msg
            }
        }

        var errorDescription: String? { description }
    }

    private(set) var state: State = .disconnected
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var pendingChunks: [Data] = []
    private var pendingByteCount = 0
    private let maxPendingBytes = 512 * 1024
    private let lock = NSLock()
    private var connectedAt: Date?
    private var isDisconnecting = false
    private var hasActiveSpeech = false
    private var uncommittedByteCount = 0
    private static let minimumCommitBytes = 4_800 // 100 ms of 24 kHz mono PCM16.

    /// Fired when the server detects the start of a new speech segment.
    /// `audioStartMs` is the offset in ms from when audio first started flowing on this stream.
    var onSegmentStarted: ((_ segmentId: String, _ audioStartMs: Int) -> Void)?
    /// Fired with each partial transcript delta.
    var onSegmentDelta: ((_ segmentId: String, _ delta: String) -> Void)?
    /// Fired when transcription for a segment is finalized.
    var onSegmentCompleted: ((_ segmentId: String, _ finalText: String, _ audioEndMs: Int?) -> Void)?
    var onSegmentFailed: ((_ segmentId: String?, _ message: String) -> Void)?
    var onError: ((Error) -> Void)?

    private let label: String

    init(label: String = "stream") {
        self.label = label
        super.init()
    }

    func connect(apiKey: String, model: String = "gpt-4o-mini-transcribe", language: String = "") {
        lock.lock()
        defer { lock.unlock() }

        if case .ready = state { return }
        if case .connecting = state { return }
        state = .connecting
        pendingChunks.removeAll()
        pendingByteCount = 0
        connectedAt = nil
        isDisconnecting = false
        hasActiveSpeech = false
        uncommittedByteCount = 0

        guard let url = URL(string: "wss://api.openai.com/v1/realtime?intent=transcription") else {
            state = .failed(StreamError.invalidURL)
            onError?(StreamError.invalidURL)
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        self.urlSession = session
        let task = session.webSocketTask(with: request)
        self.webSocketTask = task
        task.resume()

        listen()
        sendSessionUpdate(model: model, language: language)
    }

    func sendAudioChunk(_ pcm16: Data) {
        lock.lock()
        let isReady: Bool
        switch state {
        case .ready: isReady = true
        default: isReady = false
        }
        if !isReady {
            // Buffer chunks while we're still completing the handshake to avoid losing the
            // first second of audio. Keep it bounded so a stalled socket cannot retain a
            // whole meeting in memory.
            if case .connecting = state {
                appendPendingChunkLocked(pcm16)
            }
            lock.unlock()
            return
        }
        lock.unlock()

        sendAudioAppend(pcm16)
    }

    /// Send `input_audio_buffer.commit` to flush in-flight audio. The server will emit a
    /// `transcription.completed` event for the current segment shortly after.
    /// Caller is expected to wait briefly before calling `disconnect()` so the completion
    /// event can land while the socket is still open.
    @discardableResult
    func commitPendingAudio() -> Bool {
        lock.lock()
        let isReady: Bool = {
            if case .ready = state { return true }
            return false
        }()
        let shouldCommit = isReady && hasActiveSpeech && uncommittedByteCount >= Self.minimumCommitBytes
        lock.unlock()
        guard shouldCommit else {
            logDebug("LiveTranscriptionStream[\(label)]: skipping commit (no active speech, buffer too small, or stream not ready)")
            return false
        }
        sendJSON(["type": "input_audio_buffer.commit"])
        return true
    }

    func disconnect() {
        let task: URLSessionWebSocketTask?
        let session: URLSession?
        lock.lock()
        isDisconnecting = true
        task = webSocketTask
        session = urlSession
        webSocketTask = nil
        urlSession = nil
        pendingChunks.removeAll()
        pendingByteCount = 0
        hasActiveSpeech = false
        uncommittedByteCount = 0
        state = .disconnected
        lock.unlock()
        task?.cancel(with: .normalClosure, reason: nil)
        session?.invalidateAndCancel()
    }

    /// Wall-clock timestamp of when the stream connection was established. Useful for
    /// converting server-reported `audio_start_ms` into meeting-relative seconds.
    var connectionStartedAt: Date? {
        connectedAt
    }

    // MARK: - Private

    private func sendSessionUpdate(model: String, language: String) {
        var transcriptionConfig: [String: Any] = ["model": model]
        if !language.isEmpty {
            transcriptionConfig["language"] = language
        }
        let session: [String: Any] = [
            "input_audio_format": "pcm16",
            "input_audio_transcription": transcriptionConfig,
            "turn_detection": [
                "type": "server_vad",
                "threshold": 0.5,
                "prefix_padding_ms": 300,
                "silence_duration_ms": 500
            ] as [String: Any],
            "input_audio_noise_reduction": [
                "type": "far_field"
            ] as [String: Any]
        ]
        sendJSON([
            "type": "transcription_session.update",
            "session": session
        ])
    }

    private func sendAudioAppend(_ pcm16: Data) {
        let base64 = pcm16.base64EncodedString()
        sendJSON([
            "type": "input_audio_buffer.append",
            "audio": base64
        ])
        lock.lock()
        uncommittedByteCount += pcm16.count
        lock.unlock()
    }

    private func sendJSON(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let string = String(data: data, encoding: .utf8) else { return }
        webSocketTask?.send(.string(string)) { [weak self] error in
            guard let error else { return }
            logError("LiveTranscriptionStream: send error: \(error.localizedDescription)")
            self?.fail(with: error)
        }
    }

    private func listen() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text): self.handle(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) { self.handle(text) }
                @unknown default: break
                }
                self.listen()
            case .failure(let error):
                if self.shouldReportDisconnectError() {
                    logError("LiveTranscriptionStream: receive error: \(error.localizedDescription)")
                }
                self.handleDisconnect(error: error)
            }
        }
    }

    private func handle(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        switch type {
        case "session.updated", "transcription_session.updated":
            lock.lock()
            let wasConnecting: Bool = {
                if case .connecting = state { return true }
                return false
            }()
            if wasConnecting {
                state = .ready
                connectedAt = Date()
                let buffered = pendingChunks
                pendingChunks.removeAll()
                pendingByteCount = 0
                lock.unlock()
                logInfo("LiveTranscriptionStream[\(label)]: ready (flushing \(buffered.count) buffered chunks)")
                for chunk in buffered { sendAudioAppend(chunk) }
            } else {
                lock.unlock()
            }

        case "session.created", "transcription_session.created":
            logDebug("LiveTranscriptionStream[\(label)]: event \(type)")

        case "input_audio_buffer.speech_started":
            lock.lock()
            hasActiveSpeech = true
            lock.unlock()
            let segmentId = (json["item_id"] as? String) ?? UUID().uuidString
            let audioStartMs = (json["audio_start_ms"] as? Int) ?? 0
            onSegmentStarted?(segmentId, audioStartMs)

        case "conversation.item.input_audio_transcription.delta":
            guard let segmentId = json["item_id"] as? String,
                  let delta = json["delta"] as? String else { return }
            onSegmentDelta?(segmentId, delta)

        case "conversation.item.input_audio_transcription.completed":
            guard let segmentId = json["item_id"] as? String else { return }
            let transcript = (json["transcript"] as? String) ?? ""
            let audioEndMs = json["audio_end_ms"] as? Int
            onSegmentCompleted?(segmentId, transcript, audioEndMs)

        case "conversation.item.input_audio_transcription.segment":
            let segmentId = (json["item_id"] as? String) ?? (json["id"] as? String) ?? UUID().uuidString
            let text = (json["text"] as? String) ?? ""
            guard !text.isEmpty else { return }
            let start = json["start"] as? Double
            let end = json["end"] as? Double
            onSegmentStarted?(segmentId, Int((start ?? relativeAudioTime()) * 1000))
            onSegmentCompleted?(segmentId, text, end.map { Int($0 * 1000) })

        case "conversation.item.input_audio_transcription.failed":
            let segmentId = json["item_id"] as? String
            let error = json["error"] as? [String: Any]
            let code = error?["code"] as? String
            let message = error?["message"] as? String ?? "Transcription failed"
            let formatted = OpenAIErrorFormatter.userMessage(
                code: code,
                message: message,
                operation: "Transcription"
            )
            logError("LiveTranscriptionStream[\(label)]: transcription failed\(segmentId.map { " for \($0)" } ?? ""): \(formatted)")
            onSegmentFailed?(segmentId, formatted)

        case "input_audio_buffer.speech_stopped":
            lock.lock()
            hasActiveSpeech = false
            uncommittedByteCount = 0
            lock.unlock()

        case "input_audio_buffer.committed":
            lock.lock()
            uncommittedByteCount = 0
            lock.unlock()

        case "error":
            let error = json["error"] as? [String: Any]
            let rawMessage = error?["message"] as? String ?? "unknown"
            if Self.isEmptyCommitError(rawMessage) {
                lock.lock()
                hasActiveSpeech = false
                uncommittedByteCount = 0
                lock.unlock()
                logDebug("LiveTranscriptionStream[\(label)]: ignoring empty commit error: \(rawMessage)")
                return
            }
            let code = error?["code"] as? String
            let msg = OpenAIErrorFormatter.userMessage(code: code, message: rawMessage, operation: "Transcription")
            logError("LiveTranscriptionStream[\(label)]: error event: \(msg)")
            fail(with: StreamError.server(msg))

        default:
            logDebug("LiveTranscriptionStream[\(label)]: event \(type)")
        }
    }

    private func relativeAudioTime() -> Double {
        guard let connectedAt else { return 0 }
        return Date().timeIntervalSince(connectedAt)
    }

    private static func isEmptyCommitError(_ message: String) -> Bool {
        message.localizedCaseInsensitiveContains("input audio buffer")
            && message.localizedCaseInsensitiveContains("buffer too small")
    }

    private func handleDisconnect(error: Error) {
        let shouldReport: Bool
        let session: URLSession?
        lock.lock()
        shouldReport = !isDisconnecting
        session = urlSession
        state = .disconnected
        webSocketTask = nil
        urlSession = nil
        pendingChunks.removeAll()
        pendingByteCount = 0
        hasActiveSpeech = false
        uncommittedByteCount = 0
        isDisconnecting = false
        lock.unlock()
        if shouldReport {
            onError?(error)
        }
        session?.invalidateAndCancel()
    }

    private func appendPendingChunkLocked(_ chunk: Data) {
        guard chunk.count <= maxPendingBytes else {
            pendingChunks.removeAll()
            pendingByteCount = 0
            return
        }

        while pendingByteCount + chunk.count > maxPendingBytes, let first = pendingChunks.first {
            pendingByteCount -= first.count
            pendingChunks.removeFirst()
        }

        pendingChunks.append(chunk)
        pendingByteCount += chunk.count
    }

    private func fail(with error: Error) {
        let task: URLSessionWebSocketTask?
        let session: URLSession?
        lock.lock()
        if isDisconnecting {
            lock.unlock()
            return
        }
        state = .failed(error)
        pendingChunks.removeAll()
        pendingByteCount = 0
        hasActiveSpeech = false
        uncommittedByteCount = 0
        isDisconnecting = true
        task = webSocketTask
        session = urlSession
        webSocketTask = nil
        urlSession = nil
        lock.unlock()

        task?.cancel(with: .goingAway, reason: nil)
        session?.invalidateAndCancel()
        onError?(error)
    }

    private func shouldReportDisconnectError() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return !isDisconnecting
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        logInfo("LiveTranscriptionStream[\(label)]: WebSocket connected")
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        logInfo("LiveTranscriptionStream[\(label)]: WebSocket closed (code: \(closeCode.rawValue))")
    }
}
