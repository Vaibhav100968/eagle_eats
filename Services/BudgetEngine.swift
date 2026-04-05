import Foundation
import Combine

// MARK: - Budget Engine
// Computes burn rate, depletion projections, and weekly/daily spending budgets.
//
// How it works:
//   1. Each time MealPlanService reports a new balance, BudgetEngine records
//      the delta as a SpendingEvent.
//   2. From the spending history, it computes average daily spend (burn rate).
//   3. It projects when the balance will hit zero and whether that is before
//      or after the semester ends.
//   4. It divides the remaining balance by remaining weeks/days to produce
//      a "safe to spend" budget.
//
// All computation is pure — no network calls. The engine is @MainActor
// because it reads/writes Published state consumed by SwiftUI views.

@MainActor
final class BudgetEngine: ObservableObject {

    static let shared = BudgetEngine()

    @Published private(set) var snapshot: BudgetSnapshot = .empty
    @Published private(set) var spendingHistory: [SpendingEvent] = []
    @Published var semesterConfig: SemesterConfig = .current

    private let persistence = PersistenceService.shared
    private var lastKnownBalance: Double? = nil

    private init() {
        spendingHistory = persistence.loadSpendingHistory()
        recompute()
    }

    // MARK: - Balance Update

    /// Called when MealPlanService gets a new flex balance.
    /// Detects the delta and records a spending event if balance decreased.
    func recordBalanceUpdate(newBalance: Double) {
        if let prev = lastKnownBalance {
            let delta = prev - newBalance
            // Only record spending (positive delta). Ignore refills for burn rate
            // but still record them for transaction history.
            if abs(delta) > 0.01 {
                let event = SpendingEvent(
                    amount: delta,
                    balanceAfter: newBalance,
                    source: .flex
                )
                spendingHistory.insert(event, at: 0)
                persistence.saveSpendingHistory(spendingHistory)
            }
        }
        lastKnownBalance = newBalance
        recompute()
    }

    /// Force recompute with an explicit balance (e.g., on app launch with cached data).
    func recomputeWith(balance: Double) {
        lastKnownBalance = balance
        recompute()
    }

    // MARK: - Core Computation

    private func recompute() {
        guard let balance = lastKnownBalance, balance > 0 else {
            snapshot = .empty
            return
        }

        let now = Date()
        let daysRemaining = semesterConfig.daysRemaining
        let daysElapsed   = semesterConfig.daysElapsed

        // --- Burn Rate ---
        // Use spending events from the last 14 days for a responsive average,
        // falling back to total history if fewer than 3 events in that window.
        let recentCutoff = Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now
        let recentSpends = spendingHistory.filter { $0.amount > 0 && $0.date >= recentCutoff }
        let allSpends    = spendingHistory.filter { $0.amount > 0 }

        let spends = recentSpends.count >= 3 ? recentSpends : allSpends
        let avgDaily: Double
        if spends.count >= 2,
           let oldest = spends.last?.date,
           let newest = spends.first?.date {
            let span = max(1, Calendar.current.dateComponents([.day], from: oldest, to: newest).day ?? 1)
            let totalSpent = spends.reduce(0.0) { $0 + $1.amount }
            avgDaily = totalSpent / Double(span)
        } else if daysElapsed > 0, let firstBalance = spendingHistory.last?.balanceAfter {
            // Fallback: estimate from total balance change over semester so far
            let totalSpent = max(0, firstBalance + spendingHistory.filter { $0.amount > 0 }.reduce(0.0) { $0 + $1.amount } - balance)
            avgDaily = totalSpent / Double(daysElapsed)
        } else {
            avgDaily = 0
        }

        let avgWeekly = avgDaily * 7

        // --- Projections ---
        let depletionDate: Date?
        let daysUntilDepletion: Int?
        if avgDaily > 0 {
            let daysLeft = Int(balance / avgDaily)
            daysUntilDepletion = daysLeft
            depletionDate = Calendar.current.date(byAdding: .day, value: daysLeft, to: now)
        } else {
            daysUntilDepletion = nil
            depletionDate = nil
        }

        let willLast = daysUntilDepletion.map { $0 >= daysRemaining } ?? true

        // --- Budget Guidance ---
        let weeksRemaining = max(1, Double(daysRemaining) / 7.0)
        let weeklyBudget = balance / weeksRemaining
        let dailyBudget  = daysRemaining > 0 ? balance / Double(daysRemaining) : balance

        // --- Urgency ---
        let urgency: BudgetUrgency
        if let depletion = daysUntilDepletion {
            if depletion <= 7                           { urgency = .critical }
            else if depletion < daysRemaining - 14      { urgency = .warning }
            else if depletion < daysRemaining           { urgency = .caution }
            else                                        { urgency = .healthy }
        } else {
            urgency = balance > 0 ? .healthy : .none
        }

        snapshot = BudgetSnapshot(
            computedAt: now,
            currentBalance: balance,
            semesterEndDate: semesterConfig.endDate,
            daysRemaining: daysRemaining,
            averageDailySpend: avgDaily,
            averageWeeklySpend: avgWeekly,
            projectedDepletionDate: depletionDate,
            daysUntilDepletion: daysUntilDepletion,
            willLastUntilSemesterEnd: willLast,
            weeklyBudget: weeklyBudget,
            dailyBudget: dailyBudget,
            urgency: urgency
        )
    }

    // MARK: - Helpers

    /// Recent spending events for display (last 20).
    var recentTransactions: [SpendingEvent] {
        Array(spendingHistory.prefix(20))
    }

    /// Total spent this week.
    var weeklySpendSoFar: Double {
        let weekStart = Calendar.current.date(from: Calendar.current.dateComponents(
            [.yearForWeekOfYear, .weekOfYear], from: Date()))!
        return spendingHistory
            .filter { $0.amount > 0 && $0.date >= weekStart }
            .reduce(0.0) { $0 + $1.amount }
    }

    /// How much of the weekly budget has been used.
    var weeklyBudgetUsed: Double {
        guard snapshot.weeklyBudget > 0 else { return 0 }
        return min(1.0, weeklySpendSoFar / snapshot.weeklyBudget)
    }

    // MARK: - Suggestions

    /// Returns contextual advice based on current spending patterns.
    var suggestions: [BudgetSuggestion] {
        guard snapshot.urgency != .none else { return [] }
        var result: [BudgetSuggestion] = []

        switch snapshot.urgency {
        case .critical:
            result.append(BudgetSuggestion(
                icon: "exclamationmark.triangle.fill",
                message: "Use swipe meals instead of flex for the next 2 weeks",
                priority: .high
            ))
            result.append(BudgetSuggestion(
                icon: "fork.knife",
                message: "Eat at all-you-care-to-eat halls to maximize value",
                priority: .high
            ))
        case .warning:
            result.append(BudgetSuggestion(
                icon: "chart.line.downtrend.xyaxis",
                message: "Reduce daily spending by $\(String(format: "%.0f", max(0, snapshot.averageDailySpend - snapshot.dailyBudget))) to stay on track",
                priority: .medium
            ))
            result.append(BudgetSuggestion(
                icon: "building.2",
                message: "Eat at dining halls 3x this week to conserve flex dollars",
                priority: .medium
            ))
        case .caution:
            result.append(BudgetSuggestion(
                icon: "lightbulb.fill",
                message: "You are spending slightly above your target daily budget",
                priority: .low
            ))
        case .healthy:
            result.append(BudgetSuggestion(
                icon: "checkmark.circle.fill",
                message: "Great pace — your balance is on track for the semester",
                priority: .info
            ))
        case .none:
            break
        }

        if weeklyBudgetUsed > 0.8 {
            result.append(BudgetSuggestion(
                icon: "calendar.badge.exclamationmark",
                message: "You have used \(Int(weeklyBudgetUsed * 100))% of this week's budget",
                priority: weeklyBudgetUsed > 0.95 ? .high : .medium
            ))
        }

        return result
    }

    // MARK: - Recovery Plan

    var recoveryPlan: RecoveryPlan? {
        guard snapshot.urgency == .critical || snapshot.urgency == .warning || snapshot.urgency == .caution else {
            return nil
        }

        var actions: [RecoveryAction] = []
        var estimatedSavings: Double = 0

        let dailyOverspend = max(0, snapshot.averageDailySpend - snapshot.dailyBudget)
        let weeklyOverspend = max(0, snapshot.averageWeeklySpend - snapshot.weeklyBudget)

        switch snapshot.urgency {
        case .critical:
            actions.append(RecoveryAction(
                icon: "fork.knife.circle",
                text: "Use dining hall swipes exclusively for 2 weeks",
                savings: dailyOverspend * 14
            ))
            estimatedSavings += dailyOverspend * 14

            actions.append(RecoveryAction(
                icon: "xmark.circle",
                text: "Avoid all retail dining dollar purchases",
                savings: weeklyOverspend * 0.6
            ))
            estimatedSavings += weeklyOverspend * 0.6

            actions.append(RecoveryAction(
                icon: "dollarsign.arrow.circlepath",
                text: String(format: "Cap daily flex spend at $%.2f", snapshot.dailyBudget),
                savings: dailyOverspend * 7
            ))
            estimatedSavings += dailyOverspend * 7

        case .warning:
            actions.append(RecoveryAction(
                icon: "building.2",
                text: "Eat at dining halls 4+ times this week",
                savings: dailyOverspend * 4
            ))
            estimatedSavings += dailyOverspend * 4

            actions.append(RecoveryAction(
                icon: "chart.line.downtrend.xyaxis",
                text: String(format: "Reduce daily spending by $%.2f", dailyOverspend),
                savings: dailyOverspend * 7
            ))
            estimatedSavings += dailyOverspend * 7

        case .caution:
            actions.append(RecoveryAction(
                icon: "lightbulb",
                text: "Swap 2 retail meals for dining hall swipes per week",
                savings: dailyOverspend * 2
            ))
            estimatedSavings += dailyOverspend * 2

        default:
            break
        }

        guard !actions.isEmpty else { return nil }

        return RecoveryPlan(
            urgency: snapshot.urgency,
            actions: actions,
            estimatedWeeklySavings: max(0, estimatedSavings),
            targetDailyBudget: snapshot.dailyBudget,
            daysToRecovery: estimatedSavings > 0
                ? Int(ceil(max(0, snapshot.averageDailySpend - snapshot.dailyBudget) * Double(snapshot.daysRemaining) / estimatedSavings))
                : nil
        )
    }
}
