import CoreLocation

enum GeocodingService {
    static func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> String {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            let places = try await geocoder.reverseGeocodeLocation(
                location,
                preferredLocale: Locale.current
            )
            if let place = places.first {
                let street = [place.thoroughfare, place.subThoroughfare]
                    .compactMap { $0 }
                    .joined(separator: " ")
                let city = [place.postalCode, place.locality]
                    .compactMap { $0 }
                    .joined(separator: " ")
                let parts = [street, city].filter { !$0.isEmpty }
                if !parts.isEmpty {
                    return parts.joined(separator: ", ")
                }
            }
        } catch {
            // Fallback auf Koordinaten
        }

        return String(format: "Standort (%.5f, %.5f)", coordinate.latitude, coordinate.longitude)
    }
}
