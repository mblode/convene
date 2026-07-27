import AVFoundation
import Foundation

/// Owns the `AVAudioSession` for the duration of a recording: category setup, activation, and the
/// two system events that silently kill capture if nothing handles them — an interruption (an
/// incoming call, Siri) and a route change (AirPods pulled out mid-meeting). Both surface as
/// callbacks so `MicRecorder` can rebuild its engine instead of the meeting quietly going deaf.
@MainActor
final class AudioSessionController {
    /// The system took the input away. The engine is already stopped by the time this fires.
    var onInterruptionBegan: (() -> Void)?
    /// The interruption cleared. `shouldResume` is the system's hint that it's safe to restart.
    var onInterruptionEnded: ((_ shouldResume: Bool) -> Void)?
    /// The input route changed in a way that invalidates the running engine.
    var onRouteChanged: (() -> Void)?

    private var observers: [NSObjectProtocol] = []

    /// Configure and activate the session. Call before touching `AVAudioEngine.inputNode`: until
    /// the session is active, the input node reports a zero-channel format.
    func activate() throws {
        let session = AVAudioSession.sharedInstance()
        // `.record` rather than `.playAndRecord`: Convene never plays anything back, so there's no
        // reason to take the output route (and the ducking that comes with it).
        //
        // Bluetooth input is deliberately not enabled. Routing to a headset would drop capture to
        // the 8/16 kHz HFP path and pick up only whoever is wearing it — the opposite of what a
        // phone sitting in the middle of the table needs. The built-in mic array is the better
        // instrument for a room, so let it stay the input even when AirPods are connected.
        try session.setCategory(.record, mode: .default)
        try session.setActive(true)
        startObserving()
        logInfo("AudioSessionController: session active (\(routeDescription()))")
    }

    /// Reactivate after an interruption, without re-running category setup.
    func reactivate() throws {
        try AVAudioSession.sharedInstance().setActive(true)
        logInfo("AudioSessionController: session reactivated (\(routeDescription()))")
    }

    func deactivate() {
        stopObserving()
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            // Non-fatal: recording has already stopped, so this only means other apps get the
            // input back a moment later than intended.
            logError("AudioSessionController: deactivate failed: \(error.localizedDescription)")
        }
    }

    /// A short description of the current input route, for logs.
    func routeDescription() -> String {
        let inputs = AVAudioSession.sharedInstance().currentRoute.inputs
        guard !inputs.isEmpty else { return "no input" }
        return inputs.map { "\($0.portName) [\($0.portType.rawValue)]" }.joined(separator: ", ")
    }

    // MARK: - System notifications

    private func startObserving() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()

        observers.append(
            center.addObserver(
                forName: AVAudioSession.interruptionNotification, object: session, queue: .main
            ) { [weak self] note in
                MainActor.assumeIsolated { self?.handleInterruption(note) }
            }
        )

        observers.append(
            center.addObserver(forName: AVAudioSession.routeChangeNotification, object: session, queue: .main)
            { [weak self] note in
                MainActor.assumeIsolated { self?.handleRouteChange(note) }
            }
        )
    }

    private func stopObserving() {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers = []
    }

    private func handleInterruption(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: raw)
        else { return }

        switch type {
        case .began:
            logInfo("AudioSessionController: interruption began")
            onInterruptionBegan?()
        case .ended:
            let optionsRaw = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let shouldResume = AVAudioSession.InterruptionOptions(rawValue: optionsRaw).contains(
                .shouldResume)
            logInfo("AudioSessionController: interruption ended (shouldResume=\(shouldResume))")
            onInterruptionEnded?(shouldResume)
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: raw)
        else { return }

        switch reason {
        case .oldDeviceUnavailable, .newDeviceAvailable, .override:
            // The input hardware changed, so the engine's cached format is stale. Every other
            // reason (a category change we made ourselves, a wake from sleep) leaves capture fine.
            logInfo("AudioSessionController: route changed -> \(routeDescription())")
            onRouteChanged?()
        default:
            break
        }
    }
}
