import SwiftUI

/// A filled accent-coloured button style used for prominent calls to action (e.g. the
/// "Grant Calendar Access" button in the no-access state).
struct OliveProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .fill(Color.accent)
                    .opacity(configuration.isPressed ? 0.85 : 1)
            )
    }
}
