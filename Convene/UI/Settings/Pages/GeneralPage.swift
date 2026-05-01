import SwiftUI

struct GeneralPage: View {
    @EnvironmentObject var meetingStore: MeetingStore

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
            PageTitle("General")

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionLabel("Storage")
                SettingsCard {
                    SettingsRow(
                        icon: "folder",
                        title: "Output folder",
                        description: outputFolderDescription
                    ) {
                        Button("Choose…") {
                            meetingStore.chooseOutputFolderAndRetrySave()
                        }
                        .buttonStyle(.borderless)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.accentOlive)
                    }
                    SettingsRow(
                        icon: "square.and.arrow.down",
                        title: "Obsidian folder",
                        description: obsidianFolderDescription
                    ) {
                        HStack(spacing: 8) {
                            if meetingStore.persistence.obsidianFolderURL != nil {
                                Button("Clear") {
                                    meetingStore.clearObsidianFolder()
                                }
                                .buttonStyle(.borderless)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textSecondary)
                            }
                            Button("Choose…") {
                                meetingStore.chooseObsidianFolder()
                            }
                            .buttonStyle(.borderless)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.accentOlive)
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
                Text("Tip: pick your Obsidian vault's Meetings folder if you want notes to appear there automatically.")
                    .font(.captionWarm)
                    .foregroundStyle(Color.textSecondary)
                    .padding(.horizontal, 4)
            }
        }
        .padding(.top, Theme.Spacing.xl)
    }

    private var outputFolderDescription: String {
        if let url = meetingStore.persistence.outputFolderURL {
            return truncatedPath(url.path)
        }
        return "Not set; Convene will keep a local fallback copy."
    }

    private var obsidianFolderDescription: String {
        if let error = meetingStore.persistence.lastObsidianError {
            return error
        }
        if let url = meetingStore.persistence.obsidianFolderURL {
            return truncatedPath(url.path)
        }
        return "Off"
    }

    private var lastSavedDescription: String {
        if let url = meetingStore.persistence.lastObsidianFileURL {
            return "Obsidian: \(url.lastPathComponent)"
        }
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
