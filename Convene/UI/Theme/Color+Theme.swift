import AppKit
import SwiftUI

extension Color {
    static let appBackground         = dynamic(light: 0xF4F3ED, dark: 0x17171A)
    static let cardBackground        = dynamic(light: 0xFFFFFF, dark: 0x1F1F22)
    static let cardBorder            = dynamic(light: 0xE8E6DD, dark: 0x2C2C30)
    static let iconBadgeBackground   = dynamic(light: 0xF0EEE6, dark: 0x2A2A2E)
    static let menuBackground        = dynamic(light: 0xFFFFFF, dark: 0x1F1F22)
    static let hoverBackground       = dynamic(light: 0xF0EEE6, dark: 0x2A2A2E)
    static let sidebarBackground     = dynamic(light: 0xEFEDE5, dark: 0x1A1A1D)
    static let textPrimary           = dynamic(light: 0x1A1A1A, dark: 0xEDECE6)
    static let textSecondary         = dynamic(light: 0x7A7568, dark: 0x9A958A)
    static let textTertiary          = dynamic(light: 0xA8A39A, dark: 0x6E6A62)
    static let dividerWarm           = dynamic(light: 0xD9D5C9, dark: 0x34342F)
    static let accentOlive           = dynamic(light: 0x5A6F2A, dark: 0x8AA63F)
    static let accentOliveSoft       = dynamic(light: 0xE8EBD9, dark: 0x2E3A1A)
    static let toggleOffBackground   = dynamic(light: 0xD9D5C9, dark: 0x3A3A3F)
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
