import Foundation

// MARK: - Analytics Engine
// Aggregates app-wide usage data into structured summaries suitable for
// pitching to UNT Dining Services. All data is local-only — no network
// transmission occurs unless explicitly exported by the user.
//
// Aggregate signals:
//   - Popular items (most added to plate)
//   - Peak dining times
//   - Spending trends (weekly averages)
//   - Hall usage distribution
//   - Dietary preference distribution

@MainActor
final class AnalyticsEngine: ObservableObject {

    static let shared = AnalyticsEngine()

    @Published private(set) var report: AnalyticsReport = .empty

    private let persistence = PersistenceService.shared

    private init() {}

    /// Rebuild the analytics report from all stored data.
    func refresh() {
        let meals = persistence.loadMeals()
        let spending = persistence.loadSpendingHistory()
        report = AnalyticsReport.build(meals: meals, spending: spending)
    }

    /// Export the report as a JSON string for external use.
    func exportJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(report) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Analytics Report

struct AnalyticsReport: Codable {

    let generatedAt: Date

    // Popular items: (itemName, hallName, addCount)
    let popularItems: [PopularItem]

    // Peak hours: hour → meal count
    let peakHours: [Int: Int]

    // Hall usage: hallId → visit count
    let hallUsage: [String: Int]

    // Weekly spend averages (last 4 weeks)
    let weeklySpendAverages: [WeeklySpend]

    // Total stats
    let totalMealsLogged: Int
    let totalCaloriesTracked: Double
    let totalProteinTracked: Double
    let averageCaloriesPerMeal: Double

    static let empty = AnalyticsReport(
        generatedAt: Date(),
        popularItems: [],
        peakHours: [:],
        hallUsage: [:],
        weeklySpendAverages: [],
        totalMealsLogged: 0,
        totalCaloriesTracked: 0,
        totalProteinTracked: 0,
        averageCaloriesPerMeal: 0
    )

    static func build(meals: [SavedMeal], spending: [SpendingEvent]) -> AnalyticsReport {
        let calendar = Calendar.current

        // Popular items
        var itemCounts: [String: (name: String, hall: String, count: Int)] = [:]
        for meal in meals {
            for plateItem in meal.items {
                let key = plateItem.menuItem.id
                if var existing = itemCounts[key] {
                    existing.count += plateItem.quantity
                    itemCounts[key] = existing
                } else {
                    itemCounts[key] = (
                        name: plateItem.menuItem.name,
                        hall: meal.diningHallName,
                        count: plateItem.quantity
                    )
                }
            }
        }
        let popular = itemCounts.values
            .sorted { $0.count > $1.count }
            .prefix(15)
            .map { PopularItem(name: $0.name, diningHall: $0.hall, addCount: $0.count) }

        // Peak hours
        var hourCounts: [Int: Int] = [:]
        for meal in meals {
            let hour = calendar.component(.hour, from: meal.date)
            hourCounts[hour, default: 0] += 1
        }

        // Hall usage
        var hallCounts: [String: Int] = [:]
        for meal in meals {
            hallCounts[meal.diningHallId, default: 0] += 1
        }

        // Weekly spending averages (group by ISO week)
        var weeklyTotals: [String: Double] = [:]
        for event in spending where event.amount > 0 {
            let weekOfYear = calendar.component(.weekOfYear, from: event.date)
            let year = calendar.component(.yearForWeekOfYear, from: event.date)
            let key = "\(year)-W\(weekOfYear)"
            weeklyTotals[key, default: 0] += event.amount
        }
        let weeklyAverages = weeklyTotals
            .sorted { $0.key > $1.key }
            .prefix(8)
            .map { WeeklySpend(weekLabel: $0.key, totalSpent: $0.value) }

        // Totals
        let totalCals = meals.reduce(0.0) { $0 + $1.totalCalories }
        let totalProt = meals.reduce(0.0) { $0 + $1.totalProtein }
        let avgCals   = meals.isEmpty ? 0 : totalCals / Double(meals.count)

        return AnalyticsReport(
            generatedAt: Date(),
            popularItems: Array(popular),
            peakHours: hourCounts,
            hallUsage: hallCounts,
            weeklySpendAverages: weeklyAverages,
            totalMealsLogged: meals.count,
            totalCaloriesTracked: totalCals,
            totalProteinTracked: totalProt,
            averageCaloriesPerMeal: avgCals
        )
    }
}

// MARK: - Supporting Types

struct PopularItem: Codable, Identifiable {
    var id: String { name + diningHall }
    let name: String
    let diningHall: String
    let addCount: Int
}

struct WeeklySpend: Codable, Identifiable {
    var id: String { weekLabel }
    let weekLabel: String
    let totalSpent: Double
}
