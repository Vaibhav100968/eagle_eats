import Foundation

// MARK: - Event Tracking
// Sends guest/auth analytics to Supabase `app_events`.
// Offline events are queued locally and flushed on next successful send.

@MainActor
final class EventTrackingService {

    static let shared = EventTrackingService()

    private let session: URLSession
    private let supabaseURL: String
    private let supabaseKey: String
    private let queueKey = "eagle_eats_event_queue"
    private let maxQueueSize = 100

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        session = URLSession(configuration: config)
        supabaseURL = SupabaseConfig.url.absoluteString
        supabaseKey = SupabaseConfig.anonKey
    }

    // MARK: - Public API

    /// Fire-and-forget event tracking. Safe to call from any screen.
    func track(_ eventType: String, metadata: [String: String] = [:]) {
        Task { await trackAsync(eventType, metadata: metadata) }
    }

    /// Awaitable variant for sign-in flows that need ordering before link RPC.
    func trackAsync(_ eventType: String, metadata: [String: String] = [:]) async {
        let guestId = GuestIdentityService.shared.guestId
        let auth = AuthService.shared

        let userId: String
        let userType: String

        if auth.isSignedIn, let authId = auth.authUserId {
            userId = authId
            userType = "auth"
        } else {
            userId = guestId
            userType = "guest"
        }

        var meta = metadata
        meta["guest_id"] = guestId
        meta["platform"] = "ios"

        let payload = AppEventPayload(
            userId: userId,
            userType: userType,
            eventType: eventType,
            metadata: meta,
            guestId: guestId
        )

        if await send(payload) {
            await flushQueue()
        } else {
            enqueue(payload)
        }
    }

    /// Links prior guest events to the authenticated user id after login.
    func linkGuestToAuth() async {
        guard AuthService.shared.isSignedIn,
              let authId = AuthService.shared.authUserId else { return }

        let guestId = GuestIdentityService.shared.guestId
        await trackAsync("guest_upgraded", metadata: [
            "guest_id": guestId,
            "auth_user_id": authId,
        ])
        await callLinkRPC(guestId: guestId, authId: authId)
    }

    /// Retry queued events (e.g. after network returns).
    func flushQueue() async {
        var queue = loadQueue()
        guard !queue.isEmpty else { return }

        var remaining: [AppEventPayload] = []
        for event in queue {
            if await send(event) { continue }
            remaining.append(event)
            break
        }
        saveQueue(remaining)
    }

    // MARK: - Supabase

    private func send(_ event: AppEventPayload) async -> Bool {
        guard let url = URL(string: "\(supabaseURL)/rest/v1/app_events") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        let body: [String: Any] = [
            "user_id": event.userId,
            "user_type": event.userType,
            "event_type": event.eventType,
            "metadata": event.metadata,
            "guest_id": event.guestId,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200...299).contains(http.statusCode)
        } catch {
            print("[EventTracking] send failed: \(error.localizedDescription)")
            return false
        }
    }

    private func callLinkRPC(guestId: String, authId: String) async {
        guard let url = URL(string: "\(supabaseURL)/rest/v1/rpc/link_guest_to_auth") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "p_guest_id": guestId,
            "p_auth_id": authId,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                print("[EventTracking] link_guest_to_auth HTTP \(http.statusCode)")
            }
        } catch {
            print("[EventTracking] link_guest_to_auth failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Offline Queue

    private func enqueue(_ event: AppEventPayload) {
        var queue = loadQueue()
        queue.append(event)
        if queue.count > maxQueueSize {
            queue.removeFirst(queue.count - maxQueueSize)
        }
        saveQueue(queue)
    }

    private func loadQueue() -> [AppEventPayload] {
        guard let data = UserDefaults.standard.data(forKey: queueKey),
              let queue = try? JSONDecoder().decode([AppEventPayload].self, from: data)
        else { return [] }
        return queue
    }

    private func saveQueue(_ queue: [AppEventPayload]) {
        if let data = try? JSONEncoder().encode(queue) {
            UserDefaults.standard.set(data, forKey: queueKey)
        } else if queue.isEmpty {
            UserDefaults.standard.removeObject(forKey: queueKey)
        }
    }
}

// MARK: - Payload

private struct AppEventPayload: Codable {
    let userId: String
    let userType: String
    let eventType: String
    let metadata: [String: String]
    let guestId: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case userType = "user_type"
        case eventType = "event_type"
        case metadata
        case guestId = "guest_id"
    }
}
