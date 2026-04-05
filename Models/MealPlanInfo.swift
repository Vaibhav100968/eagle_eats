import Foundation

// MARK: - Meal Plan Data

struct MealPlanInfo: Codable, Equatable {
    var diningSwipes:   Int?
    var flexBalance:    Double?
    var mealPlanName:   String?
    var accountHolder:  String?
    var lastUpdated:    Date
    var isCached:       Bool    = false
    var fetchError:     String? = nil

    var hasAnyData: Bool {
        diningSwipes != nil || flexBalance != nil
    }

    var flexDisplay: String {
        guard let flex = flexBalance else { return "—" }
        return String(format: "$%.2f", flex)
    }

    var swipesDisplay: String {
        guard let swipes = diningSwipes else { return "—" }
        return swipes == 9999 ? "Unlimited" : "\(swipes)"
    }

    var lastUpdatedDisplay: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastUpdated, relativeTo: Date())
    }

    static let empty = MealPlanInfo(lastUpdated: Date())
}

// MARK: - Auth State for Meal Plan

enum MealPlanAuthState: Equatable {
    case notAuthenticated
    case loading
    case authenticated(MealPlanInfo)
    case stale(MealPlanInfo)          // Has cached data but live refresh failed
    case sessionExpired
    case error(String)
}
