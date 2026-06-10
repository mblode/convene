import AVFoundation
import Foundation

private let assemblyAISampleRate = 16_000
private let assemblyAISpeechModel = "u3-rt-pro"
private let assemblyAIEndpoint = "wss://streaming.assemblyai.com/v3/ws"

/// Streams meeting audio to AssemblyAI Universal-Streaming (v3) over one WebSocket per
/// speaker stream (mic = .you, system audio = .others) and folds `Turn` messages into
/// `TranscriptSegment`s. Mirrors the two-layer structure of the previous OpenAI
/// transcriber: a @MainActor coordinator owning segment state plus one socket client
/// per stream, each on its own serial queue.
@MainActor
final class AssemblyAIRealtimeTranscriber: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var isConnecting = false
    @Published private(set) var segments: [TranscriptSegment] = []
    @Published private(set) var lastError: String?

    var onSegmentConfirmed: ((TranscriptSegment) -> Void)?

    private var clients: [String: AssemblyAIStreamingClient] = [:]
    private var segmentIDsByTurnKey: [String: UUID] = [:]
    /// Per-stream meeting-relative offset of the socket's `Begin` message; AssemblyAI
    /// word times are relative to session start, so segment times are offset + word time.
    private var connectElapsedBySpeaker: [String: TimeInterval] = [:]
    private var terminatedSpeakers: Set<String> = []
    private var meetingStartedAt: Date?

    private let stopWaitNanoseconds: UInt64 = 8_000_000_000
    /// Grace period after Termination to drain a trailing SpeakerRevision message.
    private let revisionDrainNanoseconds: UInt64 = 300_000_000

    func start(
        apiKey: String,
        speakers: [TranscriptSegment.Speaker] = [.you],
        attendeeNames: [String] = [],
        meetingTitle: String = "",
        expectedSpeakerCount: Int? = nil
    ) async {
        guard !isRunning else { return }

        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            lastError = "AssemblyAI API key required"
            return
        }

        lastError = nil
        segments = []
        segmentIDsByTurnKey = [:]
        connectElapsedBySpeaker = [:]
        terminatedSpeakers = []
        meetingStartedAt = Date()
        isConnecting = true

        let keyterms = KeytermsBuilder.build(attendees: attendeeNames, title: meetingTitle)

        for speaker in speakers {
            guard let url = Self.streamURL(
                for: speaker,
                keyterms: keyterms,
                expectedSpeakerCount: expectedSpeakerCount
            ) else {
                lastError = "AssemblyAI: could not build streaming URL"
                isConnecting = false
                meetingStartedAt = nil
                clients = [:]
                return
            }
            let client = makeClient(for: speaker)
            clients[speaker.rawValue] = client
            client.connect(url: url, apiKey: trimmedKey)
        }

        isRunning = true
        logInfo("AssemblyAIRealtimeTranscriber: started with \(clients.count) stream(s)")
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

        // Flush buffered audio, then ForceEndpoint + Terminate each stream. Terminate is
        // required: abandoned sessions keep billing until a 3-hour cap.
        for client in clients.values {
            client.beginShutdown()
        }
        await waitForTerminations(timeoutNanoseconds: stopWaitNanoseconds)
        // Drain any trailing SpeakerRevision that follows Termination.
        try? await Task.sleep(nanoseconds: revisionDrainNanoseconds)

        for client in clients.values {
            client.disconnect()
        }

        clients = [:]
        isRunning = false
        isConnecting = false
        meetingStartedAt = nil
        terminatedSpeakers = []
        connectElapsedBySpeaker = [:]
        logInfo("AssemblyAIRealtimeTranscriber: stopped (\(segments.count) segments)")
    }

    // MARK: - Message handling (internal for tests)

    func handleServerMessage(_ message: AssemblyAIServerMessage, for speaker: TranscriptSegment.Speaker) {
        switch message {
        case .begin(let begin):
            connectElapsedBySpeaker[speaker.rawValue] = currentElapsed()
            isConnecting = clients.values.contains { !$0.isReady }
            logInfo("AssemblyAIRealtimeTranscriber[\(speaker.rawValue)]: session began (\(begin.id))")

        case .turn(let turn):
            handleTurn(turn, speaker: speaker)

        case .speakerRevision(let revision):
            applySpeakerRevision(revision, speaker: speaker)

        case .termination(let termination):
            terminatedSpeakers.insert(speaker.rawValue)
            let duration = termination.audioDurationSeconds.map { String(format: "%.1fs", $0) } ?? "?"
            logInfo("AssemblyAIRealtimeTranscriber[\(speaker.rawValue)]: terminated (audio \(duration))")

        case .speechStarted, .unknown:
            break
        }
    }

    private func handleTurn(_ turn: AssemblyAITurnMessage, speaker: TranscriptSegment.Speaker) {
        let text = turn.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = turnKey(speaker: speaker, turnOrder: turn.turnOrder)
        let connectElapsed = connectElapsedBySpeaker[speaker.rawValue] ?? 0
        let startedAt = turn.words.first.map { connectElapsed + TimeInterval($0.start) / 1000 }
            ?? currentElapsed()
        let endedAt = turn.words.last.map { connectElapsed + TimeInterval($0.end) / 1000 }
            ?? currentElapsed()
        let diarized = Self.diarizedSpeaker(from: turn.speakerLabel)

        guard turn.endOfTurn else {
            guard !text.isEmpty else { return }
            // Partials carry the full turn text so far: replace, never append.
            if let id = segmentIDsByTurnKey[key],
               let index = segments.firstIndex(where: { $0.id == id }) {
                segments[index].text = text
                segments[index].endedAt = endedAt
                segments[index].diarizedSpeaker = diarized
                return
            }
            let segment = TranscriptSegment(
                speaker: speaker,
                startedAt: startedAt,
                endedAt: endedAt,
                text: text,
                isFinal: false,
                diarizedSpeaker: diarized
            )
            segmentIDsByTurnKey[key] = segment.id
            segments.append(segment)
            return
        }

        // Finalized + formatted turn.
        if text.isEmpty {
            // Empty final turn: drop any partial we accumulated for it.
            if let id = segmentIDsByTurnKey.removeValue(forKey: key) {
                segments.removeAll { $0.id == id }
            }
            return
        }

        let finalized: TranscriptSegment
        if let id = segmentIDsByTurnKey[key],
           let index = segments.firstIndex(where: { $0.id == id }) {
            segments[index].text = text
            segments[index].endedAt = endedAt
            segments[index].isFinal = true
            if diarized != nil {
                segments[index].diarizedSpeaker = diarized
            }
            finalized = segments[index]
        } else {
            let segment = TranscriptSegment(
                speaker: speaker,
                startedAt: startedAt,
                endedAt: endedAt,
                text: text,
                isFinal: true,
                diarizedSpeaker: diarized
            )
            segmentIDsByTurnKey[key] = segment.id
            segments.append(segment)
            finalized = segment
        }

        switch TranscriptSegment.resolveEchoDuplicate(for: finalized, in: segments) {
        case .dropCandidate:
            logInfo(
                "AssemblyAIRealtimeTranscriber: suppressed likely echo duplicate \(speaker.displayName) segment; kept existing copy"
            )
            segments.removeAll { $0.id == finalized.id }
            segmentIDsByTurnKey.removeValue(forKey: key)
            return
        case .evictExisting(let duplicateID):
            logInfo(
                "AssemblyAIRealtimeTranscriber: suppressed likely echo duplicate matching \(speaker.displayName); kept \(speaker.displayName) copy"
            )
            evictSegment(withID: duplicateID)
        case .keep:
            break
        }

        onSegmentConfirmed?(finalized)
    }

    private func applySpeakerRevision(_ revision: AssemblyAISpeakerRevisionMessage, speaker: TranscriptSegment.Speaker) {
        guard !revision.revisions.isEmpty else { return }
        var applied = 0
        for (turnOrder, label) in revision.revisions {
            let key = turnKey(speaker: speaker, turnOrder: turnOrder)
            guard let id = segmentIDsByTurnKey[key],
                  let index = segments.firstIndex(where: { $0.id == id }) else { continue }
            segments[index].diarizedSpeaker = Self.diarizedSpeaker(from: label)
            applied += 1
        }
        logInfo("AssemblyAIRealtimeTranscriber[\(speaker.rawValue)]: applied speaker revision to \(applied) turn(s)")
    }

    private static func diarizedSpeaker(from label: String?) -> String? {
        guard let label, !label.isEmpty, label.uppercased() != "UNKNOWN" else { return nil }
        return label
    }

    // MARK: - Client wiring

    private func makeClient(for speaker: TranscriptSegment.Speaker) -> AssemblyAIStreamingClient {
        let client = AssemblyAIStreamingClient(label: speaker.rawValue)

        client.onMessage = { [weak self] message in
            Task { @MainActor [weak self] in
                self?.handleServerMessage(message, for: speaker)
            }
        }
        client.onError = { [weak self] message in
            Task { @MainActor [weak self] in
                // Phrased without "transcription failed:" so MeetingStore treats it as
                // fatal and stops the meeting.
                self?.lastError = message
            }
        }

        return client
    }

    private func waitForTerminations(timeoutNanoseconds: UInt64) async {
        let expected = Set(clients.keys)
        let started = ContinuousClock.now
        let timeout = Duration.nanoseconds(Int64(timeoutNanoseconds))
        while !expected.isSubset(of: terminatedSpeakers) && ContinuousClock.now - started < timeout {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    private func evictSegment(withID id: UUID) {
        segments.removeAll { $0.id == id }
        if let staleKey = segmentIDsByTurnKey.first(where: { $0.value == id })?.key {
            segmentIDsByTurnKey.removeValue(forKey: staleKey)
        }
    }

    private func currentElapsed() -> TimeInterval {
        meetingStartedAt.map { Date().timeIntervalSince($0) } ?? 0
    }

    private func turnKey(speaker: TranscriptSegment.Speaker, turnOrder: Int) -> String {
        "\(speaker.rawValue):\(turnOrder)"
    }

    // MARK: - URL building

    private static func streamURL(
        for speaker: TranscriptSegment.Speaker,
        keyterms: [String],
        expectedSpeakerCount: Int?
    ) -> URL? {
        guard var components = URLComponents(string: assemblyAIEndpoint) else { return nil }
        var items: [URLQueryItem] = [
            URLQueryItem(name: "sample_rate", value: String(assemblyAISampleRate)),
            URLQueryItem(name: "speech_model", value: assemblyAISpeechModel)
        ]

        if speaker == .others {
            items.append(URLQueryItem(name: "speaker_labels", value: "true"))
            // max_speakers only when the calendar event has attendees: everyone minus
            // the local user, clamped to AssemblyAI's supported 2...10 range.
            if let count = expectedSpeakerCount, count > 0 {
                let maxSpeakers = min(max(count - 1, 2), 10)
                items.append(URLQueryItem(name: "max_speakers", value: String(maxSpeakers)))
            }
        }

        if !keyterms.isEmpty,
           let data = try? JSONEncoder().encode(keyterms),
           let json = String(data: data, encoding: .utf8) {
            items.append(URLQueryItem(name: "keyterms_prompt", value: json))
        }

        components.queryItems = items
        return components.url
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

// MARK: - Streaming client

/// One AssemblyAI v3 WebSocket. All state is confined to its serial queue. Buffers
/// PCM16 audio into 100ms–1s binary frames (AssemblyAI closes the socket with 3007
/// for frames outside 50–1000ms).
private final class AssemblyAIStreamingClient: NSObject, URLSessionWebSocketDelegate {
    enum State {
        case disconnected
        case connecting
        case ready
        case terminating
        case failed(String)
    }

    var onMessage: ((AssemblyAIServerMessage) -> Void)?
    var onError: ((String) -> Void)?

    private(set) var state: State = .disconnected
    var isReady: Bool {
        if case .ready = state { return true }
        return false
    }

    /// 100ms of 16kHz mono PCM16 — minimum flush size.
    private static let flushThresholdBytes = 3_200
    /// 1000ms of 16kHz mono PCM16 — AssemblyAI's hard frame cap.
    private static let maxFrameBytes = 32_000
    /// 50ms of 16kHz mono PCM16 — AssemblyAI's minimum frame size.
    private static let minFrameBytes = 1_600

    private let label: String
    private let queue: DispatchQueue
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var sendBuffer = Data()

    init(label: String) {
        self.label = label
        self.queue = DispatchQueue(label: "co.blode.convene.assemblyai.\(label)")
        super.init()
    }

    func connect(url: URL, apiKey: String) {
        queue.async {
            guard case .disconnected = self.state else { return }
            self.state = .connecting

            var request = URLRequest(url: url)
            // AssemblyAI expects the raw key — no "Bearer" prefix.
            request.setValue(apiKey, forHTTPHeaderField: "Authorization")

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
            switch self.state {
            case .connecting, .ready:
                self.sendBuffer.append(pcm16Data)
                if case .ready = self.state {
                    self.flushBufferedAudio(force: false)
                }
            case .disconnected, .terminating, .failed:
                break
            }
        }
    }

    /// Flush remaining audio, then ForceEndpoint + Terminate. The Termination reply
    /// (and any trailing SpeakerRevision) still flows through `onMessage`.
    func beginShutdown() {
        queue.async {
            guard case .ready = self.state else {
                // Never became ready: nothing to terminate gracefully.
                if case .connecting = self.state {
                    self.state = .terminating
                    self.sendControl(.terminate)
                }
                return
            }
            self.state = .terminating
            self.flushBufferedAudio(force: true)
            self.sendControl(.forceEndpoint)
            self.sendControl(.terminate)
        }
    }

    func disconnect() {
        queue.async {
            self.webSocketTask?.cancel(with: .normalClosure, reason: nil)
            self.webSocketTask = nil
            self.urlSession?.invalidateAndCancel()
            self.urlSession = nil
            self.sendBuffer = Data()
            self.state = .disconnected
        }
    }

    // MARK: URLSessionWebSocketDelegate

    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        queue.async {
            logInfo("AssemblyAIStreamingClient[\(self.label)]: connected")
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        queue.async {
            switch self.state {
            case .disconnected, .terminating:
                return
            default:
                self.fail(Self.errorMessage(forCloseCode: closeCode.rawValue))
            }
        }
    }

    // MARK: Private

    private static func errorMessage(forCloseCode code: Int) -> String {
        switch code {
        case 1008:
            return "AssemblyAI API key is invalid or unauthorized"
        case 3005:
            return "AssemblyAI server error — please try again"
        case 3007:
            return "AssemblyAI rejected an audio frame (internal chunking error)"
        case 3008:
            return "AssemblyAI session exceeded the 3-hour limit"
        default:
            return "AssemblyAI connection closed unexpectedly (code \(code))"
        }
    }

    /// Send buffered PCM16 as binary frames. Frames must be 50–1000ms (1600–32000
    /// bytes at 16kHz mono); a sub-minimum tail is dropped on forced flush.
    private func flushBufferedAudio(force: Bool) {
        guard case .ready = state else {
            if !force { return }
            sendBuffer = Data()
            return
        }

        while sendBuffer.count >= Self.maxFrameBytes {
            sendFrame(sendBuffer.prefix(Self.maxFrameBytes))
            sendBuffer.removeFirst(Self.maxFrameBytes)
        }

        if force {
            if sendBuffer.count >= Self.minFrameBytes {
                sendFrame(sendBuffer)
            }
            sendBuffer = Data()
        } else if sendBuffer.count >= Self.flushThresholdBytes {
            sendFrame(sendBuffer)
            sendBuffer = Data()
        }
    }

    private func sendFrame(_ data: Data) {
        webSocketTask?.send(.data(Data(data))) { [weak self] error in
            guard let self, let error else { return }
            self.queue.async {
                if case .terminating = self.state { return }
                if case .disconnected = self.state { return }
                self.fail("AssemblyAI audio send failed: \(error.localizedDescription)")
            }
        }
    }

    private func sendControl(_ message: AssemblyAIClientMessage) {
        guard let text = String(data: message.jsonData, encoding: .utf8) else { return }
        webSocketTask?.send(.string(text)) { error in
            if let error {
                logError("AssemblyAIStreamingClient: control send failed: \(error.localizedDescription)")
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
                        self.handleMessage(Data(text.utf8))
                    case .data(let data):
                        self.handleMessage(data)
                    @unknown default:
                        break
                    }
                    self.listenForMessages()

                case .failure(let error):
                    switch self.state {
                    case .disconnected, .terminating:
                        return
                    default:
                        self.fail("AssemblyAI receive failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private func handleMessage(_ data: Data) {
        guard let message = try? AssemblyAIServerMessage.decode(from: data) else {
            logDebug("AssemblyAIStreamingClient[\(label)]: undecodable message (\(data.count) bytes)")
            return
        }

        switch message {
        case .begin:
            if case .connecting = state {
                state = .ready
                flushBufferedAudio(force: false)
            }
        case .unknown(let type):
            logDebug("AssemblyAIStreamingClient[\(label)]: ignoring message type \(type)")
        default:
            break
        }

        onMessage?(message)
    }

    private func fail(_ message: String) {
        state = .failed(message)
        logError("AssemblyAIStreamingClient[\(label)]: \(message)")
        onError?(message)
    }
}
