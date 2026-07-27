import Foundation

/// The summary models both apps offer, in menu order.
///
/// One list, shared, because the Mac and the iPhone write the same `UserDefaults` keys — a model
/// offered on one platform and not the other would render as a blank row in the other's picker.
enum SummaryModelCatalog {
    static let anthropic = ["claude-opus-5", "claude-sonnet-5"]
    static let openAI = ["gpt-5.6-sol", "gpt-5.6-terra", "gpt-5.6-luna"]

    static let defaultAnthropic = "claude-opus-5"
    static let defaultOpenAI = "gpt-5.6-sol"

    /// Resolves a stored model to one that's still offered.
    ///
    /// A SwiftUI `Picker` whose selection matches no tag renders empty, so a saved
    /// `claude-fable-5` from a previous version would leave the menu blank and the summary
    /// silently running on a model the user can no longer see or change. Falling back to the
    /// current default keeps the setting coherent instead.
    static func resolvedAnthropicModel(_ stored: String?) -> String {
        resolve(stored, in: anthropic, fallback: defaultAnthropic)
    }

    static func resolvedOpenAIModel(_ stored: String?) -> String {
        resolve(stored, in: openAI, fallback: defaultOpenAI)
    }

    private static func resolve(_ stored: String?, in offered: [String], fallback: String) -> String {
        guard let stored, offered.contains(stored) else { return fallback }
        return stored
    }
}
