import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class MeetingStore: ObservableObject {
    @Published var openAIKeyField = APIKeyField(.openAI)
    @Published var claudeKeyField = APIKeyField(.claude)
    @Published var assemblyAIKeyField = APIKeyField(.assemblyAI)
    /// Summary settings and provider routing, shared with the iPhone app. The passthroughs below
    /// keep `$meetingStore.summaryProvider`-style bindings working from Settings without each view
    /// having to observe the coordinator itself.
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
    /// The name used to label your side of the transcript ("Your name" in Settings).
    @Published var userName: String = UserDefaults.standard.string(forKey: "userName") ?? "" {
        didSet { UserDefaults.standard.set(userName, forKey: "userName") }
    }

    /// Live meeting title/notes. Owned here (not the session) so SwiftUI can bind to them; the
    /// session reads them at persist time and `makeContext` resets them at start.
    @Published var meetingTitle: String = "Untitled meeting"
    @Published var meetingNotes: String = ""
    /// Filename shown in the menu-bar toast after a stop persist copies the note path. Nil when idle.
    @Published private(set) var copiedPathToast: String?

    let captureCoordinator = AudioCaptureCoordinator()
    let persistence = PersistenceService()
    let calendarService = CalendarService()
    let meetingDetector = MeetingDetector()

    /// The shared recording lifecycle. This store keeps the UI-facing knobs and forwards to it.
    private(set) var session: RecordingSession!

    /// Currently associated calendar event, resolved per recording at `makeContext` time.
    private var currentEvent: MeetingEvent?
    /// An explicit event to record (set by `startRecording(from:)`); consumed by the next
    /// `makeContext`. When nil, a start adopts the in-progress calendar event, if any.
    private var pendingEventOverride: MeetingEvent?

    private var errorCancellable: AnyCancellable?
    private var nestedObjectCancellables = Set<AnyCancellable>()
    private var hotkeyObservers: [NSObjectProtocol] = []
    private var toastClearTask: Task<Void, Never>?

    // MARK: - Session passthroughs

    var transcriber: AssemblyAIRealtimeTranscriber { session.transcriber }
    var captureStatus: CaptureStatus { session.captureStatus }
    var isRecording: Bool { session.isRecording }
    var isToggling: Bool { session.isToggling }
    var togglePhase: RecordingSession.TogglePhase { session.togglePhase }
    var meetingStartedAt: Date? { session.meetingStartedAt }
    var currentMeetingOffset: TimeInterval? { session.currentMeetingOffset }

    @discardableResult
    func flagKeyMoment(text: String = "") -> KeyMoment? { session.flagKeyMoment(text: text) }
    func recoverOrphanedMeetings() { session.recoverOrphanedMeetings() }

    /// A short status line for the menu-bar header: capture/transcription failures plus the few
    /// transient states worth showing. Nil when there's nothing the user needs to see — the
    /// header's pulse + elapsed timer already cover the steady recording state.
    var headerBanner: (text: String, isError: Bool)? {
        if let err = captureCoordinator.startError, !err.isEmpty { return (err, true) }
        switch captureStatus {
        case .error(let message):
            return (message, true)
        case .needsAPIKey:
            return (captureStatus.displayText, true)
        case .transcriptionWarning(let message):
            return (message, false)
        case .connecting, .generatingSummary:
            return (captureStatus.displayText, false)
        // .saveFailed shows no banner — faithful to the prior string-matching behavior, where
        // persistence errors never matched a banner prefix.
        case .idle, .recording, .busy, .alreadyRecording, .cancelled, .saved, .saveFailed:
            return nil
        }
    }

    init() {
        session = RecordingSession(
            audioSource: captureCoordinator,
            persistence: persistence,
            makeContext: { [weak self] in self?.makeContext() ?? .empty },
            meetingMetadata: { [weak self] in (self?.meetingTitle ?? "", self?.meetingNotes ?? "") },
            transcriptionKey: { [weak self] in self?.assemblyAIKeyField.value ?? "" },
            shouldSummarize: { [weak self] in self?.generateSummaryAfterMeeting ?? false },
            summarize: { [weak self] meeting in await self?.generateSummary(for: meeting) ?? nil },
            summaryError: { [weak self] in self?.summary.lastError },
            onMeetingSaved: { [weak self] url in self?.copySavedNotePath(url) }
        )

        // Capture dropping mid-recording surfaces through the coordinator's startError; hand it to
        // the session to stop and persist. (Also the sole macOS permission-prompt error channel.)
        errorCancellable = captureCoordinator.$startError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                guard let self, let error, !error.isEmpty, self.transcriber.isRunning else { return }
                self.session.handleCaptureFailure(error)
            }

        forwardObjectWillChange(from: session, into: &nestedObjectCancellables)
        forwardObjectWillChange(from: captureCoordinator, into: &nestedObjectCancellables)
        forwardObjectWillChange(from: persistence, into: &nestedObjectCancellables)
        forwardObjectWillChange(from: summary, into: &nestedObjectCancellables)
        forwardObjectWillChange(from: calendarService, into: &nestedObjectCancellables)
        forwardObjectWillChange(from: meetingDetector, into: &nestedObjectCancellables)

        let center = NotificationCenter.default
        hotkeyObservers.append(
            center.addObserver(
                forName: NSNotification.Name("ConveneToggleRecording"), object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.toggleRecording() }
            }
        )
        hotkeyObservers.append(
            center.addObserver(
                forName: NSNotification.Name("ConveneStartRecordingIfIdle"), object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.startRecordingIfIdle() }
            }
        )
        hotkeyObservers.append(
            center.addObserver(
                forName: NSNotification.Name("ConveneMeetingAppsEnded"), object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.stopRecordingIfActive() }
            }
        )
    }

    deinit {
        let toastTask = toastClearTask
        toastTask?.cancel()
        let observers = hotkeyObservers
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Controls

    func toggleRecording() {
        // A plain toggle carries no explicit event; makeContext will adopt the in-progress one.
        session.toggleRecording()
    }

    /// Start recording with metadata prefilled from a calendar event.
    func startRecording(from event: MeetingEvent) {
        pendingEventOverride = event
        session.start()
    }

    func startRecordingIfIdle() {
        guard !captureCoordinator.isCapturing else { return }
        toggleRecording()
    }

    func stopRecordingIfActive() {
        session.stopIfActive()
    }

    func quit() {
        session.quit { NSApp.terminate(nil) }
    }

    func chooseOutputFolderAndRetrySave() {
        persistence.chooseOutputFolder()
        session.retryPendingSave()
    }

    func clearOutputFolder() {
        persistence.clearOutputFolder()
    }

    /// Copies a note's POSIX path and shows a short confirmation in the menu bar popover.
    func copySavedNotePath(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
        copiedPathToast = url.lastPathComponent
        AccessibilityNotification.Announcement("Copied path").post()
        toastClearTask?.cancel()
        toastClearTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(2500))
            guard !Task.isCancelled else { return }
            copiedPathToast = nil
        }
    }

    func refreshPermissionStates() async {
        captureCoordinator.refreshPermissionStates()
        await meetingDetector.refreshNotificationStatus()
        calendarService.refreshAuthorizationStatus()
        if calendarService.hasAccess {
            await calendarService.refreshEvents()
        }
    }

    #if DEBUG
    func runTranscriptionSmokeTest(seconds: Double) async {
        guard seconds > 0 else { return }
        let previousSummary = generateSummaryAfterMeeting
        generateSummaryAfterMeeting = false
        currentEvent = nil
        // Raw WAVs are a debug-build affordance only, so the smoke test opts in directly rather
        // than through a user-facing setting.
        captureCoordinator.debugWAVBaseURL = Self.debugWAVBaseURL()

        await session.debugStart()
        guard captureCoordinator.isCapturing else {
            logError(
                "TranscriptionSmokeTest: capture did not start (\(captureCoordinator.startError ?? captureStatus.displayText))"
            )
            captureCoordinator.debugWAVBaseURL = nil
            generateSummaryAfterMeeting = previousSummary
            return
        }

        logInfo("TranscriptionSmokeTest: recording for \(seconds)s")
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        await session.debugStop()
        logInfo("TranscriptionSmokeTest: finished")

        captureCoordinator.debugWAVBaseURL = nil
        generateSummaryAfterMeeting = previousSummary
    }

    /// Temp directory for a smoke test's raw WAVs, stamped so successive runs don't collide.
    static func debugWAVBaseURL() -> URL {
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("convene-smoke-\(stamp)")
    }
    #endif

    // MARK: - Session context + summary hooks

    private func makeContext() -> RecordingSession.Context {
        // An explicit event (Join & Record / event row) wins; otherwise adopt the event in
        // progress right now, so a recording started with the button, hotkey, or notification
        // during a meeting still inherits its title and attendee context.
        let event = pendingEventOverride ?? calendarService.currentEventForRecording()
        pendingEventOverride = nil
        currentEvent = event

        let title = event?.title ?? Meeting.defaultTitle()
        meetingTitle = title
        meetingNotes = ""
        return RecordingSession.Context(
            title: title,
            attendees: event?.attendees ?? [],
            selfName: resolvedSelfName(),
            othersName: resolvedOthersName(),
            speakers: [.you, .others],
            expectedSpeakerCount: event?.attendees.count
        )
    }

    /// Routes summary generation by the configured provider. Anthropic (Claude Fable 5) is the
    /// default; OpenAI remains available as a fallback choice in Settings.
    private func generateSummary(for meeting: Meeting) async -> MeetingSummary? {
        await summary.generate(
            for: meeting,
            openAIKey: openAIKeyField.value,
            claudeKey: claudeKeyField.value
        )
    }

    /// Name for `.you` transcript segments: the Settings "Your name" value, falling back to the
    /// calendar event's current-user attendee, then the macOS account's full name.
    private func resolvedSelfName() -> String? {
        let configured = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !configured.isEmpty { return configured }
        if let calendarSelf = currentEvent?.selfAttendeeName {
            return TranscriptFormatter.attendeeDisplayName(calendarSelf)
        }
        let accountName = NSFullUserName().trimmingCharacters(in: .whitespacesAndNewlines)
        return accountName.isEmpty ? nil : accountName
    }

    /// Name for `.others` segments — only when the calendar event has exactly one other attendee
    /// (a 1:1), so the attribution is unambiguous.
    private func resolvedOthersName() -> String? {
        guard let others = currentEvent?.otherAttendees, others.count == 1 else { return nil }
        let name = TranscriptFormatter.attendeeDisplayName(others[0])
        return name.isEmpty ? nil : name
    }

}
