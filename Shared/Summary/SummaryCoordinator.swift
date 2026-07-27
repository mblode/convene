import Combine
import Foundation

/// Which provider writes the summary, with which model, and whether to write one at all — plus the
/// routing that turns those settings into a call.
///
/// Both apps offer the same summary settings and both persist them to the same `UserDefaults` keys,
/// so this existed twice: once in `MeetingStore` and once in `MobileMeetingStore`, with the
/// provider/model/enabled fields, the provider switch in `generate`, and the matching error lookup
/// duplicated line for line. Keeping one copy is what makes adding or retiring a model a one-file
/// change instead of an edit that has to be remembered in two.
///
/// API keys deliberately stay on the platform stores: they're bound directly by each Settings
/// screen and the Mac's key popover addresses them by key path, so moving them here would churn
/// that UI without removing any duplicated logic.
@MainActor
final class SummaryCoordinator: ObservableObject {
    /// "anthropic" (default, better summaries) or "openai".
    @Published var provider: String = UserDefaults.standard.string(forKey: Keys.provider) ?? "anthropic" {
        didSet { UserDefaults.standard.set(provider, forKey: Keys.provider) }
    }
    @Published var openAIModel: String = SummaryModelCatalog.resolvedOpenAIModel(
        UserDefaults.standard.string(forKey: Keys.openAIModel)
    )
    {
        didSet { UserDefaults.standard.set(openAIModel, forKey: Keys.openAIModel) }
    }
    @Published var claudeModel: String = SummaryModelCatalog.resolvedAnthropicModel(
        UserDefaults.standard.string(forKey: Keys.claudeModel)
    )
    {
        didSet { UserDefaults.standard.set(claudeModel, forKey: Keys.claudeModel) }
    }
    @Published var isEnabled: Bool = UserDefaults.standard.object(forKey: Keys.isEnabled) as? Bool ?? true {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Keys.isEnabled) }
    }

    let openAIService = SummaryService()
    let claudeService = ClaudeSummaryService()

    /// The persisted keys, unchanged from when these lived on the two stores — renaming any of them
    /// would silently reset the setting for everyone who already has one saved.
    private enum Keys {
        static let provider = "summaryProvider"
        static let openAIModel = "summaryModel"
        static let claudeModel = "claudeSummaryModel"
        static let isEnabled = "generateSummaryAfterMeeting"
    }

    private var nestedCancellables = Set<AnyCancellable>()

    init() {
        forwardObjectWillChange(from: openAIService, into: &nestedCancellables)
        forwardObjectWillChange(from: claudeService, into: &nestedCancellables)
    }

    var usesAnthropic: Bool { provider == "anthropic" }

    /// The models offered for the selected provider, for a Settings picker.
    var offeredModels: [String] {
        usesAnthropic ? SummaryModelCatalog.anthropic : SummaryModelCatalog.openAI
    }

    func generate(for meeting: Meeting, openAIKey: String, claudeKey: String) async -> MeetingSummary? {
        if usesAnthropic {
            return await claudeService.generate(meeting: meeting, apiKey: claudeKey, model: claudeModel)
        }
        return await openAIService.generate(meeting: meeting, apiKey: openAIKey, model: openAIModel)
    }

    /// The failure from whichever provider actually ran.
    var lastError: String? {
        usesAnthropic ? claudeService.lastError : openAIService.lastError
    }
}
