import SwiftUI

struct MenuRow: View {
    let icon: String?
    let title: String
    let trailingText: String?
    let showsChevron: Bool
    let isDisabled: Bool
    let action: (() -> Void)?

    @State private var isHovering = false

    init(
        icon: String? = nil,
        title: String,
        trailingText: String? = nil,
        showsChevron: Bool = false,
        isDisabled: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.trailingText = trailingText
        self.showsChevron = showsChevron
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            if let icon {
                IconBadge(systemName: icon, size: 22, iconSize: 11)
            }
            Text(title)
                .font(.menuRow)
                .foregroundStyle(isDisabled ? Color.textTertiary : Color.textPrimary)
                .lineLimit(1)
            Spacer()
            if let trailingText {
                Text(trailingText)
                    .font(.menuInfo)
                    .foregroundStyle(Color.textTertiary)
                    .monospaced()
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .fill(isHovering && !isDisabled && action != nil ? Color.hoverBackground : .clear)
        )
        .onHover { isHovering = $0 }
        .onTapGesture {
            guard !isDisabled, let action else { return }
            action()
        }
        .animation(.easeInOut(duration: 0.12), value: isHovering)
    }
}
