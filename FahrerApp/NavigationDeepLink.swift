//
//  NavigationDeepLink.swift
//  Luckys Taxi Fahrer
//

import Foundation
import CoreLocation
import UIKit

enum NavigationDeepLink {
    enum App: String, CaseIterable, Identifiable {
        case appleMaps
        case googleMaps
        case waze

        var id: String { rawValue }

        var title: String {
            switch self {
            case .appleMaps: return "Apple Maps"
            case .googleMaps: return "Google Maps"
            case .waze: return "Waze"
            }
        }
    }

    static func open(app: App, coordinate: CLLocationCoordinate2D, label: String) {
        let lat = coordinate.latitude
        let lng = coordinate.longitude
        let encoded = label.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Ziel"

        let nativeURL: URL?
        let webFallback: URL?
        switch app {
        case .appleMaps:
            // http maps.apple.com öffnet die App oder die Website — kein Extra-Fallback nötig.
            nativeURL = URL(string: "http://maps.apple.com/?daddr=\(lat),\(lng)&q=\(encoded)")
            webFallback = nil
        case .googleMaps:
            nativeURL = URL(string: "comgooglemaps://?daddr=\(lat),\(lng)&directionsmode=driving")
            webFallback = URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(lat),\(lng)")
        case .waze:
            nativeURL = URL(string: "waze://?ll=\(lat),\(lng)&navigate=yes")
            webFallback = URL(string: "https://waze.com/ul?ll=\(lat),\(lng)&navigate=yes")
        }

        guard let nativeURL else { return }

        // Native zuerst; scheitert open (App fehlt), HTTPS-Fallback.
        // Nicht `URL(string:) ?? fallback` — Custom-Schemata parsen immer erfolgreich.
        UIApplication.shared.open(nativeURL, options: [:]) { success in
            if !success, let webFallback {
                UIApplication.shared.open(webFallback, options: [:], completionHandler: nil)
            }
        }
    }

    static func openChooser(coordinate: CLLocationCoordinate2D, label: String) {
        // Prefer Apple Maps as reliable default; apps can choose via UI.
        open(app: .appleMaps, coordinate: coordinate, label: label)
    }
}
