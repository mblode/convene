import SwiftUI

struct APIKeyPopover: View {
    @EnvironmentObject var meetingStore: MeetingStore
    @Binding var isPresented: Bool

    @State private var draft: String = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OpenAI API key")
                .font(.system(size: 14))
                .foregroundStyle(Color.textPrimary)

            Text("Stored in your macOS Keychain. Required for transcription and summary.")
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            SecureField("sk-…", text: $draft)
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

            if meetingStore.hasAPIKey {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.accentOlive)
                    Text("A key is currently saved.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }
            }

            HStack {
                if meetingStore.hasAPIKey {
                    Button("Delete") {
                        meetingStore.apiKey = ""
                        if meetingStore.saveAPIKey() {
                            draft = ""
                            errorMessage = nil
                        } else {
                            errorMessage = meetingStore.apiKeyError
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
                    meetingStore.apiKey = draft
                    if meetingStore.saveAPIKey() {
                        errorMessage = nil
                        isPresented = false
                    } else {
                        errorMessage = meetingStore.apiKeyError
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 320)
        .onAppear {
            draft = meetingStore.apiKey
            errorMessage = meetingStore.apiKeyError
        }
    }
}
