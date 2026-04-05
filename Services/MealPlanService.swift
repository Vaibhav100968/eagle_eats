import Foundation
import WebKit
import Combine
import SwiftUI

// MARK: - Meal Plan Service

@MainActor
final class MealPlanService: ObservableObject {

    static let shared = MealPlanService()

    @Published var authState: MealPlanAuthState = .notAuthenticated

    private let cacheKey = "eagle_eats_meal_plan_cache"
    private let encoder  = JSONEncoder()
    private let decoder  = JSONDecoder()
    private let keychain = KeychainService.shared

    private init() { loadCachedState() }

    private func loadCachedState() {
        // Try loading real cached data first
        if keychain.hasPortalSession,
           let data = UserDefaults.standard.data(forKey: cacheKey),
           let info = try? decoder.decode(MealPlanInfo.self, from: data),
           info.hasAnyData {
            authState = .stale(info)
            return
        }

        // If no real data, check for any cached data (even without portal session)
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let info = try? decoder.decode(MealPlanInfo.self, from: data),
           info.hasAnyData {
            authState = .stale(info)
            return
        }

        // Seed demo data for pitch demo so the tab is never empty
        let demo = MealPlanInfo(
            diningSwipes: 47,
            flexBalance: 382.50,
            mealPlanName: "Eagle 150 Meal Plan",
            accountHolder: nil,
            lastUpdated: Date()
        )
        cache(demo)
    }

    func cache(_ info: MealPlanInfo) {
        if let data = try? encoder.encode(info) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
        authState = .authenticated(info)
    }

    func markSessionValid(_ valid: Bool) { keychain.markPortalSession(valid) }

    /// Downgrades the current authenticated state to stale (keeps data visible but dims it).
    /// Called when a background refresh fails but we already have cached data to show.
    func markStale() {
        switch authState {
        case .authenticated(let info):
            authState = .stale(info)
        case .stale:
            break   // already stale, no change needed
        default:
            break
        }
    }

    func signOut() {
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        WKWebsiteDataStore.default().removeData(ofTypes: types, modifiedSince: .distantPast) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                UserDefaults.standard.removeObject(forKey: self.cacheKey)
                self.keychain.markPortalSession(false)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    self.authState = .notAuthenticated
                }
            }
        }
    }
}

// MARK: - Balance Scraper
//
// Parses document.body.innerText from mealplans.unt.edu.
// Ported directly from the working older app implementation.
//
// Observed portal text structure:
//   "Meal swipes left  14"
//   "Flex MP\n…\nCurrent Balance\n$45.25"

enum BalanceScraper {

    static func parse(_ rawText: String) -> MealPlanInfo? {
        guard !rawText.isEmpty else { return nil }

        // Replace non-breaking spaces with regular spaces
        let text = rawText.replacingOccurrences(of: "\u{00a0}", with: " ")

        #if DEBUG
        print("[BalanceScraper] text length: \(text.count)")
        print("[BalanceScraper] first 800 chars:\n\(text.prefix(800))")
        #endif

        var swipesText: String? = parseSwipesLeft(from: text)
        if swipesText == nil { swipesText = parseSwipesFallback(from: text) }

        var flex: Double? = parseFlexLeft(from: text)
        if flex == nil { flex = parseFlexFallback(from: text) }

        guard swipesText != nil || flex != nil else { return nil }

        var info = MealPlanInfo(lastUpdated: Date())

        if let st = swipesText {
            if st.lowercased() == "unlimited" {
                info.diningSwipes = 9999
            } else {
                info.diningSwipes = Int(st)
            }
        }
        info.flexBalance = flex
        info.accountHolder = parseAccountHolder(from: text)
        info.mealPlanName  = parseMealPlanName(from: text)

        return info
    }

    // MARK: - Account Holder

    static func parseAccountHolder(from text: String) -> String? {
        let ns = text as NSString
        let patterns = [
            #"(?i)welcome[,!\s]+([A-Z][a-zA-Z'-]+(?:\s+[A-Z][a-zA-Z'-]+){0,3})"#,
            #"(?i)hello[,!\s]+([A-Z][a-zA-Z'-]+(?:\s+[A-Z][a-zA-Z'-]+){0,3})"#,
            #"(?i)account\s*holder[:\s]+([A-Z][a-zA-Z'-]+(?:\s+[A-Z][a-zA-Z'-]+){0,3})"#,
            #"(?i)student[:\s]+([A-Z][a-zA-Z'-]+(?:\s+[A-Z][a-zA-Z'-]+){0,3})"#,
        ]
        for pattern in patterns {
            guard let re = try? NSRegularExpression(pattern: pattern),
                  let m = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
                  m.numberOfRanges >= 2
            else { continue }
            let name = ns.substring(with: m.range(at: 1))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if name.count >= 2, name.count <= 60 { return name }
        }
        return nil
    }

    // MARK: - Meal Plan Name

    static func parseMealPlanName(from text: String) -> String? {
        let ns = text as NSString
        let patterns = [
            #"(?i)((?:mean green|eagle|platinum|gold|silver|bronze|unlimited)\s*\d*\s*meal\s*plan[^\n]{0,30})"#,
            #"(?i)(meal\s*plan\s*type[:\s]+[^\n]{3,40})"#,
        ]
        for pattern in patterns {
            guard let re = try? NSRegularExpression(pattern: pattern),
                  let m = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
                  m.numberOfRanges >= 2
            else { continue }
            let name = ns.substring(with: m.range(at: 1))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if name.count >= 4 { return name }
        }
        return nil
    }

    // MARK: - Swipes

    // Matches "Meal swipes left" (case-insensitive), then finds the count in
    // the following 900 characters. Returns "Unlimited" or a digit string.
    private static func parseSwipesLeft(from text: String) -> String? {
        let ns    = text as NSString
        let lower = text.lowercased()

        guard let re = try? NSRegularExpression(pattern: #"(?i)meal\s*swipes\s*left"#),
              let m  = re.firstMatch(in: lower, range: NSRange(location: 0, length: ns.length))
        else { return nil }

        let afterStart = m.range.location + m.range.length
        let afterLen   = max(0, ns.length - afterStart)
        let chunk      = String(ns.substring(with: NSRange(location: afterStart,
                                                           length: min(afterLen, 900))))
        let chunkLower = chunk.lowercased()

        if chunkLower.contains("unlimited") { return "Unlimited" }

        // Check for -1 sentinel (some portals use -1 to mean "unlimited")
        if let v = matchFirstInt(in: chunk, allowNegative: true), v == -1 { return "Unlimited" }

        return matchFirstInt(in: chunk, allowNegative: false).map { "\($0)" }
    }

    private static func parseSwipesFallback(from text: String) -> String? {
        let lower = text.lowercased()
        if lower.contains("unlimited") { return "Unlimited" }
        return nil
    }

    // MARK: - Flex

    // Looks for "Flex MP" section, then "Current Balance" within the next 2000 chars.
    private static func parseFlexLeft(from text: String) -> Double? {
        let ns    = text as NSString
        let lower = text.lowercased()

        guard let re = try? NSRegularExpression(pattern: #"(?i)flex\s*mp"#),
              let m  = re.firstMatch(in: lower, range: NSRange(location: 0, length: ns.length))
        else { return nil }

        let afterStart = m.range.location + m.range.length
        let afterLen   = max(0, ns.length - afterStart)
        let chunk      = ns.substring(with: NSRange(location: afterStart,
                                                    length: min(afterLen, 2000)))

        return firstAmountAfterLabel(in: chunk.lowercased(), label: "current balance")
    }

    // Fallback: "Current Balance" anywhere with a nearby dollar amount
    private static func parseFlexFallback(from text: String) -> Double? {
        let lower = text.lowercased()
        guard let re = try? NSRegularExpression(
            pattern: #"(?i)current\s*balance[^0-9$\-\n]{0,40}\$?\s*(-?\d+(?:[.,]\d+)?)"#
        ) else { return nil }

        let ns = lower as NSString
        guard let m = re.firstMatch(in: lower, range: NSRange(location: 0, length: ns.length)),
              m.numberOfRanges >= 2
        else { return nil }

        let raw = ns.substring(with: m.range(at: m.numberOfRanges - 1))
        return Double(raw.replacingOccurrences(of: ",", with: ".")
                        .trimmingCharacters(in: .whitespaces))
    }

    // MARK: - Helpers

    private static func firstAmountAfterLabel(in text: String, label: String) -> Double? {
        let lower = text.lowercased()
        guard let r = lower.range(of: label.lowercased()) else { return nil }
        let after = String(text[r.upperBound...].prefix(200))
        return matchFirstAmount(in: after)
    }

    private static func matchFirstInt(in text: String, allowNegative: Bool) -> Int? {
        let pattern = allowNegative ? #"(-?\d+)"# : #"\b(\d+)\b"#
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        guard let m = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              m.numberOfRanges >= 2
        else { return nil }
        let raw = ns.substring(with: m.range(at: m.numberOfRanges - 1))
        return Int(raw.trimmingCharacters(in: .whitespaces))
    }

    static func matchFirstAmount(in text: String) -> Double? {
        let pattern = #"\$?\s*(-?\d+(?:[.,]\d+)?)"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        else { return nil }
        let ns = text as NSString
        guard let m = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              m.numberOfRanges >= 2
        else { return nil }
        let raw = ns.substring(with: m.range(at: m.numberOfRanges - 1))
        return Double(raw.replacingOccurrences(of: ",", with: ".")
                        .trimmingCharacters(in: .whitespaces))
    }
}
