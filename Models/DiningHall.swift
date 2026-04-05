import SwiftUI

// MARK: - Meal Period

enum MealPeriod: String, CaseIterable, Codable {
    case breakfast  = "Breakfast"
    case lunch      = "Lunch"
    case dinner     = "Dinner"
    case lateNight  = "Late Night"
    case closed     = "Closed"

    var icon: String {
        switch self {
        case .breakfast: return "sun.horizon.fill"
        case .lunch:     return "sun.max.fill"
        case .dinner:    return "moon.stars.fill"
        case .lateNight: return "moon.fill"
        case .closed:    return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .breakfast: return Color(hex: "F59E0B")
        case .lunch:     return Color(hex: "00853E")
        case .dinner:    return Color(hex: "3B82F6")
        case .lateNight: return Color(hex: "8B5CF6")
        case .closed:    return Color(hex: "EF4444")
        }
    }

    static func current(for date: Date = Date()) -> MealPeriod {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let totalMinutes = hour * 60 + minute
        switch totalMinutes {
        case 420..<600:   return .breakfast   // 7:00 – 10:00
        case 600..<840:   return .lunch       // 10:00 – 14:00
        case 840..<1260:  return .dinner      // 14:00 – 21:00
        case 1260..<1440: return .lateNight   // 21:00 – 24:00
        default:          return .closed
        }
    }

    var greeting: String {
        switch self {
        case .breakfast: return "Good morning! 🌅"
        case .lunch:     return "It's lunch time!"
        case .dinner:    return "Dinner is served!"
        case .lateNight: return "Late night fuel 🌙"
        case .closed:    return "Dining halls are closed"
        }
    }
}

// MARK: - Dining Hall

struct DiningHall: Identifiable, Codable, Hashable {
    let id: String
    /// Integer locationID used by diningmenus.unt.edu
    let locationID: Int
    let name: String
    let subtitle: String
    let description: String
    let location: String
    let latitude: Double
    let longitude: Double
    let gradientStart: String
    let gradientEnd: String
    let iconName: String
    let hoursText: String
    /// Overall weekday open window (Mon–Fri)
    let weekdayHours: DayHours
    /// Weekend open window (Sat–Sun); use openHour==0,closeHour==0 if closed
    let weekendHours: DayHours
    let tags: [String]
    let imageURL: String?
    var isFavorite: Bool = false

    var isOpen: Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        let isWeekend = weekday == 1 || weekday == 7
        let hours = isWeekend ? weekendHours : weekdayHours
        return hours.isCurrentlyOpen
    }

    var currentMealPeriod: MealPeriod {
        guard isOpen else { return .closed }
        return MealPeriod.current()
    }

    var gradientColors: [Color] {
        [Color(hex: gradientStart), Color(hex: gradientEnd)]
    }
}

// MARK: - Day Hours

struct DayHours: Codable, Hashable {
    let openHour: Int
    let openMinute: Int
    let closeHour: Int
    let closeMinute: Int

    var isCurrentlyOpen: Bool {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let total = hour * 60 + minute
        let open  = openHour * 60 + openMinute
        let close = closeHour * 60 + closeMinute
        return total >= open && total < close
    }

    var displayString: String {
        let openStr  = formatTime(hour: openHour,  minute: openMinute)
        let closeStr = formatTime(hour: closeHour, minute: closeMinute)
        return "\(openStr) – \(closeStr)"
    }

    private func formatTime(hour: Int, minute: Int) -> String {
        let period = hour < 12 ? "AM" : "PM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return minute == 0 ? "\(displayHour) \(period)" : "\(displayHour):\(String(format: "%02d", minute)) \(period)"
    }
}

// MARK: - Hall Data
// locationIDs confirmed from diningmenus.unt.edu navigation
// Hours from dining.unt.edu/hours (Spring 2026 standard hours)

extension DiningHall {
    static let sampleHalls: [DiningHall] = [
        DiningHall(
            id:          "bruceteria",
            locationID:  20,
            name:        "Bruceteria",
            subtitle:    "All-You-Care-To-Eat",
            description: "The heart of residential dining at UNT. Features a wide selection of globally inspired dishes, made-to-order stations, and rotating seasonal menus.",
            location:    "Bruce Hall, 1624 Chestnut St",
            latitude:    33.21040, longitude: -97.15180,
            gradientStart: "00853E",
            gradientEnd:   "005227",
            iconName:    "fork.knife",
            hoursText:   "Mon–Fri 7 AM – 4:30 PM",
            weekdayHours: DayHours(openHour: 7, openMinute: 0, closeHour: 16, closeMinute: 30),
            weekendHours: DayHours(openHour: 0, openMinute: 0, closeHour: 0,  closeMinute: 0),
            tags: ["All-You-Can-Eat", "Global Cuisine", "Made-to-Order"],
            imageURL: nil
        ),
        DiningHall(
            id:          "champs",
            locationID:  15,
            name:        "Champs",
            subtitle:    "Sports Nutrition",
            description: "Performance-focused dining at Victory Hall near Apogee Stadium. Designed for athletes and active students with high-protein options.",
            location:    "Victory Hall, 1379 S Bonnie Brae",
            latitude:    33.21530, longitude: -97.15330,
            gradientStart: "1A5276",
            gradientEnd:   "003D1F",
            iconName:    "figure.run",
            hoursText:   "Mon–Thu 7 AM – 8 PM",
            weekdayHours: DayHours(openHour: 7, openMinute: 0, closeHour: 20, closeMinute: 0),
            weekendHours: DayHours(openHour: 0, openMinute: 0, closeHour: 0,  closeMinute: 0),
            tags: ["High Protein", "Athletic", "Performance"],
            imageURL: nil
        ),
        DiningHall(
            id:          "eagle-landing",
            locationID:  31,
            name:        "Eagle Landing",
            subtitle:    "Residential Dining",
            description: "A welcoming dining hall in the residential district featuring comfort food classics alongside global options and a lively atmosphere.",
            location:    "Eagle Landing, 1416 Maple",
            latitude:    33.20910, longitude: -97.15450,
            gradientStart: "27AE60",
            gradientEnd:   "1E8449",
            iconName:    "house.fill",
            hoursText:   "Mon–Thu 10 AM – 9 PM",
            weekdayHours: DayHours(openHour: 10, openMinute: 0, closeHour: 21, closeMinute: 0),
            weekendHours: DayHours(openHour: 10, openMinute: 0, closeHour: 21, closeMinute: 0),
            tags: ["Comfort Food", "Diverse Menu", "Residential"],
            imageURL: nil
        ),
        DiningHall(
            id:          "kitchen-west",
            locationID:  25,
            name:        "Kitchen West",
            subtitle:    "Allergen-Free Zone",
            description: "Texas' first university dining hall Certified Free From™ the Big 9 Food Allergens. A safe haven for students with food allergies.",
            location:    "West Hall, 320 N Texas Blvd",
            latitude:    33.21120, longitude: -97.15690,
            gradientStart: "7D3C98",
            gradientEnd:   "512E58",
            iconName:    "leaf.fill",
            hoursText:   "Mon–Thu 11 AM – 7 PM",
            weekdayHours: DayHours(openHour: 11, openMinute: 0, closeHour: 19, closeMinute: 0),
            weekendHours: DayHours(openHour: 0,  openMinute: 0, closeHour: 0,  closeMinute: 0),
            tags: ["Allergen-Free", "Top-9 Free", "Safe Dining"],
            imageURL: nil
        ),
        DiningHall(
            id:          "mean-greens",
            locationID:  10,
            name:        "Mean Greens Caf\u{00E9}",
            subtitle:    "100% Vegan",
            description: "America's first all-vegan university dining hall. Plant-forward, sustainability-driven, and delicious — proving vegan food is anything but boring.",
            location:    "Maple Hall, 902 Avenue C",
            latitude:    33.20850, longitude: -97.15120,
            gradientStart: "00853E",
            gradientEnd:   "003D1F",
            iconName:    "leaf.circle.fill",
            hoursText:   "Mon–Thu 7 AM – 8 PM",
            weekdayHours: DayHours(openHour: 7,  openMinute: 0, closeHour: 20, closeMinute: 0),
            weekendHours: DayHours(openHour: 0,  openMinute: 0, closeHour: 0,  closeMinute: 0),
            tags: ["Vegan", "Plant-Based", "Sustainable"],
            imageURL: nil
        )
    ]
}
