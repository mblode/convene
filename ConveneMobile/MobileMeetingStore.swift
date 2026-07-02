import Combine
import Foundation
import SwiftUI

@MainActor
final class MobileMeetingStore: ObservableObject {
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

    /// Live meeting title/notes. Owned here (not the session) so SwiftUI can bind to them.
    @Published var meetingTitle: String = ""
    @Published var meetingNotes: String = ""

    let recorder = MicRecorder()
    let persistence = MobilePersistenceService()
    let claudeSummaryService = ClaudeSummaryService()

    private(set) var session: RecordingSession!
    private var nestedCancellables = Set<AnyCancellable>()

    // MARK: - Session passthroughs

    var transcriber: AssemblyAIRealtimeTranscriber { session.transcriber }
    var status: String { session.captureStatus.displayText }
    var isRecording: Bool { session.isRecording }
    var isToggling: Bool { session.isToggling }
    var meetingStartedAt: Date? { session.meetingStartedAt }
    var currentSummary: MeetingSummary? { session.currentSummary }

    func toggleRecording() { session.toggleRecording() }
    func cancelRecording() { session.cancelRecording() }
    func recoverOrphanedMeetings() { session.recoverOrphanedMeetings() }

    init() {
        session = RecordingSession(
            audioSource: recorder,
            persistence: persistence,
            makeContext: { [weak self] in self?.makeContext() ?? .empty },
            meetingMetadata: { [weak self] in (self?.meetingTitle ?? "", self?.meetingNotes ?? "") },
            transcriptionKey: { [weak self] in self?.assemblyAIKeyField.value ?? "" },
            shouldSummarize: { [weak self] in
                guard let self else { return false }
                return self.generateSummaryAfterMeeting && self.claudeKeyField.hasKey
            },
            summarize: { [weak self] meeting in
                guard let self else { return nil }
                return await self.claudeSummaryService.generate(
                    meeting: meeting,
                    apiKey: self.claudeKeyField.value,
                    model: self.summaryModel
                )
            },
            summaryError: { [weak self] in self?.claudeSummaryService.lastError }
        )

        forwardObjectWillChange(from: session, into: &nestedCancellables)
        forwardObjectWillChange(from: recorder, into: &nestedCancellables)
        forwardObjectWillChange(from: persistence, into: &nestedCancellables)
        forwardObjectWillChange(from: claudeSummaryService, into: &nestedCancellables)
    }

    private func makeContext() -> RecordingSession.Context {
        meetingTitle = defaultTitle()
        meetingNotes = ""
        return RecordingSession.Context(
            title: meetingTitle,
            attendees: [],
            selfName: nil,
            othersName: nil,
            speakers: [.you],
            expectedSpeakerCount: nil
        )
    }

    private func defaultTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d 'at' h:mm a"
        return "Meeting on \(formatter.string(from: Date()))"
    }
}
