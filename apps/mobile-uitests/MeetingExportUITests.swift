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
        XCTAssertTrue(app.staticTexts["Markdown copied"].waitForExistence(timeout: 3))
        for _ in 0..<2 {
            app.buttons["More"].tap()
            app.buttons["Show Transcript"].tap()
            let copy = app.buttons["Copy Transcript"]
            XCTAssertTrue(copy.waitForExistence(timeout: 3))
            copy.tap()
            XCTAssertTrue(app.staticTexts["Transcript copied"].waitForExistence(timeout: 3))
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "transcript-copy-confirmation"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            app.buttons["Done"].tap()
        }
        XCTAssertTrue(app.buttons["Share Text File"].exists)
    }
}
