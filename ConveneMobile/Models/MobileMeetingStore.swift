import Combine
import Foundation
import SwiftUI

/// The iPhone app's UI-facing state: API keys, summary settings, the live meeting title and
/// notes, and the saved-meeting library. The recording lifecycle itself lives in the shared
/// `RecordingSession`; this wires the iOS capture and persistence backends into it and exposes
/// thin passthroughs, mirroring what `MeetingStore` does on the Mac.
@MainActor
final class MobileMeetingStore: ObservableObject {
    @Published var openAIKeyField = APIKeyField(.openAI)
    @Published var claudeKeyField = APIKeyField(.claude)
    @Published var assemblyAIKeyField = APIKeyField(.assemblyAI)

    /// Which provider generates summaries: "anthropic" (default, better summaries) or "openai".
    @Published var summaryProvider: String = UserDefaults.standard.string(forKey: "summaryProvider") ?? "anthropic" {
        didSet { UserDefaults.standard.set(summaryProvider, forKey: "summaryProvider") }
    }
    @Published var summaryModel: String = UserDefaults.standard.string(forKey: "summaryModel") ?? "gpt-5.4-mini" {
        didSet { UserDefaults.standard.set(summaryModel, forKey: "summaryModel") }
    }
    @Published var claudeSummaryModel: String = UserDefaults.standard.string(forKey: "claudeSummaryModel") ?? "claude-fable-5" {
        didSet { UserDefaults.standard.set(claudeSummaryModel, forKey: "claudeSummaryModel") }
    }
    @Published var generateSummaryAfterMeeting: Bool = UserDefaults.standard.object(forKey: "generateSummaryAfterMeeting") as? Bool ?? true {
        didSet { UserDefaults.standard.set(generateSummaryAfterMeeting, forKey: "generateSummaryAfterMeeting") }
    }

    /// Live meeting title/notes. Owned here (not the session) so SwiftUI can bind to them; the
    /// session reads them at persist time and `makeContext` resets them at start.
    @Published var meetingTitle: String = ""
    @Published var meetingNotes: String = ""

    let recorder = MicRecorder()
    let persistence = MobilePersistenceService()
    let library = MeetingLibrary()
    let summaryService = SummaryService()
    let claudeSummaryService = ClaudeSummaryService()

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

    @discardableResult
    func flagKeyMoment(text: String = "") -> KeyMoment? { session.flagKeyMoment(text: text) }

    /// A short line for the recording screen's banner: failures plus the transient states worth
    /// showing. Nil when the pulse and elapsed timer already say everything.
    var banner: (text: String, isError: Bool)? {
        if recorder.isInterrupted {
            return ("Paused — another app is using the microphone", false)
        }
        switch captureStatus {
        case .error(let message), .saveFailed(let message):
            return (message, true)
        case .needsAPIKey:
            return ("Add your AssemblyAI key in Settings to start recording", true)
        case .transcriptionWarning(let message), .saved(let message):
            return (message, false)
        case .connecting, .generatingSummary:
            return (captureStatus.displayText, false)
        // The pulse and the elapsed timer already say everything these states would.
        case .idle, .recording, .busy, .alreadyRecording, .cancelled:
            return nil
        }
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
            summaryError: { [weak self] in self?.summaryGenerationError() ?? nil }
        )

        // The mic dropping mid-meeting (a call the system never handed back, a route that failed
        // to rebuild) surfaces as the recorder's lastError. Hand it to the session so the meeting
        // stops and saves what it has instead of recording silence.
        captureErrorCancellable = recorder.$lastError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                guard let self, let error, !error.isEmpty, self.transcriber.isRunning else { return }
                self.session.handleCaptureFailure(error)
            }

        // Both the initial save and the later summary re-save land on `.saved`, so this is the
        // one signal that keeps the Meetings tab current without polling the filesystem.
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
        forwardObjectWillChange(from: summaryService, into: &nestedObjectCancellables)
        forwardObjectWillChange(from: claudeSummaryService, into: &nestedObjectCancellables)
    }

    /// Recover anything a crash left behind and load the library. Called once at launch.
    func prepare() {
        recorder.refreshPermission()
        session.recoverOrphanedMeetings()
        library.reload()
    }

    func deleteMeeting(_ meeting: Meeting) {
        library.delete(meeting, markdownFolders: persistence.candidateFolders)
    }

    // MARK: - Per-meeting context

    private func makeContext() -> RecordingSession.Context {
        meetingTitle = defaultTitle()
        meetingNotes = ""
        // One mic, one stream, and no calendar to name anyone from: the transcript is whatever
        // diarization can separate, rendered as "Speaker A"/"Speaker B". Leaving `othersName` nil
        // is what lets those labels through — setting it would collapse the room to one name.
        return RecordingSession.Context(
            title: meetingTitle,
            attendees: [],
            selfName: nil,
            othersName: nil,
            speakers: [.others],
            expectedSpeakerCount: nil
        )
    }

    private func defaultTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d 'at' h:mm a"
        return "Meeting on \(formatter.string(from: Date()))"
    }

    // MARK: - Summaries

    private func generateSummary(for meeting: Meeting) async -> MeetingSummary? {
        if summaryProvider == "anthropic" {
            return await claudeSummaryService.generate(
                meeting: meeting,
                apiKey: claudeKeyField.value,
                model: claudeSummaryModel
            )
        }
        return await summaryService.generate(
            meeting: meeting,
            apiKey: openAIKeyField.value,
            model: summaryModel
        )
    }

    private func summaryGenerationError() -> String? {
        summaryProvider == "anthropic" ? claudeSummaryService.lastError : summaryService.lastError
    }

    /// Whether a summary can actually be produced — used to explain a disabled toggle rather
    /// than silently skipping the summary after a meeting.
    var hasSummaryKey: Bool {
        summaryProvider == "anthropic" ? claudeKeyField.hasKey : openAIKeyField.hasKey
    }
}
