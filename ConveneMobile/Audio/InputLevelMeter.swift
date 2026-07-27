import Foundation

/// Live microphone level, 0...1, for the record button's halo.
///
/// Deliberately kept off `MicRecorder`'s own published state. The store rebroadcasts the recorder's
/// changes, so a level published there would re-render the entire recording screen — transcript
/// included — around 45 times a second. On its own observable, only the halo redraws.
@MainActor
final class InputLevelMeter: ObservableObject {
    @Published private(set) var level: Float = 0

    /// Speech sits roughly between -50 dBFS and 0 dBFS on a phone mic a metre or two away.
    /// Anything below the floor is room tone and should read as silence.
    private let floorDecibels: Float = -50

    /// Rises quickly so the halo catches the start of a word, falls slowly so it doesn't strobe
    /// in the gaps between syllables.
    private let attack: Float = 0.35
    private let release: Float = 0.12

    func update(rms: Float) {
        let decibels = 20 * log10(max(rms, 1e-7))
        let normalized = min(max((decibels - floorDecibels) / -floorDecibels, 0), 1)
        level += (normalized - level) * (normalized > level ? attack : release)
    }

    func reset() {
        level = 0
    }
}
