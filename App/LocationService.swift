import CoreLocation
import Foundation
import MapKit
import Observation

struct RJPlaceResult: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
}

@MainActor
@Observable
final class LocationService: NSObject, @preconcurrency CLLocationManagerDelegate {
    static let shared = LocationService()

    private let manager = CLLocationManager()
    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var currentLocation: CLLocation?
    private(set) var lastError: String?

    override private init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var isAlwaysAuthorized: Bool { authorizationStatus == .authorizedAlways }

    var statusText: String {
        switch authorizationStatus {
        case .authorizedAlways: "Immer erlaubt"
        case .authorizedWhenInUse: "Nur beim Verwenden"
        case .denied: "Abgelehnt"
        case .restricted: "Eingeschränkt"
        case .notDetermined: "Nicht angefragt"
        @unknown default: "Unbekannt"
        }
    }

    func requestLocationReminderAccess() {
        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        case .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            lastError = "Erlaube den Standortzugriff in Einstellungen › Datenschutz › Ortungsdienste."
        @unknown default:
            break
        }
    }

    func requestCurrentLocation() {
        if authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        manager.requestLocation()
    }

    func search(_ query: String) async throws -> [RJPlaceResult] {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count >= 2 else { return [] }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = cleaned
        if let currentLocation {
            request.region = MKCoordinateRegion(
                center: currentLocation.coordinate,
                latitudinalMeters: 80_000,
                longitudinalMeters: 80_000
            )
        }
        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems.prefix(12).map { item in
            let coordinate = item.placemark.coordinate
            return RJPlaceResult(
                id: "\(coordinate.latitude),\(coordinate.longitude)",
                name: item.name ?? item.placemark.locality ?? cleaned,
                address: item.placemark.title ?? cleaned,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
        }
    }

    func currentPlace() -> RJPlaceResult? {
        guard let coordinate = currentLocation?.coordinate else { return nil }
        return RJPlaceResult(
            id: "current-\(coordinate.latitude),\(coordinate.longitude)",
            name: "Aktueller Standort",
            address: "Aktuelle Position",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse {
            manager.requestAlwaysAuthorization()
        }
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
        lastError = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        lastError = error.localizedDescription
        DebugLogger.shared.log("Location error: \(error)")
    }
}
