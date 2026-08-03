import SwiftUI

/// Liquid Glass adoption, gated so the app still builds and looks right below iOS 26.
///
/// Most of Liquid Glass arrives for free: compiling against the iOS 26 SDK already gives the
/// navigation bar, tab bar, form controls, and share sheet their glass treatment. What needs
/// saying explicitly is the custom floating controls — the record button and the in-meeting
/// actions — which are the app's own contribution to the control layer.
///
/// The HIG rule that shapes everything here: glass belongs to the layer floating *above* content,
/// never to content itself, and glass is never stacked on glass. So the transcript, the notes
/// field, and the meeting cards stay on ordinary materials; only controls float.
extension View {
    /// Glass for a floating control. `interactive` opts into the system's own press response —
    /// the glass flexes and brightens under the finger — which is a better answer to "respond on
    /// touch-down" than any scale animation, because it's the same response every other iOS 26
    /// control gives.
    /// The tint is kept light on purpose. Glass is a material that refracts what's behind it, and a
    /// heavy tint just paints over that and leaves a flat coloured disc — the tint is here to say
    /// which state the control is in (blue idle, red recording), not to colour the button in.
    @ViewBuilder
    func controlGlass(tint: Color, in shape: some Shape, fallbackOpacity: Double = 0.15) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(tint.opacity(0.22)).interactive(), in: shape)
        } else {
            self.background(tint.opacity(fallbackOpacity), in: shape)
        }
    }

    /// The soft scroll edge effect, so transcript text dissolves under the navigation bar instead
    /// of colliding with a hard edge.
    @ViewBuilder
    func softScrollEdges() -> some View {
        if #available(iOS 26.0, *) {
            self.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            self
        }
    }
}

/// A bordered button that becomes a glass button on iOS 26.
struct GlassActionButtonStyle: ViewModifier {
    var isProminent = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if isProminent {
                content.buttonStyle(.glassProminent)
            } else {
                content.buttonStyle(.glass)
            }
        } else {
            if isProminent {
                content.buttonStyle(.borderedProminent)
            } else {
                content.buttonStyle(.bordered)
            }
        }
    }
}

extension View {
    func glassActionButton(isProminent: Bool = false) -> some View {
        modifier(GlassActionButtonStyle(isProminent: isProminent))
    }
}
