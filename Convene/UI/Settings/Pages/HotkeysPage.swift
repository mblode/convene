import KeyboardShortcuts
import SwiftUI

struct HotkeysPage: View {
    @EnvironmentObject private var hotkeyManager: HotkeyManager

    /// Every configurable global shortcut, so "Restore defaults" stays in sync as new ones are added.
    private static let allNames: [KeyboardShortcuts.Name] = [
        .toggleRecording, .flagKeyMoment, .openSettings
    ]

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
                        icon: "star",
                        title: "Flag key moment",
                        description: "Mark this moment live while recording"
                    ) {
                        KeyboardShortcuts.Recorder("", name: .flagKeyMoment)
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
                HStack {
                    Text("Click a shortcut to record a new one, or clear it to disable.")
                        .font(.captionWarm)
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                    Button("Restore Defaults", action: restoreDefaults)
                        .buttonStyle(.borderless)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.accent)
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.top, Theme.Spacing.xl)
    }

    private func restoreDefaults() {
        KeyboardShortcuts.reset(Self.allNames)
        hotkeyManager.refreshDisplays()
    }
}
