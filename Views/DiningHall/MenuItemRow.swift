import SwiftUI

// MARK: - Menu Item Row

struct MenuItemRow: View {
    let item:              MenuItem
    let hall:              DiningHall
    let plateVM:           PlateViewModel
    let onNutritionTap:    () -> Void
    var userAllergenExclusions: Set<String> = []

    @EnvironmentObject private var diningService: DiningService

    @State private var isAdding:         Bool    = false
    @State private var addScale:         CGFloat = 1.0
    @State private var checkmark:        Bool    = false
    @State private var expanded:         Bool    = false
    @State private var nutritionLoading: Bool    = false
    @State private var reportedAvailable: Bool?  = nil

    // Live item from service (updates when nutrition is fetched)
    private var liveItem: MenuItem {
        diningService.menusByHall[item.diningHallId]?
            .first(where: { $0.id == item.id }) ?? item
    }

    private var inPlate: Bool    { plateVM.plate.contains(item) }
    private var qty: Int         { plateVM.plate.quantity(of: item) }

    var body: some View {
        let current = liveItem
        return VStack(spacing: 0) {
            // MARK: Main Row
            HStack(alignment: .top, spacing: 14) {
                // Category icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(hall.gradientColors[0].opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: current.category.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(hall.gradientColors[0])
                }

                // Info
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(current.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(2)
                        if current.isPopular {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Color(hex: "F59E0B"))
                        }
                        Spacer()
                    }

                    // Macro quick bar (shown only once nutrition is loaded)
                    if current.nutritionLoaded && current.nutrition.isComplete {
                        macroBar(for: current)
                    } else if nutritionLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(hall.gradientColors[0])
                    }

                    // Tags
                    if !current.dietaryTags.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(current.dietaryTags.prefix(3)) { tag in
                                Text(tag.label)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color(hex: tag.color))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Color(hex: tag.color).opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    // Allergen warning badges
                    if current.nutritionLoaded && current.nutrition.hasAllergens {
                        AllergenBadgeRow(
                            allergens: current.nutrition.allergens,
                            userExclusions: userAllergenExclusions
                        )
                    }

                    // Calories
                    Text(current.caloriesDisplay)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.textTertiary)
                }

                // Add button / quantity
                addControl(for: current)
            }
            .padding(16)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    expanded.toggle()
                }
                // Trigger nutrition fetch on first expand
                if !current.nutritionLoaded && !nutritionLoading {
                    nutritionLoading = true
                    Task {
                        await diningService.fetchNutrition(for: current)
                        await MainActor.run { nutritionLoading = false }
                    }
                }
            }

            // MARK: Expanded Nutrition
            if expanded {
                expandedNutrition(for: liveItem)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(Color.surfaceBase)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: inPlate ? Color.untGreenPrimary.opacity(0.15) : .black.opacity(0.05),
                radius: inPlate ? 12 : 8, x: 0, y: inPlate ? 4 : 3)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    inPlate ? Color.untGreenPrimary.opacity(0.35) : Color.clear,
                    lineWidth: 1.5
                )
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: inPlate)
    }

    // MARK: - Macro Bar

    private func macroBar(for current: MenuItem) -> some View {
        HStack(spacing: 8) {
            MacroChip(label: "P", value: Int(current.nutrition.protein),       unit: "g", color: .macroProtein)
            MacroChip(label: "C", value: Int(current.nutrition.carbohydrates), unit: "g", color: .macroCarbs)
            MacroChip(label: "F", value: Int(current.nutrition.fat),           unit: "g", color: .macroFat)
        }
    }

    // MARK: - Add Control

    private func addControl(for current: MenuItem) -> some View {
        VStack(spacing: 6) {
            if inPlate && qty > 0 {
                // Quantity stepper
                HStack(spacing: 0) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                            plateVM.remove(item)
                        }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.untGreenPrimary)
                            .frame(width: 30, height: 30)
                    }

                    Text("\(qty)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.textPrimary)
                        .frame(width: 22)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3), value: qty)

                    Button {
                        triggerAdd()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.untGreenPrimary)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .background(Color.untGreenBackground)
                .clipShape(Capsule())
                .scaleEffect(addScale)
                .transition(.scale(scale: 0.7).combined(with: .opacity))

            } else {
                // Add button
                Button { triggerAdd() } label: {
                    ZStack {
                        Circle()
                            .fill(Color.untGreenPrimary)
                            .frame(width: 36, height: 36)
                        if checkmark {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(SpringButtonStyle())
                .scaleEffect(addScale)
            }

            // Nutrition info button
            Button { onNutritionTap() } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textTertiary)
            }
        }
    }

    // MARK: - Expanded Nutrition

    private func expandedNutrition(for current: MenuItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider().padding(.horizontal, 16)

            if !current.description.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ingredients")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.textTertiary)
                    Text(current.description)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(3)
                }
                .padding(.horizontal, 16)
            }

            if current.nutritionLoaded && current.nutrition.isComplete {
                HStack(spacing: 10) {
                    ExpandedMacroItem(label: "Calories",  value: Int(current.nutrition.calories),      unit: "kcal", color: .macroCalories)
                    ExpandedMacroItem(label: "Protein",   value: Int(current.nutrition.protein),        unit: "g",    color: .macroProtein)
                    ExpandedMacroItem(label: "Carbs",     value: Int(current.nutrition.carbohydrates),  unit: "g",    color: .macroCarbs)
                    ExpandedMacroItem(label: "Fat",       value: Int(current.nutrition.fat),            unit: "g",    color: .macroFat)
                }
                .padding(.horizontal, 16)

                if let serving = current.nutrition.servingSize {
                    Text("Per \(serving) serving")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textTertiary)
                        .padding(.horizontal, 16)
                }
            } else if nutritionLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(hall.gradientColors[0])
                    Text("Loading nutrition…")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(.horizontal, 16)
            } else if !current.nutritionLoaded {
                Text("Nutrition info not available")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
                    .padding(.horizontal, 16)
            }

            // Crowdsourced availability
            availabilitySection(for: current)
                .padding(.horizontal, 16)
        }
        .padding(.bottom, 14)
    }

    // MARK: - Availability Section

    private func availabilitySection(for current: MenuItem) -> some View {
        let status = PersistenceService.shared.availabilityStatus(for: current.id)

        return VStack(spacing: 8) {
            Divider()

            HStack(spacing: 10) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
                Text("Is this item available?")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                Spacer()

                HStack(spacing: 6) {
                    Button {
                        submitAvailability(itemId: current.id, available: true)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                            Text("Yes")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(reportedAvailable == true ? Color.statusOpen : Color.statusOpen.opacity(0.1))
                        .foregroundStyle(reportedAvailable == true ? .white : Color.statusOpen)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(SpringButtonStyle())

                    Button {
                        submitAvailability(itemId: current.id, available: false)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                            Text("No")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(reportedAvailable == false ? Color.statusClosed : Color.statusClosed.opacity(0.1))
                        .foregroundStyle(reportedAvailable == false ? .white : Color.statusClosed)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(SpringButtonStyle())
                }
            }

            if status.reportsToday > 0 {
                HStack(spacing: 4) {
                    Image(systemName: status.shouldFlag ? "exclamationmark.triangle.fill" : "person.2.fill")
                        .font(.system(size: 10))
                    Text(status.shouldFlag
                         ? "Reported unavailable by \(status.unavailableCount) user\(status.unavailableCount == 1 ? "" : "s")"
                         : "\(status.reportsToday) report\(status.reportsToday == 1 ? "" : "s") today")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(status.shouldFlag ? Color.statusClosed : Color.textTertiary)
            }
        }
    }

    private func submitAvailability(itemId: String, available: Bool) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            reportedAvailable = available
        }
        let report = AvailabilityReport(menuItemId: itemId, isAvailable: available)
        PersistenceService.shared.saveAvailabilityReport(report)
    }

    // MARK: - Add Animation

    private func triggerAdd() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            addScale = 1.18
            checkmark = true
        }
        plateVM.add(item, from: hall)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                addScale = 1.0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.3)) { checkmark = false }
        }
    }
}

// MARK: - Macro Chip (inline)

struct MacroChip: View {
    let label: String
    let value: Int
    let unit:  String
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
            Text("\(value)\(unit)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
        }
    }
}

// MARK: - Expanded Macro Item

private struct ExpandedMacroItem: View {
    let label: String
    let value: Int
    let unit:  String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(unit)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color.opacity(0.6))
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Allergen Badge Row

struct AllergenBadgeRow: View {
    let allergens: [Allergen]
    var userExclusions: Set<String> = []

    var body: some View {
        HStack(spacing: 4) {
            ForEach(allergens.prefix(5)) { allergen in
                let isDanger = userExclusions.contains(allergen.rawValue)
                HStack(spacing: 3) {
                    if isDanger {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 8, weight: .bold))
                    }
                    Text(allergen.rawValue)
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(isDanger ? .white : Color(hex: allergen.color))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(isDanger ? Color.statusClosed : Color(hex: allergen.color).opacity(0.12))
                .clipShape(Capsule())
            }
            if allergens.count > 5 {
                Text("+\(allergens.count - 5)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.surfaceRaised)
                    .clipShape(Capsule())
            }
        }
    }
}
