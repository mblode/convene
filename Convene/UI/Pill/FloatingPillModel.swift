import Foundation

/// UI state for the floating pill HUD (P3). One state machine, two presentations: the pill is
/// the baseline; on notched displays the same states render docked at the notch. The pill is the
/// *active session* surface — the menu bar stays the passive home/library.
@MainActor
final class FloatingPillModel: ObservableObject {
    enum Mode: Equatable {
        /// Baseline: record dot, timer, and the ⌘K / ⌘? affordances.
        case collapsed
        /// Expanded capture field for annotating the moment just flagged (Dynamic-Island-style).
        case capture
        /// Expanded recap: last few minutes interleaved with flagged moments.
        case recap
    }

    @Published var mode: Mode = .collapsed
    /// Draft annotation text while in `.capture`.
    @Published var captureText: String = ""
    /// Brief confirmation pulse after a bare flag lands.
    @Published var flashFlagConfirmation: Bool = false

    /// The moment a capture field is annotating (flagged the instant capture opened, so a bare
    /// flag survives even if the user dismisses without typing).
    var pendingMomentID: UUID?
}
