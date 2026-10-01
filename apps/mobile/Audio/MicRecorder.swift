import AVFoundation
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

/// Room capture for the iPhone app: one microphone stream, resampled to 16 kHz mono PCM16.
///
/// iOS can't tap another app's audio, so this is the only stream there is — everyone in the room
/// arrives mixed together and AssemblyAI's diarization does the splitting (see
/// `MicRecorder+RecordingAudioSource`). There's deliberately no noise gate: the Mac needs one to
/// suppress bleed between its two streams, but here a gate would just clip whoever is sitting
/// furthest from the phone.
///
/// `isRecording` stays true across an interruption or a route change — the engine is rebuilt
/// underneath and the meeting keeps its transcript, with a gap for the seconds the input was gone.
@MainActor
final class MicRecorder: ObservableObject {
    @Published private var recovery = MicrophoneRecoveryState()
    @Published private(set) var permissionState: MicrophonePermissionState = .current()
    /// Recoverable availability errors must not flow into RecordingSession's fatal-error path.
    @Published private(set) var interruptionMessage: String?

    var isRecording: Bool { recovery.isRecording }
    var isInterrupted: Bool { recovery.isInterrupted }
    var canResume: Bool { recovery.canResume }

    /// Emits 16 kHz mono PCM16 chunks. Called from a background audio queue.
    var onPCM16: (@Sendable (Data) -> Void)?

    /// Live input level for the record button. Its own observable — see `InputLevelMeter`.
    let levelMeter = InputLevelMeter()

    private var engine: AVAudioEngine?
    private let session = AudioSessionController()
    private let audioQueue = DispatchQueue(label: "co.blode.convene.mobile.mic")
    private var configurationObserver: NSObjectProtocol?
    private var processor: MicAudioProcessor?
    private var activeEngineID: UUID?
    private var recoveryTask: Task<Void, Never>?

    init() {
        session.onInterruptionBegan = { [weak self] in self?.handleInterruptionBegan() }
        session.onInterruptionEnded = { [weak self] shouldResume in
            self?.handleInterruptionEnded(shouldResume: shouldResume)
        }
        session.onRouteChanged = { [weak self] in self?.handleRouteChanged() }
        session.onMediaServicesReset = { [weak self] in self?.handleMediaServicesReset() }
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

        do {
            try session.activate()
            try startEngine()
        } catch {
            teardownEngine()
            session.deactivate()
            onPCM16 = nil
            throw error
        }
        recovery.start()
        interruptionMessage = nil
        logInfo("MicRecorder: started (16kHz PCM16 mono)")
    }

    /// Witnesses `RecordingAudioSource.stop()`, which the session awaits before draining the
    /// transcriber — hence the synchronous queue flush: the tail of the meeting has to reach the
    /// transcriber before it's told to finish up.
    func stop() {
        guard isRecording else { return }
        // Invalidate retry intent before tearing down. A delayed recovery must never reopen a
        // microphone after Stop/Discard, even if the next meeting has already started.
        recovery.stop()
        cancelRecovery()
        teardownEngine()
        session.deactivate()
        onPCM16 = nil
        interruptionMessage = nil
        logInfo("MicRecorder: stopped")
    }

    #if DEBUG
    /// Report capture as running without an engine, and light the meter, for the App Store
    /// screenshot fixture (`ScreenshotFixture`). No audio session is activated and no tap is
    /// installed, so `stop()` stays safe to call afterwards.
    ///
    /// `level` is fed as an RMS through the meter's own envelope rather than assigned, so the bars
    /// settle exactly where a room at that volume would put them.
    func debugPoseAsCapturing(level rms: Float) {
        recovery.start()
        interruptionMessage = nil
        for _ in 0..<24 { levelMeter.update(rms: rms) }
    }
    #endif

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

        // Tap the input node directly and let `AudioSampleConverter` resample (and downmix, if a
        // route ever hands us more than one channel). Routing through a mixer to force mono first —
        // as the Mac does — buys nothing here, and it's one more connection to fail when the route
        // changes mid-meeting.
        let engineID = UUID()
        activeEngineID = engineID
        let onLevel: @Sendable (Float) -> Void = { [weak self] rms in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self, self.activeEngineID == engineID, !self.isInterrupted,
                        self.isRecording
                    else { return }
                    self.levelMeter.update(rms: rms)
                }
            }
        }
        let processor = MicAudioProcessor(
            captureFormat: inputFormat, queue: audioQueue, onPCM16: onPCM16, onLevel: onLevel
        )
        input.installTap(onBus: 0, bufferSize: MicRecorderConstants.captureBufferSize, format: inputFormat) {
            buffer, _ in
            processor.enqueue(buffer: buffer)
        }

        do {
            engine.prepare()
            try engine.start()
        } catch {
            // The local engine isn't installed on self yet, so ordinary teardown cannot clean
            // up its tap. Drain it here and don't leave an active audio session after failed start.
            activeEngineID = nil
            input.removeTap(onBus: 0)
            engine.stop()
            processor.finish()
            throw error
        }
        self.engine = engine
        self.processor = processor
        observeConfigurationChanges(for: engine)
        logInfo(
            "MicRecorder: engine running at \(Int(inputFormat.sampleRate))Hz/\(inputFormat.channelCount)ch")
    }

    private func teardownEngine() {
        stopConfigurationObserver()
        activeEngineID = nil
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        // Stop accepting callbacks, then deliver queued pre-interruption audio before replacing
        // the processor or finalizing the meeting. Stale callbacks cannot leak into a new session.
        processor?.finish()
        processor = nil
        levelMeter.reset()
    }

    /// The explicit Resume control is also an escape hatch when iOS never sends an ended event.
    /// Reactivation still goes through AVAudioSession, so a call that owns the mic cannot be tapped.
    func resume() {
        guard let token = recovery.resumeRequested() else { return }
        restartEngine(token: token, reason: "user resume")
    }

    /// Rebuild on the current route. Activation can race the system handing hardware back, so
    /// allow a short, bounded settling period instead of ending the entire meeting on one error.
    private func restartEngine(token: UInt64, reason: String) {
        cancelRecovery()
        teardownEngine()
        interruptionMessage = "Reconnecting the microphone… Your meeting is still open."
        recoveryTask = Task { @MainActor [weak self] in
            let retryDelays: [UInt64] = [0, 300_000_000, 1_000_000_000]
            for delay in retryDelays {
                if delay > 0 {
                    do {
                        try await Task.sleep(nanoseconds: delay)
                    } catch {
                        return
                    }
                }
                guard let self, !Task.isCancelled, self.recovery.acceptsRecovery(token) else { return }
                do {
                    // Reapply configuration too: a media-services reset restores session defaults.
                    try self.session.activate()
                    guard !Task.isCancelled, self.recovery.acceptsRecovery(token) else { return }
                    try self.startEngine()
                    guard self.recovery.acceptsRecovery(token) else {
                        self.teardownEngine()
                        return
                    }
                    self.recovery.recoverySucceeded(token)
                    self.interruptionMessage = nil
                    self.recoveryTask = nil
                    logInfo("MicRecorder: engine restarted after \(reason)")
                    return
                } catch {
                    guard self.recovery.acceptsRecovery(token) else { return }
                    self.teardownEngine()
                    logError("MicRecorder: restart after \(reason) failed: \(error.localizedDescription)")
                }
            }
            guard let self, self.recovery.acceptsRecovery(token) else { return }
            self.recovery.recoveryFailed(token)
            self.interruptionMessage =
                "The microphone is unavailable. Resume when the call or other audio has finished."
            self.recoveryTask = nil
        }
    }

    private func cancelRecovery() {
        recoveryTask?.cancel()
        recoveryTask = nil
    }

    // MARK: - System events

    private func handleInterruptionBegan() {
        guard isRecording else { return }
        recovery.interruptionBegan()
        cancelRecovery()
        teardownEngine()
        interruptionMessage =
            "Microphone paused by iOS. Your meeting is still open; audio during this gap isn't recorded."
    }

    private func handleInterruptionEnded(shouldResume: Bool) {
        guard recovery.phase == .interrupted else { return }
        if let token = recovery.interruptionEnded(shouldResume: shouldResume) {
            restartEngine(token: token, reason: "interruption")
        } else {
            interruptionMessage = "The microphone is paused. Tap Resume microphone to continue this meeting."
            logInfo("MicRecorder: interruption ended; waiting for user to resume")
        }
    }

    private func handleRouteChanged() {
        guard let token = recovery.routeChanged() else { return }
        restartEngine(token: token, reason: "route change")
    }

    private func handleMediaServicesReset() {
        guard isRecording else { return }
        recovery.requireUserResume()
        cancelRecovery()
        teardownEngine()
        interruptionMessage = "iOS reset its audio service. Tap Resume microphone to continue this meeting."
    }

    /// Observe only the current engine. An old engine's queued format-change notification must
    /// not tear down its replacement or start a route/configuration restart loop.
    private func observeConfigurationChanges(for engine: AVAudioEngine) {
        stopConfigurationObserver()
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self, weak engine] _ in
            MainActor.assumeIsolated {
                guard let self, let engine, self.engine === engine, !engine.isRunning,
                    let token = self.recovery.routeChanged()
                else { return }
                self.restartEngine(token: token, reason: "engine configuration change")
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

/// Per-engine conversion state. The lock only gates queue submission; conversion is confined to
/// the serial audio queue. Closing the gate before draining accounts for a tap callback already
/// in flight when its engine is removed, without retaining it past the next recording.
private final class MicAudioProcessor: @unchecked Sendable {
    private let captureFormat: AVAudioFormat
    private let converter = AudioSampleConverter()
    private let queue: DispatchQueue
    private let onPCM16: (@Sendable (Data) -> Void)?
    private let onLevel: @Sendable (Float) -> Void
    private let lock = NSLock()
    private var acceptsBuffers = true

    init(
        captureFormat: AVAudioFormat,
        queue: DispatchQueue,
        onPCM16: (@Sendable (Data) -> Void)?,
        onLevel: @escaping @Sendable (Float) -> Void
    ) {
        self.captureFormat = captureFormat
        self.queue = queue
        self.onPCM16 = onPCM16
        self.onLevel = onLevel
    }

    func enqueue(buffer: AVAudioPCMBuffer) {
        // Own the samples before leaving the tap callback rather than relying on the lifetime of
        // AVAudioEngine's supplied storage while conversion waits on another queue.
        guard let owned = Self.copyBuffer(buffer) else { return }
        lock.lock()
        defer { lock.unlock() }
        guard acceptsBuffers else { return }
        queue.async { [self] in
            guard let converted = converter.convert(owned, from: captureFormat),
                let data = AudioSampleConverter.pcm16Data(from: converted)
            else { return }
            onPCM16?(data)
            onLevel(AudioSampleConverter.rms(pcm16: data))
        }
    }

    func finish() {
        lock.lock()
        acceptsBuffers = false
        lock.unlock()
        queue.sync {}
    }

    private static func copyBuffer(_ source: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard source.frameLength > 0,
            let copy = AVAudioPCMBuffer(pcmFormat: source.format, frameCapacity: source.frameLength)
        else { return nil }
        copy.frameLength = source.frameLength
        let sourceBuffers = UnsafeMutableAudioBufferListPointer(source.mutableAudioBufferList)
        let destinationBuffers = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
        guard sourceBuffers.count == destinationBuffers.count else { return nil }
        for index in 0..<sourceBuffers.count {
            let sourceBuffer = sourceBuffers[index]
            let destinationBuffer = destinationBuffers[index]
            guard let sourceData = sourceBuffer.mData, let destinationData = destinationBuffer.mData,
                sourceBuffer.mDataByteSize <= destinationBuffer.mDataByteSize
            else { return nil }
            memcpy(destinationData, sourceData, Int(sourceBuffer.mDataByteSize))
        }
        return copy
    }
}
