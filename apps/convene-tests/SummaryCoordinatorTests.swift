import XCTest

@testable import Convene

/// The coordinator carries the summary settings both apps share. These tests pin the two things
/// that would break users silently: the persisted key names, and which model the provider switch
/// hands to the request.
@MainActor
final class SummaryCoordinatorTests: XCTestCase {

    private let persistedKeys = [
        "summaryProvider",
        "summaryModel",
        "claudeSummaryModel",
        "generateSummaryAfterMeeting"
    ]

    private var saved: [String: Any?] = [:]

    override func setUp() {
        super.setUp()
        // The coordinator reads and writes the real standard defaults, so snapshot and restore
        // rather than leaving the developer's own settings changed by a test run.
        saved = Dictionary(
            uniqueKeysWithValues: persistedKeys.map { ($0, UserDefaults.standard.object(forKey: $0)) })
        persistedKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    override func tearDown() {
        for (key, value) in saved {
            if let value {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        super.tearDown()
    }

    func testDefaultsToAnthropicWithOfferedModels() {
        let coordinator = SummaryCoordinator()

        XCTAssertTrue(coordinator.usesAnthropic)
        XCTAssertTrue(coordinator.isEnabled)
        XCTAssertEqual(coordinator.claudeModel, SummaryModelCatalog.defaultAnthropic)
        XCTAssertEqual(coordinator.openAIModel, SummaryModelCatalog.defaultOpenAI)
    }

    /// Renaming any of these keys would silently reset the setting for every existing user, so the
    /// names are pinned here rather than left to a rename-safe refactor.
    func testPersistsUnderTheEstablishedKeys() {
        let coordinator = SummaryCoordinator()
        coordinator.provider = "openai"
        coordinator.isEnabled = false
        coordinator.claudeModel = SummaryModelCatalog.anthropic.last!
        coordinator.openAIModel = SummaryModelCatalog.openAI.last!

        XCTAssertEqual(UserDefaults.standard.string(forKey: "summaryProvider"), "openai")
        XCTAssertEqual(UserDefaults.standard.object(forKey: "generateSummaryAfterMeeting") as? Bool, false)
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: "claudeSummaryModel"), SummaryModelCatalog.anthropic.last)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "summaryModel"), SummaryModelCatalog.openAI.last)
    }

    func testRestoresPersistedSettings() {
        UserDefaults.standard.set("openai", forKey: "summaryProvider")
        UserDefaults.standard.set(false, forKey: "generateSummaryAfterMeeting")

        let coordinator = SummaryCoordinator()

        XCTAssertFalse(coordinator.usesAnthropic)
        XCTAssertFalse(coordinator.isEnabled)
    }

    /// A stored model that is no longer offered must not survive into the picker.
    func testMigratesARetiredStoredModel() {
        UserDefaults.standard.set("claude-fable-5", forKey: "claudeSummaryModel")

        let coordinator = SummaryCoordinator()

        XCTAssertEqual(coordinator.claudeModel, SummaryModelCatalog.defaultAnthropic)
    }

    func testOfferedModelsFollowTheSelectedProvider() {
        let coordinator = SummaryCoordinator()

        coordinator.provider = "anthropic"
        XCTAssertEqual(coordinator.offeredModels, SummaryModelCatalog.anthropic)

        coordinator.provider = "openai"
        XCTAssertEqual(coordinator.offeredModels, SummaryModelCatalog.openAI)
    }

    /// Anything other than "anthropic" routes to OpenAI, so a garbage stored value can't leave the
    /// app with no provider at all.
    func testUnknownProviderRoutesToOpenAI() {
        UserDefaults.standard.set("something-else", forKey: "summaryProvider")

        let coordinator = SummaryCoordinator()

        XCTAssertFalse(coordinator.usesAnthropic)
        XCTAssertEqual(coordinator.offeredModels, SummaryModelCatalog.openAI)
    }
}

final class MeetingDefaultTitleTests: XCTestCase {
    /// Both apps render this into filenames in the user's own notes folder, so the format is
    /// pinned rather than left to drift per platform.
    func testUsesTheSharedFormat() {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 27
        components.hour = 15
        components.minute = 30
        let date = Calendar(identifier: .gregorian).date(from: components)!

        let title = Meeting.defaultTitle(startingAt: date)

        XCTAssertTrue(title.hasPrefix("Meeting on "), title)
        XCTAssertTrue(title.contains("Jul 27"), title)
    }
}
