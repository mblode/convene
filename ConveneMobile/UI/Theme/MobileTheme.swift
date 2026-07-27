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

    /// Diameter of the record button. Big enough to hit without looking at the phone, which is
    /// the position it's usually in — face down or across the table.
    static let recordButtonSize: CGFloat = 88
}

extension Color {
    /// The recording indicator, matched to the Mac app's palette so the two apps read as one.
    static let recordingRed = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0xE8 / 255, green: 0x55 / 255, blue: 0x4A / 255, alpha: 1)
            : UIColor(red: 0xC9 / 255, green: 0x34 / 255, blue: 0x2B / 255, alpha: 1)
    })
}
