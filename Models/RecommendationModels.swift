import SwiftUI

// MARK: - Recommendation Models
// Data structures for the dining hall recommendation engine.
// Scores halls and items based on macros, preferences, cost, and time.

/// A scored dining hall recommendation.
struct HallRecommendation: Identifiable {
    let id: String          // hall.id
    let hall: DiningHall
    let score: Double       // 0–100 composite score
    let reasons: [RecommendationReason]
    let topItems: [ScoredMenuItem]

    /// Primary reason for recommendation (highest weight).
    var headline: String {
        reasons.first?.displayText ?? "Available now"
    }
}

/// A scored menu item within a recommendation.
struct ScoredMenuItem: Identifiable {
    let id: String          // menuItem.id
    let item: MenuItem
    let score: Double       // 0–100
    let reasons: [RecommendationReason]
}

/// Why something was recommended.
enum RecommendationReason: Equatable {
    case macroMatch(macro: String, percent: Int)
    case dietaryMatch(tag: String)
    case costEfficient
    case openNow
    case highProtein
    case lowCalorie
    case favoriteHall
    case completesPlate(macro: String)
    case lowCrowd
    case nearYou(minutes: Int)
    case highVariety(count: Int)

    var displayText: String {
        switch self {
        case .macroMatch(let macro, let pct):   return "\(pct)% \(macro) match"
        case .dietaryMatch(let tag):            return "\(tag) options"
        case .costEfficient:                    return "Best value"
        case .openNow:                          return "Open now"
        case .highProtein:                      return "High protein"
        case .lowCalorie:                       return "Lower calorie"
        case .favoriteHall:                     return "Your favorite"
        case .completesPlate(let macro):        return "Completes \(macro)"
        case .lowCrowd:                         return "Low crowd"
        case .nearYou(let min):                 return "\(min) min away"
        case .highVariety(let count):           return "\(count) options"
        }
    }

    var explanationText: String {
        switch self {
        case .macroMatch(let macro, let pct):   return "Has items matching \(pct)% of your \(macro.lowercased()) goal"
        case .dietaryMatch(let tag):            return "\(tag) options are available on today's menu"
        case .costEfficient:                    return "Best value for your dining dollars right now"
        case .openNow:                          return "Currently serving \(MealPeriod.current().rawValue.lowercased())"
        case .highProtein:                      return "Multiple high-protein items (20g+) on the menu"
        case .lowCalorie:                       return "Options that fit within your remaining calorie budget"
        case .favoriteHall:                     return "One of your starred dining halls"
        case .completesPlate(let macro):        return "Items here can fill your remaining \(macro.lowercased()) gap"
        case .lowCrowd:                         return "Currently low crowd — short wait times expected"
        case .nearYou(let min):                 return "About \(min) minutes walking from your location"
        case .highVariety(let count):           return "\(count) menu items to choose from right now"
        }
    }

    var icon: String {
        switch self {
        case .macroMatch:       return "chart.pie.fill"
        case .dietaryMatch:     return "leaf.fill"
        case .costEfficient:    return "dollarsign.circle.fill"
        case .openNow:          return "clock.fill"
        case .highProtein:      return "bolt.fill"
        case .lowCalorie:       return "scalemass.fill"
        case .favoriteHall:     return "star.fill"
        case .completesPlate:   return "plus.circle.fill"
        case .lowCrowd:         return "person"
        case .nearYou:          return "figure.walk"
        case .highVariety:      return "square.grid.2x2"
        }
    }

    var color: Color {
        switch self {
        case .macroMatch:       return .macroProtein
        case .dietaryMatch:     return .untGreenPrimary
        case .costEfficient:    return .macroCarbs
        case .openNow:          return .statusOpen
        case .highProtein:      return .macroCalories
        case .lowCalorie:       return .macroFiber
        case .favoriteHall:     return .macroFat
        case .completesPlate:   return .untGreenMedium
        case .lowCrowd:         return Color(hex: "34C759")
        case .nearYou:          return .macroCarbs
        case .highVariety:      return .untGreenPrimary
        }
    }
}

// MARK: - Recommendation Explanation

struct RecommendationExplanation {
    let reasons: [String]
    let tradeoffs: [String]
}

// MARK: - Filter Models

/// Active menu filters applied in DiningHallDetailView.
struct MenuFilter: Equatable {
    var dietaryTags: Set<String> = []       // "vegan", "vegetarian", etc.
    var allergenExclusions: Set<String> = [] // Allergen rawValues to hide
    var maxCalories: Double? = nil           // upper calorie bound per item
    var minProtein: Double? = nil            // minimum protein per item
    var searchText: String = ""

    var isActive: Bool {
        !dietaryTags.isEmpty || !allergenExclusions.isEmpty || maxCalories != nil || minProtein != nil
    }

    func matches(_ item: MenuItem) -> Bool {
        // Dietary tag filter
        if !dietaryTags.isEmpty {
            let itemTags = Set(item.dietaryTags.map(\.id))
            if dietaryTags.isDisjoint(with: itemTags) { return false }
        }

        // Allergen exclusion: hide items containing any of the user's flagged allergens
        if !allergenExclusions.isEmpty && item.nutritionLoaded {
            let itemAllergens = Set(item.nutrition.allergens.map(\.rawValue))
            if !allergenExclusions.isDisjoint(with: itemAllergens) { return false }
        }

        // Calorie ceiling
        if let max = maxCalories, item.nutritionLoaded, item.nutrition.calories > max {
            return false
        }

        // Protein floor
        if let min = minProtein, item.nutritionLoaded, item.nutrition.protein < min {
            return false
        }

        // Text search
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            if !item.name.lowercased().contains(q) &&
               !item.description.lowercased().contains(q) {
                return false
            }
        }

        return true
    }
}

// MARK: - Availability Report (Crowdsourced)

/// A user-submitted availability flag for a menu item.
struct AvailabilityReport: Identifiable, Codable {
    let id: UUID
    let menuItemId: String
    let date: Date
    let isAvailable: Bool
    let reporterId: String      // anonymous device ID

    init(menuItemId: String, isAvailable: Bool, reporterId: String = UUID().uuidString) {
        self.id = UUID()
        self.menuItemId = menuItemId
        self.date = Date()
        self.isAvailable = isAvailable
        self.reporterId = reporterId
    }
}

/// Aggregated availability status for a menu item.
struct AvailabilityStatus {
    let menuItemId: String
    let reportsToday: Int
    let availableCount: Int
    let unavailableCount: Int

    var confidence: Double {
        guard reportsToday > 0 else { return 0 }
        return Double(max(availableCount, unavailableCount)) / Double(reportsToday)
    }

    var isLikelyAvailable: Bool {
        availableCount >= unavailableCount
    }

    var shouldFlag: Bool {
        unavailableCount >= 2 && !isLikelyAvailable
    }
}
