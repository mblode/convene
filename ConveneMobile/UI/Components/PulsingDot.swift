import SwiftUI

/// The live-recording indicator. Animation is driven by `isActive` rather than `onAppear` so it
/// stops cleanly when a meeting ends, instead of pulsing on a screen that's no longer recording.
struct PulsingDot: View {
    var isActive: Bool
    var size: CGFloat = 10

    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(Color.recordingRed)
            .frame(width: size, height: size)
            .opacity(isPulsing ? 0.35 : 1)
            .animation(
                isActive
                    ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                    : .default,
                value: isPulsing
            )
            .onChange(of: isActive, initial: true) { _, active in
                isPulsing = active
            }
            .accessibilityHidden(true)
    }
}
