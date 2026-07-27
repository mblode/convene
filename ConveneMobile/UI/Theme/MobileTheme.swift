import SwiftUI

enum MobileTheme {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }

    enum Radius {
        static let card: CGFloat = 14
    }

    enum Motion {
        /// Critically damped — reaches the target and stops, no overshoot. This is the only spring
        /// in the app, deliberately.
        ///
        /// Overshoot is how you show that motion inherited momentum from a gesture: a flicked card
        /// should sail past and settle back. Nothing here is dragged or flicked — every transition
        /// starts from a tap — so bounce would be decoration pretending to be physics.
        static let standard = Animation.spring(duration: 0.35, bounce: 0)
    }
}

extension Color {
    /// The recording indicator, matched to the Mac app's palette so the two read as one product.
    static let recordingRed = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0xE8 / 255, green: 0x55 / 255, blue: 0x4A / 255, alpha: 1)
                : UIColor(red: 0xC9 / 255, green: 0x34 / 255, blue: 0x2B / 255, alpha: 1)
        })
}
