import XCTest
@testable import Convene

final class MarkdownRendererTests: XCTestCase {
    private func segment(
        _ speaker: TranscriptSegment.Speaker,
        start: TimeInterval,
        end: TimeInterval,
        text: String
    ) -> TranscriptSegment {
        TranscriptSegment(speaker: speaker, startedAt: start, endedAt: end, text: text, isFinal: true)
    }

    /// Transcript spanning two sections: headers at 00:00 and at 01:30 (90s ≥ 75s interval).
    private func transcript() -> [TranscriptSegment] {
        [
            segment(.you, start: 0, end: 5, text: "Kick-off and agenda."),
            segment(.others, start: 90, end: 95, text: "Discussion of the platform."),
            segment(.you, start: 100, end: 110, text: "Wrap up.")
        ]
    }

    private func meeting(
        details: [SummaryDetail] = [],
        attendees: [String] = []
    ) -> Meeting {
        Meeting(
            title: "Render test",
            attendees: attendees,
            startedAt: Date(timeIntervalSince1970: 1_750_000_000),
            endedAt: Date(timeIntervalSince1970: 1_750_000_300),
            transcript: transcript(),
            notes: "",
            summary: MeetingSummary(
                overview: "One-sentence abstract. Main threads.",
                topics: ["Platform"],
                keyPoints: ["Key point"],
                details: details,
                actionItems: ["Matthew: Send doc — short description."],
                decisions: [],
                openQuestions: [],
                followUps: [],
                generatedAt: Date(timeIntervalSince1970: 1_750_000_310)
            )
        )
    }

    // MARK: - Details section

    func testDetailsSectionRendersBetweenTLDRAndTopics() throws {
        let detail = SummaryDetail(
            title: "Platform discussion",
            narrative: "Michael walked through the platform.",
            timestamps: ["01:35"]
        )
        let markdown = MarkdownRenderer.renderMarkdown(meeting(details: [detail]))

        XCTAssertTrue(markdown.contains("## Details"))
        XCTAssertTrue(markdown.contains("### Platform discussion"))

        let tldr = try XCTUnwrap(markdown.range(of: "## TL;DR"))
        let details = try XCTUnwrap(markdown.range(of: "## Details"))
        let topics = try XCTUnwrap(markdown.range(of: "## Topics"))
        XCTAssertLessThan(tldr.lowerBound, details.lowerBound)
        XCTAssertLessThan(details.lowerBound, topics.lowerBound)
    }

    func testEmptyDetailsOmitsSection() {
        let markdown = MarkdownRenderer.renderMarkdown(meeting(details: []))
        XCTAssertFalse(markdown.contains("## Details"))
    }

    // MARK: - Citations

    func testCitationWikilinkResolvesToEmittedSectionHeader() {
        // 01:35 (95s) falls under the section that starts at 90s → "### 01:30".
        let detail = SummaryDetail(
            title: "Platform",
            narrative: "Discussion happened.",
            timestamps: ["01:35"]
        )
        let markdown = MarkdownRenderer.renderMarkdown(meeting(details: [detail]))

        XCTAssertTrue(markdown.contains("[[#01:30|01:35]]"))
        XCTAssertTrue(markdown.contains("### 01:30"), "Link target header must be emitted in the transcript")
    }

    func testCitationBeforeAnySectionHeaderLinksToFirstHeader() {
        let detail = SummaryDetail(
            title: "Kick-off",
            narrative: "The meeting opened.",
            timestamps: ["00:03"]
        )
        let markdown = MarkdownRenderer.renderMarkdown(meeting(details: [detail]))
        XCTAssertTrue(markdown.contains("[[#00:00|00:03]]"))
        XCTAssertTrue(markdown.contains("### 00:00"))
    }

    func testOutOfRangeTimestampFallsBackToPlainText() {
        // Transcript ends at 110s; 59:59 is far past it.
        let detail = SummaryDetail(
            title: "Hallucinated",
            narrative: "Should not produce a dead link.",
            timestamps: ["59:59"]
        )
        let markdown = MarkdownRenderer.renderMarkdown(meeting(details: [detail]))
        XCTAssertTrue(markdown.contains("Should not produce a dead link. 59:59"))
        XCTAssertFalse(markdown.contains("[[#"))
    }

    func testGarbageTimestampFallsBackToPlainText() {
        let detail = SummaryDetail(
            title: "Garbage",
            narrative: "Narrative.",
            timestamps: ["around the middle"]
        )
        let markdown = MarkdownRenderer.renderMarkdown(meeting(details: [detail]))
        XCTAssertTrue(markdown.contains("Narrative. around the middle"))
        XCTAssertFalse(markdown.contains("[[#"))
    }

    // MARK: - Frontmatter attendees

    func testAttendeeEmailsBecomeDisplayNamesAndRawEmailsArePreserved() {
        let markdown = MarkdownRenderer.renderMarkdown(
            meeting(attendees: ["matthew@linktr.ee", "michael@linktr.ee"])
        )
        XCTAssertTrue(markdown.contains("attendees:\n  - \"Matthew\"\n  - \"Michael\"\n"))
        XCTAssertTrue(markdown.contains("attendee_emails:\n  - \"matthew@linktr.ee\"\n  - \"michael@linktr.ee\"\n"))
    }

    func testAttendeeEmailsKeyOmittedWhenNamesAlreadyDisplayNames() {
        let markdown = MarkdownRenderer.renderMarkdown(
            meeting(attendees: ["Matthew Blode", "Michael Ricci"])
        )
        XCTAssertTrue(markdown.contains("attendees:\n  - \"Matthew Blode\"\n  - \"Michael Ricci\"\n"))
        XCTAssertFalse(markdown.contains("attendee_emails:"))
    }
}
