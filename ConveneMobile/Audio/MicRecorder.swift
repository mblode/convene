// @preconcurrency: tap buffers are handed to the audio queue for conversion, and AVAudioPCMBuffer
// predates Sendable. Matches how the Mac's MicCapture imports it.
@preconcurrency import AVFoundation
import Foundation

enum MicRecorderConstants {
    static let captureBufferSize: AVAudioFrameCount = 1024
}

enum MicrophonePermissionState {
    case undetermined, granted, denied

    static func current() -> MicrophonePermissionState {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return .granted
        case .denied: return .denied
        case .undetermined: return .undetermined
        @unknown default: return .denied
        }
    }
}

/// Room capture for the iPhone app: one microphone stream resampled to 16 kHz mono PCM16.
///
/// Unlike the Mac, iOS can't tap another app's audio, so this is the only stream there is —
/// everyone in the room arrives mixed together and AssemblyAI's diarization does the splitting
/// (see `MicRecorder+RecordingAudioSource`). There's deliberately no noise gate: the Mac needs one
/// to suppress speaker bleed between its two streams, but here a gate would just clip whoever is
/// sitting furthest from the phone.
///
/// `isRecording` stays true across an interruption or a route change — the engine is rebuilt
/// underneath and the meeting keeps its transcript, with a gap for the seconds the input was gone.
@MainActor
final class MicRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var permissionState: MicrophonePermissionState = .current()
    @Published private(set) var lastError: String?
    /// True while the system holds the input (a call, Siri). Capture resumes on its own.
    @Published private(set) var isInterrupted = false

    /// Emits 16 kHz mono PCM16 chunks. Called from a background audio queue.
    var onPCM16: (@Sendable (Data) -> Void)?

    private var engine: AVAudioEngine?
    private let session = AudioSessionController()
    private let audioQueue = DispatchQueue(label: "co.blode.convene.mobile.mic")
    private var configurationObserver: NSObjectProtocol?

    init() {
        session.onInterruptionBegan = { [weak self] in self?.handleInterruptionBegan() }
        session.onInterruptionEnded = { [weak self] shouldResume in
            self?.handleInterruptionEnded(shouldResume: shouldResume)
        }
        session.onRouteChanged = { [weak self] in self?.handleRouteChanged() }
    }

    // MARK: - Permission

    func refreshPermission() {
        permissionState = .current()
    }

    func requestPermission() async -> Bool {
        if permissionState == .granted { return true }
        let granted = await AVAudioApplication.requestRecordPermission()
        permissionState = granted ? .granted : .denied
        return granted
    }

    // MARK: - Lifecycle

    func start() throws {
        guard !isRecording else { return }
        guard permissionState == .granted else {
            throw NSError(
                domain: "co.blode.convene.mobile.mic",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Microphone access is off for Convene"]
            )
        }

        try session.activate()
        do {
            try startEngine()
        } catch {
            // Don't leave the session holding the input after a failed start — the next attempt
            // (and every other app) needs it back.
            session.deactivate()
            throw error
        }
        observeConfigurationChanges()
        isRecording = true
        isInterrupted = false
        lastError = nil
        logInfo("MicRecorder: started (16kHz PCM16 mono)")
    }

    /// Satisfies `RecordingAudioSource.stop()`, which the session awaits before draining the
    /// transcriber — hence the synchronous flush inside `tearDownCapture`: the tail of the meeting
    /// has to reach the transcriber before it's told to finish.
    func stop() {
        guard isRecording else { return }
        tearDownCapture()
        logInfo("MicRecorder: stopped")
    }

    private func tearDownCapture() {
        stopConfigurationObserver()
        tearDownEngine()
        audioQueue.sync {}
        session.deactivate()
        isRecording = false
        isInterrupted = false
    }

    /// Give up on the in-flight recording. Capture is torn down *before* `lastError` is published,
    /// because the store hands that error to the session — which finalises the meeting without
    /// calling `stop()` itself, and would otherwise leave the session active and `isCapturing`
    /// stuck true with no meeting behind it.
    private func failCapture(_ message: String) {
        tearDownCapture()
        lastError = message
        logError("MicRecorder: \(message)")
    }

    // MARK: - Engine

    private func startEngine() throws {
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.channelCount > 0, inputFormat.sampleRate > 0 else {
            throw NSError(
                domain: "co.blode.convene.mobile.mic",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "The microphone reported an unusable audio format"]
            )
        }

        // Tap the input node directly and let `AudioSampleConverter` resample (and downmix, if the
        // route ever hands us more than one channel). Routing through a mixer to force mono first
        // buys nothing here — iPhone inputs are mono — and an extra connect is one more thing to
        // fail when the route changes mid-meeting.
        let processor = MicAudioProcessor(captureFormat: inputFormat)
        let sink = onPCM16
        let queue = audioQueue

        input.installTap(onBus: 0, bufferSize: MicRecorderConstants.captureBufferSize, format: inputFormat) { buffer, _ in
            queue.async { processor.process(buffer: buffer, onPCM16: sink) }
        }

        engine.prepare()
        try engine.start()
        self.engine = engine
        logInfo("MicRecorder: engine running at \(Int(inputFormat.sampleRate))Hz/\(inputFormat.channelCount)ch")
    }

    private func tearDownEngine() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
    }

    /// Rebuild the engine on the current route. Used after an interruption or a device change:
    /// the old engine's cached input format no longer matches the hardware.
    private func restartEngine(reason: String) {
        guard isRecording else { return }
        tearDownEngine()
        do {
            try session.reactivate()
            try startEngine()
            isInterrupted = false
            lastError = nil
            logInfo("MicRecorder: engine restarted after \(reason)")
        } catch {
            // Surfaced to the store, which hands it to the session so the meeting is saved with
            // whatever was transcribed before the input went away.
            failCapture("Recording stopped — the microphone became unavailable (\(error.localizedDescription))")
        }
    }

    // MARK: - System events

    private func handleInterruptionBegan() {
        guard isRecording else { return }
        isInterrupted = true
        tearDownEngine()
    }

    private func handleInterruptionEnded(shouldResume: Bool) {
        guard isRecording else { return }
        guard shouldResume else {
            // The system declined to hand the input back — usually because the interrupting app
            // is still holding it. End the meeting rather than let it record silence.
            failCapture("Recording stopped — another app took over the microphone")
            return
        }
        restartEngine(reason: "interruption")
    }

    private func handleRouteChanged() {
        guard isRecording, !isInterrupted else { return }
        restartEngine(reason: "route change")
    }

    /// `AVAudioEngineConfigurationChange` fires when the engine's own hardware format shifts
    /// (e.g. the sample rate changes with the route). The engine is stopped when it arrives.
    private func observeConfigurationChanges() {
        guard configurationObserver == nil else { return }
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isRecording, !self.isInterrupted else { return }
                self.restartEngine(reason: "engine configuration change")
            }
        }
    }

    private func stopConfigurationObserver() {
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
        }
        configurationObserver = nil
    }
}

/// Per-stream conversion state, confined to the audio dispatch queue.
private final class MicAudioProcessor: @unchecked Sendable {
    private let captureFormat: AVAudioFormat
    private let converter = AudioSampleConverter()

    init(captureFormat: AVAudioFormat) {
        self.captureFormat = captureFormat
    }

    func process(buffer: AVAudioPCMBuffer, onPCM16: (@Sendable (Data) -> Void)?) {
        guard let onPCM16,
              let converted = converter.convert(buffer, from: captureFormat),
              let data = AudioSampleConverter.pcm16Data(from: converted)
        else { return }
        onPCM16(data)
    }
}
