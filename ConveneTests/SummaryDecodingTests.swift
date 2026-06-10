import XCTest
@testable import Convene

final class SummaryDecodingTests: XCTestCase {
    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: - v3 payload with details

    func testSummaryWithDetailsDecodes() throws {
        let json = """
        {
            "overview": "A short abstract. More context.",
            "topics": ["Notifications"],
            "keyPoints": ["Point one"],
            "details": [
                {
                    "title": "Notification platform",
                    "narrative": "Michael committed to sharing context on push support.",
                    "timestamps": ["05:00", "07:23"]
                }
            ],
            "actionItems": ["Michael: Share context on push support — one sentence."],
            "decisions": [],
            "openQuestions": [],
            "followUps": [],
            "generatedAt": "2026-06-10T03:49:30Z",
            "provider": "anthropic",
            "model": "claude-fable-5",
            "promptVersion": "meeting-summary-v3"
        }
        """
        let summary = try decoder().decode(MeetingSummary.self, from: Data(json.utf8))
        XCTAssertEqual(summary.details.count, 1)
        XCTAssertEqual(summary.details[0].title, "Notification platform")
        XCTAssertEqual(summary.details[0].timestamps, ["05:00", "07:23"])
    }

    func testDetailWithoutTimestampsDecodesToEmptyArray() throws {
        let json = """
        {"title": "T", "narrative": "N"}
        """
        let detail = try decoder().decode(SummaryDetail.self, from: Data(json.utf8))
        XCTAssertEqual(detail.timestamps, [])
    }

    // MARK: - Legacy payload without details

    func testLegacySummaryWithoutDetailsDecodesToEmptyDetails() throws {
        let json = """
        {
            "overview": "Legacy summary",
            "topics": [],
            "keyPoints": [],
            "actionItems": [],
            "decisions": [],
            "openQuestions": [],
            "followUps": [],
            "generatedAt": "2026-01-05T10:00:00Z"
        }
        """
        let summary = try decoder().decode(MeetingSummary.self, from: Data(json.utf8))
        XCTAssertEqual(summary.details, [])
        XCTAssertEqual(summary.overview, "Legacy summary")
    }

    // MARK: - Persisted fixture (pre-details JSON on disk)

    func testPersistedMeetingFixtureWithoutDetailsStillDecodes() throws {
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "meeting-4ec85721", withExtension: "json"),
            "Fixture meeting-4ec85721.json missing from test bundle"
        )
        let meeting = try decoder().decode(Meeting.self, from: Data(contentsOf: url))
        let summary = try XCTUnwrap(meeting.summary)
        XCTAssertEqual(summary.details, [])
        XCTAssertFalse(summary.overview.isEmpty)
    }

    // MARK: - Round trip

    func testMeetingWithDetailsRoundTrips() throws {
        let summary = MeetingSummary(
            overview: "Abstract. Threads.",
            topics: ["A"],
            keyPoints: ["K"],
            details: [
                SummaryDetail(title: "Section", narrative: "Who said what.", timestamps: ["01:15"])
            ],
            actionItems: ["Matthew: Do thing — short description."],
            decisions: ["Decided"],
            openQuestions: [],
            followUps: [],
            generatedAt: Date(timeIntervalSince1970: 1_750_000_000),
            provider: "anthropic",
            model: "claude-fable-5",
            promptVersion: "meeting-summary-v3"
        )
        let meeting = Meeting(title: "Round trip", summary: summary)

        let data = try MarkdownRenderer.encodeJSON(meeting)
        let decoded = try decoder().decode(Meeting.self, from: data)

        XCTAssertEqual(decoded.summary?.details, summary.details)
        XCTAssertEqual(decoded.summary?.promptVersion, "meeting-summary-v3")
    }
}
