import Foundation
import Combine

// MARK: - Weekly Profile Service
// Tracks behavioral patterns over time to enable smarter recommendations
// and budget predictions.
//
// Tracked signals:
//   - Which dining halls the user visits (via saved meals)
//   - What time meals are saved (eating schedule)
//   - Spending patterns by day of week
//   - Late-night vs daytime eating ratio
//
// All data is derived from existing SavedMeal and SpendingEvent records —
// no new data collection is required.

@MainActor
final class WeeklyProfileService: ObservableObject {

    static let shared = WeeklyProfileService()

    @Published private(set) var profile: WeeklyProfile = .empty

    private let persistence = PersistenceService.shared

    private init() {}

    /// Recompute the weekly profile from saved meals and spending history.
    func refresh() {
        let meals = persistence.loadMeals()
        let spending = persistence.loadSpendingHistory()
        profile = WeeklyProfile.compute(meals: meals, spending: spending)
    }
}

// MARK: - Weekly Profile

struct WeeklyProfile: Equatable {

    /// Meals per day of week (0 = Sunday, 6 = Saturday).
    let mealsPerDay: [Int: Int]

    /// Average spending per day of week.
    let spendPerDay: [Int: Double]

    /// Most visited dining hall ID.
    let favoriteHallId: String?

    /// Average meal time (hour of day, e.g. 12.5 = 12:30 PM).
    let averageMealHour: Double?

    /// Fraction of meals logged after 9 PM.
    let lateNightRatio: Double

    /// The user's highest-spend day of the week (1 = Sunday … 7 = Saturday).
    let peakSpendDay: Int?

    /// Days with above-average spending.
    let highSpendDays: [Int]

    /// Pattern insights for display.
    var insights: [ProfileInsight] {
        var results: [ProfileInsight] = []

        if lateNightRatio > 0.3 {
            results.append(ProfileInsight(
                icon: "moon.fill",
                text: "You eat late at night \(Int(lateNightRatio * 100))% of the time",
                color: "8B5CF6"
            ))
        }

        if let peak = peakSpendDay {
            let dayName = Calendar.current.weekdaySymbols[peak - 1]
            results.append(ProfileInsight(
                icon: "dollarsign.circle.fill",
                text: "\(dayName) is your highest spend day",
                color: "F59E0B"
            ))
        }

        if let fav = favoriteHallId,
           let hall = DiningHall.sampleHalls.first(where: { $0.id == fav }) {
            results.append(ProfileInsight(
                icon: "star.fill",
                text: "You visit \(hall.name) most often",
                color: "00853E"
            ))
        }

        if let hour = averageMealHour {
            let h = Int(hour)
            let m = Int((hour - Double(h)) * 60)
            let period = h >= 12 ? "PM" : "AM"
            let displayH = h > 12 ? h - 12 : (h == 0 ? 12 : h)
            results.append(ProfileInsight(
                icon: "clock.fill",
                text: "Average meal time: \(displayH):\(String(format: "%02d", m)) \(period)",
                color: "3B82F6"
            ))
        }

        return results
    }

    static let empty = WeeklyProfile(
        mealsPerDay: [:],
        spendPerDay: [:],
        favoriteHallId: nil,
        averageMealHour: nil,
        lateNightRatio: 0,
        peakSpendDay: nil,
        highSpendDays: []
    )

    // MARK: - Computation

    static func compute(meals: [SavedMeal], spending: [SpendingEvent]) -> WeeklyProfile {
        let calendar = Calendar.current

        // Meals per weekday
        var mealsPerDay: [Int: Int] = [:]
        var hallCounts: [String: Int] = [:]
        var totalHour: Double = 0
        var mealCount = 0
        var lateCount = 0

        for meal in meals {
            let weekday = calendar.component(.weekday, from: meal.date)
            mealsPerDay[weekday, default: 0] += 1
            hallCounts[meal.diningHallId, default: 0] += 1

            let hour = calendar.component(.hour, from: meal.date)
            let minute = calendar.component(.minute, from: meal.date)
            totalHour += Double(hour) + Double(minute) / 60.0
            mealCount += 1

            if hour >= 21 { lateCount += 1 }
        }

        let avgHour = mealCount > 0 ? totalHour / Double(mealCount) : nil
        let lateRatio = mealCount > 0 ? Double(lateCount) / Double(mealCount) : 0
        let favHall = hallCounts.max(by: { $0.value < $1.value })?.key

        // Spending per weekday
        var spendPerDay: [Int: Double] = [:]
        var spendCounts: [Int: Int] = [:]
        for event in spending where event.amount > 0 {
            let weekday = calendar.component(.weekday, from: event.date)
            spendPerDay[weekday, default: 0] += event.amount
            spendCounts[weekday, default: 0] += 1
        }

        // Average per day
        for (day, total) in spendPerDay {
            if let count = spendCounts[day], count > 0 {
                spendPerDay[day] = total / Double(count)
            }
        }

        let peakDay = spendPerDay.max(by: { $0.value < $1.value })?.key
        let avgSpend = spendPerDay.values.isEmpty ? 0 : spendPerDay.values.reduce(0, +) / Double(spendPerDay.count)
        let highDays = spendPerDay.filter { $0.value > avgSpend * 1.2 }.map(\.key).sorted()

        return WeeklyProfile(
            mealsPerDay: mealsPerDay,
            spendPerDay: spendPerDay,
            favoriteHallId: favHall,
            averageMealHour: avgHour,
            lateNightRatio: lateRatio,
            peakSpendDay: peakDay,
            highSpendDays: highDays
        )
    }
}

// MARK: - Profile Insight

struct ProfileInsight: Identifiable, Equatable {
    let id = UUID()
    let icon: String
    let text: String
    let color: String

    static func == (lhs: ProfileInsight, rhs: ProfileInsight) -> Bool {
        lhs.icon == rhs.icon && lhs.text == rhs.text
    }
}
