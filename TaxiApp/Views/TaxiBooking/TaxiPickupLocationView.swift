import SwiftUI
import MapKit

/// Seite 3: Abholort — Karte mit Standort + Adresse manuell eingeben.
struct TaxiPickupLocationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = LocationManager()
    @State private var paymentDestination: PickupLocation?
    @State private var didCenterOnUser = false
    @State private var pickupAddress = ""
    @State private var destinationAddress = ""
    @State private var addressEditedByUser = false
    @State private var isApplyingGeocodeFromMap = false
    @State private var geocodeTask: Task<Void, Never>?
    @FocusState private var addressFieldFocused: Bool
    let pickupDate: Date

    @State private var mapRegion = TaxiConfig.europeOverviewRegion
    @State private var cameraPosition: MapCameraPosition = .region(TaxiConfig.europeOverviewRegion)

    private var trimmedAddress: String {
        pickupAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedDestination: String {
        destinationAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var pickupLocation: PickupLocation {
        PickupLocation(
            latitude: mapRegion.center.latitude,
            longitude: mapRegion.center.longitude,
            addressLine: trimmedAddress.isEmpty
                ? "Abholpunkt (Pin auf Karte)"
                : trimmedAddress,
            destinationAddressLine: trimmedDestination
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    Text("Bitte holen Sie mich hier ab")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Brand.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.top, 2)

                    mapCard
                        .padding(.horizontal, 16)

                    Text("Deutschland · Blauer Punkt = Ihr Standort · Karte wischen für Abholpunkt")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)

                    abholpunktField
                        .padding(.horizontal, 16)

                    zielField
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Brand.background)

            BookingBottomBar(
                forwardTitle: "Weiter",
                onBack: { dismiss() },
                onForward: continueToPayment
            )
        }
        .navigationBarBackButtonHidden(true)
        .safeAreaPadding(.top, 8)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") { addressFieldFocused = false }
            }
        }
        .onAppear {
            locationManager.requestLocationAccessIfNeeded()
        }
        .onReceive(locationManager.$location) { location in
            guard let location else { return }
            let coordinate = location.coordinate
            guard TaxiConfig.isInGermany(coordinate) else {
                if !didCenterOnUser {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        cameraPosition = .region(TaxiConfig.germanyOverviewRegion)
                        mapRegion = TaxiConfig.germanyOverviewRegion
                    }
                    didCenterOnUser = true
                }
                return
            }
            if !didCenterOnUser {
                centerMap(on: coordinate)
                didCenterOnUser = true
                if trimmedAddress.isEmpty {
                    scheduleGeocode(for: coordinate, force: false)
                }
            }
        }
        .navigationDestination(item: $paymentDestination) { location in
            PaymentView(pickupDate: pickupDate, pickupLocation: location)
        }
    }

    private var mapCard: some View {
        ZStack {
            Map(position: $cameraPosition, interactionModes: [.pan, .zoom]) {
                UserAnnotation()
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .onMapCameraChange(frequency: .continuous) { context in
                mapRegion = context.region
            }

            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(Brand.primary)
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                .allowsHitTesting(false)

            if locationManager.authorizationStatus == .denied
                || locationManager.authorizationStatus == .restricted {
                VStack(spacing: 4) {
                    Image(systemName: "location.slash")
                        .font(.title3)
                    Text("Standort in Einstellungen erlauben")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(10)
                .background(Color.black.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)
            }
        }
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.systemGray4), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        .lightShimmer(cornerRadius: 16, tone: .onLight, intensity: 0.85)
    }

    private var abholpunktField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Abholpunkt")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Brand.secondary)

            TextField("Straße, Hausnummer, Ort", text: $pickupAddress)
                .font(.subheadline)
                .textInputAutocapitalization(.words)
                .focused($addressFieldFocused)
                .submitLabel(.done)
                .onSubmit { addressFieldFocused = false }
                .onChange(of: pickupAddress) { _, _ in
                    guard !isApplyingGeocodeFromMap else { return }
                    addressEditedByUser = true
                }

            Button {
                addressFieldFocused = false
                if let userLocation = locationManager.location?.coordinate {
                    centerMap(on: userLocation)
                }
                scheduleGeocode(for: mapRegion.center, force: true)
            } label: {
                Label("Adresse von Karte übernehmen", systemImage: "map.fill")
                    .font(.caption2.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .foregroundStyle(Brand.primary)
                    .background(Brand.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        .lightShimmer(cornerRadius: 12, tone: .onLight, intensity: 0.9)
    }

    private var zielField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ziel (optional)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Brand.secondary)

            TextField("Wohin? z. B. Hauptbahnhof, Flughafen", text: $destinationAddress)
                .font(.subheadline)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
        }
        .padding(10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        .lightShimmer(cornerRadius: 12, tone: .onLight, intensity: 0.9)
    }

    private func continueToPayment() {
        addressFieldFocused = false
        paymentDestination = pickupLocation
    }

    private func centerMap(on coordinate: CLLocationCoordinate2D, streetLevel: Bool = true) {
        let region = streetLevel
            ? TaxiConfig.streetLevelRegion(center: coordinate)
            : TaxiConfig.germanyOverviewRegion
        mapRegion = region
        withAnimation(.easeInOut(duration: 0.45)) {
            cameraPosition = .region(region)
        }
    }

    private func scheduleGeocode(for coordinate: CLLocationCoordinate2D, force: Bool) {
        if !force {
            guard !addressEditedByUser, trimmedAddress.isEmpty else { return }
        }

        geocodeTask?.cancel()
        geocodeTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            let address = await GeocodingService.reverseGeocode(coordinate: coordinate)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                isApplyingGeocodeFromMap = true
                pickupAddress = address
                if force {
                    addressEditedByUser = false
                }
                isApplyingGeocodeFromMap = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        TaxiPickupLocationView(pickupDate: Date())
    }
}
