//
//  FahrerLocationTracker.swift
//  Luckys Taxi Fahrer
//
// Sendet GPS während einer angenommenen Fahrt an das Backend (Live-Tracking).
// Xcode: Info → Privacy → Location When In Use Usage Description setzen!
//

import Foundation
import CoreLocation

@MainActor
final class FahrerLocationTracker: NSObject, ObservableObject {
    @Published private(set) var lastError: String?
    @Published private(set) var isSharing = false

    private let manager = CLLocationManager()
    private var driverUid = ""
    private var bookingId: String?
    private var operatorSlug = BackendConfig.defaultOperatorSlug
    private var lastSentAt: Date?
    private let minInterval: TimeInterval = 4

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 15
        manager.pausesLocationUpdatesAutomatically = true
    }

    func start(driverUid: String, bookingId: String, operatorSlug: String) {
        self.driverUid = driverUid
        self.bookingId = bookingId
        self.operatorSlug = operatorSlug
        lastError = nil
        isSharing = true

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            lastError = "Standort-Zugriff verweigert. In iOS-Einstellungen erlauben."
            isSharing = false
        @unknown default:
            manager.requestWhenInUseAuthorization()
        }
    }

    func stop() {
        isSharing = false
        bookingId = nil
        manager.stopUpdatingLocation()
    }

    private func send(_ location: CLLocation) {
        guard isSharing, !driverUid.isEmpty else { return }
        if let lastSentAt, Date().timeIntervalSince(lastSentAt) < minInterval {
            return
        }
        lastSentAt = Date()
        let uid = driverUid
        let booking = bookingId
        let slug = operatorSlug
        let lat = location.coordinate.latitude
        let lng = location.coordinate.longitude

        Task {
            do {
                try await DriverAPI.postLocation(
                    driverUid: uid,
                    latitude: lat,
                    longitude: lng,
                    bookingId: booking,
                    operatorSlug: slug
                )
                await MainActor.run { lastError = nil }
            } catch {
                await MainActor.run {
                    lastError = error.localizedDescription
                }
            }
        }
    }
}

extension FahrerLocationTracker: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard isSharing else { return }
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.manager.startUpdatingLocation()
            case .denied, .restricted:
                lastError = "Standort-Zugriff verweigert."
                isSharing = false
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            send(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            lastError = error.localizedDescription
        }
    }
}
