import SwiftUI

// MARK: - Meal History View

struct MealHistoryView: View {
    @EnvironmentObject private var historyVM:  HistoryViewModel
    @EnvironmentObject private var plateVM:    PlateViewModel
    @EnvironmentObject private var appState:   AppState

    @State private var expandedGroupId: String? = nil
    @State private var groupsVisible:   Bool    = false
    @State private var showClearAlert:  Bool    = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.untSubtleGradient.ignoresSafeArea()

                if historyVM.groupedMeals.isEmpty {
                    emptyHistory
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            // MARK: Stats Banner
                            statsBanner
                                .padding(.horizontal, 20)
                                .padding(.top, 8)

                            // MARK: Grouped Meal List
                            ForEach(Array(historyVM.groupedMeals.enumerated()), id: \.element.id) { index, group in
                                MealDayGroup(
                                    group: group,
                                    isExpanded: expandedGroupId == group.id,
                                    plateVM: plateVM,
                                    onToggle: {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                                            expandedGroupId = expandedGroupId == group.id ? nil : group.id
                                        }
                                    },
                                    onDelete: { mealId in
                                        withAnimation(.spring(response: 0.4)) {
                                            historyVM.delete(mealId: mealId)
                                        }
                                    }
                                )
                                .padding(.horizontal, 20)
                                .opacity(groupsVisible ? 1 : 0)
                                .offset(y: groupsVisible ? 0 : 30)
                                .animation(
                                    .spring(response: 0.5, dampingFraction: 0.78)
                                        .delay(Double(index) * 0.08),
                                    value: groupsVisible
                                )
                            }

                            Spacer().frame(height: 100)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Meal History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !historyVM.meals.isEmpty {
                        Button(role: .destructive) { showClearAlert = true } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.statusClosed)
                        }
                    }
                }
            }
            .alert("Clear All History?", isPresented: $showClearAlert) {
                Button("Clear All", role: .destructive) {
                    withAnimation(.spring(response: 0.4)) {
                        historyVM.clearAll()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all saved meals.")
            }
        }
        .onAppear {
            historyVM.load()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.78).delay(0.15)) {
                groupsVisible = true
            }
            expandedGroupId = historyVM.groupedMeals.first?.id
        }
    }

    // MARK: - Stats Banner

    private var statsBanner: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                StatCell(value: "\(historyVM.totalMealsLogged)", label: "Meals Logged",  icon: "fork.knife",     color: .untGreenPrimary)
                Divider().frame(height: 44)
                StatCell(value: "\(historyVM.streakDays)",        label: "Day Streak",    icon: "flame.fill",     color: .macroCalories)
                Divider().frame(height: 44)
                StatCell(value: "\(Int(historyVM.weeklyCalories))", label: "Cal This Week", icon: "chart.bar.fill", color: .macroCarbs)
            }
        }
        .padding(.vertical, 16)
        .background(Color.surfaceBase)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 4)
    }

    // MARK: - Empty History

    private var emptyHistory: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.untGreenPale)
                    .frame(width: 120, height: 120)
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(Color.untGreenMint)
            }

            VStack(spacing: 8) {
                Text("No meals yet")
                    .font(.headingLarge)
                    .foregroundStyle(Color.textPrimary)
                Text("Build a plate and save it\nto start tracking your meals")
                    .font(.bodyMedium)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }

        
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Meal Day Group

private struct MealDayGroup: View {
    let group:      MealGroup
    let isExpanded: Bool
    let plateVM:    PlateViewModel
    let onToggle:   () -> Void
    let onDelete:   (UUID) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: onToggle) {
                HStack(alignment: .center, spacing: 12) {
                    // Day label
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.label)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.textPrimary)
                        Text("\(group.meals.count) meal\(group.meals.count == 1 ? "" : "s")")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textTertiary)
                    }

                    Spacer()

                    // Day totals
                    HStack(spacing: 10) {
                        DayTotalChip(value: Int(group.totalCalories), label: "cal", color: .macroCalories)
                        DayTotalChip(value: Int(group.totalProtein),  label: "P",   color: .macroProtein)
                    }

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isExpanded)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(PlainButtonStyle())

            // Expanded Meals
            if isExpanded {
                VStack(spacing: 10) {
                    Divider().padding(.horizontal, 16)
                    ForEach(group.meals) { meal in
                        HistoryMealCard(
                            meal: meal,
                            plateVM: plateVM,
                            onDelete: { onDelete(meal.id) }
                        )
                        .padding(.horizontal, 12)
                    }
                    .padding(.bottom, 10)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(Color.surfaceBase)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

// MARK: - History Meal Card

private struct HistoryMealCard: View {
    let meal:     SavedMeal
    let plateVM:  PlateViewModel
    let onDelete: () -> Void
    @State private var showActions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                // Hall gradient indicator
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(colors: meal.gradientHallColor, startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: 4, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(meal.diningHallName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        Text(meal.timeDisplay)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textTertiary)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: meal.mealPeriod.icon)
                            .font(.system(size: 10))
                            .foregroundStyle(meal.mealPeriod.color)
                        Text(meal.mealPeriod.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(meal.mealPeriod.color)
                        Text("•")
                            .foregroundStyle(Color.textTertiary)
                        Text("\(meal.itemCount) items")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }

            // Macro bar
            HStack(spacing: 8) {
                HistoryMacroChip(label: "Cal",  value: Int(meal.totalCalories), color: .macroCalories)
                HistoryMacroChip(label: "P",    value: Int(meal.totalProtein),  color: .macroProtein)
                HistoryMacroChip(label: "C",    value: Int(meal.totalCarbs),    color: .macroCarbs)
                HistoryMacroChip(label: "F",    value: Int(meal.totalFat),      color: .macroFat)
                Spacer()

                // Action menu
                Menu {
                    Button {
                        rebuildPlate()
                    } label: {
                        Label("Re-add to Plate", systemImage: "plus.circle")
                    }
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textTertiary)
                        .padding(8)
                        .background(Color.surfaceRaised)
                        .clipShape(Circle())
                }
            }

            // Item names (compact)
            if !meal.items.isEmpty {
                let names = meal.items.map { "\($0.quantity > 1 ? "\($0.quantity)x " : "")\($0.menuItem.name)" }.joined(separator: " · ")
                Text(names)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .background(Color.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func rebuildPlate() {
        for plateItem in meal.items {
            let hall = DiningHall.sampleHalls.first { $0.id == meal.diningHallId } ?? DiningHall.sampleHalls[0]
            for _ in 0..<plateItem.quantity {
                plateVM.add(plateItem.menuItem, from: hall)
            }
        }
        plateVM.showingPlateSheet = true
    }
}

// MARK: - Stat Cell

private struct StatCell: View {
    let value: String
    let label: String
    let icon:  String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textPrimary)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Day Total Chip

private struct DayTotalChip: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Text("\(value)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.textTertiary)
        }
    }
}

// MARK: - History Macro Chip

private struct HistoryMacroChip: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
