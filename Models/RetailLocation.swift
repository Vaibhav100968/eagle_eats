import SwiftUI
import CoreLocation

// MARK: - Retail Dining Location
// Places on campus that accept Dining Dollars / Flex outside the main dining halls.

struct RetailLocation: Identifiable, Hashable {
    let id: String
    let name: String
    let category: RetailCategory
    let building: String
    let address: String
    let latitude: Double
    let longitude: Double
    let hoursText: String
    let iconName: String
    let acceptsSwipes: Bool
    let acceptsFlex: Bool

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

enum RetailCategory: String, CaseIterable, Identifiable {
    case coffee     = "Coffee"
    case fastFood   = "Fast Food"
    case restaurant = "Restaurant"
    case market     = "Market"
    case foodTruck  = "Food Truck"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .coffee:     return "cup.and.saucer.fill"
        case .fastFood:   return "takeoutbag.and.cup.and.straw.fill"
        case .restaurant: return "fork.knife"
        case .market:     return "cart.fill"
        case .foodTruck:  return "truck.box.fill"
        }
    }

    var tint: String {
        switch self {
        case .coffee:     return "8B5CF6"
        case .fastFood:   return "FF3B30"
        case .restaurant: return "FF9500"
        case .market:     return "34C759"
        case .foodTruck:  return "007AFF"
        }
    }
}

// MARK: - UNT Retail Locations

extension RetailLocation {
    static let allLocations: [RetailLocation] = [
        // University Union
        RetailLocation(
            id: "chick-fil-a", name: "Chick-fil-A",
            category: .fastFood, building: "University Union",
            address: "1155 Union Circle, Denton, TX",
            latitude: 33.2098, longitude: -97.1527,
            hoursText: "Mon-Sat 7:30 AM - 9 PM",
            iconName: "takeoutbag.and.cup.and.straw.fill",
            acceptsSwipes: false, acceptsFlex: true
        ),
        RetailLocation(
            id: "panda-express", name: "Panda Express",
            category: .fastFood, building: "University Union",
            address: "1155 Union Circle, Denton, TX",
            latitude: 33.2097, longitude: -97.1525,
            hoursText: "Mon-Fri 10:30 AM - 8 PM",
            iconName: "takeoutbag.and.cup.and.straw.fill",
            acceptsSwipes: false, acceptsFlex: true
        ),
        RetailLocation(
            id: "which-wich", name: "Which Wich",
            category: .fastFood, building: "University Union",
            address: "1155 Union Circle, Denton, TX",
            latitude: 33.2096, longitude: -97.1526,
            hoursText: "Mon-Fri 10:30 AM - 7 PM",
            iconName: "takeoutbag.and.cup.and.straw.fill",
            acceptsSwipes: false, acceptsFlex: true
        ),
        RetailLocation(
            id: "starbucks-union", name: "Starbucks",
            category: .coffee, building: "University Union",
            address: "1155 Union Circle, Denton, TX",
            latitude: 33.2099, longitude: -97.1528,
            hoursText: "Mon-Fri 7 AM - 9 PM",
            iconName: "cup.and.saucer.fill",
            acceptsSwipes: false, acceptsFlex: true
        ),
        RetailLocation(
            id: "union-market", name: "Mean Green Market",
            category: .market, building: "University Union",
            address: "1155 Union Circle, Denton, TX",
            latitude: 33.2095, longitude: -97.1524,
            hoursText: "Mon-Fri 8 AM - 8 PM",
            iconName: "cart.fill",
            acceptsSwipes: false, acceptsFlex: true
        ),

        // Willis Library
        RetailLocation(
            id: "starbucks-library", name: "Starbucks",
            category: .coffee, building: "Willis Library",
            address: "1506 Highland St, Denton, TX",
            latitude: 33.2103, longitude: -97.1498,
            hoursText: "Mon-Fri 7:30 AM - 10 PM",
            iconName: "cup.and.saucer.fill",
            acceptsSwipes: false, acceptsFlex: true
        ),

        // Discovery Park
        RetailLocation(
            id: "dp-cafe", name: "Discovery Park Cafe",
            category: .restaurant, building: "Discovery Park",
            address: "3940 N Elm St, Denton, TX",
            latitude: 33.2526, longitude: -97.1518,
            hoursText: "Mon-Thu 7:30 AM - 6 PM",
            iconName: "fork.knife",
            acceptsSwipes: false, acceptsFlex: true
        ),

        // Business Leadership Building
        RetailLocation(
            id: "einstein-blb", name: "Einstein Bros. Bagels",
            category: .coffee, building: "Business Leadership Building",
            address: "1307 W Highland St, Denton, TX",
            latitude: 33.2108, longitude: -97.1537,
            hoursText: "Mon-Fri 7 AM - 3 PM",
            iconName: "cup.and.saucer.fill",
            acceptsSwipes: false, acceptsFlex: true
        ),

        // General Academic Building
        RetailLocation(
            id: "jazzman-gab", name: "Jazzman's Cafe",
            category: .coffee, building: "General Academic Building",
            address: "704 W Sycamore St, Denton, TX",
            latitude: 33.2076, longitude: -97.1530,
            hoursText: "Mon-Fri 7:30 AM - 4 PM",
            iconName: "cup.and.saucer.fill",
            acceptsSwipes: false, acceptsFlex: true
        ),

        // Wooten Hall
        RetailLocation(
            id: "fuzzys", name: "Fuzzy's Taco Shop",
            category: .restaurant, building: "Wooten Hall",
            address: "1155 Union Circle, Denton, TX",
            latitude: 33.2092, longitude: -97.1520,
            hoursText: "Mon-Fri 10 AM - 7 PM",
            iconName: "fork.knife",
            acceptsSwipes: false, acceptsFlex: true
        ),

        // Maple Hall
        RetailLocation(
            id: "jp-market", name: "JP's Market",
            category: .market, building: "Maple Hall",
            address: "902 Avenue C, Denton, TX",
            latitude: 33.2083, longitude: -97.1510,
            hoursText: "Mon-Fri 11 AM - 11 PM",
            iconName: "cart.fill",
            acceptsSwipes: false, acceptsFlex: true
        ),

        // Kerr Hall
        RetailLocation(
            id: "kerr-market", name: "Kerr Corner Store",
            category: .market, building: "Kerr Hall",
            address: "1401 W Mulberry St, Denton, TX",
            latitude: 33.2115, longitude: -97.1555,
            hoursText: "Mon-Thu 4 PM - 11 PM",
            iconName: "cart.fill",
            acceptsSwipes: false, acceptsFlex: true
        ),
    ]
}
