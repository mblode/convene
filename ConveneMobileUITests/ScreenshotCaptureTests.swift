import XCTest

/// Drives the seeded iPhone app through the screens used in the App Store listing and attaches a
/// full-screen capture of each.
///
/// Not an assertion suite: the only failure mode that matters is a screen that never appeared,
/// which would otherwise hand the store a screenshot of the wrong UI. `screenshots/capture.sh` runs
/// this and pulls the attachments back out of the result bundle.
///
/// The fixture behind it is `#if DEBUG` only (`ScreenshotFixture`), so this has to run against a
/// Debug build — a Release build lands on the welcome screen with an empty library.
final class ScreenshotCaptureTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    /// The seeded meeting the detail, summary and transcript slides open. Newest in the library, so
    /// it is the first card.
    private static let featuredMeeting = "Design review — recording sheet"

    @MainActor
    func testCaptureLightScreens() throws {
        let app = launch(liveMeeting: true)

        // The recording sheet goes last. It is the one capture that leaves a sheet on screen, and
        // dismissing it by drag is the flakiest step here — running it last means nothing depends
        // on the dismissal working.
        captureSettings(named: "05-settings", in: app)
        captureMeetingDetail(named: "02-detail", in: app)
        captureSummary(named: "03-summary", in: app)
        captureTranscript(named: "04-transcript", in: app)
        returnToLibrary(in: app)
        captureRecordingSheet(named: "01-record", in: app)
    }

    @MainActor
    func testCaptureDarkScreens() throws {
        let app = launch(dark: true)

        attach("06-library-dark", in: app)
        captureMeetingDetail(named: "07-detail-dark", in: app)
    }

    // MARK: - Steps

    /// Settings, opened from the list's toolbar: the API key rows with their saved ticks, and the
    /// "Saving to" row naming the vault the fixture points at.
    @MainActor
    private func captureSettings(named name: String, in app: XCUIApplication) {
        app.buttons["Settings"].firstMatch.tap()
        XCTAssertTrue(
            app.navigationBars["Settings"].waitForExistence(timeout: 5),
            "Settings never opened"
        )
        settle()
        attach(name, in: app)

        app.buttons["Back to meetings"].firstMatch.tap()
        XCTAssertTrue(libraryIsShowing(in: app), "Settings never closed")
    }

    @MainActor
    private func captureMeetingDetail(named name: String, in app: XCUIApplication) {
        openFeaturedMeeting(in: app)
        settle()
        attach(name, in: app)
    }

    /// The same note, scrolled to where the generated summary is doing the talking — decisions and
    /// action items rather than the title and the opening paragraph.
    @MainActor
    private func captureSummary(named name: String, in app: XCUIApplication) {
        let note = app.scrollViews.firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 5), "The note never appeared")

        let anchor = app.staticTexts["Action items"].firstMatch
        scroll(note, bringing: anchor, toFraction: 0.3, in: app)
        XCTAssertTrue(anchor.exists, "The summary's action items never came into view")
        settle()
        attach(name, in: app)
    }

    /// Reached from the overflow menu rather than by scrolling to the chip at the foot of the note,
    /// which moves every time the summary's length changes.
    @MainActor
    private func captureTranscript(named name: String, in app: XCUIApplication) {
        app.buttons["More"].firstMatch.tap()
        let showTranscript = app.buttons["Show Transcript"].firstMatch
        XCTAssertTrue(showTranscript.waitForExistence(timeout: 5), "The overflow menu never opened")
        showTranscript.tap()

        XCTAssertTrue(
            app.navigationBars["Transcript"].waitForExistence(timeout: 5),
            "The transcript sheet never opened"
        )
        settle()
        attach(name, in: app)

        app.buttons["Done"].firstMatch.tap()
    }

    /// The live meeting: elapsed timer, level meter, the notes being typed, and the transcript
    /// arriving under them.
    @MainActor
    private func captureRecordingSheet(named name: String, in app: XCUIApplication) {
        recordControl(in: app).tap()

        let stop = app.buttons["Stop"].firstMatch
        XCTAssertTrue(stop.waitForExistence(timeout: 5), "The recording sheet never opened")

        expandSheet(in: app)
        settle()
        attach(name, in: app)
    }

    // MARK: - Navigation

    @MainActor
    private func openFeaturedMeeting(in app: XCUIApplication) {
        let card = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", Self.featuredMeeting))
            .firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "The seeded meeting never appeared")
        card.tap()
        XCTAssertTrue(
            app.staticTexts[Self.featuredMeeting].waitForExistence(timeout: 5),
            "The meeting note never opened"
        )
    }

    @MainActor
    private func returnToLibrary(in app: XCUIApplication) {
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(libraryIsShowing(in: app), "Never got back to the meetings list")
    }

    @MainActor
    private func libraryIsShowing(in app: XCUIApplication) -> Bool {
        app.navigationBars["Meetings"].waitForExistence(timeout: 5)
    }

    /// The floating record pill. While the fixture poses as recording it carries the elapsed
    /// readout's label rather than "Record", so it is matched on that; the coordinate is the
    /// fallback for a label that has been reworded.
    @MainActor
    private func recordControl(in app: XCUIApplication) -> XCUIElement {
        let byLabel = app.buttons
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "elapsed"))
            .firstMatch
        if byLabel.waitForExistence(timeout: 5) {
            return byLabel
        }
        return app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.93)).referencedElement
    }

    /// Drag the sheet from its opening half height to full.
    ///
    /// The app promotes the detent itself on the first transcribed turn, but the fixture's
    /// transcript is already there when the sheet opens, so nothing changes and nothing promotes.
    /// Deliberately unasserted: a medium sheet is still a usable screenshot.
    @MainActor
    private func expandSheet(in app: XCUIApplication) {
        let grabber = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let top = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.06))
        grabber.press(forDuration: 0.1, thenDragTo: top)
    }

    /// Nudge `scrollView` until `anchor` sits `toFraction` of the way down the screen.
    ///
    /// A `swipeUp()` carries momentum and lands somewhere different on every run — usually with a
    /// line of body text sliced in half behind the floating toolbar, which reads as a rendering bug
    /// in a store listing. Short inertia-free drags, checked against the anchor's own frame, land
    /// the same way every time.
    @MainActor
    private func scroll(
        _ scrollView: XCUIElement,
        bringing anchor: XCUIElement,
        toFraction target: CGFloat,
        in app: XCUIApplication
    ) {
        let limit = app.frame.height * target
        for _ in 0..<10 {
            if anchor.exists, anchor.frame.midY <= limit { return }
            let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            let end = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
            start.press(
                forDuration: 0.15,
                thenDragTo: end,
                withVelocity: .slow,
                thenHoldForDuration: 0.15
            )
        }
    }

    // MARK: - Helpers

    /// `liveMeeting` turns the floating record pill red and starts its clock, which slide 1 needs
    /// and every other slide showing the list would be wrong to have.
    @MainActor
    private func launch(dark: Bool = false, liveMeeting: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["CONVENE_UI_TEST_SCREENSHOT_MODE"]
        if dark {
            app.launchArguments += ["CONVENE_UI_TEST_DARK_MODE"]
        }
        if liveMeeting {
            app.launchArguments += ["CONVENE_UI_TEST_LIVE_MEETING"]
        }
        app.launch()
        XCTAssertTrue(libraryIsShowing(in: app), "The meetings list never appeared")
        settle()
        return app
    }

    @MainActor
    private func attach(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Let a push, a sheet or a scroll finish, so no capture catches a view mid-transition.
    private func settle() {
        Thread.sleep(forTimeInterval: 1.2)
    }
}
