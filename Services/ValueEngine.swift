import Foundation

// MARK: - Value Engine
// Computes dining dollar efficiency metrics:
//   - calories per dollar
//   - protein per dollar
//   - best $X meal combinations
//
// Uses menu items with loaded nutrition data to rank
// the most cost-effective options currently available.
//
// Assumption: all-you-can-eat halls cost ~1 swipe (~$8-12 equivalent),
// retail items vary. Since exact prices aren't scraped, we use swipe
// equivalents and estimated retail pricing based on category.

@MainActor
final class ValueEngine: ObservableObject {

    static let shared = ValueEngine()

    @Published private(set) var bestValueItems: [ValuedItem] = []
    @Published private(set) var bestProteinPerDollar: [ValuedItem] = []
    @Published private(set) var summary: ValueSummary = .empty

    private let dining = DiningService.shared
    private let budget = BudgetEngine.shared

    private init() {}

    // MARK: - Estimated cost per meal at each hall type

    private func estimatedCost(hallId: String) -> Double {
        switch hallId {
        case "bruceteria", "eagle-landing", "kitchen-west", "mean-greens":
            return 9.50  // all-you-care-to-eat swipe equivalent
        case "champs":
            return 10.00
        default:
            return 9.50
        }
    }

    // MARK: - Compute

    func evaluate() {
        let period = MealPeriod.current()
        var allValued: [ValuedItem] = []

        for hall in dining.halls where hall.isOpen {
            let items = dining.menuItems(for: hall, period: period)
            let costPerItem = estimatedCost(hallId: hall.id) / max(1, Double(items.count))

            for item in items where item.nutritionLoaded && item.nutrition.isComplete {
                let estimatedPrice = max(1.0, costPerItem * 2)
                let calPerDollar = item.nutrition.calories / estimatedPrice
                let protPerDollar = item.nutrition.protein / estimatedPrice

                allValued.append(ValuedItem(
                    item: item,
                    hallId: hall.id,
                    hallName: hall.name,
                    estimatedPrice: estimatedPrice,
                    caloriesPerDollar: calPerDollar,
                    proteinPerDollar: protPerDollar
                ))
            }
        }

        bestValueItems = allValued
            .sorted { $0.caloriesPerDollar > $1.caloriesPerDollar }
            .prefix(8)
            .map { $0 }

        bestProteinPerDollar = allValued
            .sorted { $0.proteinPerDollar > $1.proteinPerDollar }
            .prefix(8)
            .map { $0 }

        // Summary
        let avgCalPerDollar = allValued.isEmpty ? 0 :
            allValued.reduce(0) { $0 + $1.caloriesPerDollar } / Double(allValued.count)
        let avgProtPerDollar = allValued.isEmpty ? 0 :
            allValued.reduce(0) { $0 + $1.proteinPerDollar } / Double(allValued.count)

        let bestHall: String?
        if !allValued.isEmpty {
            var hallScores: [String: Double] = [:]
            for v in allValued {
                hallScores[v.hallName, default: 0] += v.caloriesPerDollar
            }
            bestHall = hallScores.max(by: { $0.value < $1.value })?.key
        } else {
            bestHall = nil
        }

        summary = ValueSummary(
            avgCaloriesPerDollar: avgCalPerDollar,
            avgProteinPerDollar: avgProtPerDollar,
            bestValueHall: bestHall,
            totalItemsAnalyzed: allValued.count
        )
    }
}

// MARK: - Valued Item

struct ValuedItem: Identifiable {
    var id: String { item.id }
    let item: MenuItem
    let hallId: String
    let hallName: String
    let estimatedPrice: Double
    let caloriesPerDollar: Double
    let proteinPerDollar: Double
}

// MARK: - Value Summary

struct ValueSummary {
    let avgCaloriesPerDollar: Double
    let avgProteinPerDollar: Double
    let bestValueHall: String?
    let totalItemsAnalyzed: Int

    static let empty = ValueSummary(
        avgCaloriesPerDollar: 0,
        avgProteinPerDollar: 0,
        bestValueHall: nil,
        totalItemsAnalyzed: 0
    )
}
