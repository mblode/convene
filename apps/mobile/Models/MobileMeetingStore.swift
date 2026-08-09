import Combine
import Foundation
import SwiftUI

/// The iPhone app's UI-facing state: API keys, summary settings, the live meeting title and notes,
/// and the saved-meeting library. The recording lifecycle itself lives in the shared
/// `RecordingSession`; this wires the iOS capture and persistence backends into it and exposes thin
/// passthroughs, mirroring what `MeetingStore` does on the Mac.
@MainActor
final class MobileMeetingStore: ObservableObject {
    @Published var openAIKeyField = APIKeyField(.openAI)
    @Published var claudeKeyField = APIKeyField(.claude)
    @Published var assemblyAIKeyField = APIKeyField(.assemblyAI)

    /// Summary settings and provider routing, shared with the Mac app. The passthroughs below keep
    /// `$store.summaryProvider`-style bindings working from Settings without each view having to
    /// observe the coordinator itself.
    let summary = SummaryCoordinator()

    var summaryProvider: String {
        get { summary.provider }
        set { summary.provider = newValue }
    }
    var summaryModel: String {
        get { summary.openAIModel }
        set { summary.openAIModel = newValue }
    }
    var claudeSummaryModel: String {
        get { summary.claudeModel }
        set { summary.claudeModel = newValue }
    }
    var generateSummaryAfterMeeting: Bool {
        get { summary.isEnabled }
        set { summary.isEnabled = newValue }
    }

    /// Live meeting title/notes. Owned here (not the session) so SwiftUI can bind to them; the
    /// session reads them at persist time and `makeContext` resets them at start.
    @Published var meetingTitle: String = ""
    @Published var meetingNotes: String = ""

    let recorder = MicRecorder()
    let persistence = MobilePersistenceService()
    let library = MeetingLibrary()

    private(set) var session: RecordingSession!

    private var captureErrorCancellable: AnyCancellable?
    private var savedCancellable: AnyCancellable?
    private var nestedObjectCancellables = Set<AnyCancellable>()

    // MARK: - Session passthroughs

    var transcriber: AssemblyAIRealtimeTranscriber { session.transcriber }
    var captureStatus: CaptureStatus { session.captureStatus }
    var isRecording: Bool { session.isRecording }
    var isToggling: Bool { session.isToggling }
    var meetingStartedAt: Date? { session.meetingStartedAt }
    var currentSummary: MeetingSummary? { session.currentSummary }
    var keyMoments: [KeyMoment] { session.keyMoments }
    var isInterrupted: Bool { recorder.isInterrupted }

    func toggleRecording() { session.toggleRecording() }
    func cancelRecording() { session.cancelRecording() }
    func retryPendingSave() { session.retryPendingSave() }

    /// The message from a save that failed, or nil.
    ///
    /// A failed save is the one error in the app that holds something irreplaceable: the meeting is
    /// over, the transcript exists only in memory and the WAL, and the folder it was headed for
    /// refused it. `RecordingSession` keeps that meeting on hand for `retryPendingSave()`, so the
    /// only thing missing was a way for the user to ask — which is what this feeds.
    var pendingSaveError: String? {
        guard case .saveFailed(let message) = captureStatus else { return nil }
        return message
    }

    @discardableResult
    func flagKeyMoment(text: String = "") -> KeyMoment? { session.flagKeyMoment(text: text) }

    /// A short line for the recording screen's banner: failures, plus the transient states worth
    /// showing. Nil when the pulse and the elapsed timer already say everything.
    var banner: (text: String, isError: Bool)? {
        if recorder.isInterrupted {
            return ("Paused — another app is using the microphone", false)
        }
        switch captureStatus {
        case .error(let message), .saveFailed(let message):
            return (message, true)
        case .needsAPIKey:
            return ("Add your AssemblyAI key in Settings to start recording", true)
        case .transcriptionWarning(let message):
            return (message, false)
        case .connecting, .generatingSummary:
            return (captureStatus.displayText, false)
        // `.saved` deliberately stays silent here. The recording sheet is already dismissing by the
        // time it lands, so a banner would flash and go; the meeting arriving at the top of the
        // list is the confirmation, and it is the one the user is looking at.
        case .idle, .recording, .busy, .alreadyRecording, .cancelled, .saved:
            return nil
        }
    }

    /// Whether a summary can actually be produced — lets Settings explain an enabled toggle that
    /// would otherwise silently do nothing.
    var hasSummaryKey: Bool {
        summary.usesAnthropic ? claudeKeyField.hasKey : openAIKeyField.hasKey
    }

    init() {
        session = RecordingSession(
            audioSource: recorder,
            persistence: persistence,
            makeContext: { [weak self] in self?.makeContext() ?? .empty },
            meetingMetadata: { [weak self] in (self?.meetingTitle ?? "", self?.meetingNotes ?? "") },
            transcriptionKey: { [weak self] in self?.assemblyAIKeyField.value ?? "" },
            shouldSummarize: { [weak self] in self?.generateSummaryAfterMeeting ?? false },
            summarize: { [weak self] meeting in await self?.generateSummary(for: meeting) ?? nil },
            summaryError: { [weak self] in self?.summary.lastError }
        )

        // The mic dropping mid-meeting (a call the system never handed back, a route that failed to
        // rebuild) surfaces as the recorder's lastError. Hand it to the session so the meeting stops
        // and saves what it has instead of recording silence.
        captureErrorCancellable = recorder.$lastError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                guard let self, let error, !error.isEmpty, self.transcriber.isRunning else { return }
                self.session.handleCaptureFailure(error)
            }

        // Both the initial save and the later summary re-save land on `.saved`, so this is the one
        // signal that keeps the Meetings tab current without polling the filesystem.
        savedCancellable = session.$captureStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard case .saved = status else { return }
                self?.library.reload()
            }

        forwardObjectWillChange(from: session, into: &nestedObjectCancellables)
        forwardObjectWillChange(from: recorder, into: &nestedObjectCancellables)
        forwardObjectWillChange(from: persistence, into: &nestedObjectCancellables)
        forwardObjectWillChange(from: library, into: &nestedObjectCancellables)
        forwardObjectWillChange(from: summary, into: &nestedObjectCancellables)
    }

    /// Recover anything a crash left behind, then load the library. Called once at launch.
    func prepare() {
        recorder.refreshPermission()
        session.recoverOrphanedMeetings()
        library.reload()
        #if DEBUG
        // No-op unless `screenshots/capture.sh` passed its launch argument, and absent entirely
        // from a Release build.
        ScreenshotFixture.seed(into: self)
        #endif
    }

    func deleteMeeting(_ meeting: Meeting) {
        library.delete(meeting, markdownFolders: persistence.candidateFolders)
    }

    // MARK: - Per-meeting context

    private func makeContext() -> RecordingSession.Context {
        meetingTitle = Meeting.defaultTitle()
        meetingNotes = ""
        // One mic, one stream, and no calendar to name anyone from: the transcript is whatever
        // diarization can separate, rendered as "Speaker A"/"Speaker B". Leaving `othersName` nil is
        // what lets those labels through — setting it would collapse the room to a single name.
        return RecordingSession.Context(
            title: meetingTitle,
            attendees: [],
            selfName: nil,
            othersName: nil,
            speakers: [.others],
            expectedSpeakerCount: nil
        )
    }

    // MARK: - Summaries

    private func generateSummary(for meeting: Meeting) async -> MeetingSummary? {
        await summary.generate(
            for: meeting,
            openAIKey: openAIKeyField.value,
            claudeKey: claudeKeyField.value
        )
    }
}
