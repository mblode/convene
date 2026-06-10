import AVFoundation
import Foundation

private let realtimeTranscriptionModel = "gpt-realtime-whisper"
private let realtimeAudioSampleRate = 24_000

@MainActor
final class OpenAIRealtimeTranscriber: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var isConnecting = false
    @Published private(set) var segments: [TranscriptSegment] = []
    @Published private(set) var lastError: String?

    var onSegmentConfirmed: ((TranscriptSegment) -> Void)?

    private var clients: [String: OpenAIRealtimeTranscriptionClient] = [:]
    private var segmentIDsByItemID: [String: UUID] = [:]
    private var commitTask: Task<Void, Never>?
    private var meetingStartedAt: Date?
    private var pendingCommitCount = 0

    private let commitInterval: UInt64 = 6_000_000_000
    private let stopWaitNanoseconds: UInt64 = 8_000_000_000

    func start(
        apiKey: String,
        speakers: [TranscriptSegment.Speaker] = [.you],
        language: String = "en"
    ) async {
        guard !isRunning else { return }

        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            lastError = "OpenAI API key required"
            return
        }

        lastError = nil
        segments = []
        segmentIDsByItemID = [:]
        pendingCommitCount = 0
        meetingStartedAt = Date()
        isConnecting = true

        for speaker in speakers {
            let client = makeClient(for: speaker)
            clients[speaker.rawValue] = client
            client.connect(apiKey: trimmedKey, model: realtimeTranscriptionModel, language: language)
        }

        isRunning = true
        logInfo("OpenAIRealtimeTranscriber: started with \(clients.count) stream(s)")
        startPeriodicCommits()
    }

    nonisolated func ingestPCM16(_ data: Data, speaker: TranscriptSegment.Speaker = .you) {
        Task { @MainActor [data, speaker] in
            guard isRunning else { return }
            clients[speaker.rawValue]?.sendAudioChunk(data)
        }
    }

    nonisolated func ingestAudio(_ buffer: AVAudioPCMBuffer, speaker: TranscriptSegment.Speaker = .you) {
        guard let data = Self.pcm16Data(from: buffer) else { return }
        ingestPCM16(data, speaker: speaker)
    }

    func stop() async {
        guard isRunning else { return }

        commitTask?.cancel()
        commitTask = nil
        commitAll()
        await waitForPendingFinals(timeoutNanoseconds: stopWaitNanoseconds)

        for client in clients.values {
            client.disconnect()
        }

        clients = [:]
        isRunning = false
        isConnecting = false
        meetingStartedAt = nil
        pendingCommitCount = 0
        logInfo("OpenAIRealtimeTranscriber: stopped (\(segments.count) segments)")
    }

    private func makeClient(for speaker: TranscriptSegment.Speaker) -> OpenAIRealtimeTranscriptionClient {
        let client = OpenAIRealtimeTranscriptionClient(label: speaker.rawValue)

        client.onReady = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isConnecting = self.clients.values.contains { !$0.isReady }
            }
        }
        client.onDelta = { [weak self] itemID, delta in
            Task { @MainActor [weak self] in
                self?.handleDelta(speaker: speaker, itemID: itemID, delta: delta)
            }
        }
        client.onCompleted = { [weak self] itemID, transcript in
            Task { @MainActor [weak self] in
                self?.handleCompleted(speaker: speaker, itemID: itemID, transcript: transcript)
            }
        }
        client.onError = { [weak self] message in
            Task { @MainActor [weak self] in
                self?.lastError = "OpenAI transcription error: \(message)"
            }
        }

        return client
    }

    private func startPeriodicCommits() {
        commitTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let interval = self?.commitInterval else { return }
                try? await Task.sleep(nanoseconds: interval)
                await MainActor.run {
                    _ = self?.commitAll()
                }
            }
        }
    }

    @discardableResult
    private func commitAll() -> Int {
        guard isRunning else { return 0 }
        var committed = 0
        for client in clients.values {
            if client.commitPendingAudio() {
                committed += 1
            }
        }
        pendingCommitCount += committed
        return committed
    }

    private func waitForPendingFinals(timeoutNanoseconds: UInt64) async {
        let started = ContinuousClock.now
        let timeout = Duration.nanoseconds(Int64(timeoutNanoseconds))
        while pendingCommitCount > 0 && ContinuousClock.now - started < timeout {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    private func handleDelta(speaker: TranscriptSegment.Speaker, itemID: String, delta: String) {
        let text = delta.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let key = segmentKey(speaker: speaker, itemID: itemID)
        let elapsed = currentElapsed()

        if let id = segmentIDsByItemID[key],
           let index = segments.firstIndex(where: { $0.id == id }) {
            segments[index].text += delta
            segments[index].endedAt = elapsed
            return
        }

        let segment = TranscriptSegment(
            speaker: speaker,
            startedAt: elapsed,
            endedAt: elapsed,
            text: text,
            isFinal: false
        )
        segmentIDsByItemID[key] = segment.id
        segments.append(segment)
    }

    private func handleCompleted(speaker: TranscriptSegment.Speaker, itemID: String, transcript: String) {
        pendingCommitCount = max(0, pendingCommitCount - 1)

        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let key = segmentKey(speaker: speaker, itemID: itemID)
        let elapsed = currentElapsed()

        if let id = segmentIDsByItemID[key],
           let index = segments.firstIndex(where: { $0.id == id }) {
            segments[index].text = text
            segments[index].endedAt = elapsed
            segments[index].isFinal = true
            if let duplicate = TranscriptSegment.likelyEchoDuplicate(for: segments[index], in: segments, excluding: id) {
                logInfo(
                    "OpenAIRealtimeTranscriber: suppressed likely echo duplicate \(speaker.displayName) segment matching \(duplicate.speaker.displayName)"
                )
                segments.remove(at: index)
                segmentIDsByItemID.removeValue(forKey: key)
                return
            }
            onSegmentConfirmed?(segments[index])
            return
        }

        let segment = TranscriptSegment(
            speaker: speaker,
            startedAt: elapsed,
            endedAt: elapsed,
            text: text,
            isFinal: true
        )
        if let duplicate = TranscriptSegment.likelyEchoDuplicate(for: segment, in: segments) {
            logInfo(
                "OpenAIRealtimeTranscriber: suppressed likely echo duplicate \(speaker.displayName) segment matching \(duplicate.speaker.displayName)"
            )
            return
        }
        segmentIDsByItemID[key] = segment.id
        segments.append(segment)
        onSegmentConfirmed?(segment)
    }

    private func currentElapsed() -> TimeInterval {
        meetingStartedAt.map { Date().timeIntervalSince($0) } ?? 0
    }

    private func segmentKey(speaker: TranscriptSegment.Speaker, itemID: String) -> String {
        "\(speaker.rawValue):\(itemID)"
    }

    private nonisolated static func pcm16Data(from buffer: AVAudioPCMBuffer) -> Data? {
        guard let channelData = buffer.floatChannelData?[0] else { return nil }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return nil }

        var data = Data(count: frameCount * 2)
        data.withUnsafeMutableBytes { raw in
            let int16 = raw.bindMemory(to: Int16.self)
            for i in 0..<frameCount {
                let scaled = Int32(channelData[i] * 32767.0)
                int16[i] = Int16(max(-32768, min(32767, scaled))).littleEndian
            }
        }
        return data
    }
}

private final class OpenAIRealtimeTranscriptionClient: NSObject, URLSessionWebSocketDelegate {
    enum State {
        case disconnected
        case connecting
        case ready
        case failed(String)
    }

    var onReady: (() -> Void)?
    var onDelta: ((String, String) -> Void)?
    var onCompleted: ((String, String) -> Void)?
    var onError: ((String) -> Void)?

    private(set) var state: State = .disconnected
    var isReady: Bool {
        if case .ready = state { return true }
        return false
    }

    private let label: String
    private let queue: DispatchQueue
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var pendingChunks: [Data] = []
    private var pendingBytes = 0
    private var needsCommit = false
    private var model = realtimeTranscriptionModel
    private var language = "en"

    init(label: String) {
        self.label = label
        self.queue = DispatchQueue(label: "co.blode.convene.openai-realtime.\(label)")
        super.init()
    }

    func connect(apiKey: String, model: String, language: String) {
        queue.async {
            guard case .disconnected = self.state else { return }
            self.model = model
            self.language = language
            self.state = .connecting

            guard let url = URL(string: "wss://api.openai.com/v1/realtime?intent=transcription") else {
                self.fail("Invalid Realtime API URL")
                return
            }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

            let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
            let task = session.webSocketTask(with: request)
            self.urlSession = session
            self.webSocketTask = task
            task.resume()
            self.listenForMessages()
        }
    }

    func sendAudioChunk(_ pcm16Data: Data) {
        queue.async {
            guard !pcm16Data.isEmpty else { return }
            self.pendingBytes += pcm16Data.count

            if case .ready = self.state {
                self.sendAudioAppend(pcm16Data)
            } else {
                self.pendingChunks.append(pcm16Data)
            }
        }
    }

    @discardableResult
    func commitPendingAudio() -> Bool {
        queue.sync {
            commitPendingAudioOnQueue()
        }
    }

    func disconnect() {
        queue.async {
            self.webSocketTask?.cancel(with: .normalClosure, reason: nil)
            self.webSocketTask = nil
            self.urlSession?.invalidateAndCancel()
            self.urlSession = nil
            self.pendingChunks = []
            self.pendingBytes = 0
            self.needsCommit = false
            self.state = .disconnected
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        queue.async {
            logInfo("OpenAIRealtimeTranscriptionClient[\(self.label)]: connected")
            self.sendSessionUpdate()
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        queue.async {
            if case .disconnected = self.state { return }
            self.fail("WebSocket closed with code \(closeCode.rawValue)")
        }
    }

    private func sendSessionUpdate() {
        let config: [String: Any] = [
            "type": "session.update",
            "session": [
                "type": "transcription",
                "audio": [
                    "input": [
                        "format": ["type": "audio/pcm", "rate": realtimeAudioSampleRate] as [String: Any],
                        "transcription": [
                            "model": model,
                            "language": language,
                            "delay": "low"
                        ] as [String: Any],
                        "turn_detection": NSNull()
                    ] as [String: Any]
                ] as [String: Any]
            ] as [String: Any]
        ]
        sendJSON(config)
    }

    private func sendAudioAppend(_ pcm16Data: Data) {
        sendJSON([
            "type": "input_audio_buffer.append",
            "audio": pcm16Data.base64EncodedString()
        ])
    }

    private func sendJSON(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let string = String(data: data, encoding: .utf8) else {
            return
        }
        webSocketTask?.send(.string(string)) { [weak self] error in
            guard let self, let error else { return }
            self.queue.async {
                self.fail("Send failed: \(error.localizedDescription)")
            }
        }
    }

    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }

            self.queue.async {
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        self.handleMessage(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self.handleMessage(text)
                        }
                    @unknown default:
                        break
                    }
                    self.listenForMessages()

                case .failure(let error):
                    if case .disconnected = self.state { return }
                    self.fail("Receive failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        switch type {
        case "session.updated", "transcription_session.updated":
            state = .ready
            flushPendingAudio()
            onReady?()

        case "session.created", "transcription_session.created":
            logDebug("OpenAIRealtimeTranscriptionClient[\(label)]: event \(type)")

        case "conversation.item.input_audio_transcription.delta":
            guard let itemID = json["item_id"] as? String,
                  let delta = json["delta"] as? String else { return }
            onDelta?(itemID, delta)

        case "conversation.item.input_audio_transcription.completed":
            guard let itemID = json["item_id"] as? String else { return }
            let transcript = (json["transcript"] as? String) ?? ""
            onCompleted?(itemID, transcript)

        case "error":
            let message = (json["error"] as? [String: Any])?["message"] as? String ?? "Unknown Realtime API error"
            fail(message)

        default:
            logDebug("OpenAIRealtimeTranscriptionClient[\(label)]: event \(type)")
        }
    }

    private func flushPendingAudio() {
        guard case .ready = state else { return }
        for chunk in pendingChunks {
            sendAudioAppend(chunk)
        }
        pendingChunks = []
        if needsCommit {
            _ = commitPendingAudioOnQueue()
        }
    }

    private func commitPendingAudioOnQueue() -> Bool {
        guard pendingBytes > 0 else { return false }
        guard case .ready = state else {
            needsCommit = true
            return false
        }

        pendingBytes = 0
        needsCommit = false
        sendJSON(["type": "input_audio_buffer.commit"])
        return true
    }

    private func fail(_ message: String) {
        state = .failed(message)
        logError("OpenAIRealtimeTranscriptionClient[\(label)]: \(message)")
        onError?(message)
    }
}
