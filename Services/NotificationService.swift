import UserNotifications
import Foundation

// MARK: - Notification Service
// Manages local push notifications for dining intelligence alerts.
// In production, these would be triggered by a backend push service.

@MainActor
final class NotificationService: ObservableObject {

    static let shared = NotificationService()

    @Published private(set) var isAuthorized: Bool = false

    private init() {
        Task { await checkAuthorization() }
    }

    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
        } catch {
            isAuthorized = false
        }
    }

    func checkAuthorization() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Crowd Alerts

    func scheduleCrowdAlert(hallName: String, level: String) {
        guard isAuthorized else { return }
        let content = UNMutableNotificationContent()
        content.title = "Crowd Update"
        content.body = "\(hallName) is now \(level.lowercased()) traffic"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "crowd-\(hallName)-\(Date().timeIntervalSince1970)",
            content: content, trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Budget Alerts

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
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Daily Reminder

    func scheduleDailyReminder(hour: Int, minute: Int) {
        guard isAuthorized else { return }
        let content = UNMutableNotificationContent()
        content.title = "Eagle Eats"
        content.body = "Check today's dining hall menus and plan your meals"
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "daily-reminder",
            content: content, trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func removeAllPending() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
