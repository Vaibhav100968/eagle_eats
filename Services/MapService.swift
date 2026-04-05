import MapKit
import CoreLocation

// MARK: - Map Service
// Opens Apple Maps for turn-by-turn navigation and calculates distances.

struct MapService {

    static func openDirections(to hall: DiningHall) {
        let coordinate = CLLocationCoordinate2D(
            latitude: hall.latitude, longitude: hall.longitude
        )
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = hall.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }

    static func distance(from userLocation: CLLocationCoordinate2D?, to hall: DiningHall) -> Double? {
        guard let loc = userLocation else { return nil }
        let user = CLLocation(latitude: loc.latitude, longitude: loc.longitude)
        let dest = CLLocation(latitude: hall.latitude, longitude: hall.longitude)
        return user.distance(from: dest)
    }

    static func formattedDistance(meters: Double) -> String {
        let miles = meters / 1609.344
        if miles < 0.1 {
            let feet = Int(meters * 3.28084)
            return "\(feet) ft"
        }
        return String(format: "%.1f mi", miles)
    }
}
