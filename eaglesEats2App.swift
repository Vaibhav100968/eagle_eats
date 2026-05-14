import SwiftUI

@main
struct eaglesEats2App: App {

    // MARK: - Core Services
    @StateObject private var appState      = AppState.shared
    @StateObject private var diningService = DiningService.shared
    @StateObject private var plateVM       = PlateViewModel()
    @StateObject private var historyVM     = HistoryViewModel()

    // MARK: - Intelligence Engines (Phase 1-8)
    // Holding @StateObject references ensures the singletons are created at
    // app launch and their @Published state drives UI reactivity correctly.
    @StateObject private var budgetEngine      = BudgetEngine.shared
    @StateObject private var recEngine         = RecommendationEngine.shared
    @StateObject private var weeklyProfile     = WeeklyProfileService.shared
    @StateObject private var analyticsEngine   = AnalyticsEngine.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(diningService)
                .environmentObject(plateVM)
                .environmentObject(historyVM)
                .preferredColorScheme(.light)
                .task {
                    // Warm up behavioral engines after the app is running so
                    // persisted history is available for initial computations.
                    await warmUpEngines()
                }
        }
    }

    @MainActor
    private func warmUpEngines() async {
        weeklyProfile.refresh()
        analyticsEngine.refresh()
        // BudgetEngine and RecommendationEngine refresh reactively when
        // MealPlanService / DiningService post new data.
    }
}
