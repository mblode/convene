import SwiftUI

struct OliveToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        let trackWidth: CGFloat = 38
        let trackHeight: CGFloat = 22
        let knobSize: CGFloat = 18
        let inset: CGFloat = (trackHeight - knobSize) / 2

        return Button {
            configuration.isOn.toggle()
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? Color.accentOlive : Color.toggleOffBackground)
                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                    .frame(width: knobSize, height: knobSize)
                    .padding(inset)
            }
            .frame(width: trackWidth, height: trackHeight)
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: configuration.isOn)
        }
        .buttonStyle(.plain)
    }
}
