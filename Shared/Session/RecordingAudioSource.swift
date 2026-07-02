import Foundation

/// A capture backend the recording session drives. macOS uses the dual-stream
/// `AudioCaptureCoordinator` (mic = .you, system audio = .others); iOS uses the single-stream
/// `MicRecorder` (mic = .you). The session owns the transcriber and feeds it the labeled PCM16
/// chunks this source emits.
@MainActor
protocol RecordingAudioSource: AnyObject {
    var isCapturing: Bool { get }

    /// Prompt for (or confirm) capture permissions. On failure, `permissionFailureMessage`
    /// carries a user-facing reason.
    func requestPermissions() async -> Bool

    /// A user-facing reason capture couldn't be permitted, valid after `requestPermissions()`
    /// returns false.
    var permissionFailureMessage: String? { get }

    /// Begin capture, delivering labeled PCM16 chunks until `stop()`. Throws if capture can't
    /// start; the thrown error's `localizedDescription` is surfaced to the user.
    func start(onPCM16: @escaping (TranscriptSegment.Speaker, Data) -> Void) async throws

    func stop() async
}

/// A meeting persistence backend. Both platform services already match this shape.
@MainActor
protocol MeetingPersisting: AnyObject {
    @discardableResult
    func save(_ meeting: Meeting) -> URL?
    var lastError: String? { get }
    /// True when the last save fell back to a local folder instead of the configured one.
    var lastUsedFallback: Bool { get }
}
