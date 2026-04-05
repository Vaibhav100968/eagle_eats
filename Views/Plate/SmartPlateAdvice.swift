import SwiftUI

// MARK: - Smart Plate Advice
// Contextual feedback below the macro rings in the Plate tab.
// Shows goal progress messages and suggests items to complete macros.

struct SmartPlateAdvice: View {
    let plate: Plate
    let settings: AppSettings
    let suggestions: [ScoredMenuItem]
    var onSuggestionTap: ((MenuItem) -> Void)? = nil

    private var messages: [AdviceMessage] {
        var msgs: [AdviceMessage] = []

        let calPct  = settings.dailyCalorieGoal > 0 ? plate.totalCalories / settings.dailyCalorieGoal : 0
        let protPct = settings.dailyProteinGoal > 0 ? plate.totalProtein / settings.dailyProteinGoal : 0
        let carbPct = settings.dailyCarbGoal > 0    ? plate.totalCarbs / settings.dailyCarbGoal : 0
        let fatPct  = settings.dailyFatGoal > 0     ? plate.totalFat / settings.dailyFatGoal : 0

        // Protein feedback
        if protPct >= 1.0 {
            msgs.append(AdviceMessage(icon: "checkmark.circle.fill", text: "Protein goal reached!", color: .macroProtein, type: .success))
        } else if protPct >= 0.75 {
            let remaining = Int(settings.dailyProteinGoal - plate.totalProtein)
            msgs.append(AdviceMessage(icon: "bolt.fill", text: "\(Int(protPct * 100))% protein — \(remaining)g to go", color: .macroProtein, type: .progress))
        } else if protPct > 0 {
            msgs.append(AdviceMessage(icon: "arrow.up.circle.fill", text: "Add a protein source to hit your goal", color: .macroProtein, type: .suggestion))
        }

        // Calorie feedback
        if calPct >= 1.0 {
            msgs.append(AdviceMessage(icon: "exclamationmark.triangle.fill", text: "Calorie goal exceeded", color: .macroCalories, type: .warning))
        } else if calPct >= 0.8 {
            msgs.append(AdviceMessage(icon: "checkmark.circle.fill", text: "Almost at calorie target", color: .macroCalories, type: .progress))
        }

        // Fat check
        if fatPct > 1.1 {
            msgs.append(AdviceMessage(icon: "exclamationmark.circle.fill", text: "High fat intake — consider lighter options", color: .macroFat, type: .warning))
        }

        // Balance check
        if protPct < 0.3 && carbPct > 0.7 {
            msgs.append(AdviceMessage(icon: "scalemass.fill", text: "Carb-heavy plate — add protein for balance", color: .macroCarbs, type: .suggestion))
        }

        return msgs
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Advice messages
            if !messages.isEmpty {
                ForEach(messages) { msg in
                    HStack(spacing: 10) {
                        Image(systemName: msg.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(msg.color)
                        Text(msg.text)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                    }
                    .padding(12)
                    .background(msg.color.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            // Suggestions
            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.untGreenPrimary)
                        Text("Suggested to Complete Your Goals")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.textSecondary)
                            .textCase(.uppercase)
                            .letterSpacing(0.4)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(suggestions) { scored in
                                SuggestionChip(scored: scored, onTap: {
                                    onSuggestionTap?(scored.item)
                                })
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Advice Message

private struct AdviceMessage: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
    let color: Color
    let type: AdviceType

    enum AdviceType {
        case success, progress, suggestion, warning
    }
}

// MARK: - Suggestion Chip

private struct SuggestionChip: View {
    let scored: ScoredMenuItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                Text(scored.item.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(2)

                if scored.item.nutritionLoaded {
                    HStack(spacing: 4) {
                        Text("P:\(Int(scored.item.nutrition.protein))g")
                            .foregroundStyle(Color.macroProtein)
                        Text("\(Int(scored.item.nutrition.calories))cal")
                            .foregroundStyle(Color.macroCalories)
                    }
                    .font(.system(size: 10, weight: .medium))
                }

                if let reason = scored.reasons.first {
                    Text(reason.displayText)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(reason.color)
                }
            }
            .padding(10)
            .frame(width: 120, alignment: .leading)
            .background(Color.surfaceBase)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.untGreenPrimary.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(SpringButtonStyle())
    }
}
