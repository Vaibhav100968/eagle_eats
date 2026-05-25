import Foundation
import Combine

// MARK: - Content Moderation (App Review Guideline 1.2)

enum ReportableContentType: String, Codable {
    case checkIn
    case photoReview
    case feedback
    case availabilityReport
}

struct ContentReport: Identifiable, Codable {
    let id: UUID
    let type: ReportableContentType
    let contentId: String
    let reason: String
    let date: Date

    init(type: ReportableContentType, contentId: String, reason: String) {
        self.id = UUID()
        self.type = type
        self.contentId = contentId
        self.reason = reason
        self.date = Date()
    }
}

@MainActor
final class ContentModerationService: ObservableObject {

    static let shared = ContentModerationService()

    @Published private(set) var blockedUserNames: Set<String> = []

    private let reportsKey = "eagle_eats_content_reports"
    private let blockedKey = "eagle_eats_blocked_users"

    private init() {
        loadBlocked()
    }

    func isBlocked(_ userName: String) -> Bool {
        blockedUserNames.contains(userName.lowercased())
    }

    func blockUser(_ userName: String) {
        blockedUserNames.insert(userName.lowercased())
        saveBlocked()
    }

    func unblockUser(_ userName: String) {
        blockedUserNames.remove(userName.lowercased())
        saveBlocked()
    }

    func submitReport(type: ReportableContentType, contentId: String, reason: String) {
        var reports = loadReports()
        reports.insert(ContentReport(type: type, contentId: contentId, reason: reason), at: 0)
        let trimmed = Array(reports.prefix(200))
        if let data = try? JSONEncoder().encode(trimmed) {
            UserDefaults.standard.set(data, forKey: reportsKey)
        }
    }

    private func loadReports() -> [ContentReport] {
        guard let data = UserDefaults.standard.data(forKey: reportsKey),
              let list = try? JSONDecoder().decode([ContentReport].self, from: data)
        else { return [] }
        return list
    }

    private func loadBlocked() {
        if let list = UserDefaults.standard.stringArray(forKey: blockedKey) {
            blockedUserNames = Set(list.map { $0.lowercased() })
        }
    }

    private func saveBlocked() {
        UserDefaults.standard.set(Array(blockedUserNames), forKey: blockedKey)
    }
}
