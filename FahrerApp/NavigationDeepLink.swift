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
        let url: URL?
        switch app {
        case .appleMaps:
            url = URL(string: "http://maps.apple.com/?daddr=\(lat),\(lng)&q=\(encoded)")
        case .googleMaps:
            url = URL(string: "comgooglemaps://?daddr=\(lat),\(lng)&directionsmode=driving")
                ?? URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(lat),\(lng)")
        case .waze:
            url = URL(string: "waze://?ll=\(lat),\(lng)&navigate=yes")
                ?? URL(string: "https://waze.com/ul?ll=\(lat),\(lng)&navigate=yes")
        }
        guard let url else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    static func openChooser(coordinate: CLLocationCoordinate2D, label: String) {
        // Prefer Apple Maps as reliable default; apps can choose via UI.
        open(app: .appleMaps, coordinate: coordinate, label: label)
    }
}
