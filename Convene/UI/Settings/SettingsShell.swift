import SwiftUI

struct SettingsShell: View {
    @EnvironmentObject var meetingStore: MeetingStore
    @EnvironmentObject var hotkeyManager: HotkeyManager

    @State private var selection: SettingsSection = .general

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(selection: $selection)
            ZStack {
                Color.appBackground
                ScrollView {
                    Group {
                        switch selection {
                        case .general:     GeneralPage()
                        case .models:      ModelsPage()
                        case .capture:     CapturePage()
                        case .hotkeys:     HotkeysPage()
                        case .permissions: PermissionsPage()
                        case .about:       AboutPage()
                        }
                    }
                    .frame(maxWidth: 640, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 28)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 760, minHeight: 600)
        .animation(.easeInOut(duration: 0.15), value: selection)
    }
}
