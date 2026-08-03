import SwiftUI

/// The app's type scale.
///
/// SF Pro throughout — no bundled faces. With one typeface doing every job, hierarchy has to come
/// from weight, size, tracking and whitespace, so each role below fixes all of them together and
/// views never set `.font` directly.
///
/// Two rules the roles encode:
///
/// * **Text styles wherever they reach.** Most roles are built from a `Font.TextStyle`, so they
///   scale with Dynamic Type for free. `Font.system(size:)` does not scale on its own, so the two
///   roles that need to outgrow `.largeTitle` — `display` and `timer` — are driven by
///   `@ScaledMetric(relativeTo: .largeTitle)` in `TypeStyleModifier` instead. (`.extraLargeTitle`
///   would be the obvious answer and is unavailable on iOS; it is macOS-only.)
/// * **Tracking tightens as size grows.** SF's built-in tracking is tuned per optical size, but
///   large text set at the default still reads loose; display sizes pull in, small chip text pushes
///   out slightly so it doesn't set solid.
///
/// `.lineSpacing` in SwiftUI is *additive* leading in points on top of the font's own line height —
/// not a CSS-style multiplier. The values below are small for that reason.
extension MobileTheme {
    enum TypeRole {
        /// A saved meeting's title. The largest type in the app.
        case display
        /// The root list's screen title.
        case title
        /// A meeting card's title, and the recording sheet's editable title.
        case cardTitle
        /// Section headings inside a note — "Key points", "Transcript".
        case section
        /// Summary prose, notes, transcript body.
        case body
        /// Body weight-bumped for emphasis, e.g. a checklist row's label.
        case bodyEmphasis
        /// Pill metadata: date, duration, key-moment count.
        case chip
        /// Supporting text under a control or card.
        case caption
        /// The elapsed readout while recording.
        case timer
        /// Transcript and key-moment timestamps.
        case mono

        /// Point size for the two roles that outgrow `.largeTitle`, scaled relative to it.
        /// `nil` for every role that a text style already covers.
        var scaledSize: CGFloat? {
            switch self {
            case .display: 40
            case .timer: 56
            default: nil
            }
        }

        /// The font for roles a text style covers. `display` and `timer` are built in
        /// `TypeStyleModifier` from `scaledSize` and are unreachable here.
        var textStyleFont: Font {
            switch self {
            case .title: .system(.largeTitle, design: .default, weight: .bold)
            case .cardTitle: .system(.headline, design: .default, weight: .semibold)
            case .section: .system(.subheadline, design: .default, weight: .semibold)
            case .body: .system(.body)
            case .bodyEmphasis: .system(.body, design: .default, weight: .medium)
            case .chip: .system(.footnote, design: .default, weight: .medium)
            case .caption: .system(.caption)
            case .mono: .system(.caption, design: .monospaced)
            case .display: .system(.largeTitle, design: .default, weight: .bold)
            case .timer: .system(.largeTitle, design: .rounded, weight: .medium).monospacedDigit()
            }
        }

        /// `.rounded` is reserved for numerals — the elapsed timer and level readouts — which is
        /// where the app already used it. Prose stays `.default`; mixing the two in running text
        /// reads as two different apps.
        var design: Font.Design {
            self == .timer ? .rounded : .default
        }

        var weight: Font.Weight {
            switch self {
            case .display: .bold
            case .timer: .medium
            default: .regular
            }
        }

        var tracking: CGFloat {
            switch self {
            case .display: -1.0
            case .title: -0.6
            case .cardTitle: -0.2
            case .timer: -1.4
            // Footnote-sized text at a semibold-ish weight closes up; a touch of positive tracking
            // keeps a chip legible at a glance mid-meeting.
            case .chip: 0.2
            case .section, .body, .bodyEmphasis, .caption, .mono: 0
            }
        }

        /// Additive leading. Prose gets a little air; display type and single-line furniture get
        /// none, because the font's own line height is already right for them.
        var lineSpacing: CGFloat {
            switch self {
            case .body, .bodyEmphasis: 3
            case .section: 1
            case .display, .title, .cardTitle, .chip, .caption, .timer, .mono: 0
            }
        }

        /// Where a role stops growing.
        ///
        /// Body copy is never capped — an accessibility text size is a stated need, and prose can
        /// reflow to meet it. The display roles are a different case: at AX5 a 40pt title eats the
        /// whole screen before the content it names, so they stop at `.accessibility3` and let the
        /// body keep climbing past them.
        var dynamicTypeCeiling: DynamicTypeSize {
            switch self {
            case .display, .title, .timer: .accessibility3
            case .cardTitle: .accessibility4
            case .section, .body, .bodyEmphasis, .chip, .caption, .mono: .accessibility5
            }
        }
    }
}

/// Applies a role's font, tracking, leading and Dynamic Type ceiling together.
///
/// A `ViewModifier` rather than a plain `View` extension because `display` and `timer` need
/// `@ScaledMetric`, which only resolves inside a view's own environment.
struct TypeStyleModifier: ViewModifier {
    let role: MobileTheme.TypeRole

    @ScaledMetric(relativeTo: .largeTitle) private var displaySize: CGFloat = 40
    @ScaledMetric(relativeTo: .largeTitle) private var timerSize: CGFloat = 56

    func body(content: Content) -> some View {
        content
            .font(font)
            .tracking(role.tracking)
            .lineSpacing(role.lineSpacing)
            .dynamicTypeSize(...role.dynamicTypeCeiling)
    }

    private var font: Font {
        switch role {
        case .display:
            .system(size: displaySize, weight: role.weight, design: role.design)
        case .timer:
            .system(size: timerSize, weight: role.weight, design: role.design).monospacedDigit()
        default:
            role.textStyleFont
        }
    }
}

extension View {
    /// Applies a type role.
    ///
    /// One modifier rather than four so a role can't be half-applied — the most common way a type
    /// scale rots is a view that takes the font and forgets the tracking.
    func typeStyle(_ role: MobileTheme.TypeRole) -> some View {
        modifier(TypeStyleModifier(role: role))
    }
}
