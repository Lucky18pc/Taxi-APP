import SwiftUI
import MapKit
import CoreLocation

@MainActor
final class TaxiViewModel: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()

    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 52.52, longitude: 13.40),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var searchResults: [MKMapItem] = []
    @Published var route: MKRoute?
    @Published var taxiPos = CLLocationCoordinate2D(latitude: 52.515, longitude: 13.395)

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first?.coordinate {
            Task { @MainActor in
                self.userLocation = location
            }
        }
    }

    func searchPlaces(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        MKLocalSearch(request: request).start { [weak self] response, _ in
            Task { @MainActor in
                self?.searchResults = response?.mapItems ?? []
            }
        }
    }

    /// Kurzform wie im Master-Code
    func search(query: String) {
        searchPlaces(query: query)
    }
}
