import SwiftUI

/// Confirmation shown after a stop persist copies the note path to the clipboard.
struct CopiedPathToast: View {
    let filename: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text("Copied path")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                Text(filename)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.menu, style: .continuous)
                .fill(Color.cardBackground)
                .shadow(color: Color.black.opacity(0.12), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.menu, style: .continuous)
                .strokeBorder(Color.cardBorder, lineWidth: Theme.Stroke.hairline)
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityLabel("Copied path")
        .accessibilityValue(filename)
    }
}
