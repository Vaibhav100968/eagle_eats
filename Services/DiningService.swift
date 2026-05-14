import Foundation
import Combine

// MARK: - Dining Service
// Data source: Supabase (Postgres) — populated by AWS Lambda scraper at 5 AM CST daily.
// The app reads pre-scraped menu data via Supabase REST API.
// No more live HTML scraping from the iOS app.
//
// Supabase tables:
//   dining_halls    — static hall metadata
//   menu_items      — daily menus (hall_id + date index)
//   nutrition_info  — nutrition data keyed by recipe_id

@MainActor
final class DiningService: ObservableObject {

    static let shared = DiningService()

    private let session: URLSession
    private let supabaseURL: String
    private let supabaseKey: String

    @Published var halls: [DiningHall] = DiningHall.sampleHalls
    @Published var menusByHall: [String: [MenuItem]] = [:]
    @Published var isLoading: Bool = false
    @Published var lastUpdated: Date? = nil
    @Published var fetchError: String? = nil

    @Published private(set) var nutritionCache: [String: NutritionInfo] = [:]
    private var nutritionFetchInProgress: Set<String> = []

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        session = URLSession(configuration: config)

        supabaseURL = SupabaseConfig.url.absoluteString
        supabaseKey = SupabaseConfig.anonKey
    }

    // MARK: - Supabase REST Helpers

    private func supabaseRequest(path: String, query: String = "") -> URLRequest {
        let urlString = "\(supabaseURL)/rest/v1/\(path)?\(query)"
        var request = URLRequest(url: URL(string: urlString)!)
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func fetch<T: Decodable>(_ type: T.Type, path: String, query: String) async throws -> T {
        let request = supabaseRequest(path: path, query: query)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw DiningError.httpError(statusCode)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }

    // MARK: - Public API

    /// Fetch today's menus for all halls from Supabase.
    func fetchAllMenus() async {
        isLoading = true
        fetchError = nil

        let dateStr = isoDateString(effectiveMenuDate)

        do {
            // Fetch all menu items for today, joined with nutrition
            let query = "menu_date=eq.\(dateStr)&select=*"
            let rows: [SupabaseMenuItem] = try await fetch([SupabaseMenuItem].self,
                                                            path: "menu_items",
                                                            query: query)

            // Collect unique recipe IDs to batch-fetch nutrition
            let recipeIds = Set(rows.map(\.recipe_id))
            let nutritionMap = await fetchNutritionBatch(recipeIds: recipeIds)

            // Group by hall and convert to MenuItem
            var grouped: [String: [MenuItem]] = [:]
            for row in rows {
                let nutrition = nutritionMap[row.recipe_id]
                let item = row.toMenuItem(nutrition: nutrition)
                grouped[row.hall_id, default: []].append(item)
            }

            // Update published state
            for hall in halls {
                menusByHall[hall.id] = grouped[hall.id] ?? []
            }

            lastUpdated = Date()
            print("[DiningService] Loaded \(rows.count) items from Supabase for \(dateStr)")

        } catch {
            print("[DiningService] Supabase fetch error: \(error)")
            fetchError = error.localizedDescription

            // If Supabase is down, keep any existing data
            for hall in halls where menusByHall[hall.id] == nil {
                menusByHall[hall.id] = []
            }
        }

        isLoading = false
    }

    /// Fetch menu for a single hall if not yet loaded.
    func fetchMenuForHallIfNeeded(_ hall: DiningHall) async {
        guard menusByHall[hall.id] == nil else { return }
        isLoading = true

        let dateStr = isoDateString(effectiveMenuDate)

        do {
            let query = "hall_id=eq.\(hall.id)&menu_date=eq.\(dateStr)&select=*"
            let rows: [SupabaseMenuItem] = try await fetch([SupabaseMenuItem].self,
                                                            path: "menu_items",
                                                            query: query)

            let recipeIds = Set(rows.map(\.recipe_id))
            let nutritionMap = await fetchNutritionBatch(recipeIds: recipeIds)

            menusByHall[hall.id] = rows.map { $0.toMenuItem(nutrition: nutritionMap[$0.recipe_id]) }
        } catch {
            print("[DiningService] Single hall fetch error: \(error)")
            menusByHall[hall.id] = []
        }

        isLoading = false
    }

    // MARK: - Nutrition

    /// Batch-fetch nutrition for a set of recipe IDs from Supabase.
    private func fetchNutritionBatch(recipeIds: Set<String>) async -> [String: NutritionInfo] {
        guard !recipeIds.isEmpty else { return [:] }

        // Return cached entries first, only fetch missing
        var result: [String: NutritionInfo] = [:]
        var missing: [String] = []
        for rid in recipeIds {
            if let cached = nutritionCache[rid] {
                result[rid] = cached
            } else {
                missing.append(rid)
            }
        }

        guard !missing.isEmpty else { return result }

        do {
            // Supabase IN filter: recipe_id=in.(id1,id2,id3)
            let inList = missing.joined(separator: ",")
            let query = "recipe_id=in.(\(inList))&select=*"
            let rows: [SupabaseNutrition] = try await fetch([SupabaseNutrition].self,
                                                             path: "nutrition_info",
                                                             query: query)
            for row in rows {
                let info = row.toNutritionInfo()
                nutritionCache[row.recipe_id] = info
                result[row.recipe_id] = info
            }
        } catch {
            print("[DiningService] Nutrition batch fetch error: \(error)")
        }

        return result
    }

    /// On-demand nutrition fetch for a single item (used by detail views).
    @discardableResult
    func fetchNutrition(for item: MenuItem) async -> NutritionInfo? {
        let rid = item.recipeID

        if let cached = nutritionCache[rid] { return cached }

        guard !nutritionFetchInProgress.contains(rid) else {
            for _ in 0..<10 {
                try? await Task.sleep(nanoseconds: 300_000_000)
                if let cached = nutritionCache[rid] { return cached }
            }
            return nil
        }

        nutritionFetchInProgress.insert(rid)
        defer { nutritionFetchInProgress.remove(rid) }

        do {
            let query = "recipe_id=eq.\(rid)&select=*&limit=1"
            let rows: [SupabaseNutrition] = try await fetch([SupabaseNutrition].self,
                                                             path: "nutrition_info",
                                                             query: query)
            guard let row = rows.first else { return nil }

            let nutrition = row.toNutritionInfo()
            nutritionCache[rid] = nutrition

            // Back-patch MenuItems in menusByHall
            for hallId in menusByHall.keys {
                if let idx = menusByHall[hallId]?.firstIndex(where: { $0.recipeID == rid }) {
                    menusByHall[hallId]![idx].nutrition = nutrition
                    menusByHall[hallId]![idx].nutritionLoaded = true
                }
            }

            return nutrition
        } catch {
            print("[DiningService] Nutrition fetch error for \(rid): \(error)")
            return nil
        }
    }

    // MARK: - Today / Tomorrow Logic

    var effectiveMenuDate: Date {
        let anyOpen = halls.contains { $0.isOpen }
        if anyOpen { return Date() }
        return Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }

    var isShowingTomorrowMenu: Bool {
        !halls.contains { $0.isOpen }
    }

    // MARK: - Item Accessors (unchanged API for views)

    func menuItems(for hall: DiningHall, period: MealPeriod) -> [MenuItem] {
        guard let all = menusByHall[hall.id] else { return [] }
        if period == .closed { return all }
        return all.filter { $0.mealPeriods.contains(period) }
    }

    func menuItems(for hall: DiningHall, period: MealPeriod, category: MenuCategory) -> [MenuItem] {
        menuItems(for: hall, period: period).filter { $0.category == category }
    }

    func categories(for hall: DiningHall, period: MealPeriod) -> [MenuCategory] {
        let items = menuItems(for: hall, period: period)
        var seen: [MenuCategory] = []
        for item in items where !seen.contains(item.category) {
            seen.append(item.category)
        }
        return seen
    }

    func stations(for hall: DiningHall, period: MealPeriod) -> [String] {
        let items = menuItems(for: hall, period: period)
        var seen: [String] = []
        for item in items {
            let s = item.station.isEmpty ? item.category.rawValue : item.station
            if !seen.contains(s) { seen.append(s) }
        }
        return seen
    }

    // MARK: - Helpers

    private func isoDateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "America/Chicago")
        return f.string(from: date)
    }
}

// MARK: - Errors

enum DiningError: LocalizedError {
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .httpError(let code):
            return "Server error (HTTP \(code)). Please try again."
        }
    }
}

// MARK: - Supabase Response Models

private struct SupabaseMenuItem: Decodable {
    let id: String
    let hall_id: String
    let recipe_id: String
    let name: String
    let description: String?
    let category: String?
    let station: String?
    let meal_periods: [String]?
    let dietary_tags: String?      // JSONB comes as string
    let menu_date: String

    func toMenuItem(nutrition: NutritionInfo?) -> MenuItem {
        let periods = (meal_periods ?? []).compactMap { MealPeriod(rawValue: $0) }
        let tags = parseDietaryTags()
        let cat = MenuCategory(rawValue: category ?? "Entrées") ?? .entrees
        let hasNutrition = nutrition?.isComplete == true

        return MenuItem(
            id: id,
            recipeID: recipe_id,
            name: name,
            description: description ?? "",
            category: cat,
            station: station ?? "",
            nutrition: nutrition ?? .empty,
            nutritionLoaded: hasNutrition,
            dietaryTags: tags,
            mealPeriods: periods.isEmpty ? [.lunch] : periods,
            diningHallId: hall_id
        )
    }

    private func parseDietaryTags() -> [DietaryTag] {
        guard let jsonStr = dietary_tags,
              let data = jsonStr.data(using: .utf8),
              let tags = try? JSONDecoder().decode([DietaryTag].self, from: data) else {
            return []
        }
        return tags
    }
}

private struct SupabaseNutrition: Decodable {
    let recipe_id: String
    let calories: Double?
    let protein: Double?
    let carbohydrates: Double?
    let fat: Double?
    let fiber: Double?
    let sugar: Double?
    let sodium: Double?
    let serving_size: String?
    let allergens: [String]?
    let ingredients: String?

    func toNutritionInfo() -> NutritionInfo {
        let parsedAllergens = (allergens ?? []).compactMap { Allergen.from(string: $0) }
        return NutritionInfo(
            calories: calories ?? 0,
            protein: protein ?? 0,
            carbohydrates: carbohydrates ?? 0,
            fat: fat ?? 0,
            fiber: fiber,
            sugar: sugar,
            sodium: sodium,
            servingSize: serving_size,
            allergens: parsedAllergens,
            ingredients: ingredients ?? ""
        )
    }
}
