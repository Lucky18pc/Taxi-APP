import SwiftUI
import MapKit
import UIKit

private enum AddressField: Hashable {
    case street
    case houseNumber
    case postalCode
    case city
    case destination
}

/// Seite 2: Abholort — Adresse manuell eingeben + Karte mit Standort.
struct TaxiPickupLocationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = LocationManager()
    @State private var calendarDestination: PickupLocation?
    @State private var isResolvingPickup = false
    @State private var didCenterOnUser = false
    @State private var street = ""
    @State private var houseNumber = ""
    @State private var postalCode = ""
    @State private var city = ""
    @State private var destinationAddress = ""
    @State private var addressEditedByUser = false
    @State private var isApplyingGeocodeFromMap = false
    @State private var geocodeTask: Task<Void, Never>?
    @State private var forwardGeocodeTask: Task<Void, Never>?
    @State private var isGeocodingFromMap = false
    @State private var geocodeStatusMessage: String?
    @State private var geocodeStatusIsError = false
    @FocusState private var focusedField: AddressField?

    @State private var mapRegion = TaxiConfig.germanyOverviewRegion
    @State private var cameraPosition: MapCameraPosition = .region(TaxiConfig.germanyOverviewRegion)

    private var trimmedDestination: String {
        destinationAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var composedAddressLine: String {
        AddressComposer.formattedLine(
            street: street,
            houseNumber: houseNumber,
            postalCode: postalCode,
            city: city
        )
    }

    private var hasAnyAddressInput: Bool {
        !composedAddressLine.isEmpty
    }

    private var pickupLocation: PickupLocation {
        PickupLocation(
            latitude: mapRegion.center.latitude,
            longitude: mapRegion.center.longitude,
            addressLine: hasAnyAddressInput ? composedAddressLine : "Abholpunkt (Pin auf Karte)",
            destinationAddressLine: trimmedDestination
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 2) {
                Text("Abholort")
                    .font(BookingScreenStyle.titleFont)
                    .foregroundStyle(.white)
                Text("Bitte holen Sie mich hier ab")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            ScrollViewReader { scrollProxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        addressEntryCard
                            .padding(.horizontal, 16)

                        Text("Oder Karte verschieben — Pin = Abholpunkt")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)

                        mapCard
                            .padding(.horizontal, 16)

                        adoptFromMapButton
                            .padding(.horizontal, 16)

                        if let geocodeStatusMessage {
                            geocodeStatusBanner(geocodeStatusMessage)
                                .padding(.horizontal, 16)
                        }

                        zielField
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, focusedField == nil ? 8 : 280)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: focusedField) { _, field in
                    guard let field else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            scrollProxy.scrollTo(field, anchor: .center)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            BookingBottomBar(
                forwardTitle: isResolvingPickup ? "Standort wird ermittelt…" : "Weiter zur Abholzeit",
                forwardDisabled: isResolvingPickup,
                onBack: { dismiss() },
                onForward: continueToScheduling
            )
        }
        .bookingFlowBackground()
        .navigationBarBackButtonHidden(true)
        .safeAreaPadding(.top, 8)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") { focusedField = nil }
            }
        }
        .onAppear {
            locationManager.requestLocationAccessIfNeeded()
        }
        .onReceive(locationManager.$location) { location in
            guard let location else { return }
            let coordinate = location.coordinate
            guard TaxiConfig.isInEurope(coordinate), !TaxiConfig.isInAmericas(coordinate) else {
                if !didCenterOnUser {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        cameraPosition = .region(TaxiConfig.regionOverviewFallback)
                        mapRegion = TaxiConfig.regionOverviewFallback
                    }
                    didCenterOnUser = true
                }
                return
            }
            if !didCenterOnUser {
                centerMap(on: coordinate)
                didCenterOnUser = true
                if !hasAnyAddressInput {
                    scheduleGeocode(for: coordinate, force: false)
                }
            }
        }
        .navigationDestination(item: $calendarDestination) { location in
            TaxiCustomerCalendarView(pickupLocation: location)
        }
    }

    private var addressEntryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Adresse eingeben")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Brand.primary)

            addressField(
                title: "Straße",
                placeholder: "Musterstraße",
                text: $street,
                field: .street
            )

            addressField(
                title: "Hausnummer",
                placeholder: "12a",
                text: $houseNumber,
                field: .houseNumber
            )

            HStack(spacing: 8) {
                addressField(
                    title: "PLZ",
                    placeholder: "10115",
                    text: $postalCode,
                    field: .postalCode
                )
                .frame(maxWidth: 110)

                addressField(
                    title: "Ort",
                    placeholder: "Berlin",
                    text: $city,
                    field: .city
                )
            }

            if hasAnyAddressInput {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ihre Eingabe")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Brand.secondary)

                    Text(composedAddressLine)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Brand.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, 2)
            }

            Button {
                focusedField = .street
            } label: {
                Label("Tastatur: Adresse eingeben", systemImage: "keyboard")
                    .font(.caption2.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .foregroundStyle(Brand.primary)
                    .background(Brand.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        .colorScheme(.light)
    }

    private func addressField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        field: AddressField
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Brand.primary.opacity(0.85))

            TextField(placeholder, text: text)
                .textInputAutocapitalization(field == .postalCode ? .never : .words)
                .keyboardType(field == .postalCode || field == .houseNumber ? .numbersAndPunctuation : .default)
                .autocorrectionDisabled(field == .postalCode || field == .houseNumber)
                .focused($focusedField, equals: field)
                .submitLabel(nextSubmitLabel(for: field))
                .onSubmit { focusNextField(after: field) }
                .bookingFormTextField()
                .onChange(of: text.wrappedValue) { _, _ in
                    guard !isApplyingGeocodeFromMap else { return }
                    addressEditedByUser = true
                    scheduleMapForTypedAddress()
                }
        }
        .id(field)
    }

    private func nextSubmitLabel(for field: AddressField) -> SubmitLabel {
        switch field {
        case .street: .next
        case .houseNumber: .next
        case .postalCode: .next
        case .city, .destination: .done
        }
    }

    private func focusNextField(after field: AddressField) {
        switch field {
        case .street: focusedField = .houseNumber
        case .houseNumber: focusedField = .postalCode
        case .postalCode: focusedField = .city
        case .city, .destination:
            focusedField = nil
            scheduleMapForTypedAddress(immediate: true)
        }
    }

    private var isCityOnlyAddress: Bool {
        street.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && houseNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func scheduleMapForTypedAddress(immediate: Bool = false) {
        guard hasAnyAddressInput else { return }

        forwardGeocodeTask?.cancel()
        forwardGeocodeTask = Task {
            if !immediate {
                try? await Task.sleep(nanoseconds: 450_000_000)
            }
            guard !Task.isCancelled else { return }

            let addressLine = composedAddressLine
            guard let coordinate = await GeocodingService.forwardGeocode(addressLine: addressLine) else { return }
            guard !Task.isCancelled else { return }

            await MainActor.run {
                centerMap(on: coordinate, streetLevel: !isCityOnlyAddress)
                geocodeStatusIsError = false
                geocodeStatusMessage = "Karte zeigt: \(addressLine)"
            }
        }
    }

    private var adoptFromMapButton: some View {
        Button {
            adoptAddressFromMapPin()
        } label: {
            HStack(spacing: 10) {
                if isGeocodingFromMap {
                    ProgressView()
                        .tint(Brand.primary)
                } else {
                    Image(systemName: "map.fill")
                }

                Text(isGeocodingFromMap ? "Adresse wird ermittelt…" : "Adresse von Karte übernehmen")
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .foregroundStyle(Brand.primary)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(isGeocodingFromMap)
    }

    private func geocodeStatusBanner(_ message: String) -> some View {
        Text(message)
            .font(.caption.weight(.semibold))
            .foregroundStyle(geocodeStatusIsError ? Color(red: 0.55, green: 0.1, blue: 0.1) : Brand.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(geocodeStatusIsError ? Color(red: 1, green: 0.94, blue: 0.94) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .colorScheme(.light)
    }

    private func adoptAddressFromMapPin() {
        focusedField = nil
        geocodeStatusMessage = nil
        geocodeStatusIsError = false
        isGeocodingFromMap = true
        scheduleGeocode(for: mapRegion.center, force: true)
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
            .europeanBookingMap()
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
                VStack(spacing: 10) {
                    Image(systemName: "location.slash")
                        .font(.title2)
                    Text("Standort nicht erlaubt")
                        .font(.subheadline.weight(.semibold))
                    Text("Adresse oben eintippen oder Pin auf der Karte setzen.")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("Einstellungen öffnen")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Brand.primary)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(Brand.primary)
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.94))
                .clipShape(RoundedRectangle(cornerRadius: Brand.cornerRadius, style: .continuous))
                .padding(12)
            }
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: Brand.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Brand.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        .lightShimmer(cornerRadius: Brand.cornerRadius, tone: .onLight, intensity: 0.85)
    }

    private var zielField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ziel (optional)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Brand.primary)

            TextField("Wohin? z. B. Hauptbahnhof, Flughafen", text: $destinationAddress)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .focused($focusedField, equals: .destination)
                .bookingFormTextField()
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        .colorScheme(.light)
        .id(AddressField.destination)
    }

    private func continueToScheduling() {
        focusedField = nil
        guard !isResolvingPickup else { return }
        isResolvingPickup = true

        let addressLine = hasAnyAddressInput ? composedAddressLine : ""
        let mapCenter = mapRegion.center

        Task {
            let coordinate = await GeocodingService.resolvePickupCoordinate(
                mapCenter: mapCenter,
                addressLine: addressLine
            )
            let resolved = PickupLocation(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                addressLine: hasAnyAddressInput ? composedAddressLine : "Abholpunkt (Pin auf Karte)",
                destinationAddressLine: trimmedDestination
            )
            await MainActor.run {
                isResolvingPickup = false
                calendarDestination = resolved
            }
        }
    }

    private func centerMap(on coordinate: CLLocationCoordinate2D, streetLevel: Bool = true) {
        mapRegion = streetLevel
            ? TaxiConfig.streetLevelRegion(center: coordinate)
            : TaxiConfig.streetLevelRegion(center: coordinate)
        withAnimation(.easeInOut(duration: 0.45)) {
            cameraPosition = streetLevel
                ? TaxiConfig.pickupMapCamera(center: coordinate)
                : TaxiConfig.cityMapCamera(center: coordinate)
        }
    }

    private func scheduleGeocode(for coordinate: CLLocationCoordinate2D, force: Bool) {
        if !force {
            guard !addressEditedByUser, !hasAnyAddressInput else { return }
        }

        geocodeTask?.cancel()
        geocodeTask = Task {
            if !force {
                try? await Task.sleep(nanoseconds: 350_000_000)
            }
            guard !Task.isCancelled else { return }
            let parsed = await GeocodingService.reverseGeocodeParsed(coordinate: coordinate)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                applyParsedAddress(parsed, force: force)
            }
        }
    }

    private func applyParsedAddress(_ parsed: ParsedAddress, force: Bool) {
        defer { isGeocodingFromMap = false }

        if parsed.isEmpty {
            if force {
                geocodeStatusIsError = true
                geocodeStatusMessage =
                    "Adresse an diesem Punkt nicht gefunden. Karte näher zoomen oder Adresse oben eintippen."
            }
            return
        }

        isApplyingGeocodeFromMap = true
        street = parsed.street
        houseNumber = parsed.houseNumber
        postalCode = parsed.postalCode
        city = parsed.city
        if force {
            addressEditedByUser = false
            geocodeStatusIsError = false
            geocodeStatusMessage = "Adresse übernommen: \(parsed.formattedLine)"
        }
        isApplyingGeocodeFromMap = false
    }
}

#Preview {
    NavigationStack {
        TaxiPickupLocationView()
    }
}
