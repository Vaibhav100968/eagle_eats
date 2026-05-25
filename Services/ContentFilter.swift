import Foundation

enum ContentFilter {
    private static let blockedTerms = [
        "spam", "scam", "porn", "nude", "kill", "hate",
    ]

    /// Basic client-side filter for user-submitted text (Guideline 1.2).
    static func isAcceptable(_ text: String) -> Bool {
        let lower = text.lowercased()
        guard !lower.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return !blockedTerms.contains { lower.contains($0) }
    }
}
