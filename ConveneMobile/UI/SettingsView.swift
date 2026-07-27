import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: MobileMeetingStore

    @State private var isPickingFolder = false

    var body: some View {
        NavigationStack {
            Form {
                keysSection
                summarySection
                notesSection
                microphoneSection
                aboutSection
            }
            .navigationTitle("Settings")
            .fileImporter(isPresented: $isPickingFolder, allowedContentTypes: [.folder]) { result in
                switch result {
                case .success(let url):
                    store.persistence.handlePickedFolder(url)
                case .failure(let error):
                    logError("SettingsView: folder pick failed: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Keys

    private var keysSection: some View {
        Section {
            APIKeyRow(
                title: "AssemblyAI",
                placeholder: "Your AssemblyAI key…",
                footnote: "Required for transcription. Get one at assemblyai.com/dashboard/api-keys.",
                field: $store.assemblyAIKeyField
            )

            if store.summaryProvider == "anthropic" {
                APIKeyRow(
                    title: "Anthropic",
                    placeholder: "sk-ant-…",
                    footnote: "Used for summaries.",
                    field: $store.claudeKeyField
                )
            } else {
                APIKeyRow(
                    title: "OpenAI",
                    placeholder: "sk-…",
                    footnote: "Used for summaries.",
                    field: $store.openAIKeyField
                )
            }
        } header: {
            Text("API keys")
        } footer: {
            Text(
                "Keys live in your iPhone's Keychain. There's no Convene server — audio goes to AssemblyAI, the transcript goes to your summary provider, and nowhere else."
            )
        }
    }

    // MARK: - Summaries

    private var summarySection: some View {
        Section {
            Toggle("Summarise after each meeting", isOn: $store.generateSummaryAfterMeeting)

            Picker("Provider", selection: $store.summaryProvider) {
                Text("Claude").tag("anthropic")
                Text("OpenAI").tag("openai")
            }

            // A picker rather than free text: the set of models is fixed, and a typo in a text
            // field only surfaces as a failed summary after a meeting has already been recorded.
            if store.summaryProvider == "anthropic" {
                Picker("Model", selection: $store.claudeSummaryModel) {
                    ForEach(SummaryModelCatalog.anthropic, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
            } else {
                Picker("Model", selection: $store.summaryModel) {
                    ForEach(SummaryModelCatalog.openAI, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
            }
        } header: {
            Text("Summaries")
        } footer: {
            if store.generateSummaryAfterMeeting && !store.hasSummaryKey {
                Text(
                    "Add \(store.summaryProvider == "anthropic" ? "an Anthropic" : "an OpenAI") key above, or meetings will save without a summary."
                )
                .foregroundStyle(Color.recordingRed)
            } else {
                Text("Claude writes the better summaries.")
            }
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        Section {
            LabeledContent("Saving to", value: store.persistence.saveFolderDisplayName)

            Button(store.persistence.hasConfiguredVault ? "Choose a different folder…" : "Choose your vault…")
            {
                isPickingFolder = true
            }

            if store.persistence.hasConfiguredVault {
                Button("Use the Convene folder on this iPhone", role: .destructive) {
                    store.persistence.clearVaultFolder()
                }
            }

            // Checked when Settings is shown rather than left to fail at save time: a vault that's
            // been renamed, moved, or signed out of iCloud would otherwise stay listed above as the
            // destination right up until a meeting quietly landed somewhere else.
            if store.persistence.hasConfiguredVault, !store.persistence.isSaveFolderReachable {
                Label(
                    "Convene can't reach that folder right now. Meetings will save to this iPhone until you choose it again.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(Color.recordingRed)
            }

            if let error = store.persistence.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.recordingRed)
            }
        } header: {
            Text("Notes")
        } footer: {
            Text(
                "Every meeting saves as a markdown file. Pick your Obsidian vault — tap Choose, then Browse to Obsidian or iCloud Drive and select the folder you want meetings in. Notes sync to the same vault on your Mac. Leave it alone and they stay in Convene's own folder, under On My iPhone in Files."
            )
        }
    }

    // MARK: - Microphone

    /// Resolved outside the view builder on purpose.
    ///
    /// A `switch` returning `Label`s inside `LabeledContent`'s value slot renders the row correctly
    /// but leaves the Form section several times taller than its content — an empty block under the
    /// row that reads as a blank setting. Handing `LabeledContent` a plain `HStack` of resolved
    /// values avoids it.
    private var microphoneAccess: (title: String, icon: String, tint: Color) {
        switch store.recorder.permissionState {
        case .granted: ("Allowed", "checkmark.circle.fill", .green)
        case .denied: ("Off", "xmark.circle.fill", .recordingRed)
        case .undetermined: ("Not yet asked", "questionmark.circle", .secondary)
        }
    }

    private var microphoneSection: some View {
        Section("Microphone") {
            LabeledContent("Access") {
                HStack(spacing: 4) {
                    Image(systemName: microphoneAccess.icon)
                    Text(microphoneAccess.title)
                }
                .foregroundStyle(microphoneAccess.tint)
            }

            if store.recorder.permissionState == .denied,
                let settings = URL(string: UIApplication.openSettingsURLString)
            {
                Link("Open iPhone Settings", destination: settings)
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: Self.versionString)
            Link("Convene on GitHub", destination: URL(string: "https://github.com/mblode/convene")!)
        }
    }

    private static var versionString: String {
        let info = Bundle.main.infoDictionary
        let marketing = info?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(marketing) (\(build))"
    }
}
