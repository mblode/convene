import Foundation
import Security

enum KeychainManager {
    private static let service = "co.blode.convene"

    private enum Account: String {
        case openAI = "OpenAIAPIKey"
        case claude = "ClaudeAPIKey"
        case assemblyAI = "AssemblyAIAPIKey"
    }

    // MARK: - OpenAI

    @discardableResult
    static func saveAPIKey(_ key: String) -> Bool {
        save(key, account: .openAI)
    }

    static func loadAPIKey() -> String? {
        load(account: .openAI)
    }

    @discardableResult
    static func deleteAPIKey() -> Bool {
        delete(account: .openAI)
    }

    // MARK: - Claude

    @discardableResult
    static func saveClaudeAPIKey(_ key: String) -> Bool {
        save(key, account: .claude)
    }

    static func loadClaudeAPIKey() -> String? {
        load(account: .claude)
    }

    @discardableResult
    static func deleteClaudeAPIKey() -> Bool {
        delete(account: .claude)
    }

    // MARK: - AssemblyAI

    @discardableResult
    static func saveAssemblyAIAPIKey(_ key: String) -> Bool {
        save(key, account: .assemblyAI)
    }

    static func loadAssemblyAIAPIKey() -> String? {
        load(account: .assemblyAI)
    }

    @discardableResult
    static func deleteAssemblyAIAPIKey() -> Bool {
        delete(account: .assemblyAI)
    }

    // MARK: - Generic operations

    private static func save(_ key: String, account: Account) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue
        ]
        _ = deleteWithFallback(deleteQuery)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = addWithFallback(addQuery)
        if status == errSecSuccess {
            logInfo("KeychainManager: \(account.rawValue) saved")
            return true
        }
        logError("KeychainManager: Failed to save \(account.rawValue) (status: \(status))")
        return false
    }

    private static func load(account: Account) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = copyMatchingWithFallback(query, result: &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private static func delete(account: Account) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue
        ]
        let status = deleteWithFallback(query)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Data Protection Keychain with fallback

    private static func withDataProtectionKeychain(_ baseQuery: [String: Any]) -> [String: Any] {
        var query = baseQuery
        query[kSecUseDataProtectionKeychain as String] = true
        return query
    }

    private enum KeychainOperation {
        case add, copy, delete
    }

    private static func shouldFallbackToLegacy(for status: OSStatus, operation: KeychainOperation) -> Bool {
        if status == errSecMissingEntitlement { return true }
        switch operation {
        case .add:
            return status == errSecNotAvailable || status == errSecInteractionNotAllowed
        case .copy, .delete:
            return status == errSecItemNotFound || status == errSecNotAvailable || status == errSecInteractionNotAllowed
        }
    }

    private static func addWithFallback(_ baseQuery: [String: Any]) -> OSStatus {
        let dataProtectionQuery = withDataProtectionKeychain(baseQuery)
        let dataProtectionStatus = SecItemAdd(dataProtectionQuery as CFDictionary, nil)
        guard dataProtectionStatus != errSecSuccess else { return dataProtectionStatus }
        guard shouldFallbackToLegacy(for: dataProtectionStatus, operation: .add) else { return dataProtectionStatus }
        return SecItemAdd(baseQuery as CFDictionary, nil)
    }

    private static func deleteWithFallback(_ baseQuery: [String: Any]) -> OSStatus {
        let dataProtectionQuery = withDataProtectionKeychain(baseQuery)
        let dataProtectionStatus = SecItemDelete(dataProtectionQuery as CFDictionary)
        let legacyStatus = SecItemDelete(baseQuery as CFDictionary)
        if dataProtectionStatus == errSecSuccess || legacyStatus == errSecSuccess {
            return errSecSuccess
        }
        if dataProtectionStatus == errSecItemNotFound && legacyStatus == errSecItemNotFound {
            return errSecItemNotFound
        }
        return dataProtectionStatus != errSecItemNotFound ? dataProtectionStatus : legacyStatus
    }

    private static func copyMatchingWithFallback(_ baseQuery: [String: Any], result: inout AnyObject?) -> OSStatus {
        let dataProtectionQuery = withDataProtectionKeychain(baseQuery)
        let dataProtectionStatus = SecItemCopyMatching(dataProtectionQuery as CFDictionary, &result)
        guard dataProtectionStatus != errSecSuccess else { return dataProtectionStatus }
        guard shouldFallbackToLegacy(for: dataProtectionStatus, operation: .copy) else { return dataProtectionStatus }
        result = nil
        return SecItemCopyMatching(baseQuery as CFDictionary, &result)
    }
}
