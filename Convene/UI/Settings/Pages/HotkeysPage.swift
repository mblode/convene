import KeyboardShortcuts
import SwiftUI

struct HotkeysPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
            PageTitle("Hotkeys")

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionLabel("Global shortcuts")
                SettingsCard {
                    SettingsRow(
                        icon: "record.circle",
                        title: "Toggle recording",
                        description: "Start or stop a meeting from anywhere"
                    ) {
                        KeyboardShortcuts.Recorder("", name: .toggleRecording)
                            .controlSize(.small)
                    }
                    SettingsRow(
                        icon: "rectangle.on.rectangle",
                        title: "Open meeting window",
                        description: "Bring the live transcript to the front"
                    ) {
                        KeyboardShortcuts.Recorder("", name: .openMeetingWindow)
                            .controlSize(.small)
                    }
                    SettingsRow(
                        icon: "gearshape",
                        title: "Open settings",
                        description: "Open this window",
                        showsDivider: false
                    ) {
                        KeyboardShortcuts.Recorder("", name: .openSettings)
                            .controlSize(.small)
                    }
                }
            }
        }
        .padding(.top, Theme.Spacing.xl)
    }
}
