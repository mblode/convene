import AppKit
import SwiftUI

extension Color {
    static let appBackground         = dynamic(light: 0xFFFFFF, dark: 0x000000)
    static let cardBackground        = dynamic(light: 0xFAFAFA, dark: 0x141416)
    static let cardBorder            = dynamic(light: 0xE5E5E5, dark: 0x262626)
    static let iconBadgeBackground   = dynamic(light: 0xF1F1F1, dark: 0x1F1F1F)
    static let menuBackground        = dynamic(light: 0xFFFFFF, dark: 0x0F0F0F)
    static let hoverBackground       = dynamic(light: 0xF1F1F1, dark: 0x1F1F1F)
    static let sidebarBackground     = dynamic(light: 0xF7F7F7, dark: 0x000000)
    static let textPrimary           = dynamic(light: 0x0A0A0A, dark: 0xFFFFFF)
    static let textSecondary         = dynamic(light: 0x606060, dark: 0xB5B5B5)
    static let textTertiary          = dynamic(light: 0x919191, dark: 0x919191)
    static let dividerWarm           = dynamic(light: 0xE5E5E5, dark: 0x3B3B3B)
    static let accentOlive           = dynamic(light: 0x007EED, dark: 0x007EED)
    static let accentOliveSoft       = dynamic(light: 0xE6F2FE, dark: 0x00253F)
    static let toggleOffBackground   = dynamic(light: 0xD0D0D0, dark: 0x606060)
    static let recordingRed          = dynamic(light: 0xC9342B, dark: 0xE8554A)

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua, .accessibilityHighContrastVibrantDark]) != nil
            return NSColor(srgb: isDark ? dark : light)
        })
    }
}

private extension NSColor {
    convenience init(srgb hex: UInt32) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >> 8) & 0xFF) / 255
        let b = CGFloat(hex & 0xFF) / 255
        self.init(srgbRed: r, green: g, blue: b, alpha: 1)
    }
}
