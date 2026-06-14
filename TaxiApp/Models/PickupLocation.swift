import CoreLocation
import Foundation

/// Abholpunkt — wird bei „Weiter“ auf der Karte gespeichert und an die Zentrale übermittelt.
struct PickupLocation: Hashable, Codable, Sendable, Identifiable {
    var latitude: Double
    var longitude: Double
    var addressLine: String
    /// Zieladresse (Text), optional — wird an die Leitstelle übermittelt.
    var destinationAddressLine: String = ""

    var id: String {
        "\(latitude)-\(longitude)-\(addressLine)-\(destinationAddressLine)"
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    static var defaultPlaceholder: PickupLocation {
        PickupLocation(
            latitude: TaxiConfig.defaultMapCenter.latitude,
            longitude: TaxiConfig.defaultMapCenter.longitude,
            addressLine: "Abholort wird auf der Karte festgelegt"
        )
    }
}

struct PickupMapPin: Identifiable {
    let id = UUID()
    let location: PickupLocation
}
