import SwiftUI
import MapKit

extension Notification.Name {
    /// Buchung abgeschlossen — Startseite setzt den Navigationsstack zurück.
    static let taxiBookingCompleted = Notification.Name("taxiBookingCompleted")
}

// MARK: - Tip & Payment Models

private struct TipOption: Identifiable, Hashable {
    let id: String
    let amount: Double

    var label: String {
        amount == 0 ? "Kein Trinkgeld" : String(format: "%.2f €", amount)
    }
}

private let tipOptions: [TipOption] = [
    TipOption(id: "none", amount: 0),
    TipOption(id: "1_50", amount: 1.5),
    TipOption(id: "2_00", amount: 2),
    TipOption(id: "3_00", amount: 3),
    TipOption(id: "5_00", amount: 5),
]

private let voucherToggleGreen = Brand.accent

struct TaxiBookingSummary: Hashable {
    var pickupDate: Date
    var pickupLocation: PickupLocation
    /// Fahrtpreis bei Buchung immer 0 — Endbetrag kommt vom Taxameter (Fahrer).
    var tariffAmount: Double
    /// Optionaler Trinkgeld-Wunsch (wird an Leitstelle übermittelt, nicht in App berechnet).
    var tipAmount: Double
    var voucherAmount: Double
    var useVoucher: Bool
    var paymentMethodLabel: String
    var nightSurchargeApplies: Bool
    /// Sofort-Abholung — Anzeige „so bald wie möglich“ statt Kalenderzeit.
    var isImmediatePickup: Bool = false
    var passengerEmail: String = ""

    /// Bei Buchung kein fester Gesamtpreis — Zahlung nach Fahrt (Taxameter / Fahrer).
    var totalAmount: Double { 0 }

    static let taximeterFareLabel = "Nach Taxameter"

    var fareDisplayText: String {
        tariffAmount > 0 ? String(format: "%.2f €", tariffAmount) : Self.taximeterFareLabel
    }

    var totalDisplayText: String { "0,00 €" }

    func pickupTimeDisplayText(timeZone: TimeZone) -> String {
        if isImmediatePickup {
            return "Sofort — so bald wie möglich"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: pickupDate)) Uhr"
    }

    func pickupDateDisplayText(timeZone: TimeZone) -> String {
        if isImmediatePickup {
            return "Heute"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = timeZone
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: pickupDate)
    }
}

// MARK: - Fahrtübersicht (Adresse + Abholzeit)

struct BookingTripOverviewCard: View {
    let pickupLocation: PickupLocation
    let pickupDate: Date
    let isImmediate: Bool

    private var trimmedDestination: String {
        pickupLocation.destinationAddressLine.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(
                isImmediate ? "Taxi wird zur Abholung geschickt" : "Ihre geplante Fahrt",
                systemImage: "car.fill"
            )
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Brand.primary)

            overviewRow(
                icon: "mappin.circle.fill",
                title: "Abholort",
                value: pickupLocation.addressLine
            )

            if !trimmedDestination.isEmpty {
                overviewRow(
                    icon: "flag.checkered",
                    title: "Ziel",
                    value: trimmedDestination
                )
            }

            overviewRow(
                icon: isImmediate ? "bolt.fill" : "clock.fill",
                title: "Abholzeit",
                value: isImmediate
                    ? "Sofort — so bald wie möglich"
                    : pickupDate.formatted(
                        .dateTime.day().month(.abbreviated).hour().minute()
                            .locale(Locale(identifier: "de_DE"))
                    )
            )
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        .colorScheme(.light)
    }

    private func overviewRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Brand.primary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Brand.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Brand.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Payment View

/// Seite 5: Kasse — Trinkgeld, Gutschein-Hinweis, Zahlungswunsch (letzter Schritt).
struct PaymentView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var centralStore: CentralConfigStore
    @State private var showConfirmedAlert = false
    @State private var isSubmitting = false
    @State private var submitError: String?
    @State private var confirmedMessage = ""

    let pickupDate: Date
    let pickupLocation: PickupLocation
    let isImmediatePickup: Bool

    private let bookingService = BookingService()
    /// Kein Demo-Festpreis — Betrag kommt vom Taxameter am Ende der Fahrt.
    private let tariffAmount: Double = 0
    @State private var selectedTipId: String = "none"
    @State private var useVoucher = false
    @State private var voucherText = ""
    @State private var selectedPaymentMethod: TaxiPaymentMethod = .cash
    @State private var passengerEmail = ""

    private let fixedTips: [TipOption] = tipOptions

    init(
        pickupDate: Date = Date(),
        pickupLocation: PickupLocation = .defaultPlaceholder,
        isImmediatePickup: Bool = false
    ) {
        self.pickupDate = pickupDate
        self.pickupLocation = pickupLocation
        self.isImmediatePickup = isImmediatePickup
    }

    private var selectedTipOption: TipOption {
        tipOptions.first { $0.id == selectedTipId } ?? tipOptions[0]
    }

    private var tipAmount: Double {
        selectedTipOption.amount
    }

    private var voucherAmount: Double {
        guard useVoucher else { return 0 }
        let normalized = voucherText.replacingOccurrences(of: ",", with: ".")
        return Double(normalized) ?? 0
    }

    private var tipSummaryText: String {
        if tipAmount <= 0 {
            return "Kein Trinkgeld-Wunsch — optional bar beim Fahrer"
        }
        return String(
            format: "Trinkgeld-Wunsch: %.2f € — wird an die Leitstelle gemeldet, nicht zum Taxameter addiert",
            tipAmount
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 2) {
                Text("Kasse")
                    .font(BookingScreenStyle.titleFont)
                    .foregroundStyle(.white)
                Text("Trinkgeld & Zahlungswunsch — Fahrtpreis nach Taxameter")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 10)
            .padding(.horizontal, 16)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    if isSubmitting {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(Brand.primary)
                            Text("Buchung wird gesendet…")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Brand.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    BookingTripOverviewCard(
                        pickupLocation: pickupLocation,
                        pickupDate: pickupDate,
                        isImmediate: isImmediatePickup
                    )
                    tariffCard
                    nightSurchargeSection
                    tipCard
                    voucherCard
                    totalBar
                    paymentMethodCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
        }
        .bookingFlowBackground()
        .navigationBarBackButtonHidden(true)
        .safeAreaPadding(.top, 8)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BookingLegalFootnote(confirmActionLabel: "Taxi bestellen")
            BookingBottomBar(
                forwardTitle: submitButtonTitle,
                forwardDisabled: isSubmitting,
                onBack: { dismiss() },
                onForward: submitBooking
            )
        }
        .alert("Taxi bestellt", isPresented: $showConfirmedAlert) {
            Button("OK", role: .cancel) {
                NotificationCenter.default.post(name: .taxiBookingCompleted, object: nil)
            }
        } message: {
            Text(confirmedMessage)
        }
        .alert("Buchung fehlgeschlagen", isPresented: Binding(
            get: { submitError != nil },
            set: { if !$0 { submitError = nil } }
        )) {
            Button("OK", role: .cancel) { submitError = nil }
        } message: {
            Text(submitError ?? "")
        }
    }

    private var submitButtonTitle: String {
        if isSubmitting { return "Bitte warten…" }
        return "Taxi bestellen"
    }

    // MARK: - Cards

    private var tariffCard: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Fahrtpreis")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("0,00 €")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
            }
            Text(TaxiBookingSummary.taximeterFareLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
            Text("Der Betrag steht erst am Ende der Fahrt auf dem Taxameter — der Fahrer kassiert.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Brand.primary)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        .lightShimmer(cornerRadius: 18, tone: .onDark, intensity: 1.1)
    }

    @ViewBuilder
    private var nightSurchargeSection: some View {
        if centralStore.nightSurchargeApplies(for: pickupDate) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "moon.stars.fill")
                    Text("Nachtzuschlag-Zeitraum")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                Text("Abholung zwischen \(NightSurcharge.windowLabel). Ihr Taxi-Betrieb kann am Taxameter einen Nachttarif berechnen.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.88))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Brand.accentDark.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
            .lightShimmer(cornerRadius: 18, tone: .onDark, intensity: 1.0)
        }
    }

    private var tipCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trinkgeld (optional)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Text("Wunsch an Fahrer/Leitstelle — kein Aufschlag auf den Taxameter-Betrag in der App.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.85))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(fixedTips) { tip in
                    tipButton(tip)
                }
            }

            Text(tipSummaryText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(selectedTipId == "none" ? Brand.secondary : Color.white.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .animation(.easeInOut(duration: 0.2), value: selectedTipId)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.primary)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
    }

    private func tipButton(_ tip: TipOption) -> some View {
        let selected = selectedTipId == tip.id

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTipId = tip.id
            }
        } label: {
            Text(tip.label)
                .font(.caption.weight(.bold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(selected ? Brand.primary : .white)
                .background(selected ? Color.white : Brand.secondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(selected ? 0 : 0.35), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tip.label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var voucherCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Gutschein verwenden")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Toggle("", isOn: $useVoucher)
                    .labelsHidden()
                    .tint(voucherToggleGreen)
            }

            if useVoucher {
                HStack(spacing: 8) {
                    TextField("0,00", text: $voucherText)
                        .keyboardType(.decimalPad)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(Brand.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .lightShimmer(cornerRadius: 10, tone: .onDark, intensity: 1.0)

                    Text("€")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                Text("Hinweis für Fahrer/Leitstelle — kein Abzug bei der Buchung.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.primary)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        .lightShimmer(cornerRadius: 18, tone: .onDark, intensity: 1.1)
    }

    private var totalBar: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Fahrtpreis")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text(TaxiBookingSummary.taximeterFareLabel)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
            }

            HStack {
                Text("Trinkgeld-Wunsch")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text(tipAmount > 0 ? String(format: "%.2f €", tipAmount) : "Keins")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tipAmount > 0 ? Color(red: 1, green: 0.92, blue: 0.55) : .white)
            }

            Divider().overlay(Color.white.opacity(0.25))

            HStack {
                Text("Jetzt in der App")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("0,00 €")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }

            Text(
                selectedPaymentMethod == .card
                    ? "Taxameter-Betrag zahlst du nach der Fahrt per Kartenzahlungs-Link."
                    : "Taxameter + Trinkgeld zahlen Sie bar beim Fahrer nach der Fahrt."
            )
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Brand.primary)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        .animation(.easeInOut(duration: 0.2), value: selectedTipId)
    }

    private var paymentMethodCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Zahlungsart")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Brand.primary)

            ForEach(TaxiPaymentMethod.allCases) { method in
                Button {
                    selectedPaymentMethod = method
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: method.icon)
                            .font(.title3)
                            .foregroundStyle(Brand.primary)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(method.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Brand.primary)
                            Text(method.detail)
                                .font(.caption)
                                .foregroundStyle(Brand.primary.opacity(0.85))
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: selectedPaymentMethod == method ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedPaymentMethod == method ? Brand.accent : Brand.primary.opacity(0.35))
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(selectedPaymentMethod == method ? Brand.accent.opacity(0.12) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }

            if selectedPaymentMethod == .card {
                TextField("E-Mail für Quittung (optional)", text: $passengerEmail)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(10)
                    .background(Color.white.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
        .lightShimmer(cornerRadius: 18, tone: .onLight, intensity: 0.9)
    }

    // MARK: - Payment Logic

    private func submitBooking() {
        guard !isSubmitting else { return }
        isSubmitting = true

        let summary = buildSummary()
        Task {
            let result = await bookingService.submitBooking(summary: summary)
            await MainActor.run {
                isSubmitting = false
                switch result {
                case .failure(let message):
                    submitError = message
                case .success:
                    confirmedMessage = selectedPaymentMethod == .card
                        ? "Ihr Taxi ist bestellt. Nach der Fahrt zahlen Sie per Kartenzahlungs-Link (Betrag laut Taxameter)."
                        : "Ihr Taxi ist bestellt. Die Zahlung erfolgt nach der Fahrt — Betrag laut Taxameter, bar beim Fahrer."
                    showConfirmedAlert = true
                }
            }
        }
    }

    private func buildSummary() -> TaxiBookingSummary {
        TaxiBookingSummary(
            pickupDate: pickupDate,
            pickupLocation: pickupLocation,
            tariffAmount: tariffAmount,
            tipAmount: tipAmount,
            voucherAmount: voucherAmount,
            useVoucher: useVoucher,
            paymentMethodLabel: selectedPaymentMethod.rawValue,
            nightSurchargeApplies: centralStore.nightSurchargeApplies(for: pickupDate),
            isImmediatePickup: isImmediatePickup,
            passengerEmail: passengerEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

// MARK: - Confirmation View

/// Seite 4: Fahrt prüfen — Adresse und Karte, danach zur Kasse.
struct TaxiConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var centralStore: CentralConfigStore
    @State private var showCheckout = false
    @State private var cameraPosition: MapCameraPosition
    @State private var displayAddress: String
    @State private var displayPickupTime: String
    @State private var displayPickupDate: String
    @State private var displayCoordinate: CLLocationCoordinate2D

    let summary: TaxiBookingSummary

    init(summary: TaxiBookingSummary) {
        self.summary = summary
        let center = summary.pickupLocation.coordinate
        _cameraPosition = State(initialValue: TaxiConfig.pickupMapCamera(center: center))
        _displayAddress = State(initialValue: summary.pickupLocation.addressLine)
        _displayCoordinate = State(initialValue: center)
        _displayPickupTime = State(initialValue: Self.initialPickupTime(summary: summary))
        _displayPickupDate = State(initialValue: Self.initialPickupDate(summary: summary))
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Fahrt prüfen")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, 8)

            Text(summary.isImmediatePickup
                ? "Sofort-Abholung — danach Trinkgeld an der Kasse wählen."
                : "Adresse und Termin prüfen — danach zur Kasse.")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.88))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.top, 2)
                .padding(.bottom, 4)

            pickupMapPreview
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            ScrollView(showsIndicators: false) {
                tripDetailsCard
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            BookingBottomBar(
                forwardTitle: "Zur Kasse",
                onBack: { dismiss() },
                onForward: { showCheckout = true }
            )
        }
        .bookingFlowBackground()
        .navigationBarBackButtonHidden(true)
        .safeAreaPadding(.top, 8)
        .onAppear {
            refreshPickupSchedule()
        }
        .task {
            await resolvePickupOnMap()
        }
        .navigationDestination(isPresented: $showCheckout) {
            PaymentView(
                pickupDate: summary.isImmediatePickup ? Date() : summary.pickupDate,
                pickupLocation: checkoutPickupLocation,
                isImmediatePickup: summary.isImmediatePickup
            )
        }
    }

    private var checkoutPickupLocation: PickupLocation {
        PickupLocation(
            latitude: displayCoordinate.latitude,
            longitude: displayCoordinate.longitude,
            addressLine: displayAddress,
            destinationAddressLine: summary.pickupLocation.destinationAddressLine
        )
    }

    private var tripDetailsCard: some View {
        VStack(spacing: 6) {
            summaryRow(label: "Abholort", value: displayAddress)
            if !summary.pickupLocation.destinationAddressLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                summaryRow(label: "Ziel", value: summary.pickupLocation.destinationAddressLine)
            }
            summaryRow(label: "Abholzeit", value: displayPickupTime)
            summaryRow(label: "Datum", value: displayPickupDate)

            summaryRow(label: "Fahrtpreis", value: summary.fareDisplayText)

            if summary.nightSurchargeApplies {
                summaryRow(
                    label: "Nachtzuschlag",
                    value: NightSurcharge.windowLabel
                )
            }

            Text("Trinkgeld und Zahlungswunsch wählen Sie an der Kasse.")
                .font(.caption2)
                .foregroundStyle(Brand.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Brand.background)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Brand.primary.opacity(0.14), lineWidth: 1)
        }
        .colorScheme(.light)
    }

    private var pickupMapPreview: some View {
        let coordinate = displayCoordinate

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(displayAddress, systemImage: "mappin.and.ellipse")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(2)
                Spacer(minLength: 0)
                Button("Zentrieren") {
                    centerMapOnPickup(coordinate: coordinate, animated: true)
                }
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Brand.primary.opacity(0.85))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 2)

            Text("Karte verschieben und zoomen — Pin = genauer Abholpunkt")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.72))
                .padding(.leading, 2)

            Map(position: $cameraPosition, interactionModes: [.pan, .zoom]) {
                Annotation("Abholpunkt", coordinate: coordinate) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 36))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Brand.primary, .white)
                        .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .europeanBookingMap()
            .frame(height: 196)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.55), lineWidth: 1.5)
            }
            .shadow(color: .black.opacity(0.22), radius: 10, y: 4)
        }
    }

    private func centerMapOnPickup(coordinate: CLLocationCoordinate2D, animated: Bool) {
        let position = TaxiConfig.pickupMapCamera(center: coordinate)
        if animated {
            withAnimation(.easeInOut(duration: 0.45)) {
                cameraPosition = position
            }
        } else {
            cameraPosition = position
        }
    }

    private func refreshPickupSchedule() {
        let timeZone = centralStore.regionTimeZone
        if summary.isImmediatePickup {
            displayPickupTime = Self.formattedImmediatePickupTime(timeZone: timeZone)
            displayPickupDate = Self.formattedImmediatePickupDate(timeZone: timeZone)
        } else {
            displayPickupTime = summary.pickupTimeDisplayText(timeZone: timeZone)
            displayPickupDate = summary.pickupDateDisplayText(timeZone: timeZone)
        }
    }

    private func resolvePickupOnMap() async {
        var coordinate = summary.pickupLocation.coordinate
        let address = summary.pickupLocation.addressLine

        if TaxiConfig.isInAmericas(coordinate) || !TaxiConfig.isInEurope(coordinate) {
            coordinate = TaxiConfig.defaultMapCenter
        }

        if TaxiConfig.isLikelyUnsetPickupCoordinate(coordinate),
           !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let searched = await GeocodingService.forwardGeocode(addressLine: address) {
            coordinate = searched
        }

        if Self.needsAddressLookup(displayAddress) {
            let parsed = await GeocodingService.reverseGeocodeParsed(coordinate: coordinate)
            if !parsed.isEmpty {
                await MainActor.run {
                    displayAddress = parsed.formattedLine
                }
            }
        } else if !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            await MainActor.run {
                displayAddress = address
            }
        }

        await MainActor.run {
            displayCoordinate = coordinate
            centerMapOnPickup(coordinate: coordinate, animated: false)
        }
    }

    private static func needsAddressLookup(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        let lowered = trimmed.lowercased()
        return lowered.contains("abholpunkt")
            || lowered.contains("pin auf karte")
            || lowered.contains("wird auf der karte")
    }

    private static func initialPickupTime(summary: TaxiBookingSummary) -> String {
        let timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        if summary.isImmediatePickup {
            return formattedImmediatePickupTime(timeZone: timeZone)
        }
        return summary.pickupTimeDisplayText(timeZone: timeZone)
    }

    private static func initialPickupDate(summary: TaxiBookingSummary) -> String {
        let timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        if summary.isImmediatePickup {
            return formattedImmediatePickupDate(timeZone: timeZone)
        }
        return summary.pickupDateDisplayText(timeZone: timeZone)
    }

    private static func formattedImmediatePickupTime(timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return "Sofort — ca. \(formatter.string(from: Date())) Uhr"
    }

    private static func formattedImmediatePickupDate(timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = timeZone
        formatter.dateFormat = "EEEE, dd.MM.yyyy"
        return formatter.string(from: Date())
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(Brand.secondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Brand.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    NavigationStack {
        PaymentView()
            .environmentObject(CentralConfigStore())
    }
}
