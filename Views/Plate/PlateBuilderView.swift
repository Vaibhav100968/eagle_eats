import SwiftUI

// MARK: - Plate Builder View

struct PlateBuilderView: View {
    @EnvironmentObject private var plateVM:    PlateViewModel
    @EnvironmentObject private var historyVM:  HistoryViewModel
    @EnvironmentObject private var appState:   AppState
    @Environment(\.dismiss) private var dismiss

    @State private var showSaveConfirmation = false
    @State private var savedMeal: SavedMeal? = nil
    @State private var listVisible = false
    @State private var saving = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.untGreenBackground.ignoresSafeArea()

                if plateVM.plate.isEmpty {
                    emptyPlate
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            // MARK: Macro Rings
                            MacroRingsRow(plate: plateVM.plate, settings: appState.settings)
                                .padding(.horizontal, 20)
                                .padding(.top, 8)

                            // MARK: Secondary Macros
                            secondaryMacros
                                .padding(.horizontal, 20)

                            // MARK: Plate Items
                            plateItems

                            Spacer().frame(height: 100)
                        }
                        .padding(.vertical, 16)
                    }
                }

                // MARK: Bottom Actions
                if !plateVM.plate.isEmpty {
                    bottomActions
                        .padding(.bottom, 8)
                }
            }
            .navigationTitle("My Plate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !plateVM.plate.isEmpty {
                        Button(role: .destructive) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                plateVM.clear()
                            }
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.statusClosed)
                        }
                    }
                }
            }
            .alert("Meal Saved!", isPresented: $showSaveConfirmation) {
                Button("View History") {
                    dismiss()
                }
                Button("OK") { dismiss() }
            } message: {
                if let meal = savedMeal {
                    Text("\(meal.diningHallName) • \(Int(meal.totalCalories)) cal")
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.78).delay(0.1)) {
                listVisible = true
            }
        }
    }

    // MARK: - Empty State

    private var emptyPlate: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.untGreenPale)
                    .frame(width: 120, height: 120)
                Image(systemName: "fork.knife")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(Color.untGreenMint)
            }

            VStack(spacing: 8) {
                Text("Your plate is empty")
                    .font(.headingLarge)
                    .foregroundStyle(Color.textPrimary)
                Text("Browse a dining hall and add items\nto start building your plate")
                    .font(.bodyMedium)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button { dismiss() } label: {
                Label("Browse Dining Halls", systemImage: "fork.knife.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.untGreenPrimary)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .shadow(color: Color.untGreenPrimary.opacity(0.35), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(SpringButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Secondary Macros

    private var secondaryMacros: some View {
        HStack(spacing: 12) {
            if plateVM.plate.totalFiber > 0 {
                SecondaryMacroChip(label: "Fiber",  value: Int(plateVM.plate.totalFiber),  unit: "g",  color: .macroFiber)
            }
            if plateVM.plate.totalSodium > 0 {
                SecondaryMacroChip(label: "Sodium", value: Int(plateVM.plate.totalSodium), unit: "mg", color: Color.textSecondary)
            }
            SecondaryMacroChip(label: "Items", value: plateVM.plate.itemCount, unit: "", color: .untGreenPrimary)
        }
    }

    // MARK: - Plate Items

    private var plateItems: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Your Items")
                    .font(.headingSmall)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text("\(plateVM.plate.itemCount) items")
                    .font(.labelSmall)
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, 20)

            ForEach(Array(plateVM.plate.items.enumerated()), id: \.element.id) { index, plateItem in
                PlateItemRow(plateItem: plateItem, plateVM: plateVM)
                    .padding(.horizontal, 20)
                    .opacity(listVisible ? 1 : 0)
                    .offset(y: listVisible ? 0 : 20)
                    .animation(
                        .spring(response: 0.45, dampingFraction: 0.8).delay(Double(index) * 0.06),
                        value: listVisible
                    )
            }
        }
    }

    // MARK: - Bottom Actions

    private var bottomActions: some View {
        VStack(spacing: 12) {
            // Total summary bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total")
                        .font(.labelSmall)
                        .foregroundStyle(Color.textTertiary)
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(Int(plateVM.plate.totalCalories))")
                            .font(.numberLarge)
                            .foregroundStyle(Color.textPrimary)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.5), value: plateVM.plate.totalCalories)
                        Text("kcal")
                            .font(.labelSmall)
                            .foregroundStyle(Color.textSecondary)
                    }
                }

                Spacer()

                CompactMacroBar(plate: plateVM.plate, settings: appState.settings)
                    .frame(maxWidth: 220)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.surfaceBase)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: -4)
            .padding(.horizontal, 16)

            // Save button
            Button {
                saveMeal()
            } label: {
                HStack(spacing: 10) {
                    if saving {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(saving ? "Saving..." : "Save Meal to History")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(colors: [.untGreenMedium, .untGreenDark], startPoint: .leading, endPoint: .trailing)
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color.untGreenDark.opacity(0.4), radius: 14, x: 0, y: 6)
                .padding(.horizontal, 16)
            }
            .buttonStyle(SpringButtonStyle())
            .disabled(saving)
        }
        .padding(.bottom, 20)
        .background(
            LinearGradient(colors: [Color.untGreenBackground.opacity(0), Color.untGreenBackground],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .frame(height: 200)
                .offset(y: 20)
        )
    }

    // MARK: - Save Action

    private func saveMeal() {
        withAnimation(.spring(response: 0.3)) { saving = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            savedMeal = plateVM.saveMeal(persistence: PersistenceService.shared)
            historyVM.load()
            withAnimation(.spring(response: 0.3)) { saving = false }
            showSaveConfirmation = true
        }
    }
}

// MARK: - Plate Item Row

struct PlateItemRow: View {
    let plateItem: PlateItem
    let plateVM:   PlateViewModel

    @State private var removing = false

    var body: some View {
        HStack(spacing: 14) {
            // Category icon
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.untGreenPale)
                    .frame(width: 42, height: 42)
                Image(systemName: plateItem.menuItem.category.icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.untGreenPrimary)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(plateItem.menuItem.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("\(Int(plateItem.totalNutrition.calories)) cal")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.macroCalories)
                    Text("•")
                        .foregroundStyle(Color.textTertiary)
                    Text("P:\(Int(plateItem.totalNutrition.protein))g C:\(Int(plateItem.totalNutrition.carbohydrates))g F:\(Int(plateItem.totalNutrition.fat))g")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                }
            }

            Spacer()

            // Quantity stepper
            HStack(spacing: 4) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                        plateVM.remove(plateItem.menuItem)
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.borderMedium)
                }

                Text("\(plateItem.quantity)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 20)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: plateItem.quantity)

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                        plateVM.add(plateItem.menuItem, from: DiningHall.sampleHalls.first(where: { $0.id == plateItem.menuItem.diningHallId }) ?? DiningHall.sampleHalls[0])
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.untGreenPrimary)
                }
            }
        }
        .padding(14)
        .background(Color.surfaceBase)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
        .scaleEffect(removing ? 0.96 : 1.0)
        .opacity(removing ? 0.7 : 1.0)
    }
}

// MARK: - Secondary Macro Chip

struct SecondaryMacroChip: View {
    let label: String
    let value: Int
    let unit:  String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            VStack(spacing: 1) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(value)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                        .contentTransition(.numericText())
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(color.opacity(0.7))
                    }
                }
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        )
    }
}
