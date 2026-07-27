import Foundation

extension MicRecorder: RecordingAudioSource {
    var isCapturing: Bool { isRecording }

    var permissionFailureMessage: String? {
        switch permissionState {
        case .denied:
            return "Microphone access is off. Turn it on in Settings › Convene to record."
        case .undetermined, .granted:
            // Granted-but-failed means the request itself errored; the recorder's own message
            // is the more specific one in that case.
            return lastError ?? "Microphone access is required to record."
        }
    }

    func requestPermissions() async -> Bool {
        await requestPermission()
    }

    /// Begin capture, labelling every chunk `.others`.
    ///
    /// A phone on the table hears the whole room through one microphone, so there is no "your
    /// side" to separate out the way the Mac app does — every voice, including the user's, lands
    /// on this single stream. `.others` is the stream the transcriber requests speaker labels
    /// for, so mapping the mic to it is what turns the mix into "Speaker A"/"Speaker B" instead
    /// of one undifferentiated wall of text.
    func start(onPCM16: @escaping (TranscriptSegment.Speaker, Data) -> Void) async throws {
        self.onPCM16 = { data in onPCM16(.others, data) }
        try start()
    }
}
