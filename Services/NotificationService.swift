import UserNotifications
import Foundation

// MARK: - Notification Service

@MainActor
final class NotificationService: ObservableObject {

    static let shared = NotificationService()

    @Published private(set) var isAuthorized: Bool = false

    private let center = UNUserNotificationCenter.current()

    private init() {
        Task { await checkAuthorization() }
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
        } catch {
            isAuthorized = false
        }
    }

    func checkAuthorization() async {
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Master Refresh

    /// Recalculates all scheduled notifications based on current settings and favorites.
    func refreshAllNotifications(settings: AppSettings, favoriteHallIds: Set<String>, halls: [DiningHall]) {
        guard isAuthorized, settings.notificationsEnabled else {
            removeAllPending()
            return
        }

        removeAllPending()

        if settings.mealRemindersEnabled {
            scheduleMealPeriodReminders(minutesBefore: settings.reminderMinutesBefore)
        }

        if settings.hallOpenAlerts && !favoriteHallIds.isEmpty {
            scheduleFavoriteHallOpenings(favoriteIds: favoriteHallIds, halls: halls)
        }

        if settings.menuHighlights {
            scheduleMenuHighlights()
        }
    }

    // MARK: - Meal Period Reminders

    /// Schedules daily repeating reminders before breakfast, lunch, and dinner.
    private func scheduleMealPeriodReminders(minutesBefore: Int) {
        let periods: [(String, String, Int, Int)] = [
            ("Breakfast", "Time for breakfast! Check today's menu before heading out.", 7, 0),
            ("Lunch",     "Lunch menus are live! See what's being served right now.", 10, 0),
            ("Dinner",    "Dinner time is coming up. Plan your evening meal.", 17, 0),
        ]

        for (name, body, hour, minute) in periods {
            let adjustedMinutes = hour * 60 + minute - minutesBefore
            let adjHour = max(0, adjustedMinutes / 60)
            let adjMinute = max(0, adjustedMinutes % 60)

            let content = UNMutableNotificationContent()
            content.title = "\(name) Reminder"
            content.body = body
            content.sound = .default
            content.categoryIdentifier = "MEAL_REMINDER"

            var components = DateComponents()
            components.hour = adjHour
            components.minute = adjMinute

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: "meal-reminder-\(name.lowercased())",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    // MARK: - Favorite Hall Openings

    /// Schedules daily notifications when the user's favorite dining halls open.
    private func scheduleFavoriteHallOpenings(favoriteIds: Set<String>, halls: [DiningHall]) {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        let isWeekend = weekday == 1 || weekday == 7

        for hall in halls where favoriteIds.contains(hall.id) {
            let hours = isWeekend ? hall.weekendHours : hall.weekdayHours
            guard hours.openHour > 0 || hours.closeHour > 0 else { continue }

            let content = UNMutableNotificationContent()
            content.title = "\(hall.name) is Now Open"
            content.body = "Open until \(hours.displayString.components(separatedBy: "–").last?.trimmingCharacters(in: .whitespaces) ?? "close"). Tap to see today's menu."
            content.sound = .default
            content.categoryIdentifier = "HALL_OPEN"

            var components = DateComponents()
            components.hour = hours.openHour
            components.minute = hours.openMinute

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: "hall-open-\(hall.id)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    // MARK: - Morning Menu Highlights

    /// Schedules a daily morning notification summarizing today's dining options.
    private func scheduleMenuHighlights() {
        let content = UNMutableNotificationContent()
        content.title = "Today's Menu is Ready"
        content.body = "Fresh menus are loaded for all dining halls. See what's cooking today!"
        content.sound = .default
        content.categoryIdentifier = "MENU_HIGHLIGHTS"

        var components = DateComponents()
        components.hour = 6
        components.minute = 30

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "menu-highlights-daily",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    // MARK: - Favorite Item Alert (on-demand)

    /// Call after menu data is fetched to check if any favorite items are on today's menu.
    func checkFavoriteItems(menuItems: [MenuItem], favoriteNames: [String]) {
        guard isAuthorized, !favoriteNames.isEmpty else { return }

        let lowerFavorites = Set(favoriteNames.map { $0.lowercased() })
        let matches = menuItems.filter { item in
            lowerFavorites.contains(item.name.lowercased())
        }

        guard !matches.isEmpty else { return }

        let todayKey = todayDateKey()
        let sentKey = "notif_fav_items_\(todayKey)"
        guard !UserDefaults.standard.bool(forKey: sentKey) else { return }
        UserDefaults.standard.set(true, forKey: sentKey)

        let names = matches.prefix(3).map(\.name).joined(separator: ", ")
        let suffix = matches.count > 3 ? " and \(matches.count - 3) more" : ""

        let content = UNMutableNotificationContent()
        content.title = "Your Favorites Are Serving Today!"
        content.body = "\(names)\(suffix) — available now at the dining halls."
        content.sound = .default
        content.categoryIdentifier = "FAVORITE_ITEM"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "fav-items-\(todayKey)",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    // MARK: - Crowd Drop Alert (on-demand)

    func scheduleCrowdDropAlert(hallName: String) {
        guard isAuthorized else { return }

        let todayKey = todayDateKey()
        let sentKey = "notif_crowd_\(hallName)_\(todayKey)"
        guard !UserDefaults.standard.bool(forKey: sentKey) else { return }
        UserDefaults.standard.set(true, forKey: sentKey)

        let content = UNMutableNotificationContent()
        content.title = "Low Crowd Alert"
        content.body = "\(hallName) just dropped to low traffic — great time to eat!"
        content.sound = .default
        content.categoryIdentifier = "CROWD_DROP"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "crowd-drop-\(hallName)-\(todayKey)",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    // MARK: - Budget Alert (on-demand)

    func scheduleBudgetAlert(message: String) {
        guard isAuthorized else { return }
        let content = UNMutableNotificationContent()
        content.title = "Budget Alert"
        content.body = message
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "budget-\(Date().timeIntervalSince1970)",
            content: content, trigger: trigger
        )
        center.add(request)
    }

    // MARK: - Helpers

    func removeAllPending() {
        center.removeAllPendingNotificationRequests()
    }

    private func todayDateKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    /// Returns the count of currently scheduled notifications (for debug/settings display).
    func pendingCount() async -> Int {
        let pending = await center.pendingNotificationRequests()
        return pending.count
    }
}
