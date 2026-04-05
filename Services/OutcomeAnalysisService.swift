import Foundation

// MARK: - Outcome Analysis Service
// Correlates meal content with self-reported outcomes (energy, fullness, discomfort).
// Runs entirely on-device from persisted MealOutcome data.
//
// Detects patterns like:
//   - "Meals from Mean Greens correlate with higher energy"
//   - "High-fat meals correlate with discomfort"
//   - "Protein-rich meals improve your fullness ratings"

@MainActor
final class OutcomeAnalysisService: ObservableObject {

    static let shared = OutcomeAnalysisService()

    @Published private(set) var correlations: [OutcomeCorrelation] = []

    private let persistence = PersistenceService.shared
    private let outcomeKey = "eagle_eats_meal_outcomes"

    private var outcomes: [String: MealOutcome] = [:]

    private init() {
        loadOutcomes()
    }

    // MARK: - Storage

    func record(outcome: MealOutcome, for mealId: UUID) {
        outcomes[mealId.uuidString] = outcome
        saveOutcomes()
        analyze()
    }

    func outcome(for mealId: UUID) -> MealOutcome? {
        outcomes[mealId.uuidString]
    }

    private func loadOutcomes() {
        guard let data = UserDefaults.standard.data(forKey: outcomeKey),
              let decoded = try? JSONDecoder().decode([String: MealOutcome].self, from: data)
        else { return }
        outcomes = decoded
    }

    private func saveOutcomes() {
        if let data = try? JSONEncoder().encode(outcomes) {
            UserDefaults.standard.set(data, forKey: outcomeKey)
        }
    }

    // MARK: - Analysis

    func analyze() {
        let meals = persistence.loadMeals()
        guard outcomes.count >= 3 else {
            correlations = []
            return
        }

        var detected: [OutcomeCorrelation] = []

        // 1. Hall → Energy correlation
        detectHallCorrelation(meals: meals, into: &detected)

        // 2. Macro → Outcome correlations
        detectMacroCorrelation(meals: meals, into: &detected)

        // 3. Meal period → Energy
        detectPeriodCorrelation(meals: meals, into: &detected)

        correlations = detected
    }

    // MARK: - Detectors

    private func detectHallCorrelation(meals: [SavedMeal], into results: inout [OutcomeCorrelation]) {
        var hallEnergy: [String: [Int]] = [:]

        for meal in meals {
            guard let outcome = outcomes[meal.id.uuidString] else { continue }
            hallEnergy[meal.diningHallName, default: []].append(outcome.energy)
        }

        for (hall, energies) in hallEnergy where energies.count >= 2 {
            let avg = Double(energies.reduce(0, +)) / Double(energies.count)
            if avg >= 4.0 {
                results.append(OutcomeCorrelation(
                    icon: "bolt.fill",
                    title: "High energy from \(hall)",
                    description: String(format: "Average energy rating: %.1f/5 across %d meals", avg, energies.count),
                    category: .positive
                ))
            } else if avg <= 2.5 {
                results.append(OutcomeCorrelation(
                    icon: "battery.25percent",
                    title: "Low energy after \(hall)",
                    description: String(format: "Average energy rating: %.1f/5 — try different options", avg),
                    category: .warning
                ))
            }
        }
    }

    private func detectMacroCorrelation(meals: [SavedMeal], into results: inout [OutcomeCorrelation]) {
        var highProteinEnergy: [Int] = []
        var highFatDiscomfort: [Int] = []

        for meal in meals {
            guard let outcome = outcomes[meal.id.uuidString] else { continue }

            if meal.totalProtein > 30 {
                highProteinEnergy.append(outcome.energy)
            }
            if meal.totalFat > 40 {
                highFatDiscomfort.append(outcome.discomfort)
            }
        }

        if highProteinEnergy.count >= 2 {
            let avg = Double(highProteinEnergy.reduce(0, +)) / Double(highProteinEnergy.count)
            if avg >= 3.5 {
                results.append(OutcomeCorrelation(
                    icon: "bolt.circle.fill",
                    title: "Protein boosts your energy",
                    description: String(format: "High-protein meals average %.1f/5 energy", avg),
                    category: .positive
                ))
            }
        }

        if highFatDiscomfort.count >= 2 {
            let avg = Double(highFatDiscomfort.reduce(0, +)) / Double(highFatDiscomfort.count)
            if avg >= 3.0 {
                results.append(OutcomeCorrelation(
                    icon: "exclamationmark.triangle",
                    title: "High-fat meals cause discomfort",
                    description: String(format: "Discomfort averages %.1f/5 after high-fat meals", avg),
                    category: .warning
                ))
            }
        }
    }

    private func detectPeriodCorrelation(meals: [SavedMeal], into results: inout [OutcomeCorrelation]) {
        var periodEnergy: [MealPeriod: [Int]] = [:]

        for meal in meals {
            guard let outcome = outcomes[meal.id.uuidString] else { continue }
            periodEnergy[meal.mealPeriod, default: []].append(outcome.energy)
        }

        if let best = periodEnergy.max(by: {
            avg($0.value) < avg($1.value)
        }), best.value.count >= 2 {
            let avgE = avg(best.value)
            if avgE >= 3.5 {
                results.append(OutcomeCorrelation(
                    icon: best.key.icon,
                    title: "Best energy at \(best.key.rawValue.lowercased())",
                    description: String(format: "%.1f/5 average energy during %@", avgE, best.key.rawValue.lowercased()),
                    category: .info
                ))
            }
        }
    }

    private func avg(_ values: [Int]) -> Double {
        guard !values.isEmpty else { return 0 }
        return Double(values.reduce(0, +)) / Double(values.count)
    }
}

// MARK: - Meal Outcome

struct MealOutcome: Codable {
    let energy: Int      // 1–5
    let fullness: Int    // 1–5
    let discomfort: Int  // 1–5

    static let empty = MealOutcome(energy: 0, fullness: 0, discomfort: 0)
}

// MARK: - Outcome Correlation

struct OutcomeCorrelation: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let category: InsightCategory
}
