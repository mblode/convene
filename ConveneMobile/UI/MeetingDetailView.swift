import SwiftUI

/// A saved meeting: summary, your notes, the moments you flagged, and the full transcript.
struct MeetingDetailView: View {
    let meeting: Meeting

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MobileTheme.Spacing.xl) {
                header

                if let error = meeting.transcriptionError {
                    BannerView(text: error, isError: true)
                }

                if let summary = meeting.summary {
                    SummaryView(summary: summary)
                }

                if !meeting.notes.isEmpty {
                    section("Your notes") {
                        Text(meeting.notes)
                            .textSelection(.enabled)
                    }
                }

                if !meeting.keyMoments.isEmpty {
                    section("Key moments") {
                        VStack(alignment: .leading, spacing: MobileTheme.Spacing.sm) {
                            ForEach(meeting.keyMoments) { moment in
                                HStack(alignment: .firstTextBaseline, spacing: MobileTheme.Spacing.sm) {
                                    Text(moment.formattedTimestamp)
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                    Text(moment.trimmedText.isEmpty ? "Flagged" : moment.trimmedText)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                }

                if meeting.transcript.isEmpty {
                    Text("No transcript was captured for this meeting.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    section("Transcript") {
                        TranscriptView(
                            segments: meeting.transcript,
                            selfName: meeting.selfName,
                            othersName: meeting.othersName
                        )
                    }
                }
            }
            .padding(MobileTheme.Spacing.lg)
        }
        .navigationTitle(meeting.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // Shares the same markdown that was written to disk, so a note forwarded from
                // the phone is byte-for-byte what the file contains.
                ShareLink(
                    item: MarkdownRenderer.renderMarkdown(meeting),
                    subject: Text(meeting.title)
                )
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: MobileTheme.Spacing.xs) {
            Text(meeting.title)
                .font(.title2.weight(.semibold))
            Text(meeting.startedAt, format: .dateTime.weekday(.wide).day().month(.wide).hour().minute())
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: MobileTheme.Spacing.md) {
            Text(title).font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
