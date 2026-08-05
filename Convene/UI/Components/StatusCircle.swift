import AppKit
import SwiftUI

/// The leading indicator in a schedule row: a filled check for past events, a ringed dot for
/// the current one, and a hollow ring for upcoming events.
struct StatusCircle: View {
    let status: EventStatus
    let color: Color

    var body: some View {
        let color = self.color.legibleAsMarker()
        return ZStack {
            switch status {
            case .past:
                Circle().fill(color.opacity(0.18))
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(color)
            case .current:
                Circle().stroke(color, lineWidth: 2)
                Circle().fill(color).frame(width: 5, height: 5)
            case .upcoming:
                Circle().stroke(color, lineWidth: 1.5)
            }
        }
        .frame(width: 14, height: 14)
    }
}

extension Color {
    /// Darken (light appearance) or lighten (dark) until this colour clears the 3:1 WCAG minimum
    /// for non-text UI components, preserving hue and saturation.
    ///
    /// Calendar colours arrive from EventKit, where the user chose them to read as large filled
    /// blocks against white in Calendar.app. As a 1.5pt ring on the popover a pale one disappears —
    /// a stock light blue measured 1.05:1 against the panel, meaning the ring and its background
    /// were the same luminance and only a hue shift was visible. Hue and saturation are the
    /// calendar's identity and are left alone; only brightness moves.
    ///
    /// Under Liquid Glass the panel's luminance is a range rather than a point — it refracts
    /// whatever window is behind it, measuring anywhere from mid-grey to near-white in the light
    /// appearance. A marker dark enough for the *darkest* the panel gets is automatically safe
    /// against every lighter value, so these reference points are those bounds, not pure
    /// white/black. Targeting white instead leaves a pastel at 1.85:1 on a mid-grey glass panel.
    func legibleAsMarker(minimum: CGFloat = 3) -> Color {
        Color(
            nsColor: NSColor(name: nil) { [self] appearance in
                let isDark = appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
                let base = NSColor(self).usingColorSpace(.sRGB) ?? .black
                return base.adjustedForContrast(
                    against: isDark ? Self.darkPanelCeiling : Self.lightPanelFloor,
                    minimum: minimum
                )
            }
        )
    }

    /// Darkest the light-appearance panel is observed to render under glass, and lightest the dark
    /// one does. Measured off the popover, not derived — glass has no nominal background.
    private static let lightPanelFloor: CGFloat = 0.55
    private static let darkPanelCeiling: CGFloat = 0.15
}

extension NSColor {
    /// Step brightness toward `backgroundLuminance`'s opposite until the contrast ratio clears
    /// `minimum`, in HSB so hue and saturation survive.
    fileprivate func adjustedForContrast(against backgroundLuminance: CGFloat, minimum: CGFloat)
        -> NSColor
    {
        guard contrastRatio(against: backgroundLuminance) < minimum else { return self }
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)

        if backgroundLuminance > 0.5 {
            // Dropping a pastel's brightness far enough to clear 3:1 on a light panel bleaches it
            // to a neutral slate — #ADD0EB lands on #5A6C7A, which no longer reads as "the blue
            // calendar". Hue survives the move but saturation does not, so it is restored: the
            // point of the colour is identity, and a marker that is legible but unidentifiable
            // has solved half the problem.
            s = max(s, 0.5)
            var candidate = NSColor(hue: h, saturation: s, brightness: b, alpha: a)
            while b > 0, candidate.contrastRatio(against: backgroundLuminance) < minimum {
                b = max(b - 0.02, 0)
                candidate = NSColor(hue: h, saturation: s, brightness: b, alpha: a)
            }
            return candidate
        }

        // Lightening takes two axes, not one. Raising brightness alone stalls on any colour already
        // at brightness 1 — a stock orange sits there, so it stayed at 2.30:1 against a dark panel
        // until this desaturated it. Past full brightness the only way toward white is down the
        // saturation axis.
        var candidate = NSColor(hue: h, saturation: s, brightness: b, alpha: a)
        while candidate.contrastRatio(against: backgroundLuminance) < minimum {
            if b < 1 {
                b = min(b + 0.02, 1)
            } else if s > 0 {
                s = max(s - 0.02, 0)
            } else {
                break
            }
            candidate = NSColor(hue: h, saturation: s, brightness: b, alpha: a)
        }
        return candidate
    }

    fileprivate func contrastRatio(against backgroundLuminance: CGFloat) -> CGFloat {
        let l = relativeLuminance
        let lighter = max(l, backgroundLuminance)
        let darker = min(l, backgroundLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// WCAG relative luminance.
    fileprivate var relativeLuminance: CGFloat {
        guard let srgb = usingColorSpace(.sRGB) else { return 0 }
        func channel(_ value: CGFloat) -> CGFloat {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(srgb.redComponent)
            + 0.7152 * channel(srgb.greenComponent)
            + 0.0722 * channel(srgb.blueComponent)
    }
}
