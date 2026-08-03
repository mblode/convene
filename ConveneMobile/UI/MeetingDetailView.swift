import SwiftUI
import UIKit

/// A saved meeting, read as a document: its title, a line of metadata, the summary, your notes and
/// the moments you flagged. The transcript lives in `TranscriptSheet`, a tap away.
struct MeetingDetailView: View {
    let meeting: Meeting
    /// What to show where the summary goes while `meeting.summary` is still `nil`. Defaults to
    /// `.off` — nothing — so a caller holding only a meeting keeps today's behaviour.
    var summaryStatus: SummaryStatus = .off
    var retrySummary: (() -> Void)?

    @State private var isShowingTranscript = false

    /// The shareable markdown, rendered once.
    ///
    /// `ShareLink`'s item is evaluated with the view body, so building it inline re-rendered the
    /// whole meeting — transcript included — on every redraw, to produce a string the user only
    /// wants when they tap Share.
    @State private var markdown = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MobileTheme.Spacing.xxl) {
                header

                if let error = meeting.transcriptionError {
                    BannerView(text: error, isError: true)
                }

                summarySection

                if !meeting.notes.isEmpty {
                    section("Your notes") {
                        Text(meeting.notes)
                            .typeStyle(.body)
                            .foregroundStyle(Color.textPrimary)
                            .textSelection(.enabled)
                    }
                }

                if !meeting.keyMoments.isEmpty {
                    section("Key moments") { keyMoments }
                }

                transcriptSection
            }
            .padding(.horizontal, MobileTheme.Spacing.lg)
            .padding(.bottom, MobileTheme.Spacing.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.appBackground)
        // The title is set at display size in the content below; a navigation title would print the
        // same words twice, an inch apart.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        UIPasteboard.general.string = MarkdownRenderer.renderMarkdown(meeting)
                    } label: {
                        Label("Copy Markdown", systemImage: "doc.on.doc")
                    }

                    if !meeting.transcript.isEmpty {
                        Button {
                            isShowingTranscript = true
                        } label: {
                            Label("Show Transcript", systemImage: "text.alignleft")
                        }
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: markdown, preview: SharePreview(meeting.title))
            }
        }
        .sheet(isPresented: $isShowingTranscript) {
            TranscriptSheet(meeting: meeting)
        }
        // Re-rendered when the summary lands, which is the one thing that changes under an open
        // detail view.
        .task(id: meeting) {
            markdown = MarkdownRenderer.renderMarkdown(meeting)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: MobileTheme.Spacing.md) {
            Text(meeting.title)
                .typeStyle(.display)
                .foregroundStyle(Color.textPrimary)
                .textSelection(.enabled)
                .accessibilityAddTraits(.isHeader)

            ChipFlow(spacing: MobileTheme.Spacing.sm) {
                Chip(text: startedAtLabel)

                if let durationLabel {
                    Chip(text: durationLabel)
                }

                if !meeting.keyMoments.isEmpty {
                    Chip(text: keyMomentLabel, systemImage: "flag.fill")
                }
            }
            // Four pills are one sentence about the meeting, not four stops on a swipe.
            .accessibilityElement(children: .combine)
        }
        .padding(.top, MobileTheme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var summarySection: some View {
        if let summary = meeting.summary {
            SummaryView(summary: summary)
        } else {
            SummaryStatusCard(status: summaryStatus, retry: retrySummary)
        }
    }

    private var keyMoments: some View {
        VStack(alignment: .leading, spacing: MobileTheme.Spacing.sm) {
            ForEach(meeting.keyMoments) { moment in
                HStack(alignment: .firstTextBaseline, spacing: MobileTheme.Spacing.md) {
                    Text(moment.formattedTimestamp)
                        .typeStyle(.mono)
                        .foregroundStyle(Color.textTertiary)
                    Text(moment.trimmedText.isEmpty ? "Flagged" : moment.trimmedText)
                        .typeStyle(.body)
                        .foregroundStyle(Color.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    @ViewBuilder
    private var transcriptSection: some View {
        if meeting.transcript.isEmpty {
            Text("No transcript was captured for this meeting.")
                .typeStyle(.caption)
                .foregroundStyle(Color.textTertiary)
        } else {
            ChipButton(text: "Transcript", systemImage: "text.alignleft") {
                isShowingTranscript = true
            }
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: MobileTheme.Spacing.md) {
            NoteSectionHeading(title)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "Today 11:30" for the meetings a user is most likely to open, the full date for the rest.
    /// `Date.FormatStyle` has no relative day of its own, and "Aug 3 at 11:30" for a meeting that
    /// finished an hour ago makes the reader do arithmetic to place it.
    private var startedAtLabel: String {
        let time = meeting.startedAt.formatted(date: .omitted, time: .shortened)
        let calendar = Calendar.current
        if calendar.isDateInToday(meeting.startedAt) { return "Today \(time)" }
        if calendar.isDateInYesterday(meeting.startedAt) { return "Yesterday \(time)" }
        return meeting.startedAt.formatted(date: .abbreviated, time: .shortened)
    }

    /// `nil` below a minute: a chip reading "0 min" says less than no chip at all.
    private var durationLabel: String? {
        guard let endedAt = meeting.endedAt else { return nil }
        let seconds = endedAt.timeIntervalSince(meeting.startedAt)
        guard seconds >= 60 else { return nil }
        return Duration.seconds(seconds)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    private var keyMomentLabel: String {
        meeting.keyMoments.count == 1 ? "1 key moment" : "\(meeting.keyMoments.count) key moments"
    }
}

/// Lays its children out in a row, wrapping onto as many rows as they need.
///
/// An `HStack` truncates the metadata chips at an accessibility text size, and the line that says
/// when a meeting happened is the wrong one to cut — vertical space is free here, under a title in
/// a scroll view. Each child is measured against the container's width rather than its ideal size,
/// so a single chip too wide for the screen wraps its own label instead of running off the edge.
private struct ChipFlow: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let available = proposal.width ?? .infinity
        let rows = rows(fitting: available, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? (rows.map(\.width).max() ?? 0), height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        var y = bounds.minY
        for row in rows(fitting: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for element in row.elements {
                subviews[element.index].place(
                    at: CGPoint(x: x, y: y + (row.height - element.size.height) / 2),
                    proposal: ProposedViewSize(element.size)
                )
                x += element.size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Element {
        let index: Int
        let size: CGSize
    }

    private struct Row {
        var elements: [Element] = []
        var width: CGFloat = 0
        var height: CGFloat = 0

        mutating func append(_ element: Element, spacing: CGFloat) {
            width += elements.isEmpty ? element.size.width : spacing + element.size.width
            height = max(height, element.size.height)
            elements.append(element)
        }
    }

    private func rows(fitting width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil))
            if !current.elements.isEmpty, current.width + spacing + size.width > width {
                rows.append(current)
                current = Row()
            }
            current.append(Element(index: index, size: size), spacing: spacing)
        }

        if !current.elements.isEmpty { rows.append(current) }
        return rows
    }
}
