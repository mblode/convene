import AppKit
import SwiftUI

struct AboutPage: View {
    @EnvironmentObject private var updateManager: UpdateManager

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
            PageTitle("About")

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionLabel("App")
                SettingsCard {
                    SettingsRow(
                        icon: "info.circle",
                        title: "Version",
                        description: versionString
                    ) {}
                    SettingsRow(
                        icon: "doc.text.magnifyingglass",
                        title: "Logs",
                        description: "Open the Convene log file"
                    ) {
                        Button {
                            Logger.shared.openLogFile()
                        } label: {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    SettingsRow(
                        icon: "link",
                        title: "GitHub",
                        description: "View source on github.com/mblode/convene",
                        showsDivider: false
                    ) {
                        Button {
                            if let url = URL(string: "https://github.com/mblode/convene") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionLabel("Updates")
                SettingsCard {
                    SettingsRow(
                        icon: "arrow.clockwise",
                        title: "Check for Updates",
                        description: "Check the signed GitHub appcast"
                    ) {
                        Button {
                            updateManager.checkForUpdates()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .disabled(!updateManager.canCheckForUpdates)
                    }
                    SettingsRow(
                        icon: "bell.badge",
                        title: "Automatically Check",
                        description: "Let Convene periodically check for new releases"
                    ) {
                        Toggle("", isOn: automaticallyChecksBinding)
                            .labelsHidden()
                            .toggleStyle(OliveToggleStyle())
                    }
                    SettingsRow(
                        icon: "square.and.arrow.down",
                        title: "Automatically Download",
                        description: "Download updates in the background after they are found",
                        isDisabled: !updateManager.automaticallyChecksForUpdates
                    ) {
                        Toggle("", isOn: automaticallyDownloadsBinding)
                            .labelsHidden()
                            .toggleStyle(OliveToggleStyle())
                            .disabled(!updateManager.automaticallyChecksForUpdates)
                    }
                    SettingsRow(
                        icon: "doc.text",
                        title: "Release Notes",
                        description: "View Convene releases on GitHub",
                        showsDivider: false
                    ) {
                        Button {
                            if let url = URL(string: "https://github.com/mblode/convene/releases") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.top, Theme.Spacing.xl)
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = info?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? short : "\(short) (\(build))"
    }

    private var automaticallyChecksBinding: Binding<Bool> {
        Binding(
            get: { updateManager.automaticallyChecksForUpdates },
            set: { updateManager.setAutomaticallyChecksForUpdates($0) }
        )
    }

    private var automaticallyDownloadsBinding: Binding<Bool> {
        Binding(
            get: { updateManager.automaticallyDownloadsUpdates },
            set: { updateManager.setAutomaticallyDownloadsUpdates($0) }
        )
    }
}
