import SwiftUI

struct GeneralPage: View {
    @EnvironmentObject var meetingStore: MeetingStore
    @ObservedObject private var loginItem = LoginItemManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
            PageTitle("General")

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionLabel("Startup")
                SettingsCard {
                    SettingsRow(
                        icon: "power",
                        title: "Open at login",
                        description: loginItem.requiresApproval
                            ? "Allow Convene in System Settings › Login Items."
                            : "Launch Convene automatically when you sign in to your Mac.",
                        showsDivider: false
                    ) {
                        if loginItem.requiresApproval {
                            Button("Open Settings") { loginItem.openLoginItemsSettings() }
                                .buttonStyle(.borderless)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.accent)
                        } else {
                            Toggle("", isOn: Binding(
                                get: { loginItem.isEnabled },
                                set: { loginItem.setEnabled($0) }
                            ))
                            .toggleStyle(OliveToggleStyle())
                            .labelsHidden()
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionLabel("Identity")
                SettingsCard {
                    SettingsRow(
                        icon: "person",
                        title: "Your name",
                        description: "Labels your side of the transcript.",
                        showsDivider: false
                    ) {
                        TextField(NSFullUserName(), text: $meetingStore.userName)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                            .frame(width: 180)
                    }
                }
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionLabel("Storage")
                SettingsCard {
                    SettingsRow(
                        icon: "folder",
                        title: "Save folder",
                        description: outputFolderDescription
                    ) {
                        HStack(spacing: 8) {
                            if meetingStore.persistence.outputFolderURL != nil {
                                Button("Clear") {
                                    meetingStore.clearOutputFolder()
                                }
                                .buttonStyle(.borderless)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textSecondary)
                            }
                            Button("Choose…") {
                                meetingStore.chooseOutputFolderAndRetrySave()
                            }
                            .buttonStyle(.borderless)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.accent)
                        }
                    }
                    SettingsRow(
                        icon: "arrow.up.right.square",
                        title: "Reveal last save",
                        description: lastSavedDescription,
                        showsDivider: false,
                        isDisabled: meetingStore.persistence.lastSavedFileURL == nil
                    ) {
                        Button {
                            if let url = meetingStore.persistence.lastSavedFileURL {
                                meetingStore.persistence.revealInFinder(url)
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .disabled(meetingStore.persistence.lastSavedFileURL == nil)
                    }
                }
                Text("Tip: pick your Obsidian vault's meeting folder if you want notes to appear there automatically.")
                    .font(.captionWarm)
                    .foregroundStyle(Color.textSecondary)
                    .padding(.horizontal, 4)
            }
        }
        .padding(.top, Theme.Spacing.xl)
        .onAppear { loginItem.refresh() }
    }

    private var outputFolderDescription: String {
        if let url = meetingStore.persistence.outputFolderURL {
            return truncatedPath(url.path)
        }
        return "Not set; saves will use a local fallback."
    }

    private var lastSavedDescription: String {
        return meetingStore.persistence.lastSavedFileURL?.lastPathComponent ?? "No saves yet"
    }

    private func truncatedPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}
