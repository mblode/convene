import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Everything the checklist doesn't cover, plus everything it does — this is where a setting goes
/// to be changed a second time.
///
/// Still a `Form`: keys, pickers, and a folder chooser are exactly what the grouped list was built
/// for, and the platform's own row heights, editing behaviour and Dynamic Type handling are worth
/// more here than a hand-built stack. What's restyled is the type and colour around the controls —
/// section headings, footers and warnings speak in the app's voice rather than the system's.
struct SettingsView: View {
    @EnvironmentObject private var store: MobileMeetingStore

    @Environment(\.dismiss) private var dismiss

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
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .tint(Color.accent)
            .navigationTitle("Settings")
            // A sheet with no dismiss control leaves the swipe as the only way out, which is
            // undiscoverable and unreachable for anyone driving with VoiceOver or Switch Control.
            // A back chevron rather than "Done": nothing here is confirmed on the way out — every
            // control writes as it changes — so the button is a way back, not a commitment.
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.backward")
                    }
                    .accessibilityLabel("Back to meetings")
                }
            }
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
            SettingsSectionHeader("API keys")
        } footer: {
            SettingsFooter(
                "Keys live in your iPhone’s Keychain. There’s no Convene server — audio goes to AssemblyAI, the transcript goes to your summary provider, and nowhere else."
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
            SettingsSectionHeader("Summaries")
        } footer: {
            if store.generateSummaryAfterMeeting && !store.hasSummaryKey {
                SettingsFooter(
                    "Add \(store.summaryProvider == "anthropic" ? "an Anthropic" : "an OpenAI") key above, or meetings will save without a summary.",
                    tint: .recordingRed
                )
            } else {
                SettingsFooter("Claude writes the better summaries.")
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
                SettingsWarning(
                    "Convene can’t reach that folder right now. Meetings will save to this iPhone until you choose it again."
                )
            }

            if let error = store.persistence.lastError {
                SettingsWarning(error)
            }
        } header: {
            SettingsSectionHeader("Notes")
        } footer: {
            SettingsFooter(
                "Every meeting saves as a markdown file. Pick your Obsidian vault — tap Choose, then Browse to Obsidian or iCloud Drive and select the folder you want meetings in. Notes sync to the same vault on your Mac. Leave it alone and they stay in Convene’s own folder, under On My iPhone in Files."
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
        case .granted: ("Allowed", "checkmark.circle.fill", .accent)
        case .denied: ("Off", "xmark.circle.fill", .recordingRed)
        case .undetermined: ("Not yet asked", "circle", .textTertiary)
        }
    }

    private var microphoneSection: some View {
        Section {
            LabeledContent("Access") {
                HStack(spacing: MobileTheme.Spacing.xs) {
                    Image(systemName: microphoneAccess.icon)
                    Text(microphoneAccess.title)
                }
                .foregroundStyle(microphoneAccess.tint)
            }
            // Read as one phrase — "Access, Allowed" — rather than as a label and a glyph.
            .accessibilityElement(children: .combine)

            if store.recorder.permissionState == .denied,
                let settings = URL(string: UIApplication.openSettingsURLString)
            {
                Link("Open iPhone Settings", destination: settings)
            }
        } header: {
            SettingsSectionHeader("Microphone")
        } footer: {
            if store.recorder.permissionState == .undetermined {
                SettingsFooter("iOS asks the first time you record.")
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: Self.versionString)
            Link("Convene on GitHub", destination: URL(string: "https://github.com/mblode/convene")!)
        } header: {
            SettingsSectionHeader("About")
        }
    }

    private static var versionString: String {
        let info = Bundle.main.infoDictionary
        let marketing = info?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(marketing) (\(build))"
    }
}

/// `.textCase(nil)` because the grouped list would otherwise shout the heading in capitals, which
/// is the one place this screen still sounded like a system settings pane rather than like Convene.
private struct SettingsSectionHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .typeStyle(.section)
            .foregroundStyle(Color.textSecondary)
            .textCase(nil)
    }
}

private struct SettingsFooter: View {
    let text: String
    let tint: Color

    init(_ text: String, tint: Color = .textTertiary) {
        self.text = text
        self.tint = tint
    }

    var body: some View {
        Text(text)
            .typeStyle(.caption)
            .foregroundStyle(tint)
    }
}

/// A problem inside a section, rather than under it: these describe the row above them, and a
/// footer would put them past the section's edge where they read as general advice.
private struct SettingsWarning: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Label {
            Text(text)
                .typeStyle(.caption)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
                .accessibilityHidden(true)
        }
        .foregroundStyle(Color.recordingRed)
    }
}
