import SwiftUI
import PhotosUI

// MARK: - Photo Review Service

@MainActor
final class PhotoReviewService: ObservableObject {

    static let shared = PhotoReviewService()

    @Published var reviews: [PhotoReview] = []

    private let storageKey = "eagle_eats_photo_reviews"
    private let fileManager = FileManager.default

    private init() {
        reviews = loadReviews()
    }

    // MARK: - CRUD

    func addReview(
        menuItemName: String,
        recipeId: String,
        hallId: String,
        hallName: String,
        rating: Int,
        comment: String,
        image: UIImage
    ) {
        let id = UUID().uuidString
        let photoFilename = "\(id).jpg"

        if let data = image.jpegData(compressionQuality: 0.7) {
            let url = photoDirectory().appendingPathComponent(photoFilename)
            try? data.write(to: url)
        }

        let review = PhotoReview(
            id: id,
            menuItemName: menuItemName,
            recipeId: recipeId,
            hallId: hallId,
            hallName: hallName,
            rating: rating,
            comment: comment,
            photoFilename: photoFilename,
            date: Date()
        )

        reviews.insert(review, at: 0)
        saveReviews()
    }

    func deleteReview(_ reviewId: String) {
        if let review = reviews.first(where: { $0.id == reviewId }) {
            let url = photoDirectory().appendingPathComponent(review.photoFilename)
            try? fileManager.removeItem(at: url)
        }
        reviews.removeAll { $0.id == reviewId }
        saveReviews()
    }

    /// Get reviews for a specific menu item by recipe ID.
    func reviews(for recipeId: String) -> [PhotoReview] {
        reviews.filter { $0.recipeId == recipeId }
    }

    /// Get all reviews for a specific dining hall.
    func reviews(forHall hallId: String) -> [PhotoReview] {
        reviews.filter { $0.hallId == hallId }
    }

    /// Load a photo from disk.
    func loadPhoto(for review: PhotoReview) -> UIImage? {
        let url = photoDirectory().appendingPathComponent(review.photoFilename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// Average rating across all reviews for a recipe.
    func averageRating(for recipeId: String) -> (average: Double, count: Int)? {
        let itemReviews = reviews(for: recipeId)
        guard !itemReviews.isEmpty else { return nil }
        let avg = Double(itemReviews.reduce(0) { $0 + $1.rating }) / Double(itemReviews.count)
        return (avg, itemReviews.count)
    }

    // MARK: - Storage

    private func loadReviews() -> [PhotoReview] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let list = try? JSONDecoder().decode([PhotoReview].self, from: data)
        else { return [] }
        return list
    }

    private func saveReviews() {
        // Keep last 100 reviews
        let trimmed = Array(reviews.prefix(100))
        if let data = try? JSONEncoder().encode(trimmed) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func photoDirectory() -> URL {
        let dir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("photo_reviews", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
}

// MARK: - Photo Review Model

struct PhotoReview: Identifiable, Codable {
    let id: String
    let menuItemName: String
    let recipeId: String
    let hallId: String
    let hallName: String
    let rating: Int
    let comment: String
    let photoFilename: String
    let date: Date

    var timeAgo: String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 3600 { return "\(max(1, seconds / 60))m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        let days = seconds / 86400
        if days == 1 { return "yesterday" }
        return "\(days)d ago"
    }
}
