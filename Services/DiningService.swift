import Foundation
import Combine

// MARK: - Dining Service
// Data source: https://diningmenus.unt.edu
// - Menu page  : ?locationID={id}&date={MM/dd/yyyy}
// - Nutrition  : label.aspx?recipeNum={recipeID}
//
// LocationID map (confirmed from page navigation):
//   10 → Mean Greens Café  |  15 → Champs  |  20 → Bruceteria
//   25 → Kitchen West      |  31 → Eagle Landing

@MainActor
final class DiningService: ObservableObject {

    static let shared = DiningService()

    private let baseURL  = "https://diningmenus.unt.edu"
    private let session: URLSession

    @Published var halls: [DiningHall] = DiningHall.sampleHalls
    @Published var menusByHall: [String: [MenuItem]] = [:]
    @Published var isLoading: Bool = false
    @Published var lastUpdated: Date? = nil
    @Published var fetchError: String? = nil

    // Nutrition cache keyed by recipeID ("460007", etc.)
    // Shared across all halls since the same recipe can appear in multiple locations.
    @Published private(set) var nutritionCache: [String: NutritionInfo] = [:]
    private var nutritionFetchInProgress: Set<String> = []

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.requestCachePolicy = .reloadRevalidatingCacheData
        session = URLSession(configuration: config)
    }

    // MARK: - Public API

    /// Fetch menus for all halls for the effective date (today, or tomorrow if all closed).
    func fetchAllMenus() async {
        isLoading  = true
        fetchError = nil

        let date = effectiveMenuDate

        await withTaskGroup(of: (String, [MenuItem]?).self) { group in
            for hall in halls {
                group.addTask { [weak self] in
                    guard let self else { return (hall.id, nil) }
                    let items = await self.fetchMenuForHall(hall, date: date)
                    return (hall.id, items)
                }
            }
            for await (hallId, items) in group {
                if let items {
                    menusByHall[hallId] = items
                    print("[DiningService] \(hallId): \(items.count) items loaded")
                } else {
                    print("[DiningService] \(hallId): fetch returned nil — hall will show empty state")
                    // Do NOT populate with sample/fake data on failure
                    if menusByHall[hallId] == nil {
                        menusByHall[hallId] = []   // explicit empty → shows "no menu" state
                    }
                }
            }
        }

        lastUpdated = Date()
        isLoading   = false
    }

    /// Fetch menu for a single hall (called on detail view appear if not yet loaded).
    func fetchMenuForHallIfNeeded(_ hall: DiningHall) async {
        guard menusByHall[hall.id] == nil else { return }
        isLoading = true
        let items = await fetchMenuForHall(hall, date: effectiveMenuDate)
        menusByHall[hall.id] = items ?? []
        isLoading = false
    }

    // MARK: - Today / Tomorrow logic

    var effectiveMenuDate: Date {
        let anyOpen = halls.contains { $0.isOpen }
        if anyOpen { return Date() }
        return Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }

    var isShowingTomorrowMenu: Bool {
        !halls.contains { $0.isOpen }
    }

    // MARK: - Item Accessors

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

    /// Ordered list of unique station names for the given hall and meal period.
    /// Stations are the raw panel headings from the menu page (e.g. "Bamboo Basil", "Avenue A Homestyle").
    func stations(for hall: DiningHall, period: MealPeriod) -> [String] {
        let items = menuItems(for: hall, period: period)
        var seen: [String] = []
        for item in items {
            let s = item.station.isEmpty ? item.category.rawValue : item.station
            if !seen.contains(s) { seen.append(s) }
        }
        return seen
    }

    // MARK: - On-demand Nutrition Fetch

    /// Returns cached nutrition, or fetches from label.aspx if not yet loaded.
    /// Updates the corresponding MenuItem in menusByHall when complete.
    @discardableResult
    func fetchNutrition(for item: MenuItem) async -> NutritionInfo? {
        let rid = item.recipeID

        // Return from cache immediately
        if let cached = nutritionCache[rid] { return cached }

        // Deduplicate concurrent requests
        guard !nutritionFetchInProgress.contains(rid) else {
            // Poll cache briefly then give up
            for _ in 0..<10 {
                try? await Task.sleep(nanoseconds: 300_000_000)
                if let cached = nutritionCache[rid] { return cached }
            }
            return nil
        }

        nutritionFetchInProgress.insert(rid)
        defer { nutritionFetchInProgress.remove(rid) }

        guard let url = URL(string: "\(baseURL)/label.aspx?recipeNum=\(rid)") else { return nil }

        do {
            var req = URLRequest(url: url)
            req.setValue(browserUserAgent, forHTTPHeaderField: "User-Agent")
            let (data, _) = try await session.data(for: req)
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            guard let nutrition = parseNutritionLabel(html) else { return nil }

            nutritionCache[rid] = nutrition

            // Back-patch all MenuItem instances in menusByHall that share this recipeID
            for hallId in menusByHall.keys {
                if let idx = menusByHall[hallId]?.firstIndex(where: { $0.recipeID == rid }) {
                    menusByHall[hallId]![idx].nutrition        = nutrition
                    menusByHall[hallId]![idx].nutritionLoaded  = true
                    // Also patch description/ingredients if empty
                    if let ingredients = html.firstCapture(
                        pattern: #"modal-description-text">\s*(.*?)\s*<\/p>"#) {
                        menusByHall[hallId]![idx].description = ingredients
                    }
                }
            }
            print("[DiningService] Nutrition loaded for recipeID=\(rid) (\(item.name)): \(Int(nutrition.calories)) kcal")
            return nutrition
        } catch {
            print("[DiningService] Nutrition fetch failed for recipeID=\(rid): \(error)")
            return nil
        }
    }

    // MARK: - Network: Menu Page Fetch

    private func fetchMenuForHall(_ hall: DiningHall, date: Date) async -> [MenuItem]? {
        let dateStr = menuDateString(date)
        let urlString = "\(baseURL)/?locationID=\(hall.locationID)&date=\(dateStr)"
        guard let url = URL(string: urlString) else {
            print("[DiningService] Bad URL for \(hall.name): \(urlString)")
            return nil
        }

        print("[DiningService] Fetching \(hall.name) (locationID=\(hall.locationID)) for \(dateStr)")

        do {
            var req = URLRequest(url: url)
            req.setValue(browserUserAgent, forHTTPHeaderField: "User-Agent")
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let html = String(data: data, encoding: .utf8)
            else {
                print("[DiningService] HTTP error for \(hall.name)")
                return nil
            }
            let items = parseMenuPage(html, hall: hall)
            print("[DiningService] Parsed \(items.count) items for \(hall.name)")
            return items.isEmpty ? nil : items
        } catch {
            print("[DiningService] Network error for \(hall.name): \(error)")
            return nil
        }
    }

    // MARK: - HTML Parsing: Menu Page

    /// Parse diningmenus.unt.edu HTML into [MenuItem].
    ///
    /// Page structure:
    ///   Nav tabs: <a href="#breakfast" data-toggle="tab">LUNCH</a>
    ///   Tab panes: <div class="tab-pane … " id="breakfast"> … </div>
    ///   Panels inside pane: <div class="panel panel-default panel-menu">
    ///     <div class="panel-heading"><p class="h5">Station Name</p></div>
    ///     <ul class="list-group">
    ///       <li id="420069" class="list-group-item borderless food-item Vegan Vegetarian">
    ///         Baked Yellow Squash
    ///       </li>
    ///     </ul>
    ///   </div>
    ///
    /// Fallback: When no tab navigation is found (e.g. Eagle Landing's HTML variant),
    /// the entire page body is parsed as a single pane covering both Lunch and Dinner.

    private func parseMenuPage(_ html: String, hall: DiningHall) -> [MenuItem] {
        var items: [MenuItem] = []

        // 1. Build divId → MealPeriod from tab navigation.
        //    Allow any alphanumeric+hyphen IDs and case-insensitive labels.
        var divToMealPeriod: [String: MealPeriod] = [:]
        let tabPattern = "href=\"#([A-Za-z0-9_-]+)\"[^>]*data-toggle=\"tab\"[^>]*>\\s*([^<]+?)\\s*<"
        for m in html.allCaptures(pattern: tabPattern, groupCount: 2) {
            let divId = m[0]
            let label = m[1].trimmingCharacters(in: .whitespacesAndNewlines)
            if let period = mealPeriodFrom(label) {
                divToMealPeriod[divId] = period
                print("[DiningService] Tab map: #\(divId) → \(period.rawValue) (\(hall.name))")
            }
        }

        // 2. Split HTML at each tab-pane div.
        let paneSplit = #"<div[^>]+class="tab-pane[^"]*"[^>]+id="([^"]+)""#
        let paneMatches = html.allCaptures(pattern: paneSplit, groupCount: 1)

        var paneStarts: [(divId: String, range: String.Index)] = []
        var searchStart = html.startIndex
        for matchGroup in paneMatches {
            let divId = matchGroup[0]
            if let r = html.range(of: "id=\"\(divId)\"", range: searchStart..<html.endIndex) {
                paneStarts.append((divId: divId, range: r.lowerBound))
                searchStart = r.upperBound
            }
        }

        // 3. If no tabs resolved to a meal period, fall back to treating the whole HTML as
        //    a single pane covering both Lunch and Dinner (handles Eagle Landing and other
        //    hall variants whose tab markup differs from the expected pattern).
        let useFallback = paneStarts.allSatisfy { divToMealPeriod[$0.divId] == nil }

        if useFallback {
            print("[DiningService] No tab panes matched — using full-page fallback for \(hall.name)")
            items = parsePanelItems(html, period: .lunch, existingItems: &items, hallId: hall.id)
            // Also tag the same items as dinner so they appear in both periods
            for i in items.indices {
                if !items[i].mealPeriods.contains(.dinner) {
                    var periods = items[i].mealPeriods
                    periods.append(.dinner)
                    items[i] = rebuildItem(items[i], mealPeriods: periods)
                }
            }
            return items
        }

        // 4. Normal path: iterate each tab pane
        for (i, pane) in paneStarts.enumerated() {
            guard let period = divToMealPeriod[pane.divId] else { continue }
            let paneEnd  = (i + 1 < paneStarts.count) ? paneStarts[i + 1].range : html.endIndex
            let paneHTML = String(html[pane.range..<paneEnd])
            items = parsePanelItems(paneHTML, period: period, existingItems: &items, hallId: hall.id)
        }

        return items
    }

    // MARK: - Parse panels within an HTML fragment

    /// Scans `html` for `<div class="panel panel-default panel-menu">` blocks, extracts
    /// items from each, and merges them into `existingItems` (deduplicating by item id).
    private func parsePanelItems(
        _ html: String,
        period: MealPeriod,
        existingItems: inout [MenuItem],
        hallId: String
    ) -> [MenuItem] {
        var items = existingItems
        let panelMarker = #"<div class="panel panel-default panel-menu""#
        var panelStart  = html.startIndex

        while let ps = html.range(of: panelMarker, range: panelStart..<html.endIndex) {
            let nextPanelRange = html.range(of: panelMarker, range: ps.upperBound..<html.endIndex)
            let panelEnd       = nextPanelRange?.lowerBound ?? html.endIndex
            let panelHTML      = String(html[ps.lowerBound..<panelEnd])

            // Extract station name from the panel heading
            let rawHeading = panelHTML.firstCapture(pattern: #"<p[^>]+>\s*(.*?)\s*</p>"#) ?? ""
            let stationName = rawHeading
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let category = mapCategoryName(stationName)

            // Extract food items: <li id="420069" class="list-group-item borderless food-item TAGS">Name</li>
            let itemPattern = #"<li\s+id="(\d+)"\s+class="list-group-item\s+borderless\s+food-item([^"]*)"\s*>([^<]+)</li>"#
            for itemMatch in panelHTML.allCaptures(pattern: itemPattern, groupCount: 3) {
                let recipeID = itemMatch[0]
                let tagsStr  = itemMatch[1]
                let name     = itemMatch[2].trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { continue }

                let tags   = parseDietaryTags(tagsStr)
                let itemId = "\(hallId)-\(recipeID)"

                // Merge with existing item (different meal period for same recipe)
                if let existingIdx = items.firstIndex(where: { $0.id == itemId }) {
                    if !items[existingIdx].mealPeriods.contains(period) {
                        var periods = items[existingIdx].mealPeriods
                        periods.append(period)
                        items[existingIdx] = rebuildItem(items[existingIdx], mealPeriods: periods)
                    }
                    continue
                }

                items.append(MenuItem(
                    id:              itemId,
                    recipeID:        recipeID,
                    name:            name,
                    description:     "",
                    category:        category,
                    station:         stationName,
                    nutrition:       .empty,
                    nutritionLoaded: false,
                    dietaryTags:     tags,
                    mealPeriods:     [period],
                    diningHallId:    hallId
                ))
            }

            // Advance past this panel
            panelStart = nextPanelRange?.lowerBound ?? html.endIndex
            if panelStart == html.endIndex { break }
        }

        existingItems = items
        return items
    }

    private func rebuildItem(_ item: MenuItem, mealPeriods: [MealPeriod]) -> MenuItem {
        MenuItem(
            id:              item.id,
            recipeID:        item.recipeID,
            name:            item.name,
            description:     item.description,
            category:        item.category,
            station:         item.station,
            nutrition:       item.nutrition,
            nutritionLoaded: item.nutritionLoaded,
            dietaryTags:     item.dietaryTags,
            mealPeriods:     mealPeriods,
            diningHallId:    item.diningHallId
        )
    }

    // MARK: - HTML Parsing: Nutrition Label

    /// Parse label.aspx?recipeNum={id} HTML into NutritionInfo.
    private func parseNutritionLabel(_ html: String) -> NutritionInfo? {
        func numAfter(_ label: String) -> Double? {
            // Matches: "Label Name <div class="weight">70</div>" or "…4.7g…"
            let escaped = NSRegularExpression.escapedPattern(for: label)
            let pattern = escaped + #"[^<]*<div class="weight">([0-9.]+)"#
            return html.firstCapture(pattern: pattern).flatMap { Double($0) }
        }

        func numStr(_ label: String) -> Double? {
            numAfter(label)
        }

        let calories = numStr("Calories")
        let fat      = numStr("Total Fat")
        let carbs    = numStr("Total Carbohydrates")
        let protein  = numStr("Protein")
        let fiber    = numStr("Dietary Fiber")
        let sugar    = numStr("Sugars")
        let sodium   = numStr("Sodium")

        let serving  = html.firstCapture(pattern: #"<span class="highlighted">([^<]+)</span>\s*Serving Size"#)

        guard let cal = calories, let fat = fat, let carbs = carbs, let prot = protein else {
            print("[DiningService] parseNutritionLabel: missing key macros")
            return nil
        }

        return NutritionInfo(
            calories:      cal,
            protein:       prot,
            carbohydrates: carbs,
            fat:           fat,
            fiber:         fiber,
            sugar:         sugar,
            sodium:        sodium,
            servingSize:   serving
        )
    }

    // MARK: - Helpers

    private func mealPeriodFrom(_ label: String) -> MealPeriod? {
        let upper = label.uppercased()
        if upper.contains("BREAKFAST") || upper.contains("BKFST") { return .breakfast }
        if upper.contains("LUNCH")                                  { return .lunch }
        if upper.contains("DINNER")                                 { return .dinner }
        if upper.contains("LATE")  || upper.contains("NIGHT")      { return .lateNight }
        return nil
    }

    private func parseDietaryTags(_ classStr: String) -> [DietaryTag] {
        var tags: [DietaryTag] = []
        let classes = classStr.trimmingCharacters(in: .whitespaces)
        if classes.contains("Vegan")      { tags.append(.vegan) }
        if classes.contains("Vegetarian") { tags.append(.vegetarian) }
        if classes.contains("Halal")      { tags.append(.halal) }
        return tags
    }

    private func mapCategoryName(_ raw: String) -> MenuCategory {
        let lower = raw.lowercased()
        if lower.contains("grill")                             { return .grill }
        if lower.contains("soup")                              { return .soup }
        if lower.contains("pizza") || lower.contains("pasta") { return .pizza }
        if lower.contains("asian") || lower.contains("basil") || lower.contains("bamboo") || lower.contains("wok") { return .asian }
        if lower.contains("deli")  || lower.contains("sandwich") { return .deli }
        if lower.contains("bakery") || lower.contains("bread") || lower.contains("bakeshop") { return .bakery }
        if lower.contains("dessert") || lower.contains("cobbler") || lower.contains("ice cream") { return .desserts }
        if lower.contains("beverage") || lower.contains("drink") { return .beverages }
        if lower.contains("breakfast")                         { return .breakfast }
        if lower.contains("vegan") || lower.contains("leaf")   { return .vegan }
        if lower.contains("salad") || lower.contains("fresh")  { return .salad }
        if lower.contains("performance") || lower.contains("protein") { return .performance }
        if lower.contains("side")                              { return .sides }
        return .entrees
    }

    /// Returns date formatted as MM/dd/yyyy for the diningmenus.unt.edu query parameter.
    private func menuDateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM/dd/yyyy"
        return f.string(from: date)
    }

    private let browserUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
}

// MARK: - String Regex Helpers

private extension String {
    /// Returns the first capture group of the first match, or nil.
    func firstCapture(pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: self, range: NSRange(self.startIndex..., in: self)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: self)
        else { return nil }
        return String(self[range])
    }

    /// Returns all matches, each as an array of capture-group strings.
    func allCaptures(pattern: String, groupCount: Int) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        else { return [] }
        let range   = NSRange(self.startIndex..., in: self)
        let matches = regex.matches(in: self, range: range)
        return matches.compactMap { m -> [String]? in
            var groups: [String] = []
            for i in 1...groupCount {
                guard let r = Range(m.range(at: i), in: self) else { return nil }
                groups.append(String(self[r]))
            }
            return groups
        }
    }
}
