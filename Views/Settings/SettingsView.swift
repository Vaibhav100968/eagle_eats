import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject private var appState:      AppState
    @EnvironmentObject private var diningService: DiningService

    @StateObject private var weeklyProfile    = WeeklyProfileService.shared
    @StateObject private var analytics        = AnalyticsEngine.shared
    @StateObject private var biometricService = BiometricService.shared
    @StateObject private var notifService     = NotificationService.shared

    @State private var settings:              AppSettings  = AppSettings()
    @State private var showAbout:             Bool         = false
    @State private var appeared:              Bool         = false
    @State private var showExport:            Bool         = false
    @State private var exportJSON:            String       = ""
    @State private var biometricEnabled:      Bool         = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.untSubtleGradient.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // MARK: Account Card
                        accountCard
                            .padding(.horizontal, 20)
                            .staggerIn(visible: appeared, delay: 0.05)

                        // MARK: Nutrition Goals
                        SettingsSection(title: "Nutrition Goals", icon: "chart.pie.fill") {
                            NutritionGoalRow(label: "Daily Calories", unit: "kcal", value: $settings.dailyCalorieGoal, range: 1000...4000, step: 50, color: .macroCalories)
                            Divider().padding(.leading, 54)
                            NutritionGoalRow(label: "Daily Protein",  unit: "g",    value: $settings.dailyProteinGoal,  range: 50...300,   step: 5,  color: .macroProtein)
                            Divider().padding(.leading, 54)
                            NutritionGoalRow(label: "Daily Carbs",    unit: "g",    value: $settings.dailyCarbGoal,     range: 50...500,   step: 10, color: .macroCarbs)
                            Divider().padding(.leading, 54)
                            NutritionGoalRow(label: "Daily Fat",      unit: "g",    value: $settings.dailyFatGoal,      range: 20...150,   step: 5,  color: .macroFat)
                        }
                        .padding(.horizontal, 20)
                        .staggerIn(visible: appeared, delay: 0.12)

                        // MARK: Dining Preferences
                        SettingsSection(title: "Dining Preferences", icon: "fork.knife.circle.fill") {
                            DietaryFilterRow(filters: $settings.dietaryFilters)
                        }
                        .padding(.horizontal, 20)
                        .staggerIn(visible: appeared, delay: 0.18)

                        // MARK: Allergen Profile
                        SettingsSection(title: "My Allergens", icon: "exclamationmark.triangle.fill") {
                            AllergenProfileRow(exclusions: $settings.allergenExclusions)
                        }
                        .padding(.horizontal, 20)
                        .staggerIn(visible: appeared, delay: 0.20)

                        // MARK: Notifications
                        SettingsSection(title: "Notifications", icon: "bell.badge.fill") {
                            SettingsToggleRow(
                                icon: "bell.fill",
                                label: "Enable Notifications",
                                color: Color(hex: "F59E0B"),
                                value: $settings.notificationsEnabled
                            )

                            if settings.notificationsEnabled {
                                Divider().padding(.leading, 54)
                                SettingsToggleRow(
                                    icon: "clock.fill",
                                    label: "Meal Period Reminders",
                                    color: .macroCarbs,
                                    value: $settings.mealRemindersEnabled
                                )
                                if settings.mealRemindersEnabled {
                                    ReminderTimePicker(minutes: $settings.reminderMinutesBefore)
                                }
                                Divider().padding(.leading, 54)
                                SettingsToggleRow(
                                    icon: "heart.fill",
                                    label: "Favorite Hall Opens",
                                    color: .statusClosed,
                                    value: $settings.hallOpenAlerts
                                )
                                Divider().padding(.leading, 54)
                                SettingsToggleRow(
                                    icon: "sparkles",
                                    label: "Morning Menu Summary",
                                    color: .untGreenPrimary,
                                    value: $settings.menuHighlights
                                )
                                Divider().padding(.leading, 54)
                                FavoriteItemsEditor(items: $settings.favoriteItemNames)
                            }
                        }
                        .padding(.horizontal, 20)
                        .staggerIn(visible: appeared, delay: 0.22)
                        .onChange(of: settings.notificationsEnabled) { _, enabled in
                            if enabled {
                                Task { await NotificationService.shared.requestAuthorization() }
                            }
                        }

                        // MARK: App Preferences
                        SettingsSection(title: "Appearance", icon: "paintbrush.fill") {
                            AppearancePicker(preference: $settings.darkModePreference)
                            Divider().padding(.leading, 54)
                            SettingsToggleRow(
                                icon: "figure.walk",
                                label: "Reduced Motion",
                                color: .macroCarbs,
                                value: $settings.reducedMotion
                            )
                        }
                        .padding(.horizontal, 20)
                        .staggerIn(visible: appeared, delay: 0.24)

                        // MARK: Dining Halls Status
                        SettingsSection(title: "Dining Hall Status", icon: "building.2.fill") {
                            DiningHallStatusList(halls: diningService.halls)
                        }
                        .padding(.horizontal, 20)
                        .staggerIn(visible: appeared, delay: 0.28)

                        // MARK: Weekly Insights
                        if !weeklyProfile.profile.insights.isEmpty {
                            SettingsSection(title: "Your Patterns", icon: "chart.bar.fill") {
                                VStack(spacing: 0) {
                                    ForEach(Array(weeklyProfile.profile.insights.enumerated()), id: \.element.id) { index, insight in
                                        HStack(spacing: 12) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .fill(Color(hex: insight.color).opacity(0.15))
                                                    .frame(width: 36, height: 36)
                                                Image(systemName: insight.icon)
                                                    .font(.system(size: 15, weight: .semibold))
                                                    .foregroundStyle(Color(hex: insight.color))
                                            }
                                            Text(insight.text)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(Color.textPrimary)
                                            Spacer()
                                        }
                                        .padding(.vertical, 8)
                                        if index < weeklyProfile.profile.insights.count - 1 {
                                            Divider().padding(.leading, 54)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .staggerIn(visible: appeared, delay: 0.32)
                        }

                        // MARK: Dining Analytics
                        SettingsSection(title: "Dining Analytics", icon: "chart.xyaxis.line") {
                            if analytics.report.totalMealsLogged > 0 {
                                HStack(spacing: 16) {
                                    AnalyticsStat(label: "Meals", value: "\(analytics.report.totalMealsLogged)", color: .untGreenPrimary)
                                    AnalyticsStat(label: "Avg Cal", value: "\(Int(analytics.report.averageCaloriesPerMeal))", color: .macroCalories)
                                    AnalyticsStat(label: "Protein", value: "\(Int(analytics.report.totalProteinTracked))g", color: .macroProtein)
                                }
                                .padding(.vertical, 8)
                                Divider()
                            }
                            SettingsLinkRow(icon: "square.and.arrow.up", label: "Export Analytics JSON", color: .macroCarbs) {
                                analytics.refresh()
                                if let json = analytics.exportJSON() {
                                    exportJSON = json
                                    showExport = true
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .staggerIn(visible: appeared, delay: 0.36)

                        // MARK: Feedback
                        SettingsSection(title: "Dining Feedback", icon: "text.bubble.fill") {
                            NavigationLink {
                                FeedbackView()
                            } label: {
                                SettingsNavRow(icon: "square.and.pencil", label: "Submit Feedback", color: .untGreenPrimary)
                            }
                        }
                        .padding(.horizontal, 20)
                        .staggerIn(visible: appeared, delay: 0.38)

                        // MARK: Security
                        SettingsSection(title: "Security", icon: "lock.shield.fill") {
                            SettingsToggleRow(
                                icon: biometricService.biometryIcon,
                                label: biometricService.biometryName,
                                color: .untGreenPrimary,
                                value: $biometricEnabled
                            )
                        }
                        .padding(.horizontal, 20)
                        .staggerIn(visible: appeared, delay: 0.39)

                        // MARK: About & Support
                        SettingsSection(title: "About", icon: "info.circle.fill") {
                            SettingsLinkRow(icon: "globe", label: "UNT Dining Website", color: .macroCarbs) {
                                if let url = URL(string: "https://dining.unt.edu") {
                                    UIApplication.shared.open(url)
                                }
                            }
                            Divider().padding(.leading, 54)
                            SettingsLinkRow(icon: "envelope.fill", label: "Send Feedback", color: .untGreenPrimary) {}
                            Divider().padding(.leading, 54)
                            SettingsInfoRow(icon: "app.badge.fill", label: "Version", value: "1.0.0", color: .textTertiary)
                        }
                        .padding(.horizontal, 20)
                        .staggerIn(visible: appeared, delay: 0.40)

                        // Data refresh
                        if let updated = diningService.lastUpdated {
                            Text("Menu data last updated: \(updated.formatted(date: .omitted, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(Color.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }

                        Spacer().frame(height: 90)
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onChange(of: settings) { _, new in
                appState.update(settings: new)
            }
        }
        .sheet(isPresented: $showExport) {
            AnalyticsExportSheet(json: exportJSON)
        }
        .onAppear {
            settings = appState.settings
            weeklyProfile.refresh()
            analytics.refresh()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.1)) {
                appeared = true
            }
        }
    }

    // MARK: - Account Card

    private var accountCard: some View {
        VStack(spacing: 0) {
            let displayName: String = {
                if case .signedIn(_, let name) = appState.authState { return name ?? "UNT Student" }
                return "UNT Student"
            }()
            let identifier: String = {
                if case .signedIn(let id, _) = appState.authState { return id }
                return ""
            }()
            let avatarLetter = String(displayName.prefix(1)).uppercased()

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient.untCardGradient)
                        .frame(width: 56, height: 56)
                    Text(avatarLetter)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.untGreenPrimary)
                        Text("UNT Authenticated")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        appState.signOut()
                    }
                } label: {
                    Text("Sign Out")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.statusClosed)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.statusClosed.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(18)
        }
        .background(Color.surfaceBase)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Settings Section

struct SettingsSection<Content: View>: View {
    let title:   String
    let icon:    String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.untGreenPrimary)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                    .textCase(.uppercase)
                    .letterSpacing(0.5)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            VStack(spacing: 0) {
                content()
                    .padding(.vertical, 6)
            }
            .padding(.horizontal, 16)
            .background(Color.surfaceBase)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
        }
    }
}

// MARK: - Nutrition Goal Row

private struct NutritionGoalRow: View {
    let label: String
    let unit:  String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step:  Double
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(unit.prefix(1))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(color)
                )
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.textPrimary)
            Spacer()
            HStack(spacing: 8) {
                Button {
                    if value > range.lowerBound { value -= step }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.borderMedium)
                }
                Text("\(Int(value))")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .frame(width: 48, alignment: .center)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: value)
                Button {
                    if value < range.upperBound { value += step }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(color)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Dietary Filter Row

private struct DietaryFilterRow: View {
    @Binding var filters: [String]

    let options: [(String, String, String)] = [
        ("vegan",        "Vegan",        "leaf.fill"),
        ("vegetarian",   "Vegetarian",   "leaf"),
        ("gluten-free",  "Gluten Free",  "checkmark.seal.fill"),
        ("high-protein", "High Protein", "bolt.fill"),
        ("dairy-free",   "Dairy Free",   "drop.fill"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Show items matching:")
                .font(.system(size: 13))
                .foregroundStyle(Color.textTertiary)
                .padding(.top, 4)

            FlowLayout(spacing: 8) {
                ForEach(options, id: \.0) { id, label, icon in
                    let isOn = filters.contains(id)
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if isOn { filters.removeAll { $0 == id } }
                            else    { filters.append(id) }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(label)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(isOn ? Color.untGreenPrimary : Color.surfaceRaised)
                        .foregroundStyle(isOn ? .white : Color.textSecondary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(SpringButtonStyle())
                }
            }
            .padding(.bottom, 6)
        }
    }
}

// MARK: - Allergen Profile Row

private struct AllergenProfileRow: View {
    @Binding var exclusions: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Items containing these allergens will be flagged:")
                .font(.system(size: 13))
                .foregroundStyle(Color.textTertiary)
                .padding(.top, 4)

            FlowLayout(spacing: 8) {
                ForEach(Allergen.allCases) { allergen in
                    let isOn = exclusions.contains(allergen.rawValue)
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if isOn { exclusions.removeAll { $0 == allergen.rawValue } }
                            else    { exclusions.append(allergen.rawValue) }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: allergen.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(allergen.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(isOn ? Color.statusClosed : Color.surfaceRaised)
                        .foregroundStyle(isOn ? .white : Color.textSecondary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(SpringButtonStyle())
                }
            }

            if !exclusions.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.statusClosed)
                    Text("Menu items with these allergens will show a warning badge")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(.top, 2)
            }
        }
        .padding(.bottom, 6)
    }
}

// MARK: - Toggle Row

private struct SettingsToggleRow: View {
    let icon:  String
    let label: String
    let color: Color
    @Binding var value: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Toggle("", isOn: $value)
                .tint(Color.untGreenPrimary)
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Link Row

private struct SettingsLinkRow: View {
    let icon:   String
    let label:  String
    let color:  Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(color)
                }
                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Info Row

private struct SettingsInfoRow: View {
    let icon:  String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.surfaceRaised)
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Text(value)
                .font(.system(size: 14))
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Nav Row (for NavigationLink labels)

struct SettingsNavRow: View {
    let icon:  String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Dining Hall Status List (extracted to avoid ForEach binding inference issues)

private struct DiningHallStatusList: View {
    let halls: [DiningHall]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(halls.enumerated()), id: \.element.id) { index, hall in
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(hex: hall.gradientStart).opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: hall.iconName)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color(hex: hall.gradientStart))
                    }
                    Text(hall.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Text(hall.isOpen ? hall.currentMealPeriod.rawValue : "Closed")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(hall.isOpen ? Color.statusOpen : Color.statusClosed)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background((hall.isOpen ? Color.statusOpen : Color.statusClosed).opacity(0.1))
                        .clipShape(Capsule())
                }
                .padding(.vertical, 8)

                if index < halls.count - 1 {
                    Divider().padding(.leading, 54)
                }
            }
        }
    }
}

// MARK: - Analytics Stat

private struct AnalyticsStat: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Analytics Export Sheet

struct AnalyticsExportSheet: View {
    let json: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.untGreenPrimary)
                        Text("Dining Analytics Report")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.textPrimary)
                    }

                    Text("This data can be shared with UNT Dining Services to help improve campus dining. No personal information is included.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)

                    Text(json)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.textSecondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.surfaceRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button {
                        UIPasteboard.general.string = json
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.on.doc.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Copy to Clipboard")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(LinearGradient(colors: [.untGreenMedium, .untGreenDark], startPoint: .leading, endPoint: .trailing))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.untGreenDark.opacity(0.3), radius: 10, x: 0, y: 4)
                    }
                    .buttonStyle(SpringButtonStyle())

                    ShareLink(item: json) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Share Report")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.surfaceBase)
                        .foregroundStyle(Color.untGreenPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.untGreenPrimary.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(SpringButtonStyle())
                }
                .padding(20)
            }
            .background(Color.untGreenBackground.ignoresSafeArea())
            .navigationTitle("Analytics Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.untGreenPrimary)
                }
            }
        }
    }
}

// MARK: - Appearance Picker

private struct AppearancePicker: View {
    @Binding var preference: String

    private let options: [(id: String, label: String, icon: String)] = [
        ("system", "System", "gear"),
        ("light",  "Light",  "sun.max.fill"),
        ("dark",   "Dark",   "moon.fill"),
    ]

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(hex: "8B5CF6").opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "8B5CF6"))
            }
            Text("Theme")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.textPrimary)
            Spacer()
            HStack(spacing: 4) {
                ForEach(options, id: \.id) { option in
                    let isSelected = preference == option.id
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            preference = option.id
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: option.icon)
                                .font(.system(size: 10, weight: .semibold))
                            Text(option.label)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isSelected ? Color(hex: "8B5CF6") : Color.surfaceRaised)
                        .foregroundStyle(isSelected ? .white : Color.textTertiary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(SpringButtonStyle())
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Reminder Time Picker

private struct ReminderTimePicker: View {
    @Binding var minutes: Int

    let options = [5, 10, 15, 30, 60]

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "timer")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.textTertiary)
            Text("Remind me")
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)
            Spacer()
            HStack(spacing: 6) {
                ForEach(options, id: \.self) { opt in
                    let isSelected = minutes == opt
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            minutes = opt
                        }
                    } label: {
                        Text(opt < 60 ? "\(opt)m" : "1h")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(isSelected ? Color.macroCarbs : Color.surfaceRaised)
                            .foregroundStyle(isSelected ? .white : Color.textTertiary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(SpringButtonStyle())
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.leading, 54)
    }
}

// MARK: - Favorite Items Editor

private struct FavoriteItemsEditor: View {
    @Binding var items: [String]
    @State private var newItem: String = ""
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().padding(.leading, 54)

            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(hex: "F59E0B").opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "star.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: "F59E0B"))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Favorite Items")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.textPrimary)
                    Text("Get notified when these appear on the menu")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textTertiary)
                }
            }
            .padding(.vertical, 4)

            // Current items
            if !items.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(items, id: \.self) { item in
                        HStack(spacing: 4) {
                            Text(item)
                                .font(.system(size: 12, weight: .semibold))
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    items.removeAll { $0 == item }
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                            }
                        }
                        .foregroundStyle(Color(hex: "F59E0B"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(hex: "F59E0B").opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
                .padding(.leading, 54)
            }

            // Add new item
            HStack(spacing: 8) {
                TextField("e.g. Mac and Cheese", text: $newItem)
                    .font(.system(size: 14))
                    .focused($isFieldFocused)
                    .onSubmit { addItem() }

                if !newItem.isEmpty {
                    Button { addItem() } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.untGreenPrimary)
                    }
                    .buttonStyle(SpringButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.leading, 54)
        }
    }

    private func addItem() {
        let trimmed = newItem.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !items.contains(trimmed) else { return }
        withAnimation(.spring(response: 0.3)) {
            items.append(trimmed)
            newItem = ""
        }
        isFieldFocused = false
    }
}

// MARK: - Stagger In Modifier

extension View {
    func staggerIn(visible: Bool, delay: Double) -> some View {
        self
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 16)
            .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(delay), value: visible)
    }
}
