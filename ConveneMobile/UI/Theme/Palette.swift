import SwiftUI
import UIKit

/// The iPhone palette, ported from the Mac app's `Convene/UI/Theme/Color+Theme.swift`.
///
/// Same token names and the same hex values, so the two apps and the marketing site
/// (`apps/web/app/globals.css`, which names the same values `--color-twilight-ink`,
/// `--color-cerulean-accent`, and so on) read as one product. The only deliberate divergence is
/// `textTertiary` in light mode — see below.
///
/// These are resolved through `UIColor { traits in … }` rather than an asset catalog on purpose.
/// The closure form keeps the values next to the Mac app's list so a change to one is an obvious
/// change to the other, and it can answer `accessibilityContrast` as well as `userInterfaceStyle`,
/// so Increase Contrast is handled in one place instead of per-token in an asset catalog.
extension Color {
    // MARK: - Surfaces

    static let appBackground = dynamic(light: 0xFFFFFF, dark: 0x000000)
    static let cardBackground = dynamic(light: 0xFAFAFA, dark: 0x141416)
    static let cardBorder = dynamic(light: 0xE5E5E5, dark: 0x262626)
    static let iconBadgeBackground = dynamic(light: 0xF1F1F1, dark: 0x1F1F1F)
    static let dividerWarm = dynamic(light: 0xE5E5E5, dark: 0x3B3B3B)

    // MARK: - Text

    static let textPrimary = dynamic(light: 0x0A0A0A, dark: 0xFFFFFF)
    static let textSecondary = dynamic(light: 0x606060, dark: 0xB5B5B5)

    /// The Mac app uses `#919191` in both appearances. On the iPhone's white background that is
    /// only ~3.15:1 — fine for large text and UI furniture, short of the 4.5:1 that body-sized
    /// text needs. Light mode is darkened to `#767676` (~4.54:1) so this token is safe wherever
    /// it lands; dark mode keeps `#919191`, which is already ~6.66:1 on black.
    static let textTertiary = dynamic(light: 0x767676, dark: 0x919191)

    // MARK: - Accent

    static let accent = dynamic(light: 0x007EED, dark: 0x007EED)
    static let accentSoft = dynamic(light: 0xE6F2FE, dark: 0x00253F)

    /// The recording indicator, matched to the Mac app's palette.
    static let recordingRed = dynamic(light: 0xC9342B, dark: 0xE8554A)

    // MARK: - Touch additions

    // The Mac palette was built for a menu-bar app driven by a cursor. These four are what a touch
    // app needs on top of it, each derived from a token above rather than introducing a new colour.

    /// Pill/chip fill behind metadata. One step off the canvas, matching the Mac's badge surface.
    static let chipBackground = dynamic(light: 0xF1F1F1, dark: 0x1F1F1F)

    /// Overlaid on a control while the finger is down. There is no hover on a phone, so the Mac's
    /// `hoverBackground` becomes a press state instead.
    static let pressedOverlay = Color.textPrimary.opacity(0.08)

    /// Dims the root list behind the recording sheet.
    static let sheetScrim = Color.black.opacity(0.28)

    /// Foreground for a control that is present but unavailable.
    static let disabledForeground = Color.textTertiary.opacity(0.55)

    // MARK: - Resolution

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(
            uiColor: UIColor { traits in
                let isDark = traits.userInterfaceStyle == .dark
                let base = isDark ? dark : light
                guard traits.accessibilityContrast == .high else { return UIColor(srgb: base) }
                // Increase Contrast pushes text away from its background rather than recolouring
                // it — the palette stays recognisable, the separation gets stronger.
                return UIColor(srgb: base).byIncreasingContrast(isDark: isDark)
            })
    }
}

extension UIColor {
    fileprivate convenience init(srgb hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }

    /// Nudges a colour toward the extreme of its own appearance: lighter in dark mode, darker in
    /// light mode. A flat multiplier, deliberately — the point is more separation from the
    /// background, not a different hue.
    fileprivate func byIncreasingContrast(isDark: Bool) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return self
        }
        let adjusted = isDark ? min(brightness * 1.15, 1) : brightness * 0.82
        return UIColor(hue: hue, saturation: saturation, brightness: adjusted, alpha: alpha)
    }
}
