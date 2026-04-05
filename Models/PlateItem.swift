import SwiftUI

// MARK: - Plate Item

struct PlateItem: Identifiable, Codable, Hashable {
    let id: UUID
    var menuItem: MenuItem
    var quantity: Int

    init(menuItem: MenuItem, quantity: Int = 1) {
        self.id = UUID()
        self.menuItem = menuItem
        self.quantity = quantity
    }

    /// Returns the stored per-serving nutrition (without quantity scaling).
    /// Views should call totalNutrition(scaledBy:) and pass DiningService.shared.nutritionCache
    /// so the plate always reflects the most recently fetched values.
    var storedNutrition: NutritionInfo { menuItem.nutrition }

    /// Compute quantity-scaled nutrition, preferring live cache over stored snapshot.
    func totalNutrition(cache: [String: NutritionInfo]) -> NutritionInfo {
        let n = cache[menuItem.recipeID] ?? menuItem.nutrition
        return NutritionInfo(
            calories:      n.calories      * Double(quantity),
            protein:       n.protein       * Double(quantity),
            carbohydrates: n.carbohydrates * Double(quantity),
            fat:           n.fat           * Double(quantity),
            fiber:         (n.fiber  ?? 0) * Double(quantity),
            sugar:         (n.sugar  ?? 0) * Double(quantity),
            sodium:        (n.sodium ?? 0) * Double(quantity),
            servingSize:   n.servingSize
        )
    }

    /// Backwards-compat property used by SavedMeal (reads stored snapshot at save time).
    var totalNutrition: NutritionInfo {
        totalNutrition(cache: [:])
    }
}

// MARK: - Plate (assembled collection)

struct Plate: Codable {
    var items: [PlateItem] = []

    // ── Stored totals (uses snapshot nutrition; used when saving a meal) ──
    var totalCalories: Double     { items.reduce(0) { $0 + $1.totalNutrition.calories } }
    var totalProtein: Double      { items.reduce(0) { $0 + $1.totalNutrition.protein } }
    var totalCarbs: Double        { items.reduce(0) { $0 + $1.totalNutrition.carbohydrates } }
    var totalFat: Double          { items.reduce(0) { $0 + $1.totalNutrition.fat } }
    var totalFiber: Double        { items.reduce(0) { $0 + ($1.totalNutrition.fiber ?? 0) } }
    var totalSodium: Double       { items.reduce(0) { $0 + ($1.totalNutrition.sodium ?? 0) } }
    var isEmpty: Bool             { items.isEmpty }
    var itemCount: Int            { items.reduce(0) { $0 + $1.quantity } }

    // ── Live totals (pass DiningService.shared.nutritionCache for accuracy) ──
    func liveCalories(cache: [String: NutritionInfo])     -> Double { items.reduce(0) { $0 + $1.totalNutrition(cache: cache).calories } }
    func liveProtein(cache: [String: NutritionInfo])      -> Double { items.reduce(0) { $0 + $1.totalNutrition(cache: cache).protein } }
    func liveCarbs(cache: [String: NutritionInfo])        -> Double { items.reduce(0) { $0 + $1.totalNutrition(cache: cache).carbohydrates } }
    func liveFat(cache: [String: NutritionInfo])          -> Double { items.reduce(0) { $0 + $1.totalNutrition(cache: cache).fat } }

    var macroSummary: NutritionInfo {
        NutritionInfo(
            calories: totalCalories,
            protein: totalProtein,
            carbohydrates: totalCarbs,
            fat: totalFat,
            fiber: totalFiber,
            sodium: totalSodium
        )
    }

    /// Back-patch nutrition in all matching plate entries after an async fetch.
    /// Called by PlateViewModel after DiningService.fetchNutrition completes.
    mutating func applyNutrition(recipeID: String, nutrition: NutritionInfo) {
        for i in items.indices where items[i].menuItem.recipeID == recipeID {
            items[i].menuItem.nutrition       = nutrition
            items[i].menuItem.nutritionLoaded = true
        }
    }

    mutating func add(_ item: MenuItem) {
        if let index = items.firstIndex(where: { $0.menuItem.id == item.id }) {
            items[index].quantity += 1
        } else {
            items.append(PlateItem(menuItem: item, quantity: 1))
        }
    }

    mutating func remove(_ item: MenuItem) {
        if let index = items.firstIndex(where: { $0.menuItem.id == item.id }) {
            if items[index].quantity > 1 {
                items[index].quantity -= 1
            } else {
                items.remove(at: index)
            }
        }
    }

    mutating func removeAll(_ item: MenuItem) {
        items.removeAll { $0.menuItem.id == item.id }
    }

    mutating func clear() {
        items.removeAll()
    }

    func contains(_ item: MenuItem) -> Bool {
        items.contains { $0.menuItem.id == item.id }
    }

    func quantity(of item: MenuItem) -> Int {
        items.first { $0.menuItem.id == item.id }?.quantity ?? 0
    }
}
