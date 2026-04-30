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

    enum StreamError: Error, CustomStringConvertible {
        case invalidURL
        case notConnected
        case server(String)

        var description: String {
            switch self {
            case .invalidURL: return "Invalid Realtime API URL"
            case .notConnected: return "WebSocket not connected"
            case .server(let msg): return "Realtime server error: \(msg)"
            }
        }
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

    /// Fired when the server detects the start of a new speech segment.
    /// `audioStartMs` is the offset in ms from when audio first started flowing on this stream.
    var onSegmentStarted: ((_ segmentId: String, _ audioStartMs: Int) -> Void)?
    /// Fired with each partial transcript delta.
    var onSegmentDelta: ((_ segmentId: String, _ delta: String) -> Void)?
    /// Fired when transcription for a segment is finalized.
    var onSegmentCompleted: ((_ segmentId: String, _ finalText: String, _ audioEndMs: Int?) -> Void)?
    var onError: ((Error) -> Void)?

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
    func commitPendingAudio() {
        lock.lock()
        let isReady: Bool = {
            if case .ready = state { return true }
            return false
        }()
        lock.unlock()
        guard isReady else { return }
        sendJSON(["type": "input_audio_buffer.commit"])
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
                logError("LiveTranscriptionStream: receive error: \(error.localizedDescription)")
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
                logInfo("LiveTranscriptionStream: ready (flushing \(buffered.count) buffered chunks)")
                for chunk in buffered { sendAudioAppend(chunk) }
            } else {
                lock.unlock()
            }

        case "session.created", "transcription_session.created":
            logDebug("LiveTranscriptionStream: event \(type)")

        case "input_audio_buffer.speech_started":
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

        case "input_audio_buffer.speech_stopped":
            // Speech stopped fires before the completion event; nothing to do here.
            break

        case "error":
            let msg = (json["error"] as? [String: Any])?["message"] as? String ?? "unknown"
            logError("LiveTranscriptionStream: error event: \(msg)")
            fail(with: StreamError.server(msg))

        default:
            logDebug("LiveTranscriptionStream: event \(type)")
        }
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

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        logInfo("LiveTranscriptionStream: WebSocket connected")
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        logInfo("LiveTranscriptionStream: WebSocket closed (code: \(closeCode.rawValue))")
    }
}
