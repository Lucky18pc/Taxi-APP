//
//  FahrerLocationTracker.swift
//  Luckys Taxi Fahrer
//
// GPS während angenommener Fahrt → Backend Live-Tracking.
// Xcode Info: Privacy - Location When In Use Usage Description setzen!
//

import Foundation
import CoreLocation
import Combine

final class FahrerLocationTracker: NSObject, ObservableObject {
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
            guard let self = self else { return }
            self.lastError = nil
            self.isSharing = true

            let status = self.manager.authorizationStatus
            if status == .notDetermined {
                self.manager.requestWhenInUseAuthorization()
            } else if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.manager.startUpdatingLocation()
            } else if status == .denied || status == .restricted {
                self.lastError = "Standort-Zugriff verweigert. In iOS-Einstellungen erlauben."
                self.isSharing = false
            } else {
                self.manager.requestWhenInUseAuthorization()
            }
        }
    }

    func stop() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isSharing = false
            self.bookingId = nil
            self.manager.stopUpdatingLocation()
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

extension FahrerLocationTracker: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard self.isSharing else { return }
            let status = manager.authorizationStatus
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.manager.startUpdatingLocation()
            } else if status == .denied || status == .restricted {
                self.lastError = "Standort-Zugriff verweigert."
                self.isSharing = false
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
