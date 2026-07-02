import Foundation
import SwiftUI
import AppKit
import Combine

@MainActor
final class MeetingStore: ObservableObject {
    @Published var openAIKeyField = APIKeyField(.openAI)
    @Published var claudeKeyField = APIKeyField(.claude)
    @Published var assemblyAIKeyField = APIKeyField(.assemblyAI)
    @Published var saveDebugWAVs: Bool = UserDefaults.standard.object(forKey: "saveDebugWAVs") as? Bool ?? false {
        didSet { UserDefaults.standard.set(saveDebugWAVs, forKey: "saveDebugWAVs") }
    }
    /// Which provider generates summaries: "anthropic" (default, best model) or "openai".
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
    /// The name used to label your side of the transcript ("Your name" in Settings).
    @Published var userName: String = UserDefaults.standard.string(forKey: "userName") ?? "" {
        didSet { UserDefaults.standard.set(userName, forKey: "userName") }
    }

    // Live state
    @Published private(set) var captureStatus: CaptureStatus = .idle
    @Published var meetingTitle: String = "Untitled meeting"
    @Published var meetingNotes: String = ""
    @Published private(set) var lastSavedURL: URL?
    @Published private(set) var currentSummary: MeetingSummary?

    /// Human-marked flags dropped live during the in-flight meeting (the differentiator).
    /// Reset at the start of each recording; folded into the saved `Meeting` on stop.
    @Published private(set) var keyMoments: [KeyMoment] = []

    let captureCoordinator = AudioCaptureCoordinator()
    let transcriber = AssemblyAIRealtimeTranscriber()
    let persistence = PersistenceService()
    let summaryService = SummaryService()
    let claudeSummaryService = ClaudeSummaryService()
    let calendarService = CalendarService()
    let meetingDetector = MeetingDetector()
    private let walService = TranscriptWALService()

    /// Currently associated calendar event, if the user started recording from one.
    @Published private(set) var currentEvent: MeetingEvent?

    /// Wall-clock start of the in-flight meeting; nil when idle. Published so the menu-bar
    /// elapsed timer can anchor to the true start instead of when the panel last opened.
    @Published private(set) var meetingStartedAt: Date?

    /// A short status line for the menu-bar header: capture/transcription failures plus the
    /// few transient states worth showing. Nil when there's nothing the user needs to see —
    /// the header's pulse + elapsed timer already cover the steady recording state.
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
        case .idle, .recording, .busy, .alreadyRecording, .saved, .saveFailed:
            return nil
        }
    }
    /// Identifier of the meeting that's currently the "active" one in the UI. Used to
    /// invalidate stale summary tasks when the user starts a new meeting before the previous
    /// meeting's summary lands.
    private var activeMeetingId: UUID?
    private var pendingUnsavedMeeting: Meeting?

    private var captureCancellable: AnyCancellable?
    private var errorCancellable: AnyCancellable?
    private var transcriptionErrorCancellable: AnyCancellable?
    private var nestedObjectCancellables = Set<AnyCancellable>()
    private var hotkeyObservers: [NSObjectProtocol] = []
    /// Direction of an in-flight start/stop transition. Guards against double-toggle while
    /// `transcriber.stop()` sleeps through its flush grace period — and, because capture
    /// stops well before that drain finishes, lets the UI keep showing "Stopping…" instead
    /// of falling back to "Starting…" once `captureCoordinator.isCapturing` flips to false.
    enum TogglePhase { case idle, starting, stopping }
    @Published private(set) var togglePhase: TogglePhase = .idle
    var isToggling: Bool { togglePhase != .idle }

    init() {
        // Wire audio chunks into the transcription coordinator. Note: this fires from the
        // audio capture queue but TranscriptionCoordinator routes through @MainActor so the
        // outbound WebSocket writes happen on the main run loop alongside its segment state.
        captureCoordinator.onPCM16 = { [weak self] stream, data in
            self?.transcriber.ingestPCM16(data, speaker: stream.transcriptSpeaker)
        }

        captureCancellable = captureCoordinator.$isCapturing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] active in
                self?.captureStatus = active ? .recording : .idle
            }
        errorCancellable = captureCoordinator.$startError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                guard let self, let error, !error.isEmpty else { return }
                self.captureStatus = .error("Error: \(error)")
                if self.transcriber.isRunning {
                    Task { @MainActor [weak self] in
                        await self?.stopAfterCaptureFailure()
                    }
                }
            }
        transcriptionErrorCancellable = transcriber.$lastError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                guard let self, let error, !error.isEmpty else { return }
                let isSegmentFailure = error.contains("transcription failed:")
                self.captureStatus = isSegmentFailure
                    ? .transcriptionWarning("Transcription warning: \(error)")
                    : .error("Transcription error: \(error)")
                if !isSegmentFailure && self.transcriber.isRunning {
                    Task { @MainActor [weak self] in
                        await self?.stopRecording()
                    }
                }
            }

        forwardObjectWillChange(from: captureCoordinator, into: &nestedObjectCancellables)
        forwardObjectWillChange(from: transcriber, into: &nestedObjectCancellables)
        forwardObjectWillChange(from: persistence, into: &nestedObjectCancellables)
        forwardObjectWillChange(from: summaryService, into: &nestedObjectCancellables)
        forwardObjectWillChange(from: claudeSummaryService, into: &nestedObjectCancellables)
        forwardObjectWillChange(from: calendarService, into: &nestedObjectCancellables)
        forwardObjectWillChange(from: meetingDetector, into: &nestedObjectCancellables)

        let center = NotificationCenter.default
        hotkeyObservers.append(
            center.addObserver(forName: NSNotification.Name("ConveneToggleRecording"), object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.toggleRecording() }
            }
        )
        hotkeyObservers.append(
            center.addObserver(forName: NSNotification.Name("ConveneStartRecordingIfIdle"), object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.startRecordingIfIdle() }
            }
        )
        hotkeyObservers.append(
            center.addObserver(forName: NSNotification.Name("ConveneMeetingAppsEnded"), object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.stopRecordingIfActive() }
            }
        )
    }

    deinit {
        let observers = hotkeyObservers
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Runs `operation` under the toggle guard: a no-op (optionally reporting busy) when a
    /// start/stop transition is already in flight, otherwise holds `phase` for its duration and
    /// restores `.idle` afterward.
    private func runExclusive(
        _ phase: TogglePhase,
        reportBusy: Bool = true,
        operation: @escaping () async -> Void
    ) {
        guard togglePhase == .idle else {
            if reportBusy { captureStatus = .busy }
            return
        }
        togglePhase = phase
        Task {
            defer { togglePhase = .idle }
            await operation()
        }
    }

    func toggleRecording() {
        if captureCoordinator.isCapturing {
            runExclusive(.stopping) { [weak self] in await self?.stopRecording() }
        } else {
            runExclusive(.starting) { [weak self] in await self?.startRecording() }
        }
    }

    /// Stop an in-progress recording in response to an external signal (e.g. the meeting app
    /// quit). No-op when idle or already mid-transition.
    func stopRecordingIfActive() {
        guard captureCoordinator.isCapturing else { return }
        runExclusive(.stopping, reportBusy: false) { [weak self] in await self?.stopRecording() }
    }

    /// Start recording with metadata prefilled from a calendar event.
    func startRecording(from event: MeetingEvent) {
        guard !captureCoordinator.isCapturing else {
            captureStatus = .alreadyRecording
            return
        }
        runExclusive(.starting) { [weak self] in
            self?.currentEvent = event
            await self?.startRecording(eventOverride: event)
        }
    }

    func startRecordingIfIdle() {
        guard !captureCoordinator.isCapturing else { return }
        toggleRecording()
    }

    // MARK: - Key Moments

    /// Current meeting-relative offset in seconds, or nil when idle. The anchor for both
    /// key moments and the recap window.
    var currentMeetingOffset: TimeInterval? {
        meetingStartedAt.map { max(0, Date().timeIntervalSince($0)) }
    }

    var isRecording: Bool { captureCoordinator.isCapturing }

    /// Drops a key moment at the current offset. No-op (returns nil) when not recording.
    /// `text` may be empty — a bare flag is still a valid "this matters" marker.
    @discardableResult
    func flagKeyMoment(text: String = "") -> KeyMoment? {
        guard captureCoordinator.isCapturing, let offset = currentMeetingOffset else { return nil }
        let moment = KeyMoment(offset: offset, text: text.trimmingCharacters(in: .whitespacesAndNewlines))
        keyMoments.append(moment)
        walService.appendKeyMoment(moment)
        logInfo("MeetingStore: flagged key moment at \(moment.formattedTimestamp)")
        return moment
    }

    func quit() {
        let wasCapturing = captureCoordinator.isCapturing
        runExclusive(wasCapturing ? .stopping : .starting) { [weak self] in
            if wasCapturing {
                await self?.stopRecording()
            }
            NSApp.terminate(nil)
        }
    }

    func chooseOutputFolderAndRetrySave() {
        persistence.chooseOutputFolder()
        retryPendingSave()
    }

    func clearOutputFolder() {
        persistence.clearOutputFolder()
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
        let previousDebugWAVs = saveDebugWAVs
        let previousSummary = generateSummaryAfterMeeting
        saveDebugWAVs = true
        generateSummaryAfterMeeting = false
        meetingTitle = "Convene transcription smoke test"

        await startRecording()
        guard captureCoordinator.isCapturing else {
            logError("TranscriptionSmokeTest: capture did not start (\(captureCoordinator.startError ?? captureStatus.displayText))")
            saveDebugWAVs = previousDebugWAVs
            generateSummaryAfterMeeting = previousSummary
            return
        }

        logInfo("TranscriptionSmokeTest: recording for \(seconds)s")
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        await stopRecording()
        logInfo("TranscriptionSmokeTest: finished")

        saveDebugWAVs = previousDebugWAVs
        generateSummaryAfterMeeting = previousSummary
    }
    #endif

    private func startRecording(eventOverride: MeetingEvent? = nil) async {
        // An explicit event (Join & Record / event row) wins; otherwise adopt the event in
        // progress right now, so a recording started with the button or hotkey during a meeting
        // still inherits its title and attendee context.
        if let event = eventOverride ?? calendarService.currentEventForRecording() {
            meetingTitle = event.title
            currentEvent = event
        } else {
            meetingTitle = defaultTitle()
            currentEvent = nil
        }
        meetingNotes = ""
        lastSavedURL = nil
        currentSummary = nil
        activeMeetingId = nil
        keyMoments = []
        meetingStartedAt = Date()

        guard assemblyAIKeyField.hasKey else {
            captureStatus = .needsAPIKey
            meetingStartedAt = nil
            return
        }

        guard await captureCoordinator.requestPermissions() else {
            meetingStartedAt = nil
            return
        }

        captureStatus = .connecting
        await transcriber.start(
            apiKey: assemblyAIKeyField.value,
            speakers: [.you, .others],
            attendeeNames: currentEvent?.attendees ?? [],
            meetingTitle: meetingTitle,
            expectedSpeakerCount: currentEvent?.attendees.count
        )
        guard transcriber.isRunning else {
            captureStatus = .error(transcriber.lastError ?? "AssemblyAI transcription failed to start")
            meetingStartedAt = nil
            return
        }

        let walMeetingId = UUID()
        walService.beginSession(
            meetingId: walMeetingId,
            title: meetingTitle,
            attendees: currentEvent?.attendees ?? [],
            startedAt: meetingStartedAt!
        )
        transcriber.onSegmentConfirmed = { [walService] segment in
            walService.appendSegment(segment)
        }

        let baseURL = saveDebugWAVs ? debugWAVBaseURL() : nil
        await captureCoordinator.start(debugWAVBaseURL: baseURL)
        if !captureCoordinator.isCapturing {
            await transcriber.stop()
            walService.endSession()
            meetingStartedAt = nil
        }
    }

    private func stopRecording() async {
        await captureCoordinator.stop()
        await Task.yield()
        await finalizeMeeting()
    }

    /// Shared tail of a normal stop and a capture-failure stop: drain the transcriber, persist
    /// the meeting, and close out the WAL.
    private func finalizeMeeting() async {
        await transcriber.stop()
        transcriber.onSegmentConfirmed = nil
        persistCurrentMeeting()
        if let walURL = walService.endSession() {
            TranscriptWALService.deleteWAL(at: walURL)
        }
    }

    private func persistCurrentMeeting() {
        guard let started = meetingStartedAt else { return }
        let trimmedTitle = meetingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = meetingNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let transcript = transcriber.segments
        let transcriptionError = transcriber.lastError

        let meeting = Meeting(
            title: trimmedTitle.isEmpty ? "Untitled meeting" : trimmedTitle,
            attendees: currentEvent?.attendees ?? [],
            startedAt: started,
            endedAt: Date(),
            transcript: transcript,
            keyMoments: keyMoments,
            notes: trimmedNotes,
            summary: nil,
            transcriptionError: transcriptionError,
            audioFilename: nil,
            selfName: resolvedSelfName(),
            othersName: resolvedOthersName()
        )
        activeMeetingId = meeting.id

        if transcript.isEmpty && trimmedNotes.isEmpty && transcriptionError == nil {
            logInfo("MeetingStore: saving meeting with no transcript or notes")
        }
        saveMeeting(meeting)
        meetingStartedAt = nil

        // Kick off summary generation in the background. When it lands, we re-save and
        // update UI state — but only if the user hasn't started a new meeting in the meantime.
        if generateSummaryAfterMeeting && (!transcript.isEmpty || !trimmedNotes.isEmpty) {
            captureStatus = .generatingSummary
            let meetingId = meeting.id
            Task { [weak self] in
                guard let self else { return }
                let summary = await self.generateSummary(for: meeting)
                await MainActor.run {
                    // Drop the result if a newer meeting has started since we kicked this off.
                    guard self.activeMeetingId == meetingId else {
                        if let summary {
                            // The original meeting is no longer the active one, but we still
                            // want to persist its summary to the file we already wrote. Avoid
                            // clobbering retry/UI state for a newer meeting if that silent save
                            // fails or lands after the user has moved on.
                            var enriched = meeting
                            enriched.summary = summary
                            let shouldTrackFailure = self.pendingUnsavedMeeting?.id == meetingId
                            self.saveMeeting(
                                enriched,
                                updateStatus: false,
                                updateLastSaved: false,
                                trackFailure: shouldTrackFailure
                            )
                        }
                        return
                    }
                    if let summary {
                        self.currentSummary = summary
                        var enriched = meeting
                        enriched.summary = summary
                        self.saveMeeting(enriched) { [weak self] url in
                            self?.saveStatus(for: url, action: "Summary saved") ?? "Summary saved to \(url.lastPathComponent)"
                        }
                    } else if let err = self.summaryGenerationError() {
                        self.captureStatus = .error(err)
                    }
                }
            }
        }
    }

    /// Routes summary generation by the configured provider. Anthropic (Claude Fable 5)
    /// is the default; OpenAI remains available as a fallback choice in Settings.
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

    @discardableResult
    private func saveMeeting(
        _ meeting: Meeting,
        updateStatus: Bool = true,
        updateLastSaved: Bool = true,
        trackFailure: Bool = true,
        statusMessage: ((URL) -> String)? = nil
    ) -> URL? {
        if let url = persistence.save(meeting) {
            if pendingUnsavedMeeting?.id == meeting.id {
                pendingUnsavedMeeting = nil
            }
            if updateLastSaved {
                lastSavedURL = url
            }
            if updateStatus {
                captureStatus = .saved(message: statusMessage?(url) ?? saveStatus(for: url))
            }
            return url
        }

        if trackFailure {
            pendingUnsavedMeeting = meeting
        }
        if updateStatus, let err = persistence.lastError {
            captureStatus = .saveFailed(message: err)
        }
        return nil
    }

    private func retryPendingSave() {
        guard let meeting = pendingUnsavedMeeting else { return }
        saveMeeting(meeting)
    }

    private func saveStatus(for url: URL, action: String = "Saved") -> String {
        if persistence.lastUsedFallback {
            return "\(action) locally: \(url.lastPathComponent)"
        }
        return "\(action): \(url.lastPathComponent)"
    }

    private func stopAfterCaptureFailure() async {
        await finalizeMeeting()
    }

    func recoverOrphanedMeetings() {
        let orphans = walService.findOrphanedWALs()
        guard !orphans.isEmpty else { return }

        for walURL in orphans {
            do {
                let meeting = try TranscriptWALService.recoverMeeting(from: walURL)
                if !meeting.transcript.isEmpty || !meeting.keyMoments.isEmpty {
                    persistence.save(meeting)
                    logInfo("MeetingStore: recovered meeting from WAL: \(meeting.title)")
                }
                TranscriptWALService.deleteWAL(at: walURL)
            } catch {
                logError("MeetingStore: WAL recovery failed: \(error)")
            }
        }
    }

    /// Name for `.you` transcript segments: the Settings "Your name" value, falling back to
    /// the calendar event's current-user attendee, then the macOS account's full name.
    private func resolvedSelfName() -> String? {
        let configured = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !configured.isEmpty { return configured }
        if let calendarSelf = currentEvent?.selfAttendeeName {
            return TranscriptFormatter.attendeeDisplayName(calendarSelf)
        }
        let accountName = NSFullUserName().trimmingCharacters(in: .whitespacesAndNewlines)
        return accountName.isEmpty ? nil : accountName
    }

    /// Name for `.others` segments — only when the calendar event has exactly one other
    /// attendee (a 1:1), so the attribution is unambiguous.
    private func resolvedOthersName() -> String? {
        guard let others = currentEvent?.otherAttendees, others.count == 1 else { return nil }
        let name = TranscriptFormatter.attendeeDisplayName(others[0])
        return name.isEmpty ? nil : name
    }

    private func defaultTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d 'at' h:mm a"
        return "Meeting on \(formatter.string(from: Date()))"
    }

    private func debugWAVBaseURL() -> URL {
        let tmp = FileManager.default.temporaryDirectory
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        return tmp.appendingPathComponent("convene-\(stamp)")
    }
}

private extension AudioCaptureCoordinator.SpeakerStream {
    var transcriptSpeaker: TranscriptSegment.Speaker {
        switch self {
        case .you: return .you
        case .others: return .others
        }
    }
}
