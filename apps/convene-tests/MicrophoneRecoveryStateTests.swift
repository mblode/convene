import XCTest

@testable import Convene

final class MicrophoneRecoveryStateTests: XCTestCase {
    func testInterruptionKeepsMeetingOpenAndOffersExplicitResume() {
        var state = MicrophoneRecoveryState()
        state.start()
        state.interruptionBegan()

        XCTAssertTrue(state.isRecording)
        XCTAssertTrue(state.isInterrupted)
        XCTAssertTrue(state.canResume, "An interruption-ended notification is not guaranteed")
        XCTAssertNil(state.routeChanged(), "A route change cannot override an active interruption")
    }

    func testMissingResumeHintWaitsForUserWithoutEndingMeeting() {
        var state = MicrophoneRecoveryState()
        state.start()
        state.interruptionBegan()

        XCTAssertNil(state.interruptionEnded(shouldResume: false))
        XCTAssertEqual(state.phase, .needsUserResume)
        XCTAssertTrue(state.isRecording)
        XCTAssertTrue(state.canResume)
        XCTAssertNil(state.routeChanged(), "Route notifications must not bypass the missing resume hint")
    }

    func testResumeHintAllowsRecoveryThenClearsInterruptionOnSuccess() throws {
        var state = MicrophoneRecoveryState()
        state.start()
        state.interruptionBegan()
        let token = try XCTUnwrap(state.interruptionEnded(shouldResume: true))

        XCTAssertTrue(state.acceptsRecovery(token))
        XCTAssertTrue(state.isInterrupted, "Do not claim to capture before activation succeeds")
        XCTAssertFalse(state.canResume, "Repeated taps must not start concurrent recovery")
        state.recoverySucceeded(token)
        XCTAssertEqual(state.phase, .recording)
        XCTAssertFalse(state.isInterrupted)
        XCTAssertFalse(state.acceptsRecovery(token))
    }

    func testFailedRecoveryOffersRetryWithoutEndingMeeting() throws {
        var state = MicrophoneRecoveryState()
        state.start()
        let token = try XCTUnwrap(state.routeChanged())
        state.recoveryFailed(token)

        XCTAssertTrue(state.isRecording)
        XCTAssertTrue(state.isInterrupted)
        XCTAssertTrue(state.canResume)
        XCTAssertNil(state.routeChanged())
        let retry = try XCTUnwrap(state.resumeRequested())
        XCTAssertNotEqual(token, retry)
        XCTAssertFalse(state.acceptsRecovery(token))
        state.recoverySucceeded(retry)
        XCTAssertEqual(state.phase, .recording)
    }

    func testUserCanResumeWhenNoEndedNotificationArrives() throws {
        var state = MicrophoneRecoveryState()
        state.start()
        state.interruptionBegan()
        let token = try XCTUnwrap(state.resumeRequested())

        // A user action grants intent, not hardware access. If AVAudioSession refuses it,
        // the adapter reports failure and capture remains paused.
        state.recoveryFailed(token)
        XCTAssertEqual(state.phase, .needsUserResume)
        XCTAssertTrue(state.canResume)
        XCTAssertTrue(state.isRecording)
    }

    func testStopDuringRecoveryInvalidatesDelayedRetries() throws {
        var state = MicrophoneRecoveryState()
        state.start()
        state.interruptionBegan()
        let token = try XCTUnwrap(state.interruptionEnded(shouldResume: true))
        state.stop()

        XCTAssertFalse(state.acceptsRecovery(token))
        state.recoverySucceeded(token)
        state.recoveryFailed(token)
        XCTAssertEqual(state.phase, .idle)
        XCTAssertFalse(state.isInterrupted)
        XCTAssertNil(state.resumeRequested())
    }

    func testStopWhileInterruptedIgnoresLateSystemEvents() {
        var state = MicrophoneRecoveryState()
        state.start()
        state.interruptionBegan()
        state.stop()

        XCTAssertNil(state.interruptionEnded(shouldResume: true))
        XCTAssertNil(state.routeChanged())
        state.interruptionBegan()
        state.requireUserResume()
        XCTAssertEqual(state.phase, .idle)
        XCTAssertFalse(state.isRecording)
    }

    func testOldRecoveryCannotAffectANewMeeting() throws {
        var state = MicrophoneRecoveryState()
        state.start()
        let oldToken = try XCTUnwrap(state.routeChanged())
        state.stop()
        state.start()
        let newToken = try XCTUnwrap(state.routeChanged())

        XCTAssertNotEqual(oldToken, newToken)
        state.recoverySucceeded(oldToken)
        state.recoveryFailed(oldToken)
        XCTAssertTrue(state.acceptsRecovery(newToken))
        state.recoverySucceeded(newToken)
        XCTAssertEqual(state.phase, .recording)
    }

    func testAnotherInterruptionCancelsInFlightRecovery() throws {
        var state = MicrophoneRecoveryState()
        state.start()
        let token = try XCTUnwrap(state.routeChanged())
        state.interruptionBegan()

        XCTAssertFalse(state.acceptsRecovery(token))
        state.recoverySucceeded(token)
        state.recoveryFailed(token)
        XCTAssertEqual(state.phase, .interrupted)
        XCTAssertNotNil(state.interruptionEnded(shouldResume: true))
    }

    func testDuplicateEndedAndRouteEventsDoNotStartAnotherRecovery() throws {
        var state = MicrophoneRecoveryState()
        state.start()
        state.interruptionBegan()
        let token = try XCTUnwrap(state.interruptionEnded(shouldResume: true))

        XCTAssertNil(state.interruptionEnded(shouldResume: true))
        XCTAssertNil(state.routeChanged())
        XCTAssertNil(state.resumeRequested())
        XCTAssertTrue(state.acceptsRecovery(token))
        state.recoverySucceeded(token)
        XCTAssertNil(state.interruptionEnded(shouldResume: true))
        XCTAssertNil(state.interruptionEnded(shouldResume: false))
        XCTAssertEqual(state.phase, .recording)
    }

    func testMediaServiceResetRequiresUserActionAndInvalidatesRetry() throws {
        var state = MicrophoneRecoveryState()
        state.start()
        let token = try XCTUnwrap(state.routeChanged())
        state.requireUserResume()

        XCTAssertFalse(state.acceptsRecovery(token))
        XCTAssertEqual(state.phase, .needsUserResume)
        XCTAssertNil(state.interruptionEnded(shouldResume: true))
        XCTAssertNil(state.routeChanged())
        XCTAssertNotNil(state.resumeRequested())
    }
}
