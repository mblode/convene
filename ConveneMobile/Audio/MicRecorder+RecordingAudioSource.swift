import Foundation

extension MicRecorder: RecordingAudioSource {
    var isCapturing: Bool { isRecording }
    var permissionFailureMessage: String? { "Microphone permission required" }

    func requestPermissions() async -> Bool {
        await requestPermission()
    }

    /// Wire the session's PCM16 sink (the mic is always the local speaker) and begin capture.
    func start(onPCM16: @escaping (TranscriptSegment.Speaker, Data) -> Void) async throws {
        self.onPCM16 = { data in onPCM16(.you, data) }
        try start()
    }
}
