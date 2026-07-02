import Foundation

extension AudioCaptureCoordinator: RecordingAudioSource {
    var permissionFailureMessage: String? { startError }

    /// Wire the session's PCM16 sink (mapping each stream to its transcript speaker) and begin
    /// capture. Does not throw — a failure leaves `isCapturing` false with `startError` set, which
    /// the store's `$startError` sink surfaces; the session's post-start check handles cleanup.
    func start(onPCM16: @escaping (TranscriptSegment.Speaker, Data) -> Void) async {
        self.onPCM16 = { stream, data in onPCM16(stream.transcriptSpeaker, data) }
        await start()
    }
}

extension AudioCaptureCoordinator.SpeakerStream {
    var transcriptSpeaker: TranscriptSegment.Speaker {
        switch self {
        case .you: return .you
        case .others: return .others
        }
    }
}
