import SwiftUI
import UIKit

@main
struct ConveneMobileApp: App {
    @StateObject private var store = MobileMeetingStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .task { store.prepare() }
                // The audio background mode keeps capture alive when the phone locks, but a screen
                // that sleeps mid-meeting also hides the elapsed timer and the stop button — so
                // keep it awake for as long as a meeting is running.
                .onChange(of: store.isRecording, initial: true) { _, recording in
                    UIApplication.shared.isIdleTimerDisabled = recording
                }
                #if DEBUG
            // `nil` in every launch but a dark screenshot run, where `preferredColorScheme`
            // is documented as leaving the appearance to the system.
            .preferredColorScheme(ScreenshotFixture.preferredColorScheme)
                #endif
        }
    }
}

/// The whole app: one list, one floating control, and the sheets they raise.
///
/// There is no tab bar. The previous three tabs put a screen that was one button beside a list of
/// what that button produced, which asked the user to hold "recording" and "recordings" apart as
/// separate places when they are the same subject. Collapsing them leaves a single root whose
/// primary action is always under the thumb, and makes "open the app and record" two taps instead
/// of three.
struct RootView: View {
    @EnvironmentObject private var store: MobileMeetingStore

    @AppStorage(OnboardingDefaults.hasSeenWelcomeKey) private var hasSeenWelcome = false

    /// Whether the recording sheet is on screen. Presentation only, and deliberately nothing more:
    /// the meeting's life belongs to `RecordingSession`, so dismissing this leaves it running.
    @State private var isShowingRecordingSheet = false

    /// Raised when someone taps Record before there is a key to record with.
    @State private var isShowingKeySheet = false

    var body: some View {
        NavigationStack {
            MeetingsView()
                .overlay(alignment: .bottom) { recordControl }
        }
        .sheet(isPresented: $isShowingRecordingSheet) { RecordingSheet() }
        .sheet(isPresented: $isShowingKeySheet) { APIKeySheet() }
        .fullScreenCover(isPresented: .constant(!hasSeenWelcome)) {
            WelcomeView { hasSeenWelcome = true }
        }
        // Starting and stopping are the two commitments worth confirming through the hand, since
        // the phone is usually face down on the table by then.
        .sensoryFeedback(trigger: store.isRecording) { _, recording in
            recording ? .start : .stop
        }
        .sensoryFeedback(.success, trigger: store.keyMoments.count)
        // Only on the way into an error. The bare `trigger:` form fires on every change of the
        // value, so an error *clearing* buzzed exactly like one arriving.
        .sensoryFeedback(trigger: store.banner?.isError == true) { _, isError in
            isError ? .error : nil
        }
    }

    private var recordControl: some View {
        RecordFAB(
            isRecording: store.isRecording,
            isBusy: store.isToggling,
            isInterrupted: store.isInterrupted,
            startedAt: store.meetingStartedAt,
            levelMeter: store.recorder.levelMeter,
            action: recordTapped
        )
        .padding(.bottom, MobileTheme.Spacing.xl)
    }

    /// The one button, doing a different thing depending on what is in the way.
    ///
    /// Note what it deliberately does *not* do: stop a running meeting. While recording it is a way
    /// back into the sheet and nothing else. Stopping lives on the Stop button inside, where it is
    /// a considered tap rather than a second press of the thing that started it — otherwise someone
    /// who dismissed the sheet to check something in the list would end their meeting trying to get
    /// back to it.
    private func recordTapped() {
        guard SetupState(store: store).canRecord else {
            // A banner saying a key is missing leaves the user to go and find Settings. The sheet
            // that fixes it is one tap closer, and says the same thing by existing.
            isShowingKeySheet = true
            return
        }

        if !store.isRecording {
            store.toggleRecording()
        }
        isShowingRecordingSheet = true
    }
}
