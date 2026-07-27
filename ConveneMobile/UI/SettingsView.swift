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
                permissionsSection
                aboutSection
            }
            .navigationTitle("Settings")
            .fileImporter(
                isPresented: $isPickingFolder,
                allowedContentTypes: [.folder]
            ) { result in
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
            Text("Keys are stored in your iPhone's Keychain. Convene has no server — audio goes to AssemblyAI and transcripts go to your summary provider, and nowhere else.")
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

            if store.summaryProvider == "anthropic" {
                TextField("Model", text: $store.claudeSummaryModel)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } else {
                TextField("Model", text: $store.summaryModel)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        } header: {
            Text("Summaries")
        } footer: {
            if store.generateSummaryAfterMeeting && !store.hasSummaryKey {
                Text("Add a \(store.summaryProvider == "anthropic" ? "Anthropic" : "OpenAI") key above, or meetings will save without a summary.")
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

            Button("Choose a folder…") { isPickingFolder = true }

            if store.persistence.hasConfiguredVault {
                Button("Use the Convene folder on this iPhone", role: .destructive) {
                    store.persistence.clearVaultFolder()
                }
            }

            if let error = store.persistence.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.recordingRed)
            }
        } header: {
            Text("Notes")
        } footer: {
            Text("Each meeting saves as a markdown file. Leave this alone and notes live in Convene's own folder, which you'll find under On My iPhone in the Files app — or point it at an iCloud Drive folder to have them show up on your Mac.")
        }
    }

    // MARK: - Permissions

    private var permissionsSection: some View {
        Section("Microphone") {
            LabeledContent("Access") {
                switch store.recorder.permissionState {
                case .granted:
                    Label("Allowed", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .denied:
                    Label("Off", systemImage: "xmark.circle.fill")
                        .foregroundStyle(Color.recordingRed)
                case .undetermined:
                    Text("Asked when you first record")
                        .foregroundStyle(.secondary)
                }
            }

            if store.recorder.permissionState == .denied,
               let settings = URL(string: UIApplication.openSettingsURLString) {
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
