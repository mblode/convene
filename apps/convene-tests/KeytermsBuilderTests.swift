import XCTest
@testable import Convene

final class KeytermsBuilderTests: XCTestCase {
    // MARK: - Attendees

    func testAttendeeEmailsBecomeDisplayNames() {
        let terms = KeytermsBuilder.build(
            attendees: ["michael@linktr.ee", "jane.doe@example.com"],
            title: ""
        )
        XCTAssertEqual(terms, ["Michael", "Jane Doe"])
    }

    func testAttendeeFullDisplayNamesPassThrough() {
        let terms = KeytermsBuilder.build(attendees: ["Matthew Blode"], title: "")
        XCTAssertEqual(terms, ["Matthew Blode"])
    }

    // MARK: - Title words

    func testTitleWordsFilterStopwordsShortWordsAndNumbers() {
        let terms = KeytermsBuilder.build(
            attendees: [],
            title: "Weekly sync with Acme about Roadmap on 10/06/2026 in Q3"
        )
        XCTAssertEqual(terms, ["Acme", "Roadmap"])
    }

    func testPureNumbersAreExcluded() {
        let terms = KeytermsBuilder.build(attendees: [], title: "Budget 2026 planning 12345")
        XCTAssertEqual(terms, ["Budget", "planning"])
    }

    // MARK: - Truncation

    func testTermsAreTruncatedToFiftyCharacters() {
        let long = String(repeating: "a", count: 80)
        let terms = KeytermsBuilder.build(attendees: [long], title: "")
        XCTAssertEqual(terms.count, 1)
        XCTAssertEqual(terms[0].count, 50)
        XCTAssertEqual(terms[0], String(repeating: "a", count: 50))
    }

    // MARK: - Dedupe

    func testCaseInsensitiveDedupePrefersAttendeeOverTitleWord() {
        let terms = KeytermsBuilder.build(
            attendees: ["michael@linktr.ee"],
            title: "MICHAEL roadmap michael"
        )
        XCTAssertEqual(terms, ["Michael", "roadmap"])
    }

    func testDedupeKeepsFirstOccurrenceAmongAttendees() {
        let terms = KeytermsBuilder.build(
            attendees: ["Jane Doe", "jane.doe@example.com"],
            title: ""
        )
        XCTAssertEqual(terms, ["Jane Doe"])
    }

    // MARK: - Cap

    func testCapsAtOneHundredTerms() {
        let attendees = (0..<150).map { "person\($0)@example.com" }
        let terms = KeytermsBuilder.build(attendees: attendees, title: "Quarterly roadmap")
        XCTAssertEqual(terms.count, 100)
        XCTAssertEqual(terms[0], "Person0")
        XCTAssertEqual(terms[99], "Person99")
        XCTAssertFalse(terms.contains("Quarterly"))
    }

    // MARK: - Empty input

    func testEmptyInputsProduceEmptyArray() {
        XCTAssertEqual(KeytermsBuilder.build(attendees: [], title: ""), [])
        XCTAssertEqual(KeytermsBuilder.build(attendees: ["   "], title: "   "), [])
    }
}
