import SwiftUI

@main
struct eaglesEats2App: App {

    @StateObject private var appState      = AppState.shared
    @StateObject private var diningService = DiningService.shared
    @StateObject private var plateVM       = PlateViewModel()
    @StateObject private var historyVM     = HistoryViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(diningService)
                .environmentObject(plateVM)
                .environmentObject(historyVM)
                .preferredColorScheme(.light)
        }
    }
}
