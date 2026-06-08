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
    case dessert    = "Dessert"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .coffee:     return "cup.and.saucer.fill"
        case .fastFood:   return "takeoutbag.and.cup.and.straw.fill"
        case .restaurant: return "fork.knife"
        case .market:     return "cart.fill"
        case .dessert:    return "birthday.cake.fill"
        }
    }

    var tint: String {
        switch self {
        case .coffee:     return "8B5CF6"
        case .fastFood:   return "FF3B30"
        case .restaurant: return "FF9500"
        case .market:     return "34C759"
        case .dessert:    return "FF2D55"
        }
    }
}

// MARK: - UNT Retail Locations (Where to Spend)

extension RetailLocation {
    /// Dining halls + Discovery Park only — used on the campus map.
    static let mapLocations: [RetailLocation] = [discoveryPark]

    static let discoveryPark = RetailLocation(
        id: "discovery-park",
        name: "Discovery Park",
        category: .market,
        building: "Discovery Park",
        address: "3940 N Elm St, Denton, TX 76207",
        latitude: 33.2526,
        longitude: -97.1518,
        hoursText: "Mon–Thu 7:30 AM – 6 PM",
        iconName: "building.2.fill",
        acceptsSwipes: false,
        acceptsFlex: true
    )

    /// University Union center — retail pins use small offsets from here.
    private static let unionLat = 33.20989
    private static let unionLon = -97.15148

    static let allLocations: [RetailLocation] = [
        // University Union — 1st floor
        RetailLocation(
            id: "chick-fil-a",
            name: "Chick-fil-A",
            category: .fastFood,
            building: "University Union — 1st Floor",
            address: "1155 Union Cir, Denton, TX 76203",
            latitude: unionLat + 0.00004,
            longitude: unionLon + 0.00002,
            hoursText: "Mon–Fri 10:30 AM – 8 PM",
            iconName: "takeoutbag.and.cup.and.straw.fill",
            acceptsSwipes: false,
            acceptsFlex: true
        ),
        RetailLocation(
            id: "jamba-juice",
            name: "Jamba Juice",
            category: .coffee,
            building: "University Union — 1st Floor",
            address: "1155 Union Cir, Denton, TX 76203",
            latitude: unionLat + 0.00002,
            longitude: unionLon - 0.00001,
            hoursText: "Mon–Fri 8 AM – 6 PM",
            iconName: "cup.and.saucer.fill",
            acceptsSwipes: false,
            acceptsFlex: true
        ),
        RetailLocation(
            id: "scrappys-ice-cream",
            name: "Scrappy's Ice Cream",
            category: .dessert,
            building: "University Union — 1st Floor",
            address: "1155 Union Cir, Denton, TX 76203",
            latitude: unionLat - 0.00001,
            longitude: unionLon + 0.00003,
            hoursText: "Mon–Thu 10 AM – 5 PM, Fri 10 AM – 3 PM",
            iconName: "birthday.cake.fill",
            acceptsSwipes: false,
            acceptsFlex: true
        ),
        RetailLocation(
            id: "market-union",
            name: "Market Union",
            category: .market,
            building: "University Union",
            address: "1155 Union Cir, Denton, TX 76203",
            latitude: unionLat - 0.00003,
            longitude: unionLon - 0.00002,
            hoursText: "Mon–Fri 8 AM – 8 PM",
            iconName: "cart.fill",
            acceptsSwipes: false,
            acceptsFlex: true
        ),
        RetailLocation(
            id: "union-burger",
            name: "Union Burger",
            category: .fastFood,
            building: "University Union",
            address: "1155 Union Cir, Denton, TX 76203",
            latitude: unionLat - 0.00002,
            longitude: unionLon + 0.00005,
            hoursText: "Mon–Fri 11 AM – 8 PM",
            iconName: "takeoutbag.and.cup.and.straw.fill",
            acceptsSwipes: false,
            acceptsFlex: true
        ),

        // University Union — 2nd floor
        RetailLocation(
            id: "burger-king",
            name: "Burger King",
            category: .fastFood,
            building: "University Union — 2nd Floor",
            address: "1155 Union Cir, Denton, TX 76203",
            latitude: unionLat + 0.00001,
            longitude: unionLon + 0.00004,
            hoursText: "Mon–Fri 10 AM – 8 PM",
            iconName: "takeoutbag.and.cup.and.straw.fill",
            acceptsSwipes: false,
            acceptsFlex: true
        ),
        RetailLocation(
            id: "krispy-krunchy",
            name: "Krispy Krunchy Chicken",
            category: .fastFood,
            building: "University Union — 2nd Floor",
            address: "1155 Union Cir, Denton, TX 76203",
            latitude: unionLat + 0.00003,
            longitude: unionLon - 0.00003,
            hoursText: "Mon–Fri 10:30 AM – 8 PM",
            iconName: "takeoutbag.and.cup.and.straw.fill",
            acceptsSwipes: false,
            acceptsFlex: true
        ),
        RetailLocation(
            id: "union-cafe",
            name: "Union Cafe",
            category: .coffee,
            building: "University Union — 2nd Floor",
            address: "1155 Union Cir, Denton, TX 76203",
            latitude: unionLat - 0.00001,
            longitude: unionLon - 0.00004,
            hoursText: "Mon–Fri 7 AM – 4 PM",
            iconName: "cup.and.saucer.fill",
            acceptsSwipes: false,
            acceptsFlex: true
        ),

        // Other campus
        discoveryPark,
        RetailLocation(
            id: "market-gab",
            name: "The Market at G.A.B.",
            category: .market,
            building: "General Academic Building",
            address: "704 W Sycamore St, Denton, TX 76203",
            latitude: 33.2078,
            longitude: -97.1524,
            hoursText: "Mon–Fri 7:30 AM – 4 PM",
            iconName: "cart.fill",
            acceptsSwipes: false,
            acceptsFlex: true
        ),
    ]
}
