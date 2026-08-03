import SwiftUI

/// The generated summary, in the order the saved markdown uses.
///
/// Deliberately headless: the overview runs straight under the note's title as a lead paragraph
/// rather than under a "Summary" heading. The user opened a meeting to find out what happened, and
/// a heading between them and that sentence is a label on the only thing on screen.
struct SummaryView: View {
    let summary: MeetingSummary

    var body: some View {
        VStack(alignment: .leading, spacing: MobileTheme.Spacing.xl) {
            if !summary.overview.isEmpty {
                Text(summary.overview)
                    .typeStyle(.body)
                    .foregroundStyle(Color.textPrimary)
                    .textSelection(.enabled)
            }

            bulletGroup("Key points", summary.keyPoints)
            bulletGroup("Decisions", summary.decisions)
            bulletGroup("Action items", summary.actionItems)
            bulletGroup("Open questions", summary.openQuestions)
            bulletGroup("Follow-ups", summary.followUps)

            ForEach(Array(summary.details.enumerated()), id: \.offset) { _, detail in
                detailBlock(detail)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func bulletGroup(_ title: String, _ items: [String]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: MobileTheme.Spacing.md) {
                NoteSectionHeading(title)

                VStack(alignment: .leading, spacing: MobileTheme.Spacing.sm) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        BulletRow(text: item)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Keeps the rows inside their heading for VoiceOver, so swiping through action items
            // announces "Action items" once instead of five orphaned sentences.
            .accessibilityElement(children: .contain)
            .accessibilityLabel(title)
        }
    }

    private func detailBlock(_ detail: SummaryDetail) -> some View {
        VStack(alignment: .leading, spacing: MobileTheme.Spacing.sm) {
            NoteSectionHeading(detail.title)

            if !detail.timestamps.isEmpty {
                // On their own line rather than beside the title: a title long enough to wrap would
                // otherwise leave the citations stranded mid-heading.
                Text(detail.timestamps.joined(separator: " · "))
                    .typeStyle(.mono)
                    .foregroundStyle(Color.textTertiary)
                    .accessibilityLabel("Transcript at \(detail.timestamps.joined(separator: ", "))")
            }

            Text(detail.narrative)
                .typeStyle(.body)
                .foregroundStyle(Color.textPrimary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One bullet, with the wrap hanging under the text rather than under the bullet.
///
/// The bullet sits in its own fixed column, scaled against body text: a glyph inline with the
/// sentence would pull every wrapped line back to the margin, which at an accessibility text size
/// turns a five-item list into an unreadable block.
private struct BulletRow: View {
    let text: String

    @ScaledMetric(relativeTo: .body) private var gutter: CGFloat = 16

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("•")
                .foregroundStyle(Color.textTertiary)
                .frame(width: gutter, alignment: .leading)
                // Otherwise VoiceOver prefixes every item with the glyph's name; the list structure
                // is carried by the group around these rows.
                .accessibilityHidden(true)

            Text(text)
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .typeStyle(.body)
    }
}

/// A heading inside a note — "Key points", "Your notes", "Transcript".
///
/// Shared by the summary and the detail view so the two can't drift into two different weights of
/// the same word.
struct NoteSectionHeading: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .typeStyle(.section)
            .foregroundStyle(Color.textSecondary)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The status line above the record button, and the transcription-error notice on a saved meeting.
struct BannerView: View {
    let text: String
    let isError: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: MobileTheme.Spacing.sm) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .imageScale(.small)
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .typeStyle(.caption)
        .foregroundStyle(isError ? Color.recordingRed : Color.textSecondary)
        .padding(MobileTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isError ? Color.recordingRed.opacity(0.1) : Color.iconBadgeBackground,
            in: RoundedRectangle(cornerRadius: MobileTheme.Radius.card)
        )
        .accessibilityElement(children: .combine)
    }
}
