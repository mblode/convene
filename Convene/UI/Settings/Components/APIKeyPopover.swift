import SwiftUI

struct APIKeyPopover: View {
    enum Provider {
        case openAI
        case anthropic
        case assemblyAI

        var title: String {
            switch self {
            case .openAI: return "OpenAI API key"
            case .anthropic: return "Anthropic API key"
            case .assemblyAI: return "AssemblyAI API key"
            }
        }

        var detail: String {
            switch self {
            case .openAI: return "Stored in your macOS Keychain. Required for transcription and summary."
            case .anthropic: return "Stored in your macOS Keychain. Required for Claude summaries."
            case .assemblyAI: return "Stored in your macOS Keychain. Required for transcription. Get a key at assemblyai.com/dashboard/api-keys."
            }
        }

        var placeholder: String {
            switch self {
            case .openAI: return "sk-…"
            case .anthropic: return "sk-ant-…"
            case .assemblyAI: return "Your AssemblyAI key…"
            }
        }
    }

    @EnvironmentObject var meetingStore: MeetingStore
    @Binding var isPresented: Bool
    var provider: Provider = .openAI

    @State private var draft: String = ""
    @State private var errorMessage: String?

    private var hasKey: Bool {
        switch provider {
        case .openAI: return meetingStore.hasAPIKey
        case .anthropic: return meetingStore.hasClaudeAPIKey
        case .assemblyAI: return meetingStore.hasAssemblyAIKey
        }
    }

    private var storedKey: String {
        switch provider {
        case .openAI: return meetingStore.apiKey
        case .anthropic: return meetingStore.claudeAPIKey
        case .assemblyAI: return meetingStore.assemblyAIKey
        }
    }

    private var storeError: String? {
        switch provider {
        case .openAI: return meetingStore.apiKeyError
        case .anthropic: return meetingStore.claudeAPIKeyError
        case .assemblyAI: return meetingStore.assemblyAIKeyError
        }
    }

    private func save(_ value: String) -> Bool {
        switch provider {
        case .openAI:
            meetingStore.apiKey = value
            return meetingStore.saveAPIKey()
        case .anthropic:
            meetingStore.claudeAPIKey = value
            return meetingStore.saveClaudeAPIKey()
        case .assemblyAI:
            meetingStore.assemblyAIKey = value
            return meetingStore.saveAssemblyAIKey()
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(provider.title)
                .font(.system(size: 14))
                .foregroundStyle(Color.textPrimary)

            Text(provider.detail)
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            SecureField(provider.placeholder, text: $draft)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 280)

            if let errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.recordingRed)
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.recordingRed)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if hasKey {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.accent)
                    Text("A key is currently saved.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }
            }

            HStack {
                if hasKey {
                    Button("Delete") {
                        if save("") {
                            draft = ""
                            errorMessage = nil
                        } else {
                            errorMessage = storeError
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.recordingRed)
                    .font(.system(size: 12))
                }
                Spacer()
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    if save(draft) {
                        errorMessage = nil
                        isPresented = false
                    } else {
                        errorMessage = storeError
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 320)
        .onAppear {
            draft = storedKey
            errorMessage = storeError
        }
    }
}
