import Combine
import Foundation
import SwiftUI

@MainActor
final class MobileMeetingStore: ObservableObject {
    @Published var claudeAPIKey: String = "" {
        didSet { saveClaudeAPIKey() }
    }
    @Published var summaryModel: String = UserDefaults.standard.string(forKey: "summaryModel") ?? "claude-haiku-4-5-20251001" {
        didSet { UserDefaults.standard.set(summaryModel, forKey: "summaryModel") }
    }
    @Published var generateSummaryAfterMeeting: Bool = UserDefaults.standard.object(forKey: "generateSummaryAfterMeeting") as? Bool ?? true {
        didSet { UserDefaults.standard.set(generateSummaryAfterMeeting, forKey: "generateSummaryAfterMeeting") }
    }

    @Published private(set) var status: String = "Ready"
    @Published var meetingTitle: String = ""
    @Published var meetingNotes: String = ""
    @Published private(set) var lastSavedURL: URL?
    @Published private(set) var currentSummary: MeetingSummary?
    @Published private(set) var isToggling = false

    let recorder = MicRecorder()
    let transcriber = FluidTranscriber()
    let persistence = MobilePersistenceService()
    let claudeSummaryService = ClaudeSummaryService()

    var hasClaudeAPIKey: Bool { !claudeAPIKey.isEmpty }
    var isRecording: Bool { recorder.isRecording }

    private(set) var meetingStartedAt: Date?
    private var nestedCancellables = Set<AnyCancellable>()

    init() {
        if let saved = KeychainManager.loadClaudeAPIKey() {
            claudeAPIKey = saved
        }

        recorder.onAudioBuffer = { [weak self] buffer in
            self?.transcriber.ingestAudio(buffer)
        }

        recorder.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &nestedCancellables)
        transcriber.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &nestedCancellables)
        persistence.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &nestedCancellables)
        claudeSummaryService.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &nestedCancellables)
    }

    @discardableResult
    func saveClaudeAPIKey() -> Bool {
        let trimmed = claudeAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            KeychainManager.deleteClaudeAPIKey()
            claudeAPIKey = ""
            return true
        }
        guard KeychainManager.saveClaudeAPIKey(trimmed) else { return false }
        claudeAPIKey = trimmed
        return true
    }

    func toggleRecording() {
        guard !isToggling else { return }
        isToggling = true
        Task {
            defer { isToggling = false }
            if recorder.isRecording {
                await stopRecording()
            } else {
                await startRecording()
            }
        }
    }

    func cancelRecording() {
        guard recorder.isRecording, !isToggling else { return }
        isToggling = true
        Task {
            defer { isToggling = false }
            recorder.stop()
            await transcriber.stop()
            meetingStartedAt = nil
            status = "Recording cancelled"
        }
    }

    private func startRecording() async {
        meetingTitle = defaultTitle()
        meetingNotes = ""
        lastSavedURL = nil
        currentSummary = nil
        meetingStartedAt = Date()

        guard await recorder.requestPermission() else {
            status = "Microphone permission required"
            meetingStartedAt = nil
            return
        }

        status = "Loading transcription models..."
        await transcriber.start()
        guard transcriber.isRunning else {
            status = transcriber.lastError ?? "Transcription engine failed to start"
            meetingStartedAt = nil
            return
        }

        do {
            try recorder.start()
            status = "Recording..."
        } catch {
            await transcriber.stop()
            meetingStartedAt = nil
            status = "Mic start failed: \(error.localizedDescription)"
        }
    }

    private func stopRecording() async {
        recorder.stop()
        status = "Processing transcript..."
        await transcriber.stop()
        await persistMeeting()
    }

    private func persistMeeting() async {
        guard let started = meetingStartedAt else { return }
        let trimmedTitle = meetingTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        let meeting = Meeting(
            title: trimmedTitle.isEmpty ? "Untitled meeting" : trimmedTitle,
            startedAt: started,
            endedAt: Date(),
            transcript: transcriber.segments,
            notes: meetingNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        if let url = persistence.save(meeting) {
            lastSavedURL = url
            status = "Saved: \(url.lastPathComponent)"
        } else {
            status = persistence.lastError ?? "Save failed"
        }

        meetingStartedAt = nil

        if generateSummaryAfterMeeting && hasClaudeAPIKey
            && (!meeting.transcript.isEmpty || !meeting.notes.isEmpty) {
            status = "Generating summary..."
            let summary = await claudeSummaryService.generate(
                meeting: meeting,
                apiKey: claudeAPIKey,
                model: summaryModel
            )
            if let summary {
                currentSummary = summary
                var enriched = meeting
                enriched.summary = summary
                if let url = persistence.save(enriched) {
                    lastSavedURL = url
                    status = "Summary saved: \(url.lastPathComponent)"
                }
            } else if let err = claudeSummaryService.lastError {
                status = err
            }
        }
    }

    private func defaultTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d 'at' h:mm a"
        return "Meeting on \(formatter.string(from: Date()))"
    }
}
