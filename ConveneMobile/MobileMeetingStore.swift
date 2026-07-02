import Combine
import Foundation
import SwiftUI

@MainActor
final class MobileMeetingStore: ObservableObject {
    @Published var openAIKeyField = APIKeyField(.openAI) {
        didSet { openAIKeyField.save() }
    }
    @Published var claudeKeyField = APIKeyField(.claude) {
        didSet { claudeKeyField.save() }
    }
    @Published var assemblyAIKeyField = APIKeyField(.assemblyAI) {
        didSet { assemblyAIKeyField.save() }
    }
    @Published var summaryModel: String = UserDefaults.standard.string(forKey: "summaryModel") ?? "claude-fable-5" {
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
    let transcriber = AssemblyAIRealtimeTranscriber()
    let persistence = MobilePersistenceService()
    let claudeSummaryService = ClaudeSummaryService()

    var isRecording: Bool { recorder.isRecording }

    private(set) var meetingStartedAt: Date?
    private var pendingTranscriptionError: String?
    private var nestedCancellables = Set<AnyCancellable>()

    init() {
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
        transcriber.$lastError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                guard let self, let error, !error.isEmpty else { return }
                self.status = "Transcription error: \(error)"
                if self.transcriber.isRunning {
                    Task { @MainActor [weak self] in
                        await self?.stopAfterTranscriptionFailure(error)
                    }
                }
            }
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
        pendingTranscriptionError = nil
        meetingStartedAt = Date()

        guard assemblyAIKeyField.hasKey else {
            status = "Add your AssemblyAI API key in Settings to record"
            meetingStartedAt = nil
            return
        }

        guard await recorder.requestPermission() else {
            status = "Microphone permission required"
            meetingStartedAt = nil
            return
        }

        status = "Connecting to AssemblyAI…"
        await transcriber.start(
            apiKey: assemblyAIKeyField.value,
            speakers: [.you],
            attendeeNames: [],
            meetingTitle: meetingTitle
        )
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

    private func stopAfterTranscriptionFailure(_ error: String) async {
        recorder.stop()
        await transcriber.stop()
        pendingTranscriptionError = error
        await persistMeeting()
        status = "Transcription error: \(error)"
    }

    private func persistMeeting() async {
        guard let started = meetingStartedAt else { return }
        let trimmedTitle = meetingTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        let meeting = Meeting(
            title: trimmedTitle.isEmpty ? "Untitled meeting" : trimmedTitle,
            startedAt: started,
            endedAt: Date(),
            transcript: transcriber.segments,
            notes: meetingNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            transcriptionError: pendingTranscriptionError
        )

        if let url = persistence.save(meeting) {
            lastSavedURL = url
            status = "Saved: \(url.lastPathComponent)"
        } else {
            status = persistence.lastError ?? "Save failed"
        }

        meetingStartedAt = nil

        if generateSummaryAfterMeeting && claudeKeyField.hasKey
            && (!meeting.transcript.isEmpty || !meeting.notes.isEmpty) {
            status = "Generating summary..."
            let summary = await claudeSummaryService.generate(
                meeting: meeting,
                apiKey: claudeKeyField.value,
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
