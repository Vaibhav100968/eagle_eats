import Foundation
import SwiftUI

// MARK: - Recommendation Engine
// Returns "best dining hall right now" and top menu items based on:
//   - Live menu data (DiningService)
//   - User dietary preferences (AppSettings)
//   - Macro goals & current plate state (PlateViewModel)
//   - Dining dollars balance (BudgetEngine)
//   - Time of day (MealPeriod)
//   - Favorite halls (AppState)
//
// Scoring is 0–100 per hall, computed from weighted factors.
// The engine is stateless — call recommend() whenever inputs change.

@MainActor
final class RecommendationEngine: ObservableObject {

    static let shared = RecommendationEngine()

    @Published private(set) var hallRecommendations: [HallRecommendation] = []
    @Published private(set) var topItems: [ScoredMenuItem] = []

    private let dining = DiningService.shared
    private let budget = BudgetEngine.shared

    private init() {}

    // MARK: - Scoring Weights

    private struct Weights {
        static let openNow:     Double = 25    // must be open
        static let macroMatch:  Double = 25    // alignment with macro goals
        static let dietary:     Double = 20    // matches dietary preferences
        static let variety:     Double = 10    // number of items available
        static let favorite:    Double = 10    // user has starred this hall
        static let costValue:   Double = 10    // budget-friendly signal
    }

    // MARK: - Public API

    /// Recompute recommendations. Call from HomeView.onAppear or when data changes.
    func recommend(
        settings: AppSettings,
        plate: Plate,
        favoriteIds: Set<String>
    ) {
        let period = MealPeriod.current()
        var recommendations: [HallRecommendation] = []

        for hall in dining.halls {
            let items = dining.menuItems(for: hall, period: period)
            guard !items.isEmpty else { continue }

            var score: Double = 0
            var reasons: [RecommendationReason] = []

            // 1. Open now
            if hall.isOpen {
                score += Weights.openNow
                reasons.append(.openNow)
            } else {
                // Closed halls get heavily penalized but still ranked for "coming up"
                score -= 40
            }

            // 2. Macro alignment
            let macroScore = computeMacroScore(items: items, settings: settings, plate: plate)
            score += macroScore.score * (Weights.macroMatch / 100)
            reasons.append(contentsOf: macroScore.reasons)

            // 3. Dietary match
            let dietScore = computeDietaryScore(items: items, preferences: settings.dietaryFilters)
            score += dietScore.score * (Weights.dietary / 100)
            reasons.append(contentsOf: dietScore.reasons)

            // 4. Variety
            let varietyScore = min(Double(items.count) / 20.0, 1.0) * Weights.variety
            score += varietyScore

            // 5. Favorite bonus
            if favoriteIds.contains(hall.id) {
                score += Weights.favorite
                reasons.append(.favoriteHall)
            }

            // 6. Cost efficiency (if budget data available)
            if budget.snapshot.urgency == .critical || budget.snapshot.urgency == .warning {
                // Boost halls with more low-calorie (presumably cheaper) options
                let lowCalCount = items.filter { $0.nutritionLoaded && $0.nutrition.calories < 400 }.count
                let costScore = min(Double(lowCalCount) / 5.0, 1.0) * Weights.costValue
                score += costScore
                if lowCalCount > 3 { reasons.append(.costEfficient) }
            } else {
                score += Weights.costValue * 0.5 // neutral
            }

            // Score top items for this hall
            let scoredItems = scoreItems(items, settings: settings, plate: plate)

            recommendations.append(HallRecommendation(
                id: hall.id,
                hall: hall,
                score: max(0, min(100, score)),
                reasons: reasons,
                topItems: Array(scoredItems.prefix(5))
            ))
        }

        // Sort by score descending
        hallRecommendations = recommendations.sorted { $0.score > $1.score }

        // Flatten top items across all halls
        topItems = recommendations
            .flatMap(\.topItems)
            .sorted { $0.score > $1.score }
            .prefix(10)
            .map { $0 }
    }

    // MARK: - Plate Completion Suggestions

    /// Returns items that would best fill remaining macro gaps.
    func suggestionsToCompletePlate(
        plate: Plate,
        settings: AppSettings
    ) -> [ScoredMenuItem] {
        let period = MealPeriod.current()
        var allScored: [ScoredMenuItem] = []

        let proteinGap = max(0, settings.dailyProteinGoal - plate.totalProtein)
        let carbGap    = max(0, settings.dailyCarbGoal - plate.totalCarbs)
        let fatGap     = max(0, settings.dailyFatGoal - plate.totalFat)
        let calGap     = max(0, settings.dailyCalorieGoal - plate.totalCalories)

        for hall in dining.halls where hall.isOpen {
            let items = dining.menuItems(for: hall, period: period)
            for item in items where item.nutritionLoaded && item.nutrition.isComplete {
                var score: Double = 0
                var reasons: [RecommendationReason] = []

                // Protein fill
                if proteinGap > 10 && item.nutrition.protein >= 15 {
                    let fill = min(item.nutrition.protein / proteinGap, 1.0)
                    score += fill * 40
                    reasons.append(.completesPlate(macro: "protein"))
                }

                // Carb fill
                if carbGap > 20 && item.nutrition.carbohydrates >= 20 {
                    let fill = min(item.nutrition.carbohydrates / carbGap, 1.0)
                    score += fill * 20
                }

                // Calorie budget — prefer items that don't blow past the gap
                if calGap > 0 {
                    if item.nutrition.calories <= calGap {
                        score += 20
                    } else {
                        score -= 10
                    }
                }

                // Don't recommend items already in plate
                if plate.contains(item) { score -= 30 }

                if score > 0 {
                    allScored.append(ScoredMenuItem(
                        id: item.id,
                        item: item,
                        score: max(0, min(100, score)),
                        reasons: reasons
                    ))
                }
            }
        }

        return allScored.sorted { $0.score > $1.score }.prefix(5).map { $0 }
    }

    // MARK: - Private Scoring

    private struct ScoreResult {
        let score: Double   // 0–100
        let reasons: [RecommendationReason]
    }

    private func computeMacroScore(
        items: [MenuItem],
        settings: AppSettings,
        plate: Plate
    ) -> ScoreResult {
        let loaded = items.filter { $0.nutritionLoaded && $0.nutrition.isComplete }
        guard !loaded.isEmpty else { return ScoreResult(score: 50, reasons: []) }

        let proteinGap = max(0, settings.dailyProteinGoal - plate.totalProtein)
        var reasons: [RecommendationReason] = []
        var score: Double = 50 // baseline

        // High protein items available?
        let highProtein = loaded.filter { $0.nutrition.protein >= 20 }
        if !highProtein.isEmpty && proteinGap > 15 {
            let pctMatch = min(100, Int(Double(highProtein.count) / Double(loaded.count) * 100))
            score += Double(pctMatch) * 0.3
            reasons.append(.macroMatch(macro: "Protein", percent: pctMatch))
        }

        // High protein bonus
        if highProtein.count >= 3 {
            reasons.append(.highProtein)
            score += 10
        }

        return ScoreResult(score: min(100, score), reasons: reasons)
    }

    private func computeDietaryScore(
        items: [MenuItem],
        preferences: [String]
    ) -> ScoreResult {
        guard !preferences.isEmpty else {
            return ScoreResult(score: 50, reasons: []) // no preferences = neutral
        }

        var matchCount = 0
        var matchedTags: Set<String> = []

        for item in items {
            for tag in item.dietaryTags {
                if preferences.contains(tag.id) {
                    matchCount += 1
                    matchedTags.insert(tag.label)
                }
            }
        }

        let score = min(100, Double(matchCount) * 5)
        let reasons = matchedTags.map { RecommendationReason.dietaryMatch(tag: $0) }
        return ScoreResult(score: score, reasons: Array(reasons.prefix(2)))
    }

    private func scoreItems(
        _ items: [MenuItem],
        settings: AppSettings,
        plate: Plate
    ) -> [ScoredMenuItem] {
        items.compactMap { item -> ScoredMenuItem? in
            guard item.nutritionLoaded, item.nutrition.isComplete else { return nil }

            var score: Double = 50
            var reasons: [RecommendationReason] = []

            // Protein density
            if item.nutrition.protein >= 20 {
                score += 20
                reasons.append(.highProtein)
            }

            // Dietary match
            let prefs = Set(settings.dietaryFilters)
            let tags = Set(item.dietaryTags.map(\.id))
            if !prefs.isEmpty && !prefs.isDisjoint(with: tags) {
                score += 15
                if let matched = item.dietaryTags.first(where: { prefs.contains($0.id) }) {
                    reasons.append(.dietaryMatch(tag: matched.label))
                }
            }

            // Calorie check
            let calGap = max(0, settings.dailyCalorieGoal - plate.totalCalories)
            if item.nutrition.calories <= calGap && item.nutrition.calories > 0 {
                score += 10
                reasons.append(.lowCalorie)
            }

            return ScoredMenuItem(id: item.id, item: item, score: min(100, score), reasons: reasons)
        }
        .sorted { $0.score > $1.score }
    }
}
