import XCTest

final class MeetingExportUITests: XCTestCase {
    @MainActor
    func testCopyActionsSurviveTranscriptDismissalAndReopening() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["CONVENE_UI_TEST_SCREENSHOT_MODE"]
        app.launch()
        let card = app.buttons.matching(
            NSPredicate(
                format: "label BEGINSWITH %@", "Design review — recording sheet"
            )
        ).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
        app.buttons["More"].tap()
        app.buttons["Copy Markdown"].tap()
        let feedback = app.descendants(matching: .any).matching(identifier: "exportFeedback").firstMatch
        XCTAssertTrue(feedback.waitForExistence(timeout: 3))
        XCTAssertEqual(feedback.label, "Markdown copied")
        for _ in 0..<2 {
            app.buttons["More"].tap()
            app.buttons["Show Transcript"].tap()
            let copy = app.buttons["Copy Transcript"]
            XCTAssertTrue(copy.waitForExistence(timeout: 3))
            copy.tap()
            XCTAssertTrue(feedback.waitForExistence(timeout: 3))
            XCTAssertEqual(feedback.label, "Transcript copied")
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "transcript-copy-confirmation"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            app.buttons["Done"].tap()
        }
        let share = app.buttons["Share Text File"]
        XCTAssertTrue(share.exists)
        for _ in 0..<2 {
            share.tap()
            let close = app.buttons["Close"].firstMatch
            XCTAssertTrue(close.waitForExistence(timeout: 5), "The system share sheet must open")
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "text-file-share-sheet"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            close.tap()
            XCTAssertTrue(share.waitForExistence(timeout: 5))
        }
    }
}
