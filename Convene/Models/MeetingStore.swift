import Foundation
import SwiftUI
import AppKit
import Combine

/// Single source of truth for in-flight meeting state.
/// Owns the audio capture coordinator and transcription coordinator, wires them together,
/// and surfaces a unified status to the UI.
@MainActor
final class MeetingStore: ObservableObject {
    // Settings (persisted via UserDefaults / Keychain)
    @Published var apiKey: String = ""
    @Published var hasAPIKey: Bool = false
    @Published var saveDebugWAVs: Bool = false
    @Published var transcriptionModel: String = UserDefaults.standard.string(forKey: "transcriptionModel") ?? "gpt-4o-mini-transcribe" {
        didSet { UserDefaults.standard.set(transcriptionModel, forKey: "transcriptionModel") }
    }
    @Published var transcriptionLanguage: String = UserDefaults.standard.string(forKey: "transcriptionLanguage") ?? "" {
        didSet { UserDefaults.standard.set(transcriptionLanguage, forKey: "transcriptionLanguage") }
    }
    @Published var summaryModel: String = UserDefaults.standard.string(forKey: "summaryModel") ?? "gpt-4o-mini" {
        didSet { UserDefaults.standard.set(summaryModel, forKey: "summaryModel") }
    }
    @Published var generateSummaryAfterMeeting: Bool = UserDefaults.standard.object(forKey: "generateSummaryAfterMeeting") as? Bool ?? true {
        didSet { UserDefaults.standard.set(generateSummaryAfterMeeting, forKey: "generateSummaryAfterMeeting") }
    }

    // Live state
    @Published private(set) var captureStatus: String = "Idle"
    @Published var meetingTitle: String = "Untitled meeting"
    @Published var meetingNotes: String = ""
    @Published private(set) var lastSavedURL: URL?
    @Published private(set) var currentSummary: MeetingSummary?

    let captureCoordinator = AudioCaptureCoordinator()
    let transcriptionCoordinator = TranscriptionCoordinator()
    let persistence = PersistenceService()
    let summaryService = SummaryService()
    let calendarService = CalendarService()
    let meetingDetector = MeetingDetector()

    /// Currently associated calendar event, if the user started recording from one.
    @Published private(set) var currentEvent: MeetingEvent?

    /// Wall-clock start of the in-flight meeting; nil when idle.
    private var meetingStartedAt: Date?
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
    /// True while a start/stop transition is mid-flight. Guards against double-toggle while
    /// `transcriptionCoordinator.stop()` is sleeping through its 1.5 s flush grace period.
    private var isToggling: Bool = false

    init() {
        if let saved = KeychainManager.loadAPIKey() {
            apiKey = saved
            hasAPIKey = !saved.isEmpty
        }

        // Wire audio chunks into the transcription coordinator. Note: this fires from the
        // audio capture queue but TranscriptionCoordinator routes through @MainActor so the
        // outbound WebSocket writes happen on the main run loop alongside its segment state.
        captureCoordinator.onPCM16 = { [weak self] speaker, data in
            // Re-enter MainActor; weak capture avoids cycles if MeetingStore is torn down.
            Task { @MainActor [weak self] in
                self?.transcriptionCoordinator.ingest(speaker: speaker, pcm16: data)
            }
        }

        captureCancellable = captureCoordinator.$isCapturing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] active in
                self?.captureStatus = active ? "Recording…" : "Idle"
            }
        errorCancellable = captureCoordinator.$startError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                guard let self, let error, !error.isEmpty else { return }
                self.captureStatus = "Error: \(error)"
                if self.transcriptionCoordinator.isRunning {
                    Task { @MainActor [weak self] in
                        await self?.stopAfterCaptureFailure()
                    }
                }
            }
        transcriptionErrorCancellable = transcriptionCoordinator.$lastError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                guard let self, let error, !error.isEmpty else { return }
                self.captureStatus = "Transcription error: \(error)"
                if self.captureCoordinator.isCapturing {
                    Task { @MainActor [weak self] in
                        await self?.stopRecording()
                    }
                }
            }

        captureCoordinator.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &nestedObjectCancellables)
        transcriptionCoordinator.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &nestedObjectCancellables)
        persistence.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &nestedObjectCancellables)
        summaryService.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &nestedObjectCancellables)
        calendarService.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &nestedObjectCancellables)
        meetingDetector.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &nestedObjectCancellables)

        let center = NotificationCenter.default
        hotkeyObservers.append(
            center.addObserver(forName: NSNotification.Name("ConveneToggleRecording"), object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.toggleRecording() }
            }
        )
        hotkeyObservers.append(
            center.addObserver(forName: NSNotification.Name("ConveneOpenMeetingWindow"), object: nil, queue: .main) { _ in
                Task { @MainActor in
                    Self.bringMeetingWindowToFront()
                }
            }
        )
        hotkeyObservers.append(
            center.addObserver(forName: NSNotification.Name("ConveneStartRecordingIfIdle"), object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.startRecordingIfIdle() }
            }
        )
    }

    deinit {
        let observers = hotkeyObservers
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private static func bringMeetingWindowToFront() {
        // Window scene with id "meeting" — find the matching NSWindow and surface it.
        // If no window has been opened yet this session, the menu-bar action handles it.
        let target = NSApp.windows.first { window in
            window.title == "Meeting" || window.identifier?.rawValue.contains("meeting") == true
        }
        guard let target else {
            logInfo("MeetingStore: no meeting window found — open via menu bar first")
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        target.makeKeyAndOrderFront(nil)
    }

    func saveAPIKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            KeychainManager.deleteAPIKey()
            hasAPIKey = false
        } else {
            KeychainManager.saveAPIKey(trimmed)
            apiKey = trimmed
            hasAPIKey = true
        }
    }

    func toggleRecording() {
        guard !isToggling else {
            captureStatus = "Busy - wait for previous action to finish"
            return
        }
        isToggling = true
        Task {
            defer { isToggling = false }
            if captureCoordinator.isCapturing {
                await stopRecording()
            } else {
                await startRecording()
            }
        }
    }

    /// Start recording with metadata prefilled from a calendar event.
    func startRecording(from event: MeetingEvent) {
        guard !isToggling else {
            captureStatus = "Busy - wait for previous action to finish"
            return
        }
        isToggling = true
        currentEvent = event
        Task {
            defer { isToggling = false }
            await startRecording(eventOverride: event)
        }
    }

    func startRecordingIfIdle() {
        guard !captureCoordinator.isCapturing else { return }
        toggleRecording()
    }

    func quit() {
        guard !isToggling else {
            captureStatus = "Busy - wait for previous action to finish"
            return
        }
        isToggling = true
        Task {
            if captureCoordinator.isCapturing {
                await stopRecording()
            }
            isToggling = false
            NSApp.terminate(nil)
        }
    }

    func chooseOutputFolderAndRetrySave() {
        persistence.chooseOutputFolder()
        retryPendingSave()
    }

    private func startRecording(eventOverride: MeetingEvent? = nil) async {
        guard hasAPIKey else {
            captureStatus = "API key required — open Settings"
            return
        }
        // Reset meeting state.
        if let event = eventOverride {
            meetingTitle = event.title
        } else {
            meetingTitle = defaultTitle()
            currentEvent = nil
        }
        meetingNotes = ""
        lastSavedURL = nil
        currentSummary = nil
        // Invalidate any in-flight summary task from the previous meeting so its result
        // doesn't overwrite this meeting's UI state when it returns.
        activeMeetingId = nil
        meetingStartedAt = Date()

        guard await captureCoordinator.requestPermissions() else {
            meetingStartedAt = nil
            return
        }

        // Connect transcription before opening the audio engines so startup chunks are buffered
        // by the streams instead of dropped while `isRunning` is still false.
        transcriptionCoordinator.start(
            apiKey: apiKey,
            model: transcriptionModel,
            language: transcriptionLanguage
        )

        let baseURL = saveDebugWAVs ? debugWAVBaseURL() : nil
        await captureCoordinator.start(debugWAVBaseURL: baseURL)
        if !captureCoordinator.isCapturing {
            await transcriptionCoordinator.stop()
            meetingStartedAt = nil
        }
    }

    private func stopRecording() async {
        await captureCoordinator.stop()
        await Task.yield()
        // Awaits the buffer-flush grace period so the final segment's completed event
        // lands before we snapshot the transcript for persistence.
        await transcriptionCoordinator.stop()
        persistCurrentMeeting()
    }

    private func persistCurrentMeeting() {
        guard let started = meetingStartedAt else { return }
        let trimmedTitle = meetingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = meetingNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let transcript = transcriptionCoordinator.snapshot()

        // Don't write empty meetings (start → stop with no audio / notes).
        if transcript.isEmpty && trimmedNotes.isEmpty {
            logInfo("MeetingStore: skipping persistence — no transcript or notes")
            meetingStartedAt = nil
            return
        }

        let meeting = Meeting(
            title: trimmedTitle.isEmpty ? "Untitled meeting" : trimmedTitle,
            attendees: currentEvent?.attendees ?? [],
            startedAt: started,
            endedAt: Date(),
            transcript: transcript,
            notes: trimmedNotes,
            summary: nil,
            audioFilename: nil
        )
        activeMeetingId = meeting.id

        saveMeeting(meeting) { url in "Saved \(url.lastPathComponent)" }
        meetingStartedAt = nil

        // Kick off summary generation in the background. When it lands, we re-save and
        // update UI state — but only if the user hasn't started a new meeting in the meantime.
        if generateSummaryAfterMeeting {
            captureStatus = "Generating summary…"
            let apiKey = self.apiKey
            let model = self.summaryModel
            let meetingId = meeting.id
            Task { [weak self] in
                guard let self else { return }
                let summary = await self.summaryService.generate(meeting: meeting, apiKey: apiKey, model: model)
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
                        self.saveMeeting(enriched) { url in "Summary saved to \(url.lastPathComponent)" }
                    } else if let err = self.summaryService.lastError {
                        self.captureStatus = err
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
                captureStatus = statusMessage?(url) ?? "Saved \(url.lastPathComponent)"
            }
            return url
        }

        if trackFailure {
            pendingUnsavedMeeting = meeting
        }
        if updateStatus, let err = persistence.lastError {
            captureStatus = err
        }
        return nil
    }

    private func retryPendingSave() {
        guard let meeting = pendingUnsavedMeeting else { return }
        saveMeeting(meeting) { url in "Saved \(url.lastPathComponent)" }
    }

    private func stopAfterCaptureFailure() async {
        await transcriptionCoordinator.stop()
        persistCurrentMeeting()
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
