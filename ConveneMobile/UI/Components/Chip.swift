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
        .background(Color.iconBadgeBackground, in: Capsule())
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
            .background(Color.iconBadgeBackground, in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }
}

/// Press feedback for the app's custom controls.
///
/// A tint overlay rather than a scale: these sit inside scrolling content, and a control that
/// shrinks under the finger while the list is also moving reads as a glitch. On iOS 26 the glass
/// controls supply their own press response and don't use this.
///
/// Takes the shape so the highlight matches the control it lights up — a capsule's rounded ends
/// cut into a full-width row's text, and a card highlighted as a rectangle bleeds past its corners.
struct PressableStyle<S: Shape>: ButtonStyle {
    let shape: S

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ shape: S) {
        self.shape = shape
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                if configuration.isPressed {
                    shape.fill(Color.pressedOverlay)
                }
            }
            .animation(reduceMotion ? nil : MobileTheme.Motion.quiet, value: configuration.isPressed)
    }
}

extension PressableStyle where S == Capsule {
    /// The common case: chips and pills.
    init() {
        self.init(Capsule())
    }
}
