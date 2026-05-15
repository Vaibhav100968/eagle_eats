import Foundation

// MARK: - Menu History Service
// Tracks menus over time and detects patterns for predictions.

@MainActor
final class MenuHistoryService: ObservableObject {

    static let shared = MenuHistoryService()

    @Published var predictions: [MenuPrediction] = []
    @Published var trendingItems: [TrendingItem] = []

    private let storageKey = "eagle_eats_menu_history"
    private let maxDaysStored = 60

    private init() {
        computeTrends()
    }

    // MARK: - Record Today's Menu

    func recordMenus(_ menusByHall: [String: [MenuItem]], halls: [DiningHall]) {
        var history = loadHistory()

        let today = dateKey(Date())
        let dayOfWeek = Calendar.current.component(.weekday, from: Date())

        // Don't re-record if we already have today
        if history.contains(where: { $0.dateKey == today }) { return }

        var entries: [MenuHistoryEntry] = []
        for (hallId, items) in menusByHall {
            let hallName = halls.first(where: { $0.id == hallId })?.name ?? hallId
            for item in items {
                entries.append(MenuHistoryEntry(
                    dateKey: today,
                    dayOfWeek: dayOfWeek,
                    hallId: hallId,
                    hallName: hallName,
                    itemName: item.name,
                    recipeId: item.recipeID,
                    station: item.station,
                    mealPeriods: item.mealPeriods.map(\.rawValue)
                ))
            }
        }

        history.append(contentsOf: entries)

        // Prune old entries
        let cutoff = Calendar.current.date(byAdding: .day, value: -maxDaysStored, to: Date()) ?? Date()
        let cutoffKey = dateKey(cutoff)
        history.removeAll { $0.dateKey < cutoffKey }

        saveHistory(history)
        computeTrends()
    }

    // MARK: - Predictions

    /// Predict what might be served on a given day based on historical patterns.
    func predict(for targetDate: Date, hallId: String? = nil) -> [MenuPrediction] {
        let targetDay = Calendar.current.component(.weekday, from: targetDate)
        let history = loadHistory()

        // Group items by (hallId, itemName, dayOfWeek)
        var dayPatterns: [String: DayPattern] = [:]

        for entry in history {
            let key = "\(entry.hallId)|\(entry.itemName)|\(entry.dayOfWeek)"
            if dayPatterns[key] == nil {
                dayPatterns[key] = DayPattern(
                    hallId: entry.hallId,
                    hallName: entry.hallName,
                    itemName: entry.itemName,
                    dayOfWeek: entry.dayOfWeek,
                    occurrences: 0,
                    totalDaysTracked: 0,
                    station: entry.station
                )
            }
            dayPatterns[key]?.occurrences += 1
        }

        // Count how many distinct dates we have per hall per day-of-week
        var hallDayCounts: [String: Int] = [:]
        let uniqueDates = Set(history.map { "\($0.hallId)|\($0.dayOfWeek)|\($0.dateKey)" })
        for combo in uniqueDates {
            let parts = combo.components(separatedBy: "|")
            let hdKey = "\(parts[0])|\(parts[1])"
            hallDayCounts[hdKey, default: 0] += 1
        }

        for (key, _) in dayPatterns {
            let parts = key.components(separatedBy: "|")
            let hdKey = "\(parts[0])|\(parts[2])"
            dayPatterns[key]?.totalDaysTracked = hallDayCounts[hdKey] ?? 1
        }

        // Filter for the target day, calculate probability
        var result: [MenuPrediction] = []
        for (_, pattern) in dayPatterns where pattern.dayOfWeek == targetDay {
            if let filterHall = hallId, pattern.hallId != filterHall { continue }
            guard pattern.totalDaysTracked >= 2 else { continue }

            let probability = Double(pattern.occurrences) / Double(pattern.totalDaysTracked)
            guard probability >= 0.5 else { continue }

            result.append(MenuPrediction(
                itemName: pattern.itemName,
                hallId: pattern.hallId,
                hallName: pattern.hallName,
                station: pattern.station,
                probability: probability,
                occurrences: pattern.occurrences,
                totalSamples: pattern.totalDaysTracked
            ))
        }

        return result.sorted { $0.probability > $1.probability }
    }

    // MARK: - Trending Items

    func computeTrends() {
        let history = loadHistory()
        guard !history.isEmpty else { return }

        // Items that appear most frequently across all days
        var itemCounts: [String: (count: Int, hallName: String, hallId: String)] = [:]
        for entry in history {
            let key = entry.itemName
            if itemCounts[key] == nil {
                itemCounts[key] = (0, entry.hallName, entry.hallId)
            }
            itemCounts[key]?.count += 1
        }

        // Day-of-week frequency for each item
        var itemDayFreq: [String: [Int: Int]] = [:]
        for entry in history {
            itemDayFreq[entry.itemName, default: [:]][entry.dayOfWeek, default: 0] += 1
        }

        let calendar = Calendar.current
        let dayNames = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

        var trending: [TrendingItem] = []
        for (name, info) in itemCounts {
            let dayFreqs = itemDayFreq[name] ?? [:]
            let topDay = dayFreqs.max(by: { $0.value < $1.value })

            var pattern: String? = nil
            if let top = topDay, top.value >= 2, top.key >= 1, top.key <= 7 {
                pattern = "Often on \(dayNames[top.key])s"
            }

            let totalDates = Set(history.map(\.dateKey)).count
            let itemDates = Set(history.filter { $0.itemName == name }.map(\.dateKey)).count
            let freq = totalDates > 0 ? Double(itemDates) / Double(totalDates) : 0

            trending.append(TrendingItem(
                name: name,
                hallName: info.hallName,
                hallId: info.hallId,
                appearances: info.count,
                frequency: freq,
                pattern: pattern,
                lastSeen: history.filter { $0.itemName == name }.map(\.dateKey).max() ?? ""
            ))
        }

        trendingItems = Array(trending.sorted { $0.appearances > $1.appearances }.prefix(30))

        // Also compute predictions for tomorrow
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        predictions = predict(for: tomorrow)
    }

    // MARK: - Storage

    private func loadHistory() -> [MenuHistoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let entries = try? JSONDecoder().decode([MenuHistoryEntry].self, from: data)
        else { return [] }
        return entries
    }

    private func saveHistory(_ entries: [MenuHistoryEntry]) {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func dateKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "America/Chicago")
        return f.string(from: date)
    }
}

// MARK: - Models

struct MenuHistoryEntry: Codable {
    let dateKey: String
    let dayOfWeek: Int
    let hallId: String
    let hallName: String
    let itemName: String
    let recipeId: String
    let station: String
    let mealPeriods: [String]
}

private struct DayPattern {
    let hallId: String
    let hallName: String
    let itemName: String
    let dayOfWeek: Int
    var occurrences: Int
    var totalDaysTracked: Int
    let station: String
}

struct MenuPrediction: Identifiable {
    let id = UUID()
    let itemName: String
    let hallId: String
    let hallName: String
    let station: String
    let probability: Double
    let occurrences: Int
    let totalSamples: Int

    var confidenceLabel: String {
        if probability >= 0.9 { return "Very Likely" }
        if probability >= 0.7 { return "Likely" }
        return "Possible"
    }

    var confidenceColor: String {
        if probability >= 0.9 { return "00853E" }
        if probability >= 0.7 { return "F59E0B" }
        return "6B7280"
    }
}

struct TrendingItem: Identifiable {
    let id = UUID()
    let name: String
    let hallName: String
    let hallId: String
    let appearances: Int
    let frequency: Double
    let pattern: String?
    let lastSeen: String
}
