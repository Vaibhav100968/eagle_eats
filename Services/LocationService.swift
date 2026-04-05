import CoreLocation
import Foundation

// MARK: - Location Service
// CoreLocation hook for future "nearest dining hall" feature.
// Does not request permissions on init — call requestPermission() explicitly.

@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {

    static let shared = LocationService()

    @Published private(set) var currentLocation: CLLocationCoordinate2D?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()

    override private init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        guard authorizationStatus == .authorizedWhenInUse ||
              authorizationStatus == .authorizedAlways else { return }
        manager.requestLocation()
    }

    // MARK: - Nearest Hall

    struct HallDistance: Identifiable {
        let hallId: String
        let hallName: String
        let meters: Double
        var id: String { hallId }
    }

    func nearestHalls() -> [HallDistance] {
        guard let loc = currentLocation else { return [] }
        let userLoc = CLLocation(latitude: loc.latitude, longitude: loc.longitude)
        return DiningHall.sampleHalls.map { hall in
            let hallLoc = CLLocation(latitude: hall.latitude, longitude: hall.longitude)
            return HallDistance(
                hallId: hall.id,
                hallName: hall.name,
                meters: userLoc.distance(from: hallLoc)
            )
        }.sorted { $0.meters < $1.meters }
    }

    func distance(to hall: DiningHall) -> Double? {
        guard let loc = currentLocation else { return nil }
        let userLoc = CLLocation(latitude: loc.latitude, longitude: loc.longitude)
        let hallLoc = CLLocation(latitude: hall.latitude, longitude: hall.longitude)
        return userLoc.distance(from: hallLoc)
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            currentLocation = locations.last?.coordinate
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
        }
    }
}
