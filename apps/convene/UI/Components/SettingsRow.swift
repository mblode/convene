import SwiftUI

struct SettingsRow<Trailing: View>: View {
    let icon: String
    let title: String
    let description: String?
    let showsDivider: Bool
    let isDisabled: Bool
    @ViewBuilder let trailing: () -> Trailing

    init(
        icon: String,
        title: String,
        description: String? = nil,
        showsDivider: Bool = true,
        isDisabled: Bool = false,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.showsDivider = showsDivider
        self.isDisabled = isDisabled
        self.trailing = trailing
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: Theme.Spacing.md) {
                IconBadge(
                    systemName: icon,
                    tint: isDisabled ? .textTertiary : .textPrimary
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.rowTitle)
                        .foregroundStyle(isDisabled ? Color.textTertiary : Color.textPrimary)
                    if let description {
                        Text(description)
                            .font(.rowDescription)
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: Theme.Spacing.md)
                trailing()
                    .opacity(isDisabled ? 0.5 : 1)
            }
            .padding(.horizontal, Theme.Spacing.rowHorizontal)
            .padding(.vertical, Theme.Spacing.rowVertical)

            if showsDivider {
                DashedDivider()
                    .padding(.horizontal, Theme.Spacing.rowHorizontal)
            }
        }
    }
}
