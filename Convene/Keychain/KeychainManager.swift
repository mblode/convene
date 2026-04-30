import Foundation
import Security

enum KeychainManager {
    private static let service = "co.blode.convene"
    private static let apiKeyAccount = "OpenAIAPIKey"

    private enum KeychainOperation {
        case add
        case copy
        case delete
    }

    private static func withDataProtectionKeychain(_ baseQuery: [String: Any]) -> [String: Any] {
        var query = baseQuery
        query[kSecUseDataProtectionKeychain as String] = true
        return query
    }

    private static func shouldFallbackToLegacy(for status: OSStatus, operation: KeychainOperation) -> Bool {
        if status == errSecMissingEntitlement {
            return true
        }

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
        logInfo("KeychainManager: Falling back to legacy keychain for save (status: \(dataProtectionStatus))")
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
        if dataProtectionStatus != errSecItemNotFound {
            return dataProtectionStatus
        }
        return legacyStatus
    }

    private static func copyMatchingWithFallback(_ baseQuery: [String: Any], result: inout AnyObject?) -> OSStatus {
        let dataProtectionQuery = withDataProtectionKeychain(baseQuery)
        let dataProtectionStatus = SecItemCopyMatching(dataProtectionQuery as CFDictionary, &result)
        guard dataProtectionStatus != errSecSuccess else { return dataProtectionStatus }
        guard shouldFallbackToLegacy(for: dataProtectionStatus, operation: .copy) else { return dataProtectionStatus }
        result = nil
        return SecItemCopyMatching(baseQuery as CFDictionary, &result)
    }

    @discardableResult
    static func saveAPIKey(_ key: String) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount
        ]
        _ = deleteWithFallback(deleteQuery)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = addWithFallback(addQuery)
        if status == errSecSuccess {
            logInfo("KeychainManager: API key saved")
            return true
        }
        logError("KeychainManager: Failed to save API key (status: \(status))")
        return false
    }

    static func loadAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount,
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

    @discardableResult
    static func deleteAPIKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount
        ]
        let status = deleteWithFallback(query)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
