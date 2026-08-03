import SwiftUI

/// A Keychain-backed API key field. Saves when the field loses focus or the user hits return —
/// not on every keystroke, so a half-typed key never reaches the Keychain.
struct APIKeyRow: View {
    let title: String
    let placeholder: String
    let footnote: String
    @Binding var field: APIKeyField

    @State private var isRevealed = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: MobileTheme.Spacing.sm) {
            HStack {
                Text(title)
                Spacer()
                if field.hasKey {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .typeStyle(.caption)
                        .foregroundStyle(.green)
                }
            }

            HStack(spacing: MobileTheme.Spacing.sm) {
                Group {
                    if isRevealed {
                        TextField(placeholder, text: $field.value)
                    } else {
                        SecureField(placeholder, text: $field.value)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($isFocused)
                .onSubmit { field.save() }

                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.textSecondary)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel(isRevealed ? "Hide key" : "Show key")
            }

            if let error = field.error {
                Text(error)
                    .typeStyle(.caption)
                    .foregroundStyle(Color.recordingRed)
            } else {
                Text(footnote)
                    .typeStyle(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused { field.save() }
        }
    }
}
