import Foundation

// MARK: - Habit Engine
// Detects behavioral patterns from meal history and spending data.
// Runs on-device — no backend needed.
//
// Patterns detected:
//   - Late-night eating frequency
//   - Day-of-week spending spikes
//   - Protein under-consumption trends
//   - Hall loyalty patterns
//   - Meal timing consistency

@MainActor
final class HabitEngine: ObservableObject {

    static let shared = HabitEngine()

    @Published private(set) var insights: [HabitInsight] = []

    private let persistence = PersistenceService.shared

    private init() {}

    // MARK: - Analyze

    func analyze() {
        var detected: [HabitInsight] = []
        let meals = persistence.loadMeals()
        let spending = persistence.loadSpendingHistory()

        if meals.count < 3 {
            insights = [HabitInsight(
                icon: "chart.bar.doc.horizontal",
                title: "Building your profile",
                description: "Log a few more meals to unlock personalized insights",
                category: .info
            )]
            return
        }

        // 1. Late-night eating
        detectLateNight(meals: meals, into: &detected)

        // 2. Day-of-week spending
        detectDaySpikes(spending: spending, into: &detected)

        // 3. Protein trends
        detectProteinTrend(meals: meals, into: &detected)

        // 4. Hall loyalty
        detectHallLoyalty(meals: meals, into: &detected)

        // 5. Meal timing
        detectMealTiming(meals: meals, into: &detected)

        // 6. Calorie trends
        detectCalorieTrend(meals: meals, into: &detected)

        insights = detected.isEmpty
            ? [HabitInsight(icon: "checkmark.circle", title: "Looking good",
                           description: "Your dining patterns are balanced", category: .positive)]
            : detected
    }

    // MARK: - Detectors

    private func detectLateNight(meals: [SavedMeal], into results: inout [HabitInsight]) {
        let recent = mealsInLast(days: 14, from: meals)
        let lateNight = recent.filter { $0.mealPeriod == .lateNight }
        let ratio = recent.isEmpty ? 0 : Double(lateNight.count) / Double(recent.count)

        if lateNight.count >= 3 && ratio > 0.25 {
            results.append(HabitInsight(
                icon: "moon.fill",
                title: "Frequent late-night meals",
                description: "\(lateNight.count) of your last \(recent.count) meals were after 9 PM",
                category: .warning
            ))
        }
    }

    private func detectDaySpikes(spending: [SpendingEvent], into results: inout [HabitInsight]) {
        let recent = spending.filter {
            $0.amount > 0 &&
            $0.date > Calendar.current.date(byAdding: .day, value: -28, to: Date())!
        }
        guard recent.count >= 5 else { return }

        var byDay: [Int: Double] = [:]
        for event in recent {
            let day = Calendar.current.component(.weekday, from: event.date)
            byDay[day, default: 0] += event.amount
        }

        let avg = byDay.values.reduce(0, +) / max(1, Double(byDay.count))
        let dayNames = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

        for (day, total) in byDay where total > avg * 1.5 && avg > 0 {
            let multiplier = total / avg
            results.append(HabitInsight(
                icon: "calendar.badge.exclamationmark",
                title: "High spending on \(dayNames[day])s",
                description: String(format: "You spend %.1fx more than average on \(dayNames[day])s", multiplier),
                category: .warning
            ))
        }
    }

    private func detectProteinTrend(meals: [SavedMeal], into results: inout [HabitInsight]) {
        let recent = mealsInLast(days: 7, from: meals)
        guard recent.count >= 3 else { return }

        let avgProtein = recent.reduce(0) { $0 + $1.totalProtein } / Double(recent.count)
        let goal = AppState.shared.settings.dailyProteinGoal

        if avgProtein < goal * 0.6 && goal > 0 {
            results.append(HabitInsight(
                icon: "bolt.trianglebadge.exclamationmark",
                title: "Low protein intake",
                description: String(format: "Averaging %.0fg per meal vs %.0fg goal", avgProtein, goal),
                category: .warning
            ))
        } else if avgProtein >= goal * 0.85 {
            results.append(HabitInsight(
                icon: "bolt.fill",
                title: "Strong protein intake",
                description: String(format: "Averaging %.0fg per meal — on target", avgProtein),
                category: .positive
            ))
        }
    }

    private func detectHallLoyalty(meals: [SavedMeal], into results: inout [HabitInsight]) {
        let recent = mealsInLast(days: 14, from: meals)
        guard recent.count >= 5 else { return }

        var counts: [String: Int] = [:]
        for meal in recent {
            counts[meal.diningHallName, default: 0] += 1
        }

        if let (name, count) = counts.max(by: { $0.value < $1.value }),
           Double(count) / Double(recent.count) > 0.6 {
            results.append(HabitInsight(
                icon: "building.2.fill",
                title: "Hall loyalty: \(name)",
                description: "\(count) of \(recent.count) recent meals — try other halls for variety",
                category: .info
            ))
        }
    }

    private func detectMealTiming(meals: [SavedMeal], into results: inout [HabitInsight]) {
        let recent = mealsInLast(days: 7, from: meals)
        guard recent.count >= 4 else { return }

        let skippedBreakfast = recent.allSatisfy { $0.mealPeriod != .breakfast }
        if skippedBreakfast {
            results.append(HabitInsight(
                icon: "sun.horizon",
                title: "No breakfast logged this week",
                description: "Starting your day with a meal can improve focus and energy",
                category: .info
            ))
        }
    }

    private func detectCalorieTrend(meals: [SavedMeal], into results: inout [HabitInsight]) {
        let recent = mealsInLast(days: 7, from: meals)
        guard recent.count >= 3 else { return }

        let avgCal = recent.reduce(0) { $0 + $1.totalCalories } / Double(recent.count)
        let goal = AppState.shared.settings.dailyCalorieGoal

        if avgCal > goal * 1.3 && goal > 0 {
            results.append(HabitInsight(
                icon: "flame",
                title: "Above calorie target",
                description: String(format: "Averaging %.0f cal/meal vs %.0f goal", avgCal, goal),
                category: .warning
            ))
        }
    }

    // MARK: - Helpers

    private func mealsInLast(days: Int, from meals: [SavedMeal]) -> [SavedMeal] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return meals.filter { $0.date >= cutoff }
    }
}

// MARK: - Habit Insight

struct HabitInsight: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let category: InsightCategory
}

enum InsightCategory {
    case positive, info, warning

    var tint: String {
        switch self {
        case .positive: return "34C759"
        case .info:     return "3B82F6"
        case .warning:  return "FF9500"
        }
    }
}
