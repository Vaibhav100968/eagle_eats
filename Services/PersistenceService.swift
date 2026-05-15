import Foundation

// MARK: - Persistence Service
// Handles local storage for guest mode and optionally syncs for authenticated users

@MainActor
final class PersistenceService {

    static let shared = PersistenceService()
    private init() {}

    private let mealsKey           = "eagle_eats_saved_meals"
    private let favoritesKey       = "eagle_eats_favorites"
    private let settingsKey        = "eagle_eats_settings"
    private let firstLaunchKey     = "eagle_eats_first_launch"
    private let guestModeKey       = "eagle_eats_guest_mode"
    private let spendingKey        = "eagle_eats_spending_history"
    private let availabilityKey    = "eagle_eats_availability_reports"
    private let semesterConfigKey  = "eagle_eats_semester_config"

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - First Launch

    var isFirstLaunch: Bool {
        get { !UserDefaults.standard.bool(forKey: firstLaunchKey) }
        set { UserDefaults.standard.set(!newValue, forKey: firstLaunchKey) }
    }

    var isGuestMode: Bool {
        get { UserDefaults.standard.bool(forKey: guestModeKey) }
        set { UserDefaults.standard.set(newValue, forKey: guestModeKey) }
    }

    // MARK: - Meal History

    func loadMeals() -> [SavedMeal] {
        guard let data = UserDefaults.standard.data(forKey: mealsKey),
              let meals = try? decoder.decode([SavedMeal].self, from: data)
        else { return [] }
        return meals.sorted { $0.date > $1.date }
    }

    func save(meal: SavedMeal) {
        var meals = loadMeals()
        meals.insert(meal, at: 0)
        if let data = try? encoder.encode(meals) {
            UserDefaults.standard.set(data, forKey: mealsKey)
        }
    }

    func delete(mealId: UUID) {
        var meals = loadMeals()
        meals.removeAll { $0.id == mealId }
        if let data = try? encoder.encode(meals) {
            UserDefaults.standard.set(data, forKey: mealsKey)
        }
    }

    func clearAllMeals() {
        UserDefaults.standard.removeObject(forKey: mealsKey)
    }

    // MARK: - Favorites

    func loadFavoriteHallIds() -> Set<String> {
        guard let data = UserDefaults.standard.data(forKey: favoritesKey),
              let ids = try? decoder.decode(Set<String>.self, from: data)
        else { return [] }
        return ids
    }

    func toggleFavorite(hallId: String) {
        var ids = loadFavoriteHallIds()
        if ids.contains(hallId) { ids.remove(hallId) } else { ids.insert(hallId) }
        if let data = try? encoder.encode(ids) {
            UserDefaults.standard.set(data, forKey: favoritesKey)
        }
    }

    // MARK: - App Settings

    func loadSettings() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let settings = try? decoder.decode(AppSettings.self, from: data)
        else { return AppSettings() }
        return settings
    }

    func save(settings: AppSettings) {
        if let data = try? encoder.encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }

    // MARK: - Spending History

    func loadSpendingHistory() -> [SpendingEvent] {
        guard let data = UserDefaults.standard.data(forKey: spendingKey),
              let events = try? decoder.decode([SpendingEvent].self, from: data)
        else { return [] }
        return events.sorted { $0.date > $1.date }
    }

    func saveSpendingHistory(_ events: [SpendingEvent]) {
        // Keep last 200 events to prevent unbounded growth
        let trimmed = Array(events.prefix(200))
        if let data = try? encoder.encode(trimmed) {
            UserDefaults.standard.set(data, forKey: spendingKey)
        }
    }

    // MARK: - Availability Reports

    func loadAvailabilityReports() -> [AvailabilityReport] {
        guard let data = UserDefaults.standard.data(forKey: availabilityKey),
              let reports = try? decoder.decode([AvailabilityReport].self, from: data)
        else { return [] }
        return reports
    }

    func saveAvailabilityReport(_ report: AvailabilityReport) {
        var reports = loadAvailabilityReports()
        reports.insert(report, at: 0)
        // Keep only today's reports + last 50
        let cutoff = Calendar.current.startOfDay(for: Date())
        let todayReports = reports.filter { $0.date >= cutoff }
        let olderReports = reports.filter { $0.date < cutoff }.prefix(50)
        let trimmed = todayReports + olderReports
        if let data = try? encoder.encode(Array(trimmed)) {
            UserDefaults.standard.set(data, forKey: availabilityKey)
        }
    }

    /// Aggregated availability status for a given menu item (today's reports only).
    func availabilityStatus(for menuItemId: String) -> AvailabilityStatus {
        let cutoff = Calendar.current.startOfDay(for: Date())
        let todayReports = loadAvailabilityReports().filter {
            $0.menuItemId == menuItemId && $0.date >= cutoff
        }
        let available = todayReports.filter(\.isAvailable).count
        let unavailable = todayReports.count - available
        return AvailabilityStatus(
            menuItemId: menuItemId,
            reportsToday: todayReports.count,
            availableCount: available,
            unavailableCount: unavailable
        )
    }

    // MARK: - Semester Config

    func loadSemesterConfig() -> SemesterConfig? {
        guard let data = UserDefaults.standard.data(forKey: semesterConfigKey),
              let config = try? decoder.decode(SemesterConfig.self, from: data)
        else { return nil }
        return config
    }

    func save(semesterConfig: SemesterConfig) {
        if let data = try? encoder.encode(semesterConfig) {
            UserDefaults.standard.set(data, forKey: semesterConfigKey)
        }
    }
}

// MARK: - App Settings Model

struct AppSettings: Codable, Equatable {
    var dailyCalorieGoal:   Double = 2000
    var dailyProteinGoal:   Double = 150
    var dailyCarbGoal:      Double = 250
    var dailyFatGoal:       Double = 65
    var dietaryFilters:     [String] = []
    var allergenExclusions: [String] = []
    var notificationsEnabled: Bool  = true
    var mealRemindersEnabled: Bool  = true    // Remind before each meal period
    var hallOpenAlerts:      Bool   = true    // Alert when favorite hall opens
    var menuHighlights:      Bool   = true    // Morning menu summary
    var reminderMinutesBefore: Int  = 15      // How many minutes before meal to remind
    var reducedMotion:      Bool    = false
    var darkModePreference: String  = "system" // "system", "light", "dark"
    var defaultHallId:      String? = nil
    var favoriteItemNames:  [String] = []
}
