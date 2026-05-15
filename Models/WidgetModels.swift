import Foundation

// Shared models between the main app and widget extension.
// Both targets must include this file.

struct WidgetMenuItem: Codable, Identifiable {
    let id: String
    let name: String
    let hallName: String
    let calories: Int
    let station: String
}

struct WidgetHallStatus: Codable, Identifiable {
    let id: String
    let name: String
    let isOpen: Bool
    let mealPeriod: String
}
