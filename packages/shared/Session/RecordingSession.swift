import Combine
import Foundation

/// The recording lifecycle: start/stop orchestration, the transcriber, the write-ahead log,
/// persistence, and background summary generation. Everything app-specific is injected — a
/// `RecordingAudioSource`, a `MeetingPersisting`, and a few closures (`makeContext` for
/// per-meeting metadata, `transcriptionKey`, and the summary hooks). `MeetingStore` keeps the
/// UI-facing knobs (keys, settings, calendar, hotkeys) and exposes thin passthroughs to this
/// session.
@MainActor
final class RecordingSession: ObservableObject {
    /// Per-meeting metadata resolved by the platform at the moment recording starts.
    struct Context {
        var title: String
        var attendees: [String]
        var selfName: String?
        var othersName: String?
        var speakers: [TranscriptSegment.Speaker]
        var expectedSpeakerCount: Int?

        /// Fallback used only when a weak platform reference has gone away mid-teardown.
        static let empty = Context(
            title: "Untitled meeting",
            attendees: [],
            selfName: nil,
            othersName: nil,
            speakers: [.you],
            expectedSpeakerCount: nil
        )
    }

    // MARK: - Published lifecycle state

    @Published private(set) var captureStatus: CaptureStatus = .idle
    @Published private(set) var lastSavedURL: URL?
    @Published private(set) var currentSummary: MeetingSummary?

    /// Human-marked flags dropped live during the in-flight meeting. Reset at the start of each
    /// recording; folded into the saved `Meeting` on stop.
    @Published private(set) var keyMoments: [KeyMoment] = []

    /// Wall-clock start of the in-flight meeting; nil when idle.
    @Published private(set) var meetingStartedAt: Date?

    /// Direction of an in-flight start/stop transition. Guards against double-toggle while
    /// `transcriber.stop()` sleeps through its flush grace period.
    enum TogglePhase { case idle, starting, stopping }
    @Published private(set) var togglePhase: TogglePhase = .idle
    var isToggling: Bool { togglePhase != .idle }

    let transcriber = AssemblyAIRealtimeTranscriber()

    // MARK: - Injected platform behavior

    private let audioSource: RecordingAudioSource
    private let persistence: MeetingPersisting
    private let makeContext: () -> Context
    /// The live (possibly user-edited) title and notes, read at persist time.
    private let meetingMetadata: () -> (title: String, notes: String)
    private let transcriptionKey: () -> String
    private let shouldSummarize: () -> Bool
    private let summarize: (Meeting) async -> MeetingSummary?
    private let summaryError: () -> String?
    /// Fired once after a stop persist succeeds. Not called for summary re-saves, retries, or WAL recovery.
    private let onMeetingSaved: ((URL) -> Void)?

    private let walService = TranscriptWALService()

    /// Identifier of the meeting that's currently the "active" one in the UI. Used to invalidate
    /// stale summary tasks when the user starts a new meeting before the previous summary lands.
    private var activeMeetingId: UUID?
    private var pendingUnsavedMeeting: Meeting?

    private var transcriptionErrorCancellable: AnyCancellable?
    private var nestedObjectCancellables = Set<AnyCancellable>()

    /// Polls the live title and notes into the WAL while a meeting runs. See `mirrorMetadataToWAL`.
    private var metadataMirrorTask: Task<Void, Never>?

    /// The last pair written, so an unchanged poll costs nothing.
    private var lastMirroredMetadata: (title: String, notes: String)?

    init(
        audioSource: RecordingAudioSource,
        persistence: MeetingPersisting,
        makeContext: @escaping () -> Context,
        meetingMetadata: @escaping () -> (title: String, notes: String),
        transcriptionKey: @escaping () -> String,
        shouldSummarize: @escaping () -> Bool,
        summarize: @escaping (Meeting) async -> MeetingSummary?,
        summaryError: @escaping () -> String?,
        onMeetingSaved: ((URL) -> Void)? = nil
    ) {
        self.audioSource = audioSource
        self.persistence = persistence
        self.makeContext = makeContext
        self.meetingMetadata = meetingMetadata
        self.transcriptionKey = transcriptionKey
        self.shouldSummarize = shouldSummarize
        self.summarize = summarize
        self.summaryError = summaryError
        self.onMeetingSaved = onMeetingSaved

        // Segment failures are warnings (keep recording); other transcription errors are fatal
        // and stop the meeting. Unifying both platforms on this behavior.
        transcriptionErrorCancellable = transcriber.$lastError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                guard let self, let error, !error.isEmpty else { return }
                let isSegmentFailure = error.contains("transcription failed:")
                self.captureStatus =
                    isSegmentFailure
                    ? .transcriptionWarning("Transcription warning: \(error)")
                    : .error("Transcription error: \(error)")
                if !isSegmentFailure && self.transcriber.isRunning {
                    Task { @MainActor [weak self] in
                        await self?.stopRecording()
                    }
                }
            }

        forwardObjectWillChange(from: transcriber, into: &nestedObjectCancellables)
    }

    var isRecording: Bool { audioSource.isCapturing }

    /// Current meeting-relative offset in seconds, or nil when idle.
    var currentMeetingOffset: TimeInterval? {
        meetingStartedAt.map { max(0, Date().timeIntervalSince($0)) }
    }

    // MARK: - Public controls

    func toggleRecording() {
        if audioSource.isCapturing {
            run(.stopping) { await self.stopRecording() }
        } else {
            run(.starting) { await self.startRecording() }
        }
    }

    /// Begin recording. Callers set any platform context (e.g. the calendar event) before this.
    /// No-op with an "already recording" status if capture is in progress.
    func start() {
        guard !audioSource.isCapturing else {
            captureStatus = .alreadyRecording
            return
        }
        run(.starting) { await self.startRecording() }
    }

    /// Stop an in-progress recording in response to an external signal (e.g. the meeting app
    /// quit). No-op when idle or already mid-transition.
    func stopIfActive() {
        guard audioSource.isCapturing else { return }
        run(.stopping, reportBusy: false) { await self.stopRecording() }
    }

    /// Discard the in-flight recording without persisting it.
    func cancelRecording() {
        guard audioSource.isCapturing else { return }
        run(.stopping, reportBusy: false) {
            self.stopMirroringMetadata()
            await self.audioSource.stop()
            await self.transcriber.stop()
            self.transcriber.onSegmentConfirmed = nil
            if let walURL = self.walService.endSession() {
                TranscriptWALService.deleteWAL(at: walURL)
            }
            self.meetingStartedAt = nil
            self.captureStatus = .cancelled
        }
    }

    /// Stop (if recording) then run `terminate` — used by the macOS quit command.
    func quit(_ terminate: @escaping () -> Void) {
        let wasCapturing = audioSource.isCapturing
        run(wasCapturing ? .stopping : .starting) {
            if wasCapturing {
                await self.stopRecording()
            }
            terminate()
        }
    }

    /// The macOS $startError sink calls this when capture drops mid-recording.
    func handleCaptureFailure(_ message: String) {
        captureStatus = .error("Error: \(message)")
        if transcriber.isRunning {
            Task { @MainActor [weak self] in
                await self?.stopAfterCaptureFailure()
            }
        }
    }

    /// Drops a key moment at the current offset. No-op (returns nil) when not recording.
    @discardableResult
    func flagKeyMoment(text: String = "") -> KeyMoment? {
        guard audioSource.isCapturing, let offset = currentMeetingOffset else { return nil }
        let moment = KeyMoment(offset: offset, text: text.trimmingCharacters(in: .whitespacesAndNewlines))
        keyMoments.append(moment)
        walService.appendKeyMoment(moment)
        logInfo("RecordingSession: flagged key moment at \(moment.formattedTimestamp)")
        return moment
    }

    func retryPendingSave() {
        guard let meeting = pendingUnsavedMeeting else { return }
        saveMeeting(meeting)
    }

    /// Recover any WAL files left behind by a crash and persist them. Call at launch.
    func recoverOrphanedMeetings() {
        let orphans = walService.findOrphanedWALs()
        guard !orphans.isEmpty else { return }

        for walURL in orphans {
            do {
                let meeting = try TranscriptWALService.recoverMeeting(from: walURL)
                if !meeting.transcript.isEmpty || !meeting.keyMoments.isEmpty {
                    persistence.save(meeting)
                    logInfo("RecordingSession: recovered meeting from WAL: \(meeting.title)")
                }
                TranscriptWALService.deleteWAL(at: walURL)
            } catch {
                logError("RecordingSession: WAL recovery failed: \(error)")
            }
        }
    }

    // MARK: - Exclusive transition guard

    /// Runs `operation` under the toggle guard: a no-op (optionally reporting busy) when a
    /// transition is already in flight, otherwise holds `phase` for its duration.
    private func run(
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

    // MARK: - Lifecycle

    private func startRecording() async {
        // makeContext resolves the meeting title and resets the platform's title/notes fields.
        let context = makeContext()
        lastSavedURL = nil
        currentSummary = nil
        activeMeetingId = nil
        keyMoments = []
        meetingStartedAt = Date()

        let key = transcriptionKey().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            captureStatus = .needsAPIKey
            meetingStartedAt = nil
            return
        }

        guard await audioSource.requestPermissions() else {
            if let message = audioSource.permissionFailureMessage {
                captureStatus = .error(message)
            }
            meetingStartedAt = nil
            return
        }

        captureStatus = .connecting
        await transcriber.start(
            apiKey: key,
            speakers: context.speakers,
            attendeeNames: context.attendees,
            meetingTitle: context.title,
            expectedSpeakerCount: context.expectedSpeakerCount
        )
        guard transcriber.isRunning else {
            captureStatus = .error(transcriber.lastError ?? "AssemblyAI transcription failed to start")
            meetingStartedAt = nil
            return
        }

        walService.beginSession(
            meetingId: UUID(),
            title: context.title,
            attendees: context.attendees,
            startedAt: meetingStartedAt!
        )
        transcriber.onSegmentConfirmed = { [walService] segment in
            walService.appendSegment(segment)
        }
        startMirroringMetadata()

        do {
            try await audioSource.start { [weak self] speaker, data in
                self?.transcriber.ingestPCM16(data, speaker: speaker)
            }
        } catch {
            captureStatus = .error("Capture failed: \(error.localizedDescription)")
        }

        if !audioSource.isCapturing {
            stopMirroringMetadata()
            await transcriber.stop()
            transcriber.onSegmentConfirmed = nil
            walService.endSession()
            meetingStartedAt = nil
        } else {
            captureStatus = .recording
            // Snapshot the resolved names for persistence at stop.
            pendingContext = context
        }
    }

    /// Context captured at start, read back at persist time so attribution matches the meeting.
    private var pendingContext: Context?

    // MARK: - Metadata mirroring

    /// Keeps the WAL's copy of the title and notes current while a meeting runs.
    ///
    /// Segments and key moments reach the log as they happen, but the title and the notes are
    /// typed, and nothing published an edit anywhere the session could see it — so a crash or a
    /// jetsam kill took the whole lot and recovery rebuilt the meeting with empty notes. An app
    /// that holds the microphone open in the background is a prime candidate for being killed, so
    /// this is the likeliest way to lose work in the product.
    ///
    /// A poll rather than an observer because `meetingMetadata` is a closure over whatever the
    /// platform keeps its fields in — `@Published` strings on both stores today, but the session
    /// deliberately doesn't know that. Two seconds bounds the loss at a sentence or so, and the
    /// unchanged case costs a string compare.
    private func startMirroringMetadata() {
        metadataMirrorTask?.cancel()
        lastMirroredMetadata = nil
        metadataMirrorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                self?.mirrorMetadataToWAL()
            }
        }
    }

    /// Writes the current title and notes to the WAL if either has changed since the last write.
    private func mirrorMetadataToWAL() {
        let current = meetingMetadata()
        guard
            current.title != lastMirroredMetadata?.title
                || current.notes != lastMirroredMetadata?.notes
        else { return }
        lastMirroredMetadata = current
        walService.appendMetadata(title: current.title, notes: current.notes)
    }

    /// Stops the poll. Safe to call when it was never started.
    private func stopMirroringMetadata() {
        metadataMirrorTask?.cancel()
        metadataMirrorTask = nil
        lastMirroredMetadata = nil
    }

    private func stopRecording() async {
        await audioSource.stop()
        await Task.yield()
        await finalizeMeeting()
    }

    private func stopAfterCaptureFailure() async {
        await finalizeMeeting()
    }

    /// Shared tail of a normal stop and a capture-failure stop: drain the transcriber, persist
    /// the meeting, and close out the WAL.
    private func finalizeMeeting() async {
        stopMirroringMetadata()
        await transcriber.stop()
        transcriber.onSegmentConfirmed = nil
        persistCurrentMeeting()
        if let walURL = walService.endSession() {
            TranscriptWALService.deleteWAL(at: walURL)
        }
    }

    private func persistCurrentMeeting() {
        guard let started = meetingStartedAt else { return }
        let context = pendingContext ?? makeContext()
        let metadata = meetingMetadata()
        let trimmedTitle = metadata.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = metadata.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let transcript = transcriber.segments
        let transcriptionError = transcriber.lastError

        let meeting = Meeting(
            title: trimmedTitle.isEmpty ? "Untitled meeting" : trimmedTitle,
            attendees: context.attendees,
            startedAt: started,
            endedAt: Date(),
            transcript: transcript,
            keyMoments: keyMoments,
            notes: trimmedNotes,
            summary: nil,
            transcriptionError: transcriptionError,
            audioFilename: nil,
            selfName: context.selfName,
            othersName: context.othersName
        )
        activeMeetingId = meeting.id

        if transcript.isEmpty && trimmedNotes.isEmpty && transcriptionError == nil {
            logInfo("RecordingSession: saving meeting with no transcript or notes")
        }
        if let url = saveMeeting(meeting) {
            onMeetingSaved?(url)
        }
        meetingStartedAt = nil

        // Kick off summary generation in the background. When it lands, re-save and update UI —
        // but only if the user hasn't started a new meeting in the meantime.
        if shouldSummarize() && (!transcript.isEmpty || !trimmedNotes.isEmpty) {
            captureStatus = .generatingSummary
            let meetingId = meeting.id
            Task { [weak self] in
                guard let self else { return }
                let summary = await self.summarize(meeting)
                await MainActor.run {
                    guard self.activeMeetingId == meetingId else {
                        if let summary {
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
                        self.saveMeeting(enriched) { url in
                            self.saveStatus(for: url, action: "Summary saved")
                        }
                    } else if let err = self.summaryError() {
                        self.captureStatus = .error(err)
                    }
                }
            }
        }
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

    private func saveStatus(for url: URL, action: String = "Saved") -> String {
        if persistence.lastUsedFallback {
            return "\(action) locally: \(url.lastPathComponent)"
        }
        return "\(action): \(url.lastPathComponent)"
    }

    #if DEBUG
    /// Awaitable start/stop for the DEBUG transcription smoke test, bypassing the toggle guard.
    func debugStart() async { await startRecording() }
    func debugStop() async { await stopRecording() }

    /// Dress the session as a meeting already in progress, for the App Store screenshot fixture
    /// (`ScreenshotFixture`). Nothing is captured, no socket opens and no WAL session begins — the
    /// audio source is faked separately, and there is no meeting here to persist or discard.
    func debugPoseAsRunningMeeting(
        startedAt: Date,
        transcript: [TranscriptSegment],
        keyMoments: [KeyMoment]
    ) {
        meetingStartedAt = startedAt
        self.keyMoments = keyMoments
        captureStatus = .recording
        transcriber.debugReplaceSegments(transcript)
    }
    #endif
}
