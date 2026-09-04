//
//  FahrerLocationTracker.swift
//  Luckys Taxi Fahrer
//
// Sendet GPS während einer angenommenen Fahrt an das Backend (Live-Tracking).
// Xcode: Info → Privacy → Location When In Use Usage Description setzen!
//

import Foundation
import CoreLocation
import Combine

/// GPS-Sender für Live-Tracking. Läuft bewusst ohne class-weiten @MainActor
/// (weniger Concurrency-Fehler in Xcode).
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

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lastError = nil
            self.isSharing = true

            switch self.manager.authorizationStatus {
            case .notDetermined:
                self.manager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                self.manager.startUpdatingLocation()
            case .denied, .restricted:
                self.lastError = "Standort-Zugriff verweigert. In iOS-Einstellungen erlauben."
                self.isSharing = false
            @unknown default:
                self.manager.requestWhenInUseAuthorization()
            }
        }
    }

    func stop() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isSharing = false
            self.bookingId = nil
            self.manager.stopUpdatingLocation()
        }
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
                await MainActor.run { [weak self] in
                    self?.lastError = nil
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.lastError = error.localizedDescription
                }
            }
        }
    }
}

extension FahrerLocationTracker: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isSharing else { return }
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.manager.startUpdatingLocation()
            case .denied, .restricted:
                self.lastError = "Standort-Zugriff verweigert."
                self.isSharing = false
            default:
                break
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async { [weak self] in
            self?.send(location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.lastError = error.localizedDescription
        }
    }
}
