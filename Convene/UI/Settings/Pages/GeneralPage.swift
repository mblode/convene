import SwiftUI

struct GeneralPage: View {
    @EnvironmentObject var meetingStore: MeetingStore

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            PageTitle("General")

            VStack(alignment: .leading, spacing: 12) {
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
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.accentOlive)
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
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .disabled(meetingStore.persistence.lastSavedFileURL == nil)
                    }
                }
                Text("Tip: pick a folder inside iCloud Drive to sync notes across devices.")
                    .font(.captionWarm)
                    .foregroundStyle(Color.textSecondary)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var outputFolderDescription: String {
        if let url = meetingStore.persistence.outputFolderURL {
            return truncatedPath(url.path)
        }
        return "No folder set — meetings will not be saved."
    }

    private var lastSavedDescription: String {
        meetingStore.persistence.lastSavedFileURL?.lastPathComponent ?? "No saves yet"
    }

    private func truncatedPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}
