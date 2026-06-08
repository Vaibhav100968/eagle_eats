import SwiftUI

// MARK: - Macro Ring (single animated ring)

struct MacroRing: View {
    let value:    Double
    let goal:     Double
    let label:    String
    let unit:     String
    let color:    Color
    var size:     CGFloat = 80
    var lineWidth: CGFloat = 8

    @State private var progress: Double = 0
    @State private var displayValue: Double = 0

    private var ratio: Double { goal > 0 ? min(value / goal, 1.0) : 0 }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Track
                Circle()
                    .stroke(color.opacity(0.12), lineWidth: lineWidth)
                    .frame(width: size, height: size)

                // Progress
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [color.opacity(0.7), color],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 1.0, dampingFraction: 0.75).delay(0.1), value: progress)

                // Dot at end of arc
                Circle()
                    .fill(color)
                    .frame(width: lineWidth * 1.1, height: lineWidth * 1.1)
                    .offset(y: -(size / 2))
                    .rotationEffect(.degrees(-90 + progress * 360))
                    .opacity(progress > 0.02 ? 1 : 0)

                // Center text
                VStack(spacing: 1) {
                    Text("\(Int(displayValue))")
                        .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.textPrimary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4), value: displayValue)
                    Text(unit)
                        .font(.system(size: size * 0.14, weight: .medium))
                        .foregroundStyle(Color.textTertiary)
                }
            }

            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
        }
        .onAppear { animate() }
        .onChange(of: value) { _, _ in animate() }
    }

    private func animate() {
        withAnimation(.spring(response: 1.0, dampingFraction: 0.75).delay(0.05)) {
            progress = ratio
        }
        withAnimation(.interpolatingSpring(stiffness: 40, damping: 12).delay(0.05)) {
            displayValue = value
        }
    }
}

// MARK: - Macro Rings Row

struct MacroRingsRow: View {
    let plate: Plate
    let settings: AppSettings

    var body: some View {
        HStack(spacing: 0) {
            MacroRing(
                value: plate.totalCalories,
                goal: settings.dailyCalorieGoal,
                label: "Calories",
                unit: "kcal",
                color: .macroCalories,
                size: 76
            )
            Spacer()
            MacroRing(
                value: plate.totalProtein,
                goal: settings.dailyProteinGoal,
                label: "Protein",
                unit: "g",
                color: .macroProtein,
                size: 76
            )
            Spacer()
            MacroRing(
                value: plate.totalCarbs,
                goal: settings.dailyCarbGoal,
                label: "Carbs",
                unit: "g",
                color: .macroCarbs,
                size: 76
            )
            Spacer()
            MacroRing(
                value: plate.totalFat,
                goal: settings.dailyFatGoal,
                label: "Fat",
                unit: "g",
                color: .macroFat,
                size: 76
            )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(Color.surfaceBase)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 6)
    }
}

// MARK: - Daily Intake Header (My Plate tab)

struct DailyIntakeHeader: View {
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let savedCalories: Double
    let plateCalories: Double
    let settings: AppSettings

    private var calorieProgress: Double {
        guard settings.dailyCalorieGoal > 0 else { return 0 }
        return min(calories / settings.dailyCalorieGoal, 1.0)
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("Today's Intake")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(calories))")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.textPrimary)
                        .contentTransition(.numericText())
                    Text("kcal")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.textTertiary)
                }

                if plateCalories > 0 {
                    Text("\(Int(savedCalories)) saved · +\(Int(plateCalories)) on your plate")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.untGreenPrimary)
                } else if settings.dailyCalorieGoal > 0 {
                    Text("\(Int(max(settings.dailyCalorieGoal - calories, 0))) kcal remaining")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.textTertiary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.macroCalories.opacity(0.15))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.macroCalories)
                            .frame(width: geo.size.width * calorieProgress, height: 6)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: calorieProgress)
                    }
                }
                .frame(height: 6)
                .padding(.horizontal, 8)
            }

            HStack(spacing: 0) {
                MacroRing(
                    value: protein,
                    goal: settings.dailyProteinGoal,
                    label: "Protein",
                    unit: "g",
                    color: .macroProtein,
                    size: 68,
                    lineWidth: 7
                )
                Spacer()
                MacroRing(
                    value: carbs,
                    goal: settings.dailyCarbGoal,
                    label: "Carbs",
                    unit: "g",
                    color: .macroCarbs,
                    size: 68,
                    lineWidth: 7
                )
                Spacer()
                MacroRing(
                    value: fat,
                    goal: settings.dailyFatGoal,
                    label: "Fat",
                    unit: "g",
                    color: .macroFat,
                    size: 68,
                    lineWidth: 7
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(Color.surfaceBase)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 6)
    }
}

// MARK: - Compact Macro Bar (for FAB/summary)

struct CompactMacroBar: View {
    let plate: Plate
    let settings: AppSettings

    var body: some View {
        HStack(spacing: 12) {
            CompactMacroItem(label: "Cal",     value: Int(plate.totalCalories), goal: Int(settings.dailyCalorieGoal), color: .macroCalories)
            CompactMacroItem(label: "Protein", value: Int(plate.totalProtein),  goal: Int(settings.dailyProteinGoal), color: .macroProtein)
            CompactMacroItem(label: "Carbs",   value: Int(plate.totalCarbs),    goal: Int(settings.dailyCarbGoal),   color: .macroCarbs)
            CompactMacroItem(label: "Fat",     value: Int(plate.totalFat),      goal: Int(settings.dailyFatGoal),    color: .macroFat)
        }
    }
}

private struct CompactMacroItem: View {
    let label: String
    let value: Int
    let goal:  Int
    let color: Color

    var ratio: Double { goal > 0 ? min(Double(value) / Double(goal), 1.0) : 0 }

    var body: some View {
        VStack(spacing: 5) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.15))
                    .frame(height: 4)
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: max(CGFloat(ratio) * 56, 0), height: 4)
                    .animation(.spring(response: 0.7, dampingFraction: 0.8), value: ratio)
            }
            .frame(width: 56)

            Text("\(value)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textPrimary)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}
