import SwiftUI

/// A pill of metadata: a date, a duration, a key-moment count.
///
/// Chips are read at a glance and never alone — a row of them under a title is how a meeting says
/// what it is. They are deliberately not buttons; `ChipButton` below is the interactive sibling, so
/// that "looks tappable" and "is tappable" never come apart.
struct Chip: View {
    let text: String
    var systemImage: String?
    var tint: Color = .textSecondary

    var body: some View {
        HStack(spacing: MobileTheme.Spacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
            }
            Text(text)
        }
        .typeStyle(.chip)
        .foregroundStyle(tint)
        .padding(.horizontal, MobileTheme.Spacing.md)
        .padding(.vertical, MobileTheme.Spacing.sm)
        .background(Color.chipBackground, in: Capsule())
    }
}

/// A chip that does something — "Transcript", "Add to folder".
///
/// Sized to a 44pt minimum height so it stays a legitimate touch target at the smallest text size,
/// where the chip's own padding would otherwise leave it around 32pt.
struct ChipButton: View {
    let text: String
    var systemImage: String?
    var tint: Color = .textPrimary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MobileTheme.Spacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .imageScale(.small)
                }
                Text(text)
            }
            .typeStyle(.chip)
            .foregroundStyle(tint)
            .padding(.horizontal, MobileTheme.Spacing.lg)
            .frame(minHeight: 44)
            .background(Color.chipBackground, in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }
}

/// Press feedback for the app's custom controls.
///
/// A tint overlay rather than a scale: these sit inside scrolling content, and a control that
/// shrinks under the finger while the list is also moving reads as a glitch. On iOS 26 the glass
/// controls supply their own press response and don't use this.
struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                if configuration.isPressed {
                    Capsule().fill(Color.pressedOverlay)
                }
            }
            .animation(reduceMotion ? nil : MobileTheme.Motion.quiet, value: configuration.isPressed)
    }
}
