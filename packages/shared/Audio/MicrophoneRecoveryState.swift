/// The user's recording intent is separate from temporary microphone availability. An
/// interruption never ends the meeting; only Stop/Discard does. Kept independent of AVFoundation
/// so delayed retries, missing resume hints, and stopped sessions can be tested on either platform.
struct MicrophoneRecoveryState {
    enum Phase: Equatable {
        case idle
        case recording
        case interrupted
        case recovering
        case needsUserResume
    }

    private(set) var phase: Phase = .idle
    private(set) var generation: UInt64 = 0

    var isRecording: Bool { phase != .idle }
    var isInterrupted: Bool { isRecording && phase != .recording }
    var canResume: Bool { phase == .interrupted || phase == .needsUserResume }

    mutating func start() {
        transition(to: .recording)
    }

    mutating func stop() {
        transition(to: .idle)
    }

    mutating func interruptionBegan() {
        guard isRecording else { return }
        transition(to: .interrupted)
    }

    /// A missing `shouldResume` hint requires explicit user intent, not a failed meeting. Ignore
    /// delayed/duplicate end notifications once capture has resumed or the user has stopped it.
    mutating func interruptionEnded(shouldResume: Bool) -> UInt64? {
        guard phase == .interrupted else { return nil }
        transition(to: shouldResume ? .recovering : .needsUserResume)
        return shouldResume ? generation : nil
    }

    mutating func routeChanged() -> UInt64? {
        guard phase == .recording else { return nil }
        transition(to: .recovering)
        return generation
    }

    /// Explicit intent also handles systems that never deliver an interruption-ended event.
    /// `AVAudioSession.setActive` must still succeed before capture may actually restart.
    mutating func resumeRequested() -> UInt64? {
        guard canResume else { return nil }
        transition(to: .recovering)
        return generation
    }

    mutating func requireUserResume() {
        guard isRecording else { return }
        transition(to: .needsUserResume)
    }

    func acceptsRecovery(_ token: UInt64) -> Bool {
        phase == .recovering && generation == token
    }

    mutating func recoverySucceeded(_ token: UInt64) {
        guard acceptsRecovery(token) else { return }
        transition(to: .recording)
    }

    mutating func recoveryFailed(_ token: UInt64) {
        guard acceptsRecovery(token) else { return }
        transition(to: .needsUserResume)
    }

    private mutating func transition(to phase: Phase) {
        generation &+= 1
        self.phase = phase
    }
}
