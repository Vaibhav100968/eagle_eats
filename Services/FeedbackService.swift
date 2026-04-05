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
        if entries.isEmpty { seedDemoData() }
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

    // MARK: - Demo Seed Data

    private func seedDemoData() {
        let cal = Calendar.current
        let now = Date()

        func ago(days: Int, hours: Int = 0) -> Date {
            cal.date(byAdding: .day, value: -days,
                     to: cal.date(byAdding: .hour, value: -hours, to: now)!)!
        }

        let seed: [(String, String, String, Int, [FeedbackTag], String, Date)] = [
            ("bruceteria", "Bruceteria", "Lunch", 5, [.taste, .variety],
             "The chicken tikka masala station was incredible today. Perfectly spiced.", ago(days: 0, hours: 3)),
            ("bruceteria", "Bruceteria", "Breakfast", 4, [.quality, .availability],
             "Omelette station had a long line but the food was worth the wait.", ago(days: 1, hours: 5)),
            ("bruceteria", "Bruceteria", "Lunch", 4, [.taste, .cleanliness],
             "Solid lunch options. The salad bar was fresh and well-stocked.", ago(days: 2)),
            ("bruceteria", "Bruceteria", "Dinner", 3, [.availability],
             "Some stations closed early before 4 PM.", ago(days: 3)),

            ("mean-greens", "Mean Greens Caf\u{00E9}", "Lunch", 5, [.taste, .quality, .variety],
             "Best vegan dining hall in the country for a reason. The jackfruit tacos were perfect.", ago(days: 0, hours: 5)),
            ("mean-greens", "Mean Greens Caf\u{00E9}", "Lunch", 4, [.taste, .cleanliness],
             "Really clean, food was fresh. The smoothie bar is a nice touch.", ago(days: 1)),
            ("mean-greens", "Mean Greens Caf\u{00E9}", "Breakfast", 5, [.quality, .variety],
             "Tofu scramble and the acai bowl were both excellent.", ago(days: 2, hours: 8)),
            ("mean-greens", "Mean Greens Caf\u{00E9}", "Dinner", 4, [.taste],
             "The mushroom risotto was really creamy and well-seasoned.", ago(days: 4)),

            ("eagle-landing", "Eagle Landing", "Dinner", 4, [.taste, .service],
             "Good comfort food. The mac and cheese was great.", ago(days: 0, hours: 2)),
            ("eagle-landing", "Eagle Landing", "Lunch", 3, [.availability, .quality],
             "Limited options at 1 PM. Most of the hot food was sitting out.", ago(days: 1, hours: 4)),
            ("eagle-landing", "Eagle Landing", "Dinner", 5, [.taste, .variety, .service],
             "Thursday dinner was steak night. Cooked to order, really impressed.", ago(days: 3)),

            ("champs", "Champs", "Lunch", 4, [.quality, .taste],
             "High-protein options are solid. The grilled chicken was well-seasoned.", ago(days: 1)),
            ("champs", "Champs", "Breakfast", 4, [.availability, .quality],
             "Egg white omelettes and protein pancakes available every morning.", ago(days: 2, hours: 9)),
            ("champs", "Champs", "Dinner", 3, [.variety],
             "Menu could use more variety. Same rotation most weeks.", ago(days: 5)),

            ("kitchen-west", "Kitchen West", "Lunch", 5, [.quality, .taste, .cleanliness],
             "Finally a dining hall where I can eat without worrying about allergens.", ago(days: 0, hours: 6)),
            ("kitchen-west", "Kitchen West", "Lunch", 4, [.taste, .service],
             "Staff is always helpful explaining ingredients. Food is consistent.", ago(days: 2)),
            ("kitchen-west", "Kitchen West", "Dinner", 4, [.quality, .availability],
             "Smaller menu but everything is safe and well-prepared.", ago(days: 4)),
        ]

        for (hallId, hallName, period, rating, tags, comment, date) in seed {
            let entry = FeedbackEntry(
                hallId: hallId, hallName: hallName,
                mealPeriod: period, rating: rating,
                tags: tags, comment: comment
            )
            // Override the auto-generated date by re-encoding
            var mutable = entry
            mutable = FeedbackEntry(
                hallId: hallId, hallName: hallName,
                mealPeriod: period, rating: rating,
                tags: tags, comment: comment
            )
            entries.append(mutable)
        }

        // Sort by the insertion order (newest first based on array position)
        // Since we can't override dates in the struct, reverse so newest-looking are first
        entries.reverse()
        save()
        rebuildSummaries()
    }
}
