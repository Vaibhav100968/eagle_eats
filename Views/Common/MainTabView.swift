import SwiftUI

// MARK: - Main Tab View
// Tab order: Home | Plate | Meal Plan (Swipes & Flex) | Settings
// History has been moved inside the Plate tab (accessible via toolbar button).

struct MainTabView: View {
    @EnvironmentObject private var plateVM:   PlateViewModel
    @EnvironmentObject private var historyVM: HistoryViewModel

    @State private var selectedTab: Tab = .home
    @State private var tabVisible:  Bool = false

    enum Tab: Int, CaseIterable {
        case home      = 0
        case plate     = 1
        case mealPlan  = 2
        case settings  = 3

        var title: String {
            switch self {
            case .home:     return "Home"
            case .plate:    return "Plate"
            case .mealPlan: return "Meal Plan"
            case .settings: return "Settings"
            }
        }

        var icon: String {
            switch self {
            case .home:     return "house.fill"
            case .plate:    return "fork.knife"
            case .mealPlan: return "creditcard.fill"
            case .settings: return "gearshape.fill"
            }
        }

        var inactiveIcon: String {
            switch self {
            case .home:     return "house"
            case .plate:    return "fork.knife"
            case .mealPlan: return "creditcard"
            case .settings: return "gearshape"
            }
        }

        var color: Color {
            switch self {
            case .home:     return .untGreenPrimary
            case .plate:    return .untGreenMedium
            case .mealPlan: return .macroCarbs
            case .settings: return .textSecondary
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tag(Tab.home)
                    .toolbar(.hidden, for: .tabBar)

                PlateTabView()
                    .tag(Tab.plate)
                    .toolbar(.hidden, for: .tabBar)

                MealPlanTab()
                    .tag(Tab.mealPlan)
                    .toolbar(.hidden, for: .tabBar)

                SettingsView()
                    .tag(Tab.settings)
                    .toolbar(.hidden, for: .tabBar)
            }

            customTabBar
                .opacity(tabVisible ? 1 : 0)
                .offset(y: tabVisible ? 0 : 60)
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.3)) {
                tabVisible = true
            }
        }
        .sheet(isPresented: $plateVM.showingPlateSheet) {
            PlateBuilderView()
        }
    }

    // MARK: - Custom Tab Bar

    private var customTabBar: some View {
        VStack(spacing: 0) {
            Divider()
                .opacity(0.3)
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.rawValue) { tab in
                    TabBarItem(
                        tab:          tab,
                        selectedTab:  $selectedTab,
                        badgeCount:   tab == .plate ? plateVM.itemCount : 0
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 2)
        }
        .background(
            Color.surfaceBase
                .shadow(.drop(color: .black.opacity(0.08), radius: 8, x: 0, y: -4))
        )
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Tab Bar Item

private struct TabBarItem: View {
    let tab:          MainTabView.Tab
    @Binding var selectedTab: MainTabView.Tab
    var badgeCount:   Int = 0

    @State private var bouncing = false

    var isSelected: Bool { selectedTab == tab }

    var body: some View {
        Button {
            guard !isSelected else { return }
            HapticService.shared.selection()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.62)) {
                bouncing    = true
                selectedTab = tab
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) { bouncing = false }
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(tab.color.opacity(0.12))
                            .frame(width: 44, height: 30)
                            .transition(.scale.combined(with: .opacity))
                    }
                    Image(systemName: isSelected ? tab.icon : tab.inactiveIcon)
                        .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? tab.color : Color.textTertiary)
                        .contentTransition(.symbolEffect(.replace.downUp))
                        .scaleEffect(isSelected ? 1.08 : 1.0)
                        .scaleEffect(bouncing ? 1.25 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                }
                .frame(width: 44, height: 30)

                Text(tab.title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? tab.color : Color.textTertiary)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
            }
            .frame(maxWidth: .infinity)
            .overlay(alignment: .topTrailing) {
                if badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(tab.color)
                        .clipShape(Capsule())
                        .offset(x: 14, y: -4)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: selectedTab)
    }
}

// MARK: - Plate Tab (with History access via toolbar)

private struct PlateTabView: View {
    @EnvironmentObject private var plateVM:   PlateViewModel
    @EnvironmentObject private var historyVM: HistoryViewModel
    @EnvironmentObject private var appState:  AppState

    @State private var showHistory = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.untGreenBackground.ignoresSafeArea()

                if plateVM.plate.isEmpty {
                    emptyState
                } else {
                    PlateBuilderContent(historyVM: historyVM)
                }
            }
            .navigationTitle("My Plate")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.untGreenPrimary)
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                NavigationStack {
                    MealHistoryView()
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") { showHistory = false }
                                    .foregroundStyle(Color.untGreenPrimary)
                            }
                        }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle().fill(Color.untGreenPale).frame(width: 100, height: 100)
                Image(systemName: "fork.knife")
                    .font(.system(size: 42, weight: .light)).foregroundStyle(Color.untGreenMint)
            }
            VStack(spacing: 8) {
                Text("Your plate is empty")
                    .font(.headingMedium).foregroundStyle(Color.textPrimary)
                Text("Browse a dining hall and add items to start building your plate and tracking macros")
                    .font(.bodyMedium).foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Plate Builder Content (inline tab view)

private struct PlateBuilderContent: View {
    let historyVM: HistoryViewModel

    @EnvironmentObject private var plateVM:   PlateViewModel
    @EnvironmentObject private var appState:  AppState

    @StateObject private var recEngine = RecommendationEngine.shared

    @State private var saving     = false
    @State private var savedAlert = false
    @State private var savedMeal: SavedMeal? = nil
    @State private var listVisible = false

    private var plateSuggestions: [ScoredMenuItem] {
        recEngine.suggestionsToCompletePlate(plate: plateVM.plate, settings: appState.settings)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                MacroRingsRow(plate: plateVM.plate, settings: appState.settings)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                // Smart plate advice
                SmartPlateAdvice(
                    plate: plateVM.plate,
                    settings: appState.settings,
                    suggestions: plateSuggestions
                )
                .padding(.horizontal, 20)

                HStack(spacing: 12) {
                    SecondaryMacroChip(label: "Fiber",  value: Int(plateVM.plate.totalFiber),  unit: "g",  color: .macroFiber)
                    SecondaryMacroChip(label: "Sodium", value: Int(plateVM.plate.totalSodium), unit: "mg", color: .textSecondary)
                    SecondaryMacroChip(label: "Items",  value: plateVM.plate.itemCount,        unit: "",   color: .untGreenPrimary)
                }
                .padding(.horizontal, 20)

                ForEach(Array(plateVM.plate.items.enumerated()), id: \.element.id) { index, pItem in
                    PlateItemRow(plateItem: pItem, plateVM: plateVM)
                        .padding(.horizontal, 20)
                        .opacity(listVisible ? 1 : 0)
                        .offset(y: listVisible ? 0 : 18)
                        .animation(.spring(response: 0.45, dampingFraction: 0.8).delay(Double(index) * 0.05), value: listVisible)
                }

                Button {
                    saving = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        savedMeal = plateVM.saveMeal(persistence: PersistenceService.shared)
                        historyVM.load()
                        saving = false
                        savedAlert = true
                        HapticService.shared.success()
                    }
                } label: {
                    HStack(spacing: 10) {
                        if saving {
                            ProgressView().tint(.white).scaleEffect(0.85)
                        } else {
                            Image(systemName: "bookmark.fill")
                        }
                        Text(saving ? "Saving..." : "Save Meal to History")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(LinearGradient(colors: [.untGreenMedium, .untGreenDark], startPoint: .leading, endPoint: .trailing))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Color.untGreenDark.opacity(0.4), radius: 14, x: 0, y: 6)
                    .padding(.horizontal, 20)
                }
                .buttonStyle(SpringButtonStyle())
                .disabled(saving)

                Spacer().frame(height: 90)
            }
            .padding(.vertical, 16)
        }
        .alert("Meal Saved!", isPresented: $savedAlert) {
            Button("OK") {}
        } message: {
            if let m = savedMeal {
                Text("\(m.diningHallName) • \(Int(m.totalCalories)) kcal saved to history")
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) { listVisible = true }
        }
    }
}
