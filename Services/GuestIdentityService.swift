import Foundation

// MARK: - Guest Identity
// Stable per-device guest_id persisted in Keychain across sessions.
// Format: guest_{uuid}

final class GuestIdentityService {

    static let shared = GuestIdentityService()

    private let keychain = KeychainService.shared
    private var cachedGuestId: String?

    private init() {}

    /// Returns the device guest id, creating and persisting one on first access.
    var guestId: String {
        if let cachedGuestId { return cachedGuestId }
        if let existing = keychain.load(.guestId) {
            cachedGuestId = existing
            return existing
        }
        let id = "guest_\(UUID().uuidString.lowercased())"
        keychain.save(id, for: .guestId)
        cachedGuestId = id
        return id
    }

    /// Call at app launch so guest_id exists before any events fire.
    func ensureGuestId() -> String {
        guestId
    }
}
