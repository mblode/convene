import SwiftUI

struct SettingsSidebar: View {
    @Binding var selection: SettingsSection

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Convene")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, 12)
                .padding(.top, 14)

            VStack(alignment: .leading, spacing: 2) {
                ForEach(SettingsSection.allCases) { section in
                    SidebarRow(
                        icon: section.icon,
                        label: section.label,
                        isSelected: selection == section
                    ) {
                        selection = section
                    }
                }
            }
            .padding(.horizontal, 4)

            Spacer(minLength: 0)
        }
        .frame(width: 220)
        .frame(maxHeight: .infinity)
        .background(Color.sidebarBackground)
    }
}
