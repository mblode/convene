import Foundation

/// Drops mic chunks that are likely just the remote speaker bleeding from the laptop
/// speakers into the mic. AEC is deliberately disabled in MicCapture (VoiceProcessingIO
/// ducks system audio), so without this the remote side gets transcribed twice — once
/// from system capture and again as "You" from the mic.
///
/// Heuristic: while system audio is active (held briefly past the last loud system
/// chunk), mic chunks quieter than ~1.5× the recent system level are treated as bleed
/// and dropped. Loud near-field user speech still passes during double-talk because
/// the user's voice at the mic is much hotter than speaker bleed.
///
/// MainActor-confined: both capture streams hop to the main actor in
/// AudioCaptureCoordinator before reaching this type, so no locking is needed.
@MainActor
final class CrossStreamGate {
    private enum Constants {
        /// How long system audio is considered "active" after a loud chunk.
        static let systemHoldTime: TimeInterval = 0.6
        /// System RMS below this (normalized 0...1) is treated as silence/noise floor.
        static let systemRMSFloor: Float = 0.004
        /// Mic must beat recentSystemRMS by this ratio to pass while system is active.
        static let micPassRatio: Float = 1.5
        /// Time constant for the exponential decay of recentSystemRMS.
        static let systemRMSDecayTau: TimeInterval = 0.5
    }

    private var systemActiveUntil = Date.distantPast
    private var recentSystemRMS: Float = 0
    private var lastSystemUpdate = Date.distantPast

    #if DEBUG
    private var droppedChunkCount = 0
    private var passedChunkCount = 0
    #endif

    /// Feed every system-audio PCM16 chunk through here (whether or not the mic is gated).
    func observeSystemChunk(_ pcm16: Data) {
        let rms = AudioSampleConverter.rms(pcm16: pcm16)
        let now = Date()

        // Exponentially decay the tracked system level toward zero between loud chunks.
        if lastSystemUpdate != .distantPast {
            let dt = now.timeIntervalSince(lastSystemUpdate)
            recentSystemRMS *= Float(exp(-dt / Constants.systemRMSDecayTau))
        }
        lastSystemUpdate = now

        // Near-silent system audio (idle Zoom, noise floor) shouldn't gate the mic.
        guard rms >= Constants.systemRMSFloor else { return }

        systemActiveUntil = now.addingTimeInterval(Constants.systemHoldTime)
        recentSystemRMS = max(recentSystemRMS, rms)
    }

    /// Returns true when the mic chunk should be dropped (not forwarded to transcription).
    func shouldDropMicChunk(_ pcm16: Data) -> Bool {
        let systemActive = Date() <= systemActiveUntil
        var drop = false
        if systemActive, recentSystemRMS > 0 {
            let micRMS = AudioSampleConverter.rms(pcm16: pcm16)
            drop = micRMS < Constants.micPassRatio * recentSystemRMS
        }

        #if DEBUG
        if drop {
            droppedChunkCount += 1
            if droppedChunkCount % 100 == 0 {
                logInfo("CrossStreamGate: dropped \(droppedChunkCount) mic chunks so far (passed \(passedChunkCount)) recentSystemRMS=\(recentSystemRMS)")
            }
        } else {
            passedChunkCount += 1
        }
        #endif

        return drop
    }
}
