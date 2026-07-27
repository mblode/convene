import SwiftUI

/// The generated summary, in the order the saved markdown uses.
struct SummaryView: View {
    let summary: MeetingSummary

    var body: some View {
        VStack(alignment: .leading, spacing: MobileTheme.Spacing.lg) {
            Text("Summary")
                .font(.headline)

            if !summary.overview.isEmpty {
                Text(summary.overview)
                    .textSelection(.enabled)
            }

            bulletSection("Key points", summary.keyPoints)
            bulletSection("Decisions", summary.decisions)
            bulletSection("Action items", summary.actionItems)
            bulletSection("Open questions", summary.openQuestions)
            bulletSection("Follow-ups", summary.followUps)

            if !summary.details.isEmpty {
                VStack(alignment: .leading, spacing: MobileTheme.Spacing.md) {
                    ForEach(Array(summary.details.enumerated()), id: \.offset) { _, detail in
                        VStack(alignment: .leading, spacing: MobileTheme.Spacing.xs) {
                            HStack(spacing: MobileTheme.Spacing.sm) {
                                Text(detail.title)
                                    .font(.subheadline.weight(.semibold))
                                if !detail.timestamps.isEmpty {
                                    Text(detail.timestamps.joined(separator: " "))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text(detail.narrative)
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func bulletSection(_ title: String, _ items: [String]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: MobileTheme.Spacing.xs) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: MobileTheme.Spacing.sm) {
                        Text("•").foregroundStyle(.secondary)
                        Text(item).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// The status line above the record button, and the transcription-error notice on a saved meeting.
struct BannerView: View {
    let text: String
    let isError: Bool

    var body: some View {
        HStack(alignment: .top, spacing: MobileTheme.Spacing.sm) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "info.circle.fill")
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.footnote)
        .foregroundStyle(isError ? Color.recordingRed : Color.secondary)
        .padding(MobileTheme.Spacing.md)
        .background(
            isError ? Color.recordingRed.opacity(0.1) : Color(.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: MobileTheme.Radius.card)
        )
    }
}
