import Foundation

// MARK: - Social Service
// Handles dining check-ins, meal sharing, and item ratings.

@MainActor
final class SocialService: ObservableObject {

    static let shared = SocialService()

    @Published var activeCheckIn: CheckIn? = nil
    @Published var recentCheckIns: [CheckIn] = []
    @Published var hallCheckInCounts: [String: Int] = [:]

    private let session: URLSession
    private let supabaseURL: String
    private let supabaseKey: String
    private let persistence = PersistenceService.shared

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        session = URLSession(configuration: config)
        supabaseURL = SupabaseConfig.url.absoluteString
        supabaseKey = SupabaseConfig.anonKey
    }

    // MARK: - Check-in

    func checkIn(hallId: String, hallName: String, mealPeriod: String, userName: String?) async {
        let checkIn = CheckIn(
            id: UUID().uuidString,
            hallId: hallId,
            hallName: hallName,
            mealPeriod: mealPeriod,
            userName: userName ?? "Eagle",
            checkedInAt: Date()
        )

        activeCheckIn = checkIn

        // Save locally
        saveCheckInLocally(checkIn)

        // Push to Supabase
        await pushCheckIn(checkIn)

        // Refresh counts
        await fetchCheckInCounts()
    }

    func checkOut() {
        activeCheckIn = nil
    }

    /// Fetch how many people checked in to each hall today.
    func fetchCheckInCounts() async {
        let today = isoDateString(Date())
        let urlString = "\(supabaseURL)/rest/v1/check_ins?select=hall_id&checked_in_date=eq.\(today)"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await session.data(for: request)
            if let rows = try? JSONDecoder().decode([[String: String]].self, from: data) {
                var counts: [String: Int] = [:]
                for row in rows {
                    if let hallId = row["hall_id"] {
                        counts[hallId, default: 0] += 1
                    }
                }
                hallCheckInCounts = counts
            }
        } catch {
            print("[SocialService] Failed to fetch check-in counts: \(error)")
        }
    }

    /// Fetch recent check-ins across all halls (last 20).
    func fetchRecentCheckIns() async {
        let today = isoDateString(Date())
        let urlString = "\(supabaseURL)/rest/v1/check_ins?checked_in_date=eq.\(today)&select=*&order=checked_in_at.desc&limit=20"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await session.data(for: request)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let rows = try? decoder.decode([SupabaseCheckIn].self, from: data) {
                recentCheckIns = rows.map { $0.toCheckIn() }
            }
        } catch {
            print("[SocialService] Failed to fetch recent check-ins: \(error)")
        }
    }

    // MARK: - Ratings

    func rateItem(itemId: String, recipeId: String, hallId: String, rating: Int) {
        let entry = ItemRating(
            itemId: itemId,
            recipeId: recipeId,
            hallId: hallId,
            rating: rating,
            date: Date()
        )
        saveRating(entry)
    }

    func rating(for itemId: String) -> Int? {
        let ratings = loadRatings()
        return ratings.first(where: { $0.itemId == itemId })?.rating
    }

    func averageRating(for recipeId: String) -> (average: Double, count: Int)? {
        let ratings = loadRatings().filter { $0.recipeId == recipeId }
        guard !ratings.isEmpty else { return nil }
        let avg = Double(ratings.reduce(0) { $0 + $1.rating }) / Double(ratings.count)
        return (avg, ratings.count)
    }

    // MARK: - Share Plate

    func sharePlateText(items: [(name: String, calories: Double)], hallName: String) -> String {
        var text = "Eating at \(hallName) today!\n\n"
        for item in items {
            text += "• \(item.name) (\(Int(item.calories)) cal)\n"
        }
        let totalCal = items.reduce(0) { $0 + Int($1.calories) }
        text += "\nTotal: \(totalCal) cal"
        text += "\n\n— via Eagle Eats"
        return text
    }

    // MARK: - Private: Supabase Push

    private func pushCheckIn(_ checkIn: CheckIn) async {
        let urlString = "\(supabaseURL)/rest/v1/check_ins"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

        let body: [String: Any] = [
            "id": checkIn.id,
            "hall_id": checkIn.hallId,
            "hall_name": checkIn.hallName,
            "meal_period": checkIn.mealPeriod,
            "user_name": checkIn.userName,
            "checked_in_date": isoDateString(checkIn.checkedInAt),
            "checked_in_at": ISO8601DateFormatter().string(from: checkIn.checkedInAt),
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: [body])

        do {
            let (_, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                print("[SocialService] Check-in push failed: HTTP \(http.statusCode)")
            }
        } catch {
            print("[SocialService] Check-in push error: \(error)")
        }
    }

    // MARK: - Private: Local Storage

    private let checkInsKey = "eagle_eats_checkins"
    private let ratingsKey  = "eagle_eats_ratings"

    private func saveCheckInLocally(_ checkIn: CheckIn) {
        var list = loadLocalCheckIns()
        list.insert(checkIn, at: 0)
        let trimmed = Array(list.prefix(50))
        if let data = try? JSONEncoder().encode(trimmed) {
            UserDefaults.standard.set(data, forKey: checkInsKey)
        }
    }

    private func loadLocalCheckIns() -> [CheckIn] {
        guard let data = UserDefaults.standard.data(forKey: checkInsKey),
              let list = try? JSONDecoder().decode([CheckIn].self, from: data)
        else { return [] }
        return list
    }

    private func saveRating(_ rating: ItemRating) {
        var ratings = loadRatings()
        ratings.removeAll { $0.itemId == rating.itemId }
        ratings.insert(rating, at: 0)
        let trimmed = Array(ratings.prefix(200))
        if let data = try? JSONEncoder().encode(trimmed) {
            UserDefaults.standard.set(data, forKey: ratingsKey)
        }
    }

    private func loadRatings() -> [ItemRating] {
        guard let data = UserDefaults.standard.data(forKey: ratingsKey),
              let list = try? JSONDecoder().decode([ItemRating].self, from: data)
        else { return [] }
        return list
    }

    // MARK: - Helpers

    private func isoDateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "America/Chicago")
        return f.string(from: date)
    }
}

// MARK: - Models

struct CheckIn: Identifiable, Codable {
    let id: String
    let hallId: String
    let hallName: String
    let mealPeriod: String
    let userName: String
    let checkedInAt: Date

    var timeAgo: String {
        let seconds = Int(Date().timeIntervalSince(checkedInAt))
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        return "\(seconds / 3600)h ago"
    }
}

struct ItemRating: Codable {
    let itemId: String
    let recipeId: String
    let hallId: String
    let rating: Int
    let date: Date
}

private struct SupabaseCheckIn: Decodable {
    let id: String
    let hall_id: String
    let hall_name: String
    let meal_period: String
    let user_name: String?
    let checked_in_at: String

    func toCheckIn() -> CheckIn {
        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: checked_in_at) ?? Date()
        return CheckIn(
            id: id,
            hallId: hall_id,
            hallName: hall_name,
            mealPeriod: meal_period,
            userName: user_name ?? "Eagle",
            checkedInAt: date
        )
    }
}
