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
                .preferredColorScheme(resolvedColorScheme)
                .task {
                    await warmUpEngines()
                    await scheduleNotifications()
                }
        }
    }

    private var resolvedColorScheme: ColorScheme? {
        switch appState.settings.darkModePreference {
        case "dark":  return .dark
        case "light": return .light
        default:      return nil  // follow system
        }
    }

    @MainActor
    private func warmUpEngines() async {
        weeklyProfile.refresh()
        analyticsEngine.refresh()
    }

    @MainActor
    private func scheduleNotifications() async {
        let notifService = NotificationService.shared
        await notifService.checkAuthorization()

        guard notifService.isAuthorized else { return }

        let settings = appState.settings
        let favoriteIds = PersistenceService.shared.loadFavoriteHallIds()

        notifService.refreshAllNotifications(
            settings: settings,
            favoriteHallIds: favoriteIds,
            halls: diningService.halls
        )

        // Check for favorite menu items after menus are loaded
        let allItems = diningService.menusByHall.values.flatMap { $0 }
        if !allItems.isEmpty && !settings.favoriteItemNames.isEmpty {
            notifService.checkFavoriteItems(
                menuItems: Array(allItems),
                favoriteNames: settings.favoriteItemNames
            )
        }
    }
}
