import SwiftUI

/// A tappable icon+label row used for the menu-bar contextual actions above the schedule.
struct ActionRow: View {
    let icon: String
    let label: String
    var tint: Color = .primary
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .frame(width: 18)
                Text(label)
                    .font(.system(size: 13))
                Spacer()
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                hovering ? Color.hoverBackground : .clear,
                in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeInOut(duration: 0.12), value: hovering)
        .accessibilityLabel(label)
    }
}
