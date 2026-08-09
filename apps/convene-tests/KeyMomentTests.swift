import XCTest
@testable import Convene

final class KeyMomentTests: XCTestCase {
    /// Two sections: headers at 00:00 and 01:30 (90s ≥ 75s interval), like MarkdownRendererTests.
    private func transcript() -> [TranscriptSegment] {
        [
            makeSegment(.you, start: 0, end: 5, text: "Kick-off and agenda."),
            makeSegment(.others, start: 90, end: 95, text: "Discussion of the platform."),
            makeSegment(.you, start: 100, end: 110, text: "Wrap up.")
        ]
    }

    private func meeting(keyMoments: [KeyMoment], transcript: [TranscriptSegment]) -> Meeting {
        Meeting(
            title: "Render test",
            startedAt: Date(timeIntervalSince1970: 1_750_000_000),
            endedAt: Date(timeIntervalSince1970: 1_750_000_300),
            transcript: transcript,
            keyMoments: keyMoments,
            notes: ""
        )
    }

    // MARK: - Markdown rendering

    func testKeyMomentsIndexLinksToTranscriptSection() throws {
        let moment = KeyMoment(offset: 95, text: "Pricing decision")
        let markdown = MarkdownRenderer.renderMarkdown(meeting(keyMoments: [moment], transcript: transcript()))

        XCTAssertTrue(markdown.contains("## Key Moments"))
        // 95s formats as 01:35; falls under the 01:30 section header.
        XCTAssertTrue(markdown.contains("- [[#01:30|01:35]] — Pricing decision"))
    }

    func testBareFlagRendersWithoutDash() throws {
        let moment = KeyMoment(offset: 2, text: "")
        let markdown = MarkdownRenderer.renderMarkdown(meeting(keyMoments: [moment], transcript: transcript()))

        XCTAssertTrue(markdown.contains("## Key Moments"))
        // No annotation: just the link, no " — " separator.
        XCTAssertTrue(markdown.contains("- [[#00:00|00:02]]\n"))
        XCTAssertFalse(markdown.contains("00:02]] —"))
    }

    func testInlineMarkerLandsBeforeTheBlockItPrecedes() throws {
        let moment = KeyMoment(offset: 95, text: "Pricing decision")
        let markdown = MarkdownRenderer.renderMarkdown(meeting(keyMoments: [moment], transcript: transcript()))

        let marker = "> ⭐ **Key moment** (01:35) — Pricing decision"
        XCTAssertTrue(markdown.contains(marker))
        // The marker (offset 95) precedes the 100s "Wrap up." block but follows the 90s block.
        let markerRange = try XCTUnwrap(markdown.range(of: marker))
        let wrapUpRange = try XCTUnwrap(markdown.range(of: "Wrap up."))
        let platformRange = try XCTUnwrap(markdown.range(of: "Discussion of the platform."))
        XCTAssertLessThan(markerRange.lowerBound, wrapUpRange.lowerBound)
        XCTAssertLessThan(platformRange.lowerBound, markerRange.lowerBound)
    }

    func testMomentAfterLastBlockStillRenders() throws {
        let moment = KeyMoment(offset: 500, text: "Closing thought")
        let markdown = MarkdownRenderer.renderMarkdown(meeting(keyMoments: [moment], transcript: transcript()))

        XCTAssertTrue(markdown.contains("> ⭐ **Key moment** (08:20) — Closing thought"))
        // Past transcript end, so the index falls back to a plain label (no dead wikilink).
        XCTAssertTrue(markdown.contains("- 08:20 — Closing thought"))
    }

    func testNoKeyMomentsOmitsSection() throws {
        let markdown = MarkdownRenderer.renderMarkdown(meeting(keyMoments: [], transcript: transcript()))
        XCTAssertFalse(markdown.contains("## Key Moments"))
        XCTAssertFalse(markdown.contains("⭐"))
    }

    // MARK: - Legacy decode

    func testLegacyMeetingJSONWithoutKeyMomentsDecodes() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "title": "Legacy",
            "attendees": [],
            "startedAt": "2024-01-01T00:00:00Z",
            "transcript": [],
            "notes": ""
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let meeting = try decoder.decode(Meeting.self, from: XCTUnwrap(json.data(using: .utf8)))
        XCTAssertEqual(meeting.keyMoments, [])
    }

    func testKeyMomentRoundTripsThroughCodable() throws {
        let original = Meeting(
            title: "Round trip",
            startedAt: Date(timeIntervalSince1970: 1_750_000_000),
            transcript: [],
            keyMoments: [KeyMoment(offset: 42, text: "Important")],
            notes: ""
        )
        let data = try MarkdownRenderer.encodeJSON(original)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Meeting.self, from: data)
        XCTAssertEqual(decoded.keyMoments.count, 1)
        XCTAssertEqual(decoded.keyMoments.first?.offset, 42)
        XCTAssertEqual(decoded.keyMoments.first?.text, "Important")
    }
}
