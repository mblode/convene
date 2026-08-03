import SwiftUI

enum MobileTheme {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        /// Between a screen's title and the first thing under it, and between major sections of a
        /// note. The scale's top end is what makes the app read as unhurried.
        static let xxl: CGFloat = 40
    }

    enum Radius {
        static let card: CGFloat = 14
        /// Fully-rounded pills — chips, the FAB, the live recording indicator. Large enough that
        /// any control shorter than 200pt resolves to a capsule.
        static let pill: CGFloat = 999
    }

    enum Motion {
        /// Critically damped — reaches the target and stops, no overshoot. The workhorse.
        ///
        /// Overshoot is how you show that motion inherited momentum from a gesture: a flicked card
        /// should sail past and settle back. Almost nothing here is dragged or flicked — nearly
        /// every transition starts from a tap — so bounce would be decoration pretending to be
        /// physics. `sheet` below is the one exception, and it earns it.
        static let standard = Animation.spring(duration: 0.35, bounce: 0)

        /// The recording sheet's own entry and exit.
        ///
        /// This is the one place bounce is honest: the sheet is draggable, so the user *will* flick
        /// it, and a surface that stops dead when thrown reads as broken rather than as calm. Kept
        /// small — this is momentum, not personality.
        static let sheet = Animation.spring(duration: 0.42, bounce: 0.18)

        /// State changes that shouldn't draw the eye: a chip's label updating, a checklist row
        /// ticking off, a banner swapping text.
        static let quiet = Animation.easeInOut(duration: 0.2)
    }
}

extension View {
    /// The standard card surface: fill, hairline, corner radius.
    ///
    /// A modifier rather than a wrapper view so it composes with `NavigationLink`, context menus and
    /// button styles without adding a layout container each time.
    func cardSurface() -> some View {
        background(Color.cardBackground, in: RoundedRectangle(cornerRadius: MobileTheme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: MobileTheme.Radius.card)
                    .strokeBorder(Color.cardBorder, lineWidth: 1)
            )
    }
}
