import Foundation
import CryptoKit
import Combine

// MARK: - Auth Error

enum AuthError: LocalizedError {
    case invalidIdentifier
    case passwordTooShort
    case accountExists
    case accountNotFound
    case wrongPassword
    case keychainFailure

    var errorDescription: String? {
        switch self {
        case .invalidIdentifier: return "Enter a valid email address or 10-digit phone number."
        case .passwordTooShort:  return "Password must be at least 8 characters."
        case .accountExists:     return "An account with that email or phone already exists."
        case .accountNotFound:   return "No account found. Check your login or create an account."
        case .wrongPassword:     return "Incorrect password. Please try again."
        case .keychainFailure:   return "Could not save credentials. Please try again."
        }
    }
}

// MARK: - Auth Service
// Manages authentication state based on UNT portal session.
// The user authenticates via WKWebView against mealplans.unt.edu (UNT SSO).
// Portal session cookies persist in the default WKWebsiteDataStore.
// This service tracks whether a valid session exists and stores the user's
// display name extracted from the portal.

@MainActor
final class AuthService: ObservableObject {

    static let shared = AuthService()

    @Published private(set) var isSignedIn: Bool = false
    @Published private(set) var displayName: String? = nil
    @Published private(set) var identifier: String? = nil

    private let keychain = KeychainService.shared

    private init() {
        restoreSession()
    }

    // MARK: - Session Restore

    private func restoreSession() {
        guard keychain.hasPortalSession else { return }
        isSignedIn  = true
        displayName = keychain.load(.untDisplayName) ?? keychain.load(.accountDisplayName)
        identifier  = keychain.load(.accountIdentifier) ?? displayName
    }

    // MARK: - Portal Authentication

    /// Called after successful UNT portal login (SSO via WKWebView).
    /// Stores the user identity extracted from the portal page.
    func authenticateWithPortal(displayName name: String?) {
        let resolvedName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = (resolvedName?.isEmpty == false) ? resolvedName! : "UNT Student"

        keychain.save(finalName, for: .untDisplayName)
        keychain.save(finalName, for: .accountDisplayName)
        keychain.save(finalName, for: .accountIdentifier)
        keychain.markPortalSession(true)

        let token = UUID().uuidString
        keychain.save(token, for: .appSessionToken)

        isSignedIn  = true
        displayName = finalName
        identifier  = finalName
    }

    // MARK: - Sign Out

    func signOut() {
        keychain.delete(.appSessionToken)
        keychain.markPortalSession(false)
        isSignedIn  = false
        identifier  = nil
        displayName = nil
    }

    // MARK: - Delete Account

    func deleteAccount() {
        keychain.deleteAll()
        isSignedIn  = false
        identifier  = nil
        displayName = nil
    }

    // MARK: - First launch welcome

    var isFirstLogin: Bool {
        keychain.load(.welcomeEmailSent) == nil
    }

    func markWelcomeEmailSent() {
        keychain.save("1", for: .welcomeEmailSent)
    }
}
