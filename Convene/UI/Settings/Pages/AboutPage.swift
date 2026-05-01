import AppKit
import SwiftUI

struct AboutPage: View {
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
        }
        .padding(.top, Theme.Spacing.xl)
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = info?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? short : "\(short) (\(build))"
    }
}
