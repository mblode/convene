import XCTest

@testable import Convene

/// The catalog decides what a saved model setting resolves to on launch. It's pure and it's the
/// only thing standing between a retired model ID and a Settings picker that renders blank, so it
/// gets tested directly rather than through a store.
final class SummaryModelCatalogTests: XCTestCase {

    // MARK: - Offered lists

    func testOfferedListsAreNonEmptyAndContainTheirDefault() {
        XCTAssertFalse(SummaryModelCatalog.anthropic.isEmpty)
        XCTAssertFalse(SummaryModelCatalog.openAI.isEmpty)

        // A default outside its own list is the exact bug this catalog exists to prevent: the
        // picker would open with nothing selected on a fresh install.
        XCTAssertTrue(SummaryModelCatalog.anthropic.contains(SummaryModelCatalog.defaultAnthropic))
        XCTAssertTrue(SummaryModelCatalog.openAI.contains(SummaryModelCatalog.defaultOpenAI))
    }

    func testProviderListsDoNotOverlap() {
        let shared = Set(SummaryModelCatalog.anthropic).intersection(SummaryModelCatalog.openAI)
        XCTAssertTrue(shared.isEmpty, "A model offered under both providers would be sent to the wrong API")
    }

    // MARK: - Resolution

    func testKeepsAModelThatIsStillOffered() {
        for model in SummaryModelCatalog.anthropic {
            XCTAssertEqual(SummaryModelCatalog.resolvedAnthropicModel(model), model)
        }
        for model in SummaryModelCatalog.openAI {
            XCTAssertEqual(SummaryModelCatalog.resolvedOpenAIModel(model), model)
        }
    }

    func testFallsBackWhenNothingIsStored() {
        XCTAssertEqual(SummaryModelCatalog.resolvedAnthropicModel(nil), SummaryModelCatalog.defaultAnthropic)
        XCTAssertEqual(SummaryModelCatalog.resolvedOpenAIModel(nil), SummaryModelCatalog.defaultOpenAI)
    }

    /// The upgrade case that motivated the catalog: someone who ran the previous version has
    /// `claude-fable-5` in UserDefaults, and it is no longer offered.
    func testMigratesARetiredModelOntoTheDefault() {
        XCTAssertEqual(
            SummaryModelCatalog.resolvedAnthropicModel("claude-fable-5"),
            SummaryModelCatalog.defaultAnthropic
        )
        XCTAssertEqual(
            SummaryModelCatalog.resolvedOpenAIModel("gpt-5.4-mini"),
            SummaryModelCatalog.defaultOpenAI
        )
    }

    func testDoesNotAcceptAModelFromTheOtherProvider() {
        // Resolving cross-provider would send an Anthropic ID to the OpenAI endpoint.
        XCTAssertEqual(
            SummaryModelCatalog.resolvedOpenAIModel(SummaryModelCatalog.defaultAnthropic),
            SummaryModelCatalog.defaultOpenAI
        )
        XCTAssertEqual(
            SummaryModelCatalog.resolvedAnthropicModel(SummaryModelCatalog.defaultOpenAI),
            SummaryModelCatalog.defaultAnthropic
        )
    }

    func testRejectsEmptyAndUnknownStrings() {
        XCTAssertEqual(SummaryModelCatalog.resolvedAnthropicModel(""), SummaryModelCatalog.defaultAnthropic)
        XCTAssertEqual(SummaryModelCatalog.resolvedOpenAIModel("  "), SummaryModelCatalog.defaultOpenAI)
        XCTAssertEqual(
            SummaryModelCatalog.resolvedAnthropicModel("not-a-model"), SummaryModelCatalog.defaultAnthropic)
    }
}
