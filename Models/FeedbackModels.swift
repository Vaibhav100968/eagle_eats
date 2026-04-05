import Foundation

// MARK: - Feedback Tag

enum FeedbackTag: String, Codable, CaseIterable, Identifiable {
    case taste        = "Taste"
    case quality      = "Quality"
    case availability = "Availability"
    case cleanliness  = "Cleanliness"
    case service      = "Service"
    case variety      = "Variety"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .taste:        return "mouth.fill"
        case .quality:      return "star.fill"
        case .availability: return "clock.fill"
        case .cleanliness:  return "sparkles"
        case .service:      return "person.fill"
        case .variety:      return "square.grid.3x3.fill"
        }
    }
}

// MARK: - Feedback Entry

struct FeedbackEntry: Identifiable, Codable {
    let id: UUID
    let hallId: String
    let hallName: String
    let mealPeriod: String
    let rating: Int
    let tags: [FeedbackTag]
    let comment: String
    let date: Date

    init(
        hallId: String,
        hallName: String,
        mealPeriod: String,
        rating: Int,
        tags: [FeedbackTag],
        comment: String = ""
    ) {
        self.id = UUID()
        self.hallId = hallId
        self.hallName = hallName
        self.mealPeriod = mealPeriod
        self.rating = min(5, max(1, rating))
        self.tags = tags
        self.comment = comment
        self.date = Date()
    }
}

// MARK: - Hall Rating Summary

struct HallRatingSummary: Identifiable {
    let hallId: String
    let hallName: String
    let averageRating: Double
    let totalReviews: Int
    let topTags: [FeedbackTag]

    var id: String { hallId }
}
