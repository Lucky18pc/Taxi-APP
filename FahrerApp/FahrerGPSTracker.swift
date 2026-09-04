//
//  FahrerGPSTracker.swift
//  Luckys Taxi Fahrer
//
// NEU — ersetzt FahrerLocationTracker.swift (alte Datei LÖSCHEN!).
// Xcode → Target → Info → Privacy - Location When In Use Usage Description:
// „Standort wird während der Fahrt an den Fahrgast gesendet.“
//

import Foundation
import CoreLocation
import Combine

final class FahrerGPSTracker: NSObject, ObservableObject {
    @Published var lastError: String?
    @Published var isSharing = false

    private let manager = CLLocationManager()
    private var driverUid = ""
    private var bookingId: String?
    private var operatorSlug = FahrerBackendConfig.defaultOperatorSlug
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
            lastError = nil
            isSharing = true

            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.startUpdatingLocation()
            case .denied, .restricted:
                lastError = "Standort-Zugriff verweigert. In iOS-Einstellungen erlauben."
                isSharing = false
            default:
                manager.requestWhenInUseAuthorization()
            }
        }
    }

    func stop() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            isSharing = false
            bookingId = nil
            manager.stopUpdatingLocation()
        }
    }

    private func send(_ location: CLLocation) {
        guard isSharing, !driverUid.isEmpty else { return }
        if let last = lastSentAt, Date().timeIntervalSince(last) < minInterval {
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
                let message = error.localizedDescription
                await MainActor.run { [weak self] in
                    self?.lastError = message
                }
            }
        }
    }
}

extension FahrerGPSTracker: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { [weak self] in
            guard let self, isSharing else { return }
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

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async { [weak self] in
            self?.send(location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let message = error.localizedDescription
        DispatchQueue.main.async { [weak self] in
            self?.lastError = message
        }
    }
}
