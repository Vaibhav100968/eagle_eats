import Foundation

// MARK: - Spending Models
// Data structures for the Dining Dollars Intelligence system.
// Used by BudgetEngine to compute burn rate, projections, and weekly budgets.

/// A single spending event (balance change detected between refreshes).
struct SpendingEvent: Identifiable, Codable {
    let id: UUID
    let date: Date
    let amount: Double          // positive = spend, negative = deposit
    let balanceAfter: Double
    let source: SpendingSource

    init(date: Date = Date(), amount: Double, balanceAfter: Double, source: SpendingSource = .flex) {
        self.id = UUID()
        self.date = date
        self.amount = amount
        self.balanceAfter = balanceAfter
        self.source = source
    }
}

enum SpendingSource: String, Codable {
    case flex       = "Flex"
    case swipes     = "Swipes"
}

// MARK: - Budget Snapshot

/// Point-in-time budget computation produced by BudgetEngine.
struct BudgetSnapshot: Equatable {
    let computedAt: Date

    // Current state
    let currentBalance: Double
    let semesterEndDate: Date
    let daysRemaining: Int

    // Burn rate
    let averageDailySpend: Double
    let averageWeeklySpend: Double

    // Projections
    let projectedDepletionDate: Date?   // nil if balance is zero or no spend history
    let daysUntilDepletion: Int?
    let willLastUntilSemesterEnd: Bool

    // Budget guidance
    let weeklyBudget: Double
    let dailyBudget: Double

    // Warning level
    let urgency: BudgetUrgency

    static let empty = BudgetSnapshot(
        computedAt: Date(),
        currentBalance: 0,
        semesterEndDate: Date(),
        daysRemaining: 0,
        averageDailySpend: 0,
        averageWeeklySpend: 0,
        projectedDepletionDate: nil,
        daysUntilDepletion: nil,
        willLastUntilSemesterEnd: true,
        weeklyBudget: 0,
        dailyBudget: 0,
        urgency: .none
    )
}

/// Urgency levels drive the color and messaging in SpendingInsightsCard.
enum BudgetUrgency: String, Codable {
    case none       // no balance data
    case healthy    // on track to last the semester
    case caution    // will run out in the last 2 weeks
    case warning    // will run out with >1 week remaining
    case critical   // will run out within 7 days
}

// MARK: - Swipe Snapshot

/// Tracks dining swipe usage rate.
struct SwipeSnapshot: Equatable {
    let totalSwipes: Int
    let swipesUsedPerDay: Double
    let projectedSwipesAtSemesterEnd: Int
    let willRunOut: Bool
}

// MARK: - Budget Suggestion

struct BudgetSuggestion: Identifiable {
    let id = UUID()
    let icon: String
    let message: String
    let priority: SuggestionPriority
}

enum SuggestionPriority {
    case info, low, medium, high

    var tint: String {
        switch self {
        case .info:   return "34C759"
        case .low:    return "F59E0B"
        case .medium: return "FF9500"
        case .high:   return "FF3B30"
        }
    }
}

// MARK: - Semester Configuration

/// Defines semester boundaries for budget calculations.
/// Defaults can be overridden in Settings.
struct SemesterConfig: Codable, Equatable {
    var startDate: Date
    var endDate: Date
    var name: String

    /// Spring 2026 default — update each semester or let user configure.
    static let current: SemesterConfig = {
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: 2026, month: 1, day: 13))!
        let end   = cal.date(from: DateComponents(year: 2026, month: 5, day: 8))!
        return SemesterConfig(startDate: start, endDate: end, name: "Spring 2026")
    }()

    var daysRemaining: Int {
        max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()),
                                                to: Calendar.current.startOfDay(for: endDate)).day ?? 0)
    }

    var totalDays: Int {
        max(1, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: startDate),
                                                to: Calendar.current.startOfDay(for: endDate)).day ?? 1)
    }

    var daysElapsed: Int {
        max(0, totalDays - daysRemaining)
    }

    var progress: Double {
        guard totalDays > 0 else { return 0 }
        return Double(daysElapsed) / Double(totalDays)
    }
}

// MARK: - Recovery Plan

struct RecoveryPlan {
    let urgency: BudgetUrgency
    let actions: [RecoveryAction]
    let estimatedWeeklySavings: Double
    let targetDailyBudget: Double
    let daysToRecovery: Int?
}

struct RecoveryAction: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
    let savings: Double
}
