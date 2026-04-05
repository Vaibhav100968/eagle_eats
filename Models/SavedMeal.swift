import SwiftUI

// MARK: - Saved Meal (History Entry)

struct SavedMeal: Identifiable, Codable {
    let id: UUID
    var date: Date
    var diningHallId: String
    var diningHallName: String
    var mealPeriod: MealPeriod
    var items: [PlateItem]
    var notes: String

    init(from plate: Plate, at hall: DiningHall, period: MealPeriod = MealPeriod.current(), notes: String = "") {
        self.id            = UUID()
        self.date          = Date()
        self.diningHallId  = hall.id
        self.diningHallName = hall.name
        self.mealPeriod    = period
        self.items         = plate.items
        self.notes         = notes
    }

    var totalCalories: Double     { items.reduce(0) { $0 + $1.totalNutrition.calories } }
    var totalProtein: Double      { items.reduce(0) { $0 + $1.totalNutrition.protein } }
    var totalCarbs: Double        { items.reduce(0) { $0 + $1.totalNutrition.carbohydrates } }
    var totalFat: Double          { items.reduce(0) { $0 + $1.totalNutrition.fat } }
    var itemCount: Int            { items.reduce(0) { $0 + $1.quantity } }

    var dateDisplay: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var dayDisplay: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    var timeDisplay: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var macroSummary: String {
        "Cal: \(Int(totalCalories))  •  P: \(Int(totalProtein))g  •  C: \(Int(totalCarbs))g  •  F: \(Int(totalFat))g"
    }

    var gradientHallColor: [Color] {
        DiningHall.sampleHalls.first { $0.id == diningHallId }?.gradientColors
            ?? [.untGreenPrimary, .untGreenDark]
    }
}

// MARK: - Meal Group (grouped by day for history display)

struct MealGroup: Identifiable {
    let id: String
    let label: String
    let date: Date
    var meals: [SavedMeal]

    var totalCalories: Double { meals.reduce(0) { $0 + $1.totalCalories } }
    var totalProtein: Double  { meals.reduce(0) { $0 + $1.totalProtein } }
    var totalCarbs: Double    { meals.reduce(0) { $0 + $1.totalCarbs } }
    var totalFat: Double      { meals.reduce(0) { $0 + $1.totalFat } }
}
