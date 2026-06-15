import Foundation
import CoreLocation
import MapKit

/// Zentrale Einstellungen für den Taxi-Bereich (Zentrale, Logo, etc.).
enum TaxiConfig {
    /// Asset-Name für Header-Logo auf Karten-Ansichten — `pickup_background`.
    static let logoImageName: String? = "pickup_background"

    /// Vollbild-Hintergrund im Buchungsflow.
    static let backgroundImageName = "app_background"

    /// Asset-Name für Fahrerbild (oben links, Fahrer-Sheet) — `driver_avatar`.
    static let driverPhotoImageName = "driver_avatar"

    /// Standard-Fahrer für die Startseite (Prototyp).
    static var defaultDriver: TaxiDriver {
        TaxiDriver(
            name: "Markus",
            coordinate: defaultMapCenter,
            phoneNumber: centralPhoneNumber,
            photoImageName: driverPhotoImageName
        )
    }

    /// Telefonnummer der Taxi-Zentrale („Zentrale Anrufen“).
    static let centralPhoneNumber = "03012345678"

    /// Geografische Mitte Europas — Standard für Abholort-Karte.
    static let defaultMapCenter = CLLocationCoordinate2D(latitude: 51.1657, longitude: 10.4515)

    /// Straßen-Zoom beim Abholpunkt setzen.
    static let defaultMapSpanDelta: CLLocationDegrees = 0.012

    /// Europa-Übersicht — Startansicht der Abholort-Karte.
    static var europeOverviewRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 50.0, longitude: 12.0),
            span: MKCoordinateSpan(latitudeDelta: 28, longitudeDelta: 38)
        )
    }

    /// Fallback ohne GPS — zentrale Europa-Ansicht.
    static var regionOverviewFallback: MKCoordinateRegion {
        europeOverviewRegion
    }

    static var germanyOverviewRegion: MKCoordinateRegion {
        regionOverviewFallback
    }

    /// Straßen-Ansicht um einen Punkt.
    static func streetLevelRegion(center: CLLocationCoordinate2D) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: defaultMapSpanDelta,
                longitudeDelta: defaultMapSpanDelta
            )
        )
    }

    /// Deutschland — Legacy-Hilfsfunktion.
    static func isInGermany(_ coordinate: CLLocationCoordinate2D) -> Bool {
        coordinate.latitude >= 47.2 && coordinate.latitude <= 55.2
            && coordinate.longitude >= 5.7 && coordinate.longitude <= 15.1
    }

    /// Europa-Bounding-Box — GPS-Zentrierung und Standortprüfung.
    static func isInEurope(_ coordinate: CLLocationCoordinate2D) -> Bool {
        coordinate.latitude >= 35 && coordinate.latitude <= 72
            && coordinate.longitude >= -12 && coordinate.longitude <= 45
    }

    /// Formatierte Nummer für tel:-Links (ohne Leerzeichen).
    static var centralPhoneURLString: String {
        "tel:\(centralPhoneNumber.replacingOccurrences(of: " ", with: ""))"
    }

    // MARK: - Stripe (Testmodus)

    /// Publishable Key aus Stripe Dashboard (pk_test_…).
    static let stripePublishableKey = "pk_test_PLACEHOLDER"

    /// Cloud-Backend (HTTPS) — nach Render-Deploy eintragen.
    /// Deploy: github.com/Lucky18pc/Taxi-APP → dashboard.render.com/blueprints
    /// Beispiel: https://taxiapp-api.onrender.com
    static let cloudBackendURL = "https://taxiapp-api.onrender.com"

    /// Mac im gleichen WLAN — nur wenn cloudBackendURL leer ist.
    static let deviceBackendURL = "http://192.168.1.1:4242"

    /// Backend für Buchungen, Stripe, Leitstellen-Config.
    static var stripeBackendURL: String {
        let cloud = cloudBackendURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cloud.isEmpty {
            return cloud.hasSuffix("/") ? String(cloud.dropLast()) : cloud
        }
        #if targetEnvironment(simulator)
        return "http://127.0.0.1:4242"
        #else
        return deviceBackendURL
        #endif
    }
}
