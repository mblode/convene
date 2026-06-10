import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var store: MobileMeetingStore
    @State private var showingFolderPicker = false
    @State private var showingClearConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Obsidian Vault") {
                    if let url = store.persistence.vaultFolderURL {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading) {
                                Text(url.lastPathComponent)
                                    .font(.body)
                                Text(url.deletingLastPathComponent().lastPathComponent)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Change") {
                                showingFolderPicker = true
                            }
                            .buttonStyle(.borderless)
                        }
                        Button("Remove vault folder", role: .destructive) {
                            showingClearConfirmation = true
                        }
                        .confirmationDialog(
                            "Remove vault folder?",
                            isPresented: $showingClearConfirmation,
                            titleVisibility: .visible
                        ) {
                            Button("Remove", role: .destructive) {
                                store.persistence.clearVaultFolder()
                            }
                        } message: {
                            Text("Recordings will be saved locally until you choose a new folder.")
                        }
                    } else {
                        Button {
                            showingFolderPicker = true
                        } label: {
                            Label("Choose vault folder", systemImage: "folder.badge.plus")
                        }
                        Text("Select your Obsidian vault's convene/ folder")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("OpenAI API") {
                    SecureField("API Key", text: $store.openAIAPIKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Text("Required for cloud transcription.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Claude API") {
                    SecureField("API Key", text: $store.claudeAPIKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Toggle("Generate summary after recording", isOn: $store.generateSummaryAfterMeeting)
                }

                Section("About") {
                    LabeledContent("Transcription", value: "OpenAI Realtime")
                    LabeledContent("Summarization", value: "Claude Haiku")
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingFolderPicker) {
                FolderPickerView { url in
                    store.persistence.handlePickedFolder(url)
                }
            }
        }
    }
}

struct FolderPickerView: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}
