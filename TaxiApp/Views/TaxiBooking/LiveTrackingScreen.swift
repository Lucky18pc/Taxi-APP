import SwiftUI
import MapKit

/// Native Live-Tracking nach Ride Request (Phase 4) — pollt Tracking-API ~2,5 s.
struct LiveTrackingScreen: View {
    let bookingId: String

    @State private var statusText = "Taxi wird gesucht…"
    @State private var driverLine = ""
    @State private var pickupLine = ""
    @State private var cameraPosition: MapCameraPosition = .region(TaxiConfig.germanyOverviewRegion)
    @State private var pickupCoord: CLLocationCoordinate2D?
    @State private var taxiCoord: CLLocationCoordinate2D?
    @State private var pollTask: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Map(position: $cameraPosition) {
                if let pickupCoord {
                    Annotation("Abholung", coordinate: pickupCoord) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(Brand.primary)
                            .font(.title)
                    }
                }
                if let taxiCoord {
                    Annotation("Taxi", coordinate: taxiCoord) {
                        Image(systemName: "car.fill")
                            .foregroundStyle(Brand.accent)
                            .padding(6)
                            .background(Brand.primary, in: Circle())
                    }
                }
            }
            .ignoresSafeArea(edges: .top)

            VStack(alignment: .leading, spacing: 8) {
                Text(statusText)
                    .font(.headline)
                if !pickupLine.isEmpty {
                    Text(pickupLine)
                        .font(.footnote)
                }
                if !driverLine.isEmpty {
                    Text(driverLine)
                        .font(.footnote.weight(.semibold))
                }
                Button("Schließen") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(Brand.primary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Brand.accent)
        }
        .navigationTitle("Taxi live")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { startPolling() }
        .onDisappear { pollTask?.cancel() }
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(nanoseconds: 2_500_000_000)
            }
        }
    }

    @MainActor
    private func refresh() async {
        guard let url = URL(string: "\(TaxiConfig.stripeBackendURL)/api/public/bookings/\(bookingId)/tracking") else {
            return
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            if let pickup = json["pickup"] as? [String: Any] {
                pickupLine = "Abholung: \(pickup["addressLine"] as? String ?? "")"
                if let lat = pickup["latitude"] as? Double, let lng = pickup["longitude"] as? Double {
                    pickupCoord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                }
            }
            if let driver = json["driver"] as? [String: Any] {
                let name = driver["name"] as? String ?? "Fahrer"
                let vehicle = driver["vehicle"] as? String ?? ""
                driverLine = vehicle.isEmpty ? name : "\(name) · \(vehicle)"
                if json["hasDriverLocation"] as? Bool == true,
                   let lat = driver["latitude"] as? Double,
                   let lng = driver["longitude"] as? Double {
                    taxiCoord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                    statusText = "Dein Taxi ist unterwegs."
                } else {
                    statusText = "Fahrer zugewiesen — GPS startet gleich."
                }
            } else {
                statusText = "Buchung bestätigt. Fahrer folgt."
                driverLine = ""
            }
            fitCamera()
        } catch {
            statusText = "Tracking vorübergehend nicht erreichbar."
        }
    }

    private func fitCamera() {
        if let taxiCoord {
            cameraPosition = .region(TaxiConfig.streetLevelRegion(center: taxiCoord))
        } else if let pickupCoord {
            cameraPosition = .region(TaxiConfig.streetLevelRegion(center: pickupCoord))
        }
    }
}
