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

enum WidgetSnapshot {
    private struct HallSchedule {
        let id: String
        let name: String
        let weekdayOpen: Int
        let weekdayClose: Int
        let weekendOpen: Int
        let weekendClose: Int
    }

    private static let halls: [HallSchedule] = [
        HallSchedule(id: "bruceteria", name: "Bruceteria", weekdayOpen: 7 * 60, weekdayClose: 16 * 60 + 30, weekendOpen: 0, weekendClose: 0),
        HallSchedule(id: "champs", name: "Champs", weekdayOpen: 7 * 60, weekdayClose: 20 * 60, weekendOpen: 0, weekendClose: 0),
        HallSchedule(id: "eagle-landing", name: "Eagle Landing", weekdayOpen: 10 * 60, weekdayClose: 21 * 60, weekendOpen: 10 * 60, weekendClose: 21 * 60),
        HallSchedule(id: "kitchen-west", name: "Kitchen West", weekdayOpen: 11 * 60, weekdayClose: 19 * 60, weekendOpen: 0, weekendClose: 0),
        HallSchedule(id: "mean-greens", name: "Mean Greens Café", weekdayOpen: 7 * 60, weekdayClose: 20 * 60, weekendOpen: 0, weekendClose: 0),
    ]

    static func mealPeriod(for date: Date = Date()) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 7..<10:  return "Breakfast"
        case 10..<14: return "Lunch"
        case 14..<21: return "Dinner"
        default:      return "Closed"
        }
    }

    static func hallStatuses(for date: Date = Date()) -> [WidgetHallStatus] {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let isWeekend = weekday == 1 || weekday == 7
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let now = hour * 60 + minute
        let period = mealPeriod(for: date)

        return halls.map { hall in
            let open = isWeekend ? hall.weekendOpen : hall.weekdayOpen
            let close = isWeekend ? hall.weekendClose : hall.weekdayClose
            let isOpen = open > 0 && close > 0 && now >= open && now < close
            return WidgetHallStatus(id: hall.id, name: hall.name, isOpen: isOpen, mealPeriod: period)
        }
    }
}
