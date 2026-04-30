import Foundation
import Combine

/// Owns two `LiveTranscriptionStream` instances (one per speaker stream) and merges their
/// segment events into a single ordered `[TranscriptSegment]` keyed by start time.
///
/// Server item ids only correlate within a single stream, so we key our segment table by
/// `(speaker, serverItemId)` while exposing a sorted, time-ordered snapshot for the UI.
@MainActor
final class TranscriptionCoordinator: ObservableObject {
    @Published private(set) var segments: [TranscriptSegment] = []
    @Published private(set) var isRunning = false
    @Published private(set) var lastError: String?

    private let youStream = LiveTranscriptionStream()
    private let othersStream = LiveTranscriptionStream()

    /// Wall-clock time of when the meeting started — used as the `startedAt` reference.
    private var meetingStartedAt: Date?

    /// Authoritative segment table keyed by `mergeKey(speaker, serverItemId)`.
    private var segmentTable: [String: TranscriptSegment] = [:]

    init() {
        wire(stream: youStream, speaker: .you)
        wire(stream: othersStream, speaker: .others)
    }

    func start(apiKey: String, model: String, language: String) {
        guard !isRunning else { return }
        guard !apiKey.isEmpty else {
            lastError = "API key required"
            return
        }
        lastError = nil
        segments = []
        segmentTable = [:]
        meetingStartedAt = Date()
        youStream.connect(apiKey: apiKey, model: model, language: language)
        othersStream.connect(apiKey: apiKey, model: model, language: language)
        isRunning = true
        logInfo("TranscriptionCoordinator: started (model=\(model))")
    }

    /// Commit the in-flight audio buffers so the server emits completion events for the last
    /// utterances, wait briefly, then tear the WebSockets down.
    func stop() async {
        guard isRunning else { return }
        youStream.commitPendingAudio()
        othersStream.commitPendingAudio()
        // Give the server time to emit the final transcription.completed events.
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        youStream.disconnect()
        othersStream.disconnect()
        isRunning = false
        logInfo("TranscriptionCoordinator: stopped")
    }

    /// Route an audio chunk from `AudioCaptureCoordinator` to the right stream.
    func ingest(speaker: AudioCaptureCoordinator.SpeakerStream, pcm16: Data) {
        guard isRunning else { return }
        switch speaker {
        case .you: youStream.sendAudioChunk(pcm16)
        case .others: othersStream.sendAudioChunk(pcm16)
        }
    }

    func snapshot() -> [TranscriptSegment] { segments }

    // MARK: - Stream callbacks

    private func wire(stream: LiveTranscriptionStream, speaker: TranscriptSegment.Speaker) {
        stream.onSegmentStarted = { [weak self] segmentId, audioStartMs in
            Task { @MainActor in
                self?.handleStarted(speaker: speaker, serverItemId: segmentId, audioStartMs: audioStartMs)
            }
        }
        stream.onSegmentDelta = { [weak self] segmentId, delta in
            Task { @MainActor in
                self?.handleDelta(speaker: speaker, serverItemId: segmentId, delta: delta)
            }
        }
        stream.onSegmentCompleted = { [weak self] segmentId, finalText, audioEndMs in
            Task { @MainActor in
                self?.handleCompleted(speaker: speaker, serverItemId: segmentId, finalText: finalText, audioEndMs: audioEndMs)
            }
        }
        stream.onError = { [weak self] error in
            Task { @MainActor in
                self?.lastError = error.localizedDescription
                logError("TranscriptionCoordinator: stream error: \(error.localizedDescription)")
            }
        }
    }

    private func handleStarted(speaker: TranscriptSegment.Speaker, serverItemId: String, audioStartMs: Int) {
        let key = mergeKey(speaker: speaker, serverItemId: serverItemId)
        guard segmentTable[key] == nil else { return }
        let started = TimeInterval(audioStartMs) / 1000.0
        let segment = TranscriptSegment(
            speaker: speaker,
            startedAt: started,
            endedAt: started,
            text: "",
            isFinal: false
        )
        segmentTable[key] = segment
        publishSorted()
    }

    private func handleDelta(speaker: TranscriptSegment.Speaker, serverItemId: String, delta: String) {
        let key = mergeKey(speaker: speaker, serverItemId: serverItemId)
        if var segment = segmentTable[key] {
            segment.text += delta
            segmentTable[key] = segment
        } else {
            // Delta arrived before speech_started — synthesize a segment.
            let now = relativeNow()
            let segment = TranscriptSegment(
                speaker: speaker, startedAt: now, endedAt: now, text: delta, isFinal: false
            )
            segmentTable[key] = segment
        }
        publishSorted()
    }

    private func handleCompleted(speaker: TranscriptSegment.Speaker, serverItemId: String, finalText: String, audioEndMs: Int?) {
        let key = mergeKey(speaker: speaker, serverItemId: serverItemId)
        if var segment = segmentTable[key] {
            if !finalText.isEmpty { segment.text = finalText }
            segment.isFinal = true
            if let endMs = audioEndMs { segment.endedAt = TimeInterval(endMs) / 1000.0 }
            segmentTable[key] = segment
        } else {
            let now = relativeNow()
            let segment = TranscriptSegment(
                speaker: speaker, startedAt: now, endedAt: now, text: finalText, isFinal: true
            )
            segmentTable[key] = segment
        }
        publishSorted()
    }

    private func mergeKey(speaker: TranscriptSegment.Speaker, serverItemId: String) -> String {
        "\(speaker.rawValue):\(serverItemId)"
    }

    private func relativeNow() -> TimeInterval {
        guard let start = meetingStartedAt else { return 0 }
        return Date().timeIntervalSince(start)
    }

    private func publishSorted() {
        segments = segmentTable.values.sorted { $0.startedAt < $1.startedAt }
    }
}
