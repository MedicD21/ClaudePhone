import Foundation
import Security
import OSLog

// MARK: - Keychain Manager for Secure API Key Storage
final class KeychainManager {
    static let shared = KeychainManager()
    private let serviceName = "com.claudephone.apikey"
    private let accountName = "claude-api-key"
    private let logger = Logger(subsystem: "com.claudephone.app", category: "keychain")

    private init() {}

    // MARK: - Validate API Key Format
    func validateAPIKey(_ key: String) -> Bool {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)

        // Anthropic API keys start with "sk-ant-" and are at least 30 characters
        guard trimmedKey.hasPrefix("sk-ant-") else {
            logger.warning("⚠️ API key validation failed: Invalid prefix")
            return false
        }

        guard trimmedKey.count >= 30 else {
            logger.warning("⚠️ API key validation failed: Too short")
            return false
        }

        // Only allow alphanumeric characters, hyphens, and underscores
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        guard trimmedKey.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
            logger.warning("⚠️ API key validation failed: Invalid characters")
            return false
        }

        logger.info("✅ API key validation passed")
        return true
    }

    func saveAPIKey(_ key: String) throws {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate before saving
        guard validateAPIKey(trimmedKey) else {
            logger.error("❌ Failed to save: Invalid API key format")
            throw KeychainError.invalidKeyFormat
        }

        let data = Data(trimmedKey.utf8)

        // Delete existing
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            logger.error("❌ Failed to save API key: \(status)")
            throw KeychainError.saveFailed(status)
        }

        logger.info("✅ API key saved successfully")
    }

    func getAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    func deleteAPIKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    var hasAPIKey: Bool {
        getAPIKey() != nil
    }
}

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case invalidKeyFormat

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save to Keychain: \(status)"
        case .deleteFailed(let status):
            return "Failed to delete from Keychain: \(status)"
        case .invalidKeyFormat:
            return "Invalid API key format. Anthropic API keys start with 'sk-ant-' and are at least 30 characters long."
        }
    }
}
