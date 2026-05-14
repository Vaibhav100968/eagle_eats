import SwiftUI

// MARK: - Nutrition Info

struct NutritionInfo: Codable, Hashable {
    var calories:       Double
    var protein:        Double
    var carbohydrates:  Double
    var fat:            Double
    var fiber:          Double?
    var sugar:          Double?
    var sodium:         Double?
    var servingSize:    String?
    var allergens:      [Allergen] = []
    var ingredients:    String = ""

    static let empty = NutritionInfo(calories: 0, protein: 0, carbohydrates: 0, fat: 0)

    var isComplete: Bool {
        calories > 0 || protein > 0 || carbohydrates > 0 || fat > 0
    }

    var hasAllergens: Bool { !allergens.isEmpty }
}

// MARK: - Allergen

enum Allergen: String, CaseIterable, Codable, Identifiable {
    case milk       = "Milk"
    case eggs       = "Eggs"
    case fish       = "Fish"
    case shellfish  = "Shellfish"
    case treeNuts   = "Tree Nuts"
    case peanuts    = "Peanuts"
    case wheat      = "Wheat"
    case soybeans   = "Soybeans"
    case sesame     = "Sesame"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .milk:      return "cup.and.saucer.fill"
        case .eggs:      return "oval.fill"
        case .fish:      return "fish.fill"
        case .shellfish: return "tortoise.fill"
        case .treeNuts:  return "chart.dots.scatter"
        case .peanuts:   return "leaf.circle.fill"
        case .wheat:     return "w.circle.fill"
        case .soybeans:  return "drop.circle.fill"
        case .sesame:    return "circle.grid.3x3.fill"
        }
    }

    var color: String {
        switch self {
        case .milk:      return "3B82F6"
        case .eggs:      return "F59E0B"
        case .fish:      return "06B6D4"
        case .shellfish: return "EF4444"
        case .treeNuts:  return "8B5CF6"
        case .peanuts:   return "D97706"
        case .wheat:     return "D4A574"
        case .soybeans:  return "10B981"
        case .sesame:    return "6B7280"
        }
    }

    static func from(string: String) -> Allergen? {
        let lower = string.lowercased().trimmingCharacters(in: .whitespaces)
        switch lower {
        case "milk", "dairy":                         return .milk
        case "eggs", "egg":                           return .eggs
        case "fish":                                  return .fish
        case "shellfish", "crustacean shellfish":      return .shellfish
        case "tree nuts", "tree_nuts", "tree nut":     return .treeNuts
        case "peanuts", "peanut":                     return .peanuts
        case "wheat", "gluten":                       return .wheat
        case "soybeans", "soybean", "soy":            return .soybeans
        case "sesame":                                return .sesame
        default:                                      return nil
        }
    }
}

// MARK: - Dietary Tags

struct DietaryTag: Identifiable, Codable, Hashable {
    let id: String
    let label: String
    let color: String
    let icon: String

    static let vegan        = DietaryTag(id: "vegan",        label: "Vegan",        color: "00853E", icon: "leaf.fill")
    static let vegetarian   = DietaryTag(id: "vegetarian",   label: "Vegetarian",   color: "27AE60", icon: "leaf")
    static let glutenFree   = DietaryTag(id: "gluten-free",  label: "Gluten Free",  color: "3B82F6", icon: "checkmark.seal.fill")
    static let dairyFree    = DietaryTag(id: "dairy-free",   label: "Dairy Free",   color: "8B5CF6", icon: "drop.fill")
    static let highProtein  = DietaryTag(id: "high-protein", label: "High Protein", color: "EF4444", icon: "bolt.fill")
    static let halal        = DietaryTag(id: "halal",        label: "Halal",        color: "F59E0B", icon: "checkmark.circle.fill")
}

// MARK: - Menu Category

enum MenuCategory: String, CaseIterable, Codable {
    case grill          = "Grill"
    case soup           = "Soup & Salad"
    case pizza          = "Pizza & Pasta"
    case asian          = "Asian Station"
    case deli           = "Deli"
    case bakery         = "Bakery"
    case sides          = "Sides"
    case desserts       = "Desserts"
    case beverages      = "Beverages"
    case breakfast      = "Breakfast"
    case vegan          = "Vegan"
    case performance    = "Performance"
    case allergenFree   = "Allergen-Free"
    case entrees        = "Entrées"
    case salad          = "Salad Bar"
    case fruits         = "Fruits & Yogurt"
    case other          = "Other"

    var icon: String {
        switch self {
        case .grill:        return "flame.fill"
        case .soup:         return "drop.fill"
        case .pizza:        return "circle.grid.2x2.fill"
        case .asian:        return "bowl.fill"
        case .deli:         return "bag.fill"
        case .bakery:       return "birthday.cake.fill"
        case .sides:        return "takeoutbag.and.cup.and.straw.fill"
        case .desserts:     return "birthday.cake"
        case .beverages:    return "cup.and.saucer.fill"
        case .breakfast:    return "sun.horizon.fill"
        case .vegan:        return "leaf.fill"
        case .performance:  return "bolt.fill"
        case .allergenFree: return "checkmark.seal.fill"
        case .entrees:      return "fork.knife"
        case .salad:        return "leaf"
        case .fruits:       return "apple.logo"
        case .other:        return "square.grid.2x2"
        }
    }
}

// MARK: - Menu Item

struct MenuItem: Identifiable, Codable, Hashable {
    /// Unique key: "\(diningHallId)-\(recipeID)" — stable across fetches for the same hall
    let id: String
    /// Numeric ID from diningmenus.unt.edu (e.g. "460007") — used for nutrition label lookup
    let recipeID: String
    let name: String
    /// Ingredients text, populated after a nutrition label fetch (label.aspx?recipeNum=)
    var description: String
    let category: MenuCategory
    /// Raw panel heading from the dining hall page, e.g. "Bamboo Basil", "Avenue A Homestyle".
    /// Used as the section header in the menu list view.
    /// Defaults to "" for backwards Codable compatibility with saved PlateItems.
    var station: String = ""
    /// All nutrition values. Starts at .empty; populated lazily via fetchNutrition()
    var nutrition: NutritionInfo
    /// True once a successful nutrition label fetch has completed for this item
    var nutritionLoaded: Bool = false
    let dietaryTags: [DietaryTag]
    let mealPeriods: [MealPeriod]
    let diningHallId: String
    var isPopular: Bool = false

    var primaryDietaryTag: DietaryTag? { dietaryTags.first }

    var caloriesDisplay: String {
        guard nutritionLoaded else { return "—" }
        return "\(Int(nutrition.calories)) cal"
    }

    var macroSummary: String {
        guard nutritionLoaded else { return "Tap for nutrition info" }
        guard nutrition.isComplete else { return "Nutrition info unavailable" }
        return "P: \(Int(nutrition.protein))g  C: \(Int(nutrition.carbohydrates))g  F: \(Int(nutrition.fat))g"
    }
}

// MARK: - Sample Menu Data
// sampleItems is intentionally empty.
// All real menu data is loaded from diningmenus.unt.edu at runtime.
// Do NOT populate this with fake data — the app shows a proper
// empty/error state when live data is unavailable.

extension MenuItem {
    static let sampleItems: [MenuItem] = []
}
