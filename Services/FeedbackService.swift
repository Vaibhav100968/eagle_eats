import Foundation
import Combine

// MARK: - Feedback Service
//
// Local storage for verified dining hall feedback.
// In production this would sync to a backend API.
// All feedback is associated with an authenticated user session.

@MainActor
final class FeedbackService: ObservableObject {

    static let shared = FeedbackService()

    @Published private(set) var entries: [FeedbackEntry] = []
    @Published private(set) var summaries: [HallRatingSummary] = []

    private let storageKey = "eagle_eats_feedback"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        load()
    }

    // MARK: - CRUD

    func submit(_ entry: FeedbackEntry) {
        entries.insert(entry, at: 0)
        save()
        rebuildSummaries()
    }

    func delete(id: UUID) {
        entries.removeAll { $0.id == id }
        save()
        rebuildSummaries()
    }

    func entries(for hallId: String) -> [FeedbackEntry] {
        entries.filter { $0.hallId == hallId }
    }

    func summary(for hallId: String) -> HallRatingSummary? {
        summaries.first { $0.hallId == hallId }
    }

    // MARK: - Aggregation

    private func rebuildSummaries() {
        let grouped = Dictionary(grouping: entries, by: \.hallId)
        summaries = grouped.map { hallId, feedbacks in
            let avg = feedbacks.isEmpty ? 0 :
                Double(feedbacks.reduce(0) { $0 + $1.rating }) / Double(feedbacks.count)

            var tagCounts: [FeedbackTag: Int] = [:]
            for entry in feedbacks {
                for tag in entry.tags {
                    tagCounts[tag, default: 0] += 1
                }
            }
            let topTags = tagCounts.sorted { $0.value > $1.value }
                .prefix(3).map(\.key)

            let name = feedbacks.first?.hallName ?? hallId

            return HallRatingSummary(
                hallId: hallId,
                hallName: name,
                averageRating: avg,
                totalReviews: feedbacks.count,
                topTags: topTags
            )
        }.sorted { $0.totalReviews > $1.totalReviews }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? decoder.decode([FeedbackEntry].self, from: data)
        else { return }
        entries = decoded.sorted { $0.date > $1.date }
        rebuildSummaries()
    }

    private func save() {
        let trimmed = Array(entries.prefix(500))
        if let data = try? encoder.encode(trimmed) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

}
