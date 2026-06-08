import Foundation
import Security

// MARK: - Keychain Service
// Wraps Apple's Security framework for secure string storage.
// All Mean Eats sensitive data (session tokens, credential hashes) lives here.
// Never store raw passwords — only hashes or session tokens.

final class KeychainService {

    static let shared = KeychainService()
    private init() {}

    private let service = "com.eagleeats.app"

    // MARK: - Public Interface

    /// Persist a string value under the given key. Returns true on success.
    @discardableResult
    func save(_ value: String, for key: KeychainKey) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        delete(key)   // remove any existing item first

        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key.rawValue,
            kSecValueData:   data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    /// Load a string value for the given key. Returns nil if not found.
    func load(_ key: KeychainKey) -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      key.rawValue,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8)
        else { return nil }
        return string
    }

    /// Delete a stored value. Silent on missing key.
    func delete(_ key: KeychainKey) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Delete all Mean Eats keychain entries (used on sign-out / reset).
    func deleteAll() {
        for key in KeychainKey.allCases { delete(key) }
    }

    // MARK: - Convenience

    var hasAppSession: Bool {
        load(.appSessionToken) != nil
    }

    var hasPortalSession: Bool {
        load(.portalSessionFlag) == "1"
    }

    func markPortalSession(_ valid: Bool) {
        if valid { save("1", for: .portalSessionFlag) }
        else      { delete(.portalSessionFlag) }
    }
}

// MARK: - Key Enum

enum KeychainKey: String, CaseIterable {
    case appSessionToken    = "eagle_app_session_token"
    case accountIdentifier  = "eagle_account_identifier"
    case accountDisplayName = "eagle_account_display_name"
    case credentialHash     = "eagle_credential_hash"
    case credentialSalt     = "eagle_credential_salt"
    case portalSessionFlag  = "eagle_portal_session_valid"  // "1" or absent
    case untDisplayName     = "eagle_unt_display_name"      // name from UNT portal
    case welcomeEmailSent   = "eagle_welcome_email_sent"    // "1" after first login
}
