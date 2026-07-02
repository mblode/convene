import Foundation

/// A single API key backed by the Keychain. Loads its stored value on init, and `save()`
/// trims, persists (or deletes when empty), and refreshes `hasKey`/`error`. Used as a
/// `@Published` value in the stores so SwiftUI can bind directly to `value`.
struct APIKeyField {
    let account: KeychainManager.Account
    var value: String
    /// Stored (not derived from `value`): a failed save leaves `value` populated but
    /// `hasKey` false, so the UI can show the typed key while flagging it as unsaved.
    private(set) var hasKey: Bool
    private(set) var error: String?

    init(_ account: KeychainManager.Account) {
        self.account = account
        let saved = KeychainManager.load(for: account) ?? ""
        value = saved
        hasKey = !saved.isEmpty
        error = nil
    }

    /// Trim, persist (or delete when empty), and update `hasKey`/`error`. Returns whether the
    /// Keychain write succeeded. Only reassigns `value` when trimming actually changed it, so
    /// a `didSet { save() }` binding doesn't churn.
    @discardableResult
    mutating func save() -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            guard KeychainManager.delete(for: account) else {
                error = "Could not delete the key from Keychain."
                return false
            }
            if value != trimmed { value = trimmed }
            hasKey = false
            error = nil
            return true
        }
        guard KeychainManager.save(trimmed, for: account) else {
            error = "Could not save the key to Keychain."
            hasKey = false
            return false
        }
        if value != trimmed { value = trimmed }
        hasKey = true
        error = nil
        return true
    }
}
