import Foundation
import CoreLocation
import MapKit

/// Zentrale Einstellungen für den Taxi-Bereich (Zentrale, Logo, etc.).
enum TaxiConfig {
    /// Kein Logo in der Mitte — Prototyp nur mit Hintergrundfoto (`app_background`).
    static let logoImageName: String? = nil

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

    /// Standard-Kartenmittelpunkt — Berlin (europäischer Dienst).
    static let defaultMapCenter = CLLocationCoordinate2D(latitude: 52.520008, longitude: 13.404954)

    /// Locale für Kartenbeschriftung und Geocoding.
    static let mapLocale = Locale(identifier: "de_DE")

    /// Straßen-Zoom beim Abholpunkt setzen.
    static let defaultMapSpanDelta: CLLocationDegrees = 0.012

    /// Deutschland-Übersicht — Startansicht (keine US-Weltkarte).
    static var germanyOverviewRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: defaultMapCenter,
            span: MKCoordinateSpan(latitudeDelta: 5.5, longitudeDelta: 5.5)
        )
    }

    /// Suchgebiet für Adressen — Europa, Schwerpunkt Deutschland.
    static var europeSearchRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 51.0, longitude: 10.5),
            span: MKCoordinateSpan(latitudeDelta: 18, longitudeDelta: 22)
        )
    }

    /// Europa-Übersicht — Fallback wenn kein GPS in Europa.
    static var europeOverviewRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 50.0, longitude: 12.0),
            span: MKCoordinateSpan(latitudeDelta: 22, longitudeDelta: 28)
        )
    }

    /// Fallback ohne GPS — Deutschland statt Welt/US-Schwerpunkt.
    static var regionOverviewFallback: MKCoordinateRegion {
        germanyOverviewRegion
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

    /// Kamera-Abstand für Hausnummern-Genauigkeit (Apple Maps / MapKit).
    static let pickupMapCameraDistance: CLLocationDistance = 360

    /// Kamera-Abstand für Orte/Städte (z. B. Speyer).
    static let cityMapCameraDistance: CLLocationDistance = 2_400

    /// Noch keine echte Pin-Position — oder Simulator/US-Standort außerhalb Europa.
    static func isLikelyUnsetPickupCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        if isInAmericas(coordinate) || !isInEurope(coordinate) {
            return true
        }
        let unsetSamples: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 50.0, longitude: 12.0),
            CLLocationCoordinate2D(latitude: 51.1657, longitude: 10.4515)
        ]
        return unsetSamples.contains { sample in
            abs(coordinate.latitude - sample.latitude) < 0.2
                && abs(coordinate.longitude - sample.longitude) < 0.2
        }
    }

    /// USA / Kanada / Mittelamerika — Simulator-Default (z. B. Cupertino) ausschließen.
    static func isInAmericas(_ coordinate: CLLocationCoordinate2D) -> Bool {
        coordinate.latitude >= 14 && coordinate.latitude <= 72
            && coordinate.longitude >= -168 && coordinate.longitude <= -52
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

    /// Standard-Mandant (Multi-Tenant). Leer = Backend resolvt nach GPS/PLZ.
    static let defaultOperatorSlug = ""

    // MARK: - Stripe (Testmodus)

    /// Publishable Key aus Stripe Dashboard (pk_test_…).
    static let stripePublishableKey = "pk_test_PLACEHOLDER"

    /// Cloud-Backend auf Render (Go-Live-Plattform für TaxiApp).
    /// Nach Deploy: https://dashboard.render.com → taxiapp-api
    /// Anleitung: docs/RENDER-GO-LIVE.md
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
