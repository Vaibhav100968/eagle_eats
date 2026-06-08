import SwiftUI
import Combine

// MARK: - Auth State

enum AuthState: Equatable {
    case unknown
    case onboarding
    case signedIn(identifier: String, displayName: String?)

    var isAuthenticated: Bool {
        if case .signedIn = self { return true }
        return false
    }

    var needsOnboarding: Bool { self == .onboarding }

    static func == (lhs: AuthState, rhs: AuthState) -> Bool {
        switch (lhs, rhs) {
        case (.unknown, .unknown),
             (.onboarding, .onboarding):
            return true
        case (.signedIn(let a, _), .signedIn(let b, _)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - App State (root observable)

@MainActor
final class AppState: ObservableObject {

    static let shared = AppState()

    @Published var authState: AuthState = .unknown
    @Published var settings: AppSettings = AppSettings()
    @Published var favoriteHallIds: Set<String> = []

    let auth = AuthService.shared
    private let persistence = PersistenceService.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        settings = persistence.loadSettings()
        favoriteHallIds = persistence.loadFavoriteHallIds()
        resolveInitialAuthState()

        auth.$isSignedIn
            .receive(on: RunLoop.main)
            .sink { [weak self] signedIn in
                guard let self else { return }
                if !signedIn, case .signedIn = self.authState {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        self.authState = .onboarding
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func resolveInitialAuthState() {
        if auth.isSignedIn, let id = auth.identifier {
            authState = .signedIn(identifier: id, displayName: auth.displayName)
        } else {
            authState = .onboarding
        }
    }

    // MARK: - Auth Actions

    /// Called after successful UNT portal login.
    func didSignIn() {
        persistence.isFirstLaunch = false
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            authState = .signedIn(
                identifier: auth.identifier ?? "UNT Student",
                displayName: auth.displayName
            )
        }
    }

    func signOut() {
        auth.signOut()
        MealPlanService.shared.signOut()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            authState = .onboarding
        }
    }

    /// Deletes local account data and returns user to onboarding (Guideline 5.1.1).
    func deleteAccount() {
        auth.deleteAccount()
        MealPlanService.shared.signOut()
        clearLocalUserData()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            authState = .onboarding
        }
    }

    private func clearLocalUserData() {
        persistence.clearAllMeals()
        let keys = [
            "eagle_eats_feedback",
            "eagle_eats_checkins",
            "eagle_eats_ratings",
            "eagle_eats_availability_reports",
            "eagle_eats_photo_reviews",
            "eagle_eats_meal_plan_cache",
            "eagle_eats_content_reports",
            "eagle_eats_blocked_users",
        ]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        favoriteHallIds = []
        persistence.save(settings: AppSettings())
        settings = AppSettings()
    }

    // MARK: - Favorites

    func toggleFavorite(hallId: String) {
        persistence.toggleFavorite(hallId: hallId)
        favoriteHallIds = persistence.loadFavoriteHallIds()
    }

    func isFavorite(_ hallId: String) -> Bool {
        favoriteHallIds.contains(hallId)
    }

    // MARK: - Settings

    func update(settings: AppSettings) {
        self.settings = settings
        persistence.save(settings: settings)
    }
}

// MARK: - Plate View Model

@MainActor
final class PlateViewModel: ObservableObject {

    @Published var plate: Plate = Plate()
    @Published var selectedHall: DiningHall? = nil
    @Published var showingPlateSheet: Bool = false
    @Published var lastAddedItem: MenuItem? = nil

    private let dining = DiningService.shared

    var itemCount: Int { plate.itemCount }
    var hasItems: Bool { !plate.isEmpty }

    var liveCalories: Double     { liveStat(\.calories) }
    var liveProtein: Double      { liveStat(\.protein) }
    var liveCarbs: Double        { liveStat(\.carbohydrates) }
    var liveFat: Double          { liveStat(\.fat) }

    private func liveStat(_ kp: KeyPath<NutritionInfo, Double>) -> Double {
        let cache = dining.nutritionCache
        return plate.items.reduce(0) { sum, item in
            let n = cache[item.menuItem.recipeID] ?? item.menuItem.nutrition
            return sum + n[keyPath: kp] * Double(item.quantity)
        }
    }

    // MARK: - Mutating

    func add(_ item: MenuItem, from hall: DiningHall) {
        plate.add(item)
        selectedHall = hall
        lastAddedItem = item

        if !item.nutritionLoaded {
            Task { [weak self] in
                guard let self else { return }
                if let nutrition = await dining.fetchNutrition(for: item) {
                    plate.applyNutrition(recipeID: item.recipeID, nutrition: nutrition)
                    objectWillChange.send()
                }
            }
        }
    }

    func remove(_ item: MenuItem) {
        plate.remove(item)
        if plate.isEmpty { selectedHall = nil }
    }

    func removeAll(_ item: MenuItem) {
        plate.removeAll(item)
        if plate.isEmpty { selectedHall = nil }
    }

    func clear() {
        plate.clear()
        selectedHall = nil
    }

    func saveMeal(persistence: PersistenceService) -> SavedMeal? {
        guard let hall = selectedHall, !plate.isEmpty else { return nil }
        let cache = dining.nutritionCache
        for item in plate.items {
            if let n = cache[item.menuItem.recipeID] {
                plate.applyNutrition(recipeID: item.menuItem.recipeID, nutrition: n)
            }
        }
        let meal = SavedMeal(from: plate, at: hall, period: MealPeriod.current())
        persistence.save(meal: meal)
        clear()
        return meal
    }
}

// MARK: - History View Model

@MainActor
final class HistoryViewModel: ObservableObject {

    @Published var meals: [SavedMeal] = []
    @Published var groupedMeals: [MealGroup] = []

    private let persistence = PersistenceService.shared

    init() { load() }

    func load() {
        meals = persistence.loadMeals()
        groupedMeals = groupByDay(meals)
    }

    func delete(mealId: UUID) {
        persistence.delete(mealId: mealId)
        load()
    }

    func clearAll() {
        persistence.clearAllMeals()
        load()
    }

    private func groupByDay(_ meals: [SavedMeal]) -> [MealGroup] {
        var groups: [String: MealGroup] = [:]
        let calendar = Calendar.current
        for meal in meals {
            let day = calendar.startOfDay(for: meal.date)
            let key = ISO8601DateFormatter().string(from: day)
            if var group = groups[key] {
                group.meals.append(meal)
                groups[key] = group
            } else {
                let label = meal.dayDisplay
                groups[key] = MealGroup(id: key, label: label, date: day, meals: [meal])
            }
        }
        return groups.values.sorted { $0.date > $1.date }
    }

    // MARK: - Stats

    var weeklyCalories: Double {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return meals.filter { $0.date >= cutoff }.reduce(0) { $0 + $1.totalCalories }
    }

    var totalMealsLogged: Int { meals.count }

    var streakDays: Int {
        var streak = 0
        var checkDate = Calendar.current.startOfDay(for: Date())
        let calendar = Calendar.current
        while true {
            let hasMeal = meals.contains {
                calendar.startOfDay(for: $0.date) == checkDate
            }
            if hasMeal {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else { break }
        }
        return streak
    }

    var todaysMeals: [SavedMeal] {
        meals.filter { Calendar.current.isDateInToday($0.date) }
    }

    var todayCalories: Double { todaysMeals.reduce(0) { $0 + $1.totalCalories } }
    var todayProtein: Double  { todaysMeals.reduce(0) { $0 + $1.totalProtein } }
    var todayCarbs: Double    { todaysMeals.reduce(0) { $0 + $1.totalCarbs } }
    var todayFat: Double        { todaysMeals.reduce(0) { $0 + $1.totalFat } }
}
