import SwiftUI

// MARK: - Spending Insights Card
// Displays budget projections below the balance cards in MealPlanTab.
// Matches the existing gradient card style used by BalanceCard.
//
// States:
//   - healthy:  green gradient, "You're on track"
//   - caution:  amber tint, "Spending faster than expected"
//   - warning:  orange, "May run out before semester ends"
//   - critical: red, "Running low — adjust spending"

struct SpendingInsightsCard: View {
    let snapshot: BudgetSnapshot
    var suggestions: [BudgetSuggestion] = []
    @State private var appeared = false

    private var gradientColors: [Color] {
        switch snapshot.urgency {
        case .none:     return [Color(hex: "6B7280"), Color(hex: "4B5563")]
        case .healthy:  return [Color(hex: "00853E"), Color(hex: "005227")]
        case .caution:  return [Color(hex: "D97706"), Color(hex: "92400E")]
        case .warning:  return [Color(hex: "EA580C"), Color(hex: "9A3412")]
        case .critical: return [Color(hex: "DC2626"), Color(hex: "991B1B")]
        }
    }

    private var statusIcon: String {
        switch snapshot.urgency {
        case .none:     return "questionmark.circle.fill"
        case .healthy:  return "checkmark.shield.fill"
        case .caution:  return "exclamationmark.triangle.fill"
        case .warning:  return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }

    private var statusTitle: String {
        switch snapshot.urgency {
        case .none:     return "No Balance Data"
        case .healthy:  return "On Track"
        case .caution:  return "Spending Faster Than Expected"
        case .warning:  return "May Run Out Early"
        case .critical: return "Running Low"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: statusIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Text("Budget Intelligence")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text(statusTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.15))
                    .clipShape(Capsule())
            }

            // Budget metrics
            if snapshot.urgency != .none {
                HStack(spacing: 0) {
                    budgetMetric(
                        label: "Weekly Budget",
                        value: String(format: "$%.0f", snapshot.weeklyBudget),
                        sub: "safe to spend"
                    )
                    Divider()
                        .frame(height: 36)
                        .background(.white.opacity(0.2))
                    budgetMetric(
                        label: "Daily Budget",
                        value: String(format: "$%.2f", snapshot.dailyBudget),
                        sub: "per day"
                    )
                    Divider()
                        .frame(height: 36)
                        .background(.white.opacity(0.2))
                    budgetMetric(
                        label: "Days Left",
                        value: "\(snapshot.daysRemaining)",
                        sub: "in semester"
                    )
                }

                // Depletion projection
                if let depletionDays = snapshot.daysUntilDepletion {
                    HStack(spacing: 8) {
                        Image(systemName: "chart.line.downtrend.xyaxis")
                            .font(.system(size: 13))
                        if snapshot.willLastUntilSemesterEnd {
                            Text("Your balance will last through the semester")
                        } else {
                            Text("At current rate, you'll run out in \(depletionDays) days")
                        }
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.top, 4)
                }

                // Burn rate + depletion date
                if snapshot.averageDailySpend > 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 13))
                            Text("Avg spend: $\(String(format: "%.2f", snapshot.averageDailySpend))/day")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))

                        if let date = snapshot.projectedDepletionDate {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 12))
                                Text("Projected depletion: \(date, format: .dateTime.month(.abbreviated).day())")
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }

                // Suggestions
                if !suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(suggestions.prefix(2)) { suggestion in
                            HStack(spacing: 8) {
                                Image(systemName: suggestion.icon)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.8))
                                Text(suggestion.message)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            } else {
                Text("Sign in to the UNT portal to see your budget projections")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.vertical, 8)
            }
        }
        .padding(20)
        .background(
            ZStack {
                LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                // Decorative circle
                Circle()
                    .fill(.white.opacity(0.05))
                    .frame(width: 160)
                    .offset(x: 130, y: -30)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: gradientColors[0].opacity(0.3), radius: 14, x: 0, y: 6)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.78).delay(0.15)) {
                appeared = true
            }
        }
    }

    private func budgetMetric(label: String, value: String, sub: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
            Text(sub)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Add Funds Button

struct AddFundsButton: View {
    private let paymentURL = URL(string: "https://myunt.unt.edu")!

    var body: some View {
        Button {
            UIApplication.shared.open(paymentURL)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add Dining Dollars")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("Opens UNT payment portal (external)")
                        .font(.system(size: 11))
                        .opacity(0.7)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(Color.untGreenPrimary)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color.untGreenPale)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.untGreenMint, lineWidth: 1)
            )
        }
        .buttonStyle(SpringButtonStyle())
    }
}

// MARK: - Weekly Budget Progress Bar

struct WeeklyBudgetBar: View {
    let used: Double    // 0–1
    let spent: Double
    let budget: Double

    private var barColor: Color {
        if used > 0.9 { return .statusClosed }
        if used > 0.7 { return .macroFat }
        return .untGreenPrimary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("This Week")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text("$\(String(format: "%.2f", spent)) / $\(String(format: "%.0f", budget))")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.textSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor.opacity(0.15))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: max(0, geo.size.width * min(used, 1.0)))
                        .animation(.spring(response: 0.8, dampingFraction: 0.75), value: used)
                }
            }
            .frame(height: 8)
        }
        .padding(16)
        .background(Color.surfaceBase)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
    }
}
