import SwiftUI
import PassKit
import MapKit

// MARK: - Apple Pay Button (UIKit-Wrapper)
struct ApplePayButton: UIViewRepresentable {
    let action: () -> Void

    func makeUIView(context: Context) -> PKPaymentButton {
        let button = PKPaymentButton(paymentButtonType: .plain, paymentButtonStyle: .black)
        button.addTarget(context.coordinator, action: #selector(Coordinator.tapped), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: PKPaymentButton, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tapped() { action() }
    }
}

// MARK: - Apple Pay Authorization Delegate
final class ApplePayHandler: NSObject, ObservableObject, PKPaymentAuthorizationControllerDelegate {
    private var controller: PKPaymentAuthorizationController?
    private var onComplete: ((Bool, String?) -> Void)?
    private var didAuthorizeSuccess = false

    func startPayment(
        merchantId: String = "merchant.com.pececarmine.collectionshop",
        countryCode: String = "DE",
        currencyCode: String = "EUR",
        summaryItems: [PKPaymentSummaryItem],
        completion: @escaping (Bool, String?) -> Void
    ) {
        guard PKPaymentAuthorizationController.canMakePayments() else {
            completion(false, "Apple Pay ist auf diesem Gerät nicht verfügbar.")
            return
        }

        didAuthorizeSuccess = false
        let request = PKPaymentRequest()
        request.merchantIdentifier = merchantId
        request.countryCode = countryCode
        request.currencyCode = currencyCode
        request.supportedNetworks = [.visa, .masterCard, .amex, .girocard]
        request.merchantCapabilities = [.threeDSecure, .debit, .credit]
        request.paymentSummaryItems = summaryItems

        let authController = PKPaymentAuthorizationController(paymentRequest: request)
        authController.delegate = self
        onComplete = completion
        controller = authController
        authController.present { [weak self] presented in
            if !presented {
                self?.onComplete?(false, "Apple Pay konnte nicht angezeigt werden.")
                self?.onComplete = nil
                self?.controller = nil
            }
        }
    }

    func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didAuthorizePayment payment: PKPayment,
        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void
    ) {
        didAuthorizeSuccess = true
        completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
    }

    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss { [weak self] in
            guard let self = self else { return }
            let success = self.didAuthorizeSuccess
            self.onComplete?(success, success ? nil : "Zahlung abgebrochen.")
            self.onComplete = nil
            self.controller = nil
        }
    }
}

// MARK: - Tip & Payment Models

private enum TipSelection: Hashable {
    case percent(Int)
    case fixed(Double)

    var label: String {
        switch self {
        case .percent(let pct): return "\(pct)%"
        case .fixed(let amount): return String(format: "%.2f €", amount)
        }
    }
}

private enum CheckoutPaymentMethod: String, CaseIterable, Identifiable {
    case card = "Karte"
    case cash = "Bar"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .card: return "creditcard.fill"
        case .cash: return "banknote.fill"
        }
    }

    /// Marken-Akzent pro Zahlungsart.
    var accentColor: Color {
        switch self {
        case .card: return Brand.accent
        case .cash: return Brand.primary
        }
    }
}

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

    /// Bei Buchung kein fester Gesamtpreis — Zahlung nach Fahrt (Taxameter / Fahrer).
    var totalAmount: Double { 0 }

    static let taximeterFareLabel = "Nach Taxameter"

    var fareDisplayText: String {
        tariffAmount > 0 ? String(format: "%.2f €", tariffAmount) : Self.taximeterFareLabel
    }

    var totalDisplayText: String { "0,00 €" }
}

// MARK: - Payment View

/// Seite 4: Zahlung — Tarif, Trinkgeld, Gutschein, ZahlungsArt.
struct PaymentView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var centralStore: CentralConfigStore
    @State private var showConfirmation = false
    @State private var showCardPayment = false

    let pickupDate: Date
    let pickupLocation: PickupLocation
    /// Kein Demo-Festpreis — Betrag kommt vom Taxameter am Ende der Fahrt.
    private let tariffAmount: Double = 0
    @State private var selectedTip: TipSelection = .fixed(0)
    @State private var useVoucher = false
    @State private var voucherText = ""
    @State private var selectedMethod: CheckoutPaymentMethod = .cash

    private let fixedTips: [TipSelection] = [.fixed(0), .fixed(1.50), .fixed(2.00), .fixed(3.00), .fixed(5.00)]

    init(pickupDate: Date = Date(), pickupLocation: PickupLocation = .defaultPlaceholder) {
        self.pickupDate = pickupDate
        self.pickupLocation = pickupLocation
    }

    private var tipAmount: Double {
        switch selectedTip {
        case .percent:
            return 0
        case .fixed(let amount):
            return amount
        }
    }

    private var voucherAmount: Double {
        guard useVoucher else { return 0 }
        let normalized = voucherText.replacingOccurrences(of: ",", with: ".")
        return Double(normalized) ?? 0
    }

    private var tipSummaryText: String {
        if tipAmount <= 0 {
            return "Kein Trinkgeld-Wunsch — optional beim Fahrer"
        }
        return String(format: "Trinkgeld-Wunsch: %.2f € (beim Fahrer)", tipAmount)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Zahlung")
                .font(BookingScreenStyle.titleFont)
                .foregroundStyle(.white)
                .padding(.top, 10)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
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
            BookingBottomBar(forwardTitle: "Jetzt buchen", onBack: { dismiss() }, onForward: payTapped)
        }
        .navigationDestination(isPresented: $showConfirmation) {
            TaxiConfirmationView(summary: buildSummary())
        }
        .navigationDestination(isPresented: $showCardPayment) {
            CardTapPaymentView(summary: buildSummary()) {
                showCardPayment = false
                showConfirmation = true
            }
        }
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

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(fixedTips, id: \.self) { tip in
                    tipButton(tip)
                }
            }

            Text(tipSummaryText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Brand.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .lightShimmer(cornerRadius: 8, tone: .onDark, intensity: 0.9)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.primary)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        .lightShimmer(cornerRadius: 18, tone: .onDark, intensity: 1.1)
    }

    private func tipButton(_ tip: TipSelection) -> some View {
        let selected = selectedTip == tip
        let title: String = {
            switch tip {
            case .percent: return "—"
            case .fixed(let amount):
                return amount == 0 ? "Keins" : String(format: "%.2f €", amount)
            }
        }()

        return Button {
            selectedTip = tip
        } label: {
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text("Trinkgeld")
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundStyle(.white)
            .background(Brand.secondary)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(selected ? 1.0 : 0.45), lineWidth: selected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .lightShimmer(active: true, cornerRadius: 10, tone: .onDark, intensity: selected ? 1.25 : 0.95)
        }
        .buttonStyle(.plain)
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
        VStack(spacing: 4) {
            HStack {
                Text("Jetzt in der App")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("0,00 €")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }
            Text("Zahlung nach der Fahrt — Betrag laut Taxameter beim Fahrer")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Brand.primary)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        .lightShimmer(cornerRadius: 16, tone: .onDark, intensity: 1.2)
    }

    private var paymentMethodCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Zahlungsart")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Brand.primary)

            HStack(spacing: 10) {
                ForEach(CheckoutPaymentMethod.allCases) { method in
                    paymentMethodButton(method)
                }
            }

            if selectedMethod == .cash {
                Text("Bar am Ende der Fahrt beim Fahrer — jetzt nur die Fahrt buchen.")
                    .font(.caption)
                    .foregroundStyle(Brand.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            } else {
                Text("Kartenzahlung in der App folgt nach der Fahrt (Taxameter-Betrag). Bis dahin bitte Bar wählen.")
                    .font(.caption)
                    .foregroundStyle(Brand.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
        .lightShimmer(cornerRadius: 18, tone: .onLight, intensity: 0.9)
    }

    private func paymentMethodButton(_ method: CheckoutPaymentMethod) -> some View {
        let selected = selectedMethod == method
        let accent = method.accentColor

        return Button {
            selectedMethod = method
        } label: {
            VStack(spacing: 6) {
                Image(systemName: method.icon)
                    .font(.title3)
                Text(method.rawValue)
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(selected ? Color.white : accent)
            .background(selected ? accent : accent.opacity(0.10))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? accent : accent.opacity(0.35), lineWidth: selected ? 0 : 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .lightShimmer(
                active: true,
                cornerRadius: 12,
                tone: selected ? .onDark : .onLight,
                intensity: selected ? 1.3 : 0.75
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Payment Logic

    private func payTapped() {
        switch selectedMethod {
        case .card:
            // Kein Vorab-Betrag — Kartenzahlung erst nach Taxameter (später).
            showConfirmation = true
        case .cash:
            showConfirmation = true
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
            paymentMethodLabel: selectedMethod.rawValue,
            nightSurchargeApplies: centralStore.nightSurchargeApplies(for: pickupDate)
        )
    }
}

// MARK: - Card Tap Payment View

private enum BankCardPaymentMode: String, CaseIterable, Identifiable {
    case cardEntry = "Bankkarte"
    case contactless = "Kontaktlos"

    var id: String { rawValue }
}

/// Bankkarten-Zahlung — Stripe Payment Sheet oder Kontaktlos.
struct CardTapPaymentView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var centralStore: CentralConfigStore
    @StateObject private var applePayHandler = ApplePayHandler()
    @State private var paymentMode: BankCardPaymentMode = .cardEntry
    @State private var isProcessing = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var errorMessage: String?

    private let stripeService = StripePaymentService()

    let summary: TaxiBookingSummary
    let onSuccess: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("Bankkarte")
                .font(BookingScreenStyle.titleFont)
                .foregroundStyle(.white)
                .padding(.top, 10)

            Picker("Zahlungsart", selection: $paymentMode) {
                ForEach(BankCardPaymentMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.top, 12)

            ScrollView(showsIndicators: false) {
                Group {
                    if paymentMode == .cardEntry {
                        stripeBankCardView
                    } else {
                        contactlessCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
        }
        .safeAreaPadding(.top, 8)
        .bookingFlowBackground()
        .navigationBarBackButtonHidden(true)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BookingBottomBar(
                backTitle: "Zurück",
                forwardTitle: paymentMode == .cardEntry ? "Mit Bankkarte bezahlen" : "Jetzt bezahlen",
                forwardDisabled: isProcessing,
                onBack: { dismiss() },
                onForward: submitPayment
            )
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseScale = 1.18
            }
        }
    }

    private var stripeBankCardView: some View {
        VStack(spacing: 20) {
            Text(String(format: "%.2f €", summary.totalAmount))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(Brand.primary)

            Image(systemName: "creditcard.fill")
                .font(.system(size: 48))
                .foregroundStyle(Brand.primary)

            VStack(spacing: 8) {
                Text("Sichere Zahlung mit Stripe")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Brand.primary)
                Text("EC- oder Kreditkarte — verschlüsselt über Stripe Payment Sheet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Testkarte (Stripe Testmodus):")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Brand.primary)
                Text("4242 4242 4242 4242 · MM/JJ beliebig · CVC 123")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if isProcessing {
                ProgressView("Verbindung zur Bank…")
                    .font(.subheadline)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 16, y: 8)
        .lightShimmer(cornerRadius: 22, tone: .onLight, intensity: 0.9)
    }

    private var contactlessCard: some View {
        VStack(spacing: 24) {
            Text(String(format: "%.2f €", summary.totalAmount))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(Brand.primary)

            ZStack {
                Circle()
                    .stroke(Brand.primary.opacity(0.25), lineWidth: 3)
                    .frame(width: 120, height: 120)
                    .scaleEffect(pulseScale)

                Circle()
                    .stroke(Brand.primary.opacity(0.15), lineWidth: 2)
                    .frame(width: 150, height: 150)
                    .scaleEffect(pulseScale * 0.95)

                VStack(spacing: 8) {
                    Image(systemName: "wave.3.right")
                        .font(.system(size: 36))
                        .foregroundStyle(Brand.primary)
                    Image(systemName: "creditcard.fill")
                        .font(.title2)
                        .foregroundStyle(Brand.primary)
                }
            }
            .frame(height: 160)

            Text("Bankkarte ans Gerät halten")
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(Brand.primary)

            if isProcessing {
                ProgressView("Zahlung wird verarbeitet…")
                    .font(.subheadline)
            }

            if PKPaymentAuthorizationController.canMakePayments() {
                VStack(spacing: 6) {
                    Text("Oder mit hinterlegter Karte:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ApplePayButton(action: processApplePay)
                        .frame(height: 44)
                }
                .disabled(isProcessing)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 16, y: 8)
        .lightShimmer(cornerRadius: 22, tone: .onLight, intensity: 0.9)
    }

    private func submitPayment() {
        errorMessage = nil
        if paymentMode == .cardEntry {
            startStripePayment()
        } else {
            processContactlessSimulation()
        }
    }

    private func startStripePayment() {
        guard !isProcessing else { return }
        isProcessing = true

        let amountInCents = Int((summary.totalAmount * 100).rounded())

        Task { @MainActor in
            do {
                let clientSecret = try await stripeService.fetchClientSecret(
                    amountInCents: amountInCents,
                    currency: centralStore.stripeCurrencyCode
                )
                isProcessing = false
                stripeService.presentPaymentSheet(clientSecret: clientSecret) { success in
                    if success {
                        onSuccess()
                    }
                }
            } catch {
                isProcessing = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func processContactlessSimulation() {
        guard !isProcessing else { return }
        isProcessing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isProcessing = false
            onSuccess()
        }
    }

    private func processApplePay() {
        guard !isProcessing else { return }
        let total = NSDecimalNumber(value: summary.totalAmount)
        let items: [PKPaymentSummaryItem] = [
            PKPaymentSummaryItem(label: "Tarif", amount: NSDecimalNumber(value: summary.tariffAmount)),
            PKPaymentSummaryItem(label: "Trinkgeld", amount: NSDecimalNumber(value: summary.tipAmount)),
            PKPaymentSummaryItem(label: "TaxiApp", amount: total)
        ]

        applePayHandler.startPayment(
            countryCode: centralStore.regionCountryCode,
            currencyCode: centralStore.paymentCurrencyCode,
            summaryItems: items
        ) { success, _ in
            DispatchQueue.main.async {
                if success {
                    onSuccess()
                }
            }
        }
    }
}

// MARK: - Confirmation View

/// Seite 5: Buchungsbestätigung — Zusammenfassung vor finaler Bestätigung.
struct TaxiConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var centralStore: CentralConfigStore
    @State private var showConfirmedAlert = false
    @State private var isSubmitting = false
    @State private var submitError: String?
    @State private var confirmedMessage = ""

    let summary: TaxiBookingSummary

    private let bookingService = BookingService()

    var body: some View {
        VStack(spacing: 0) {
            Text("Taxi bestellen")
                .font(BookingScreenStyle.titleFont)
                .foregroundStyle(.white)
                .padding(.top, 10)

            if summary.paymentMethodLabel == "Bar" {
                Text("Barzahlung am Ende der Fahrt beim Fahrer")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                Text("Preis nach Taxameter — unten Taxi bestellen, kein Zahlvorgang in der App.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 2)
            }

            ScrollView(showsIndicators: false) {
                summaryCard
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if isSubmitting {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.white)
                    Text("Buchung wird gesendet…")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Brand.primary.opacity(0.92))
            }

            BookingBottomBar(
                forwardTitle: confirmButtonTitle,
                forwardDisabled: isSubmitting,
                onBack: { dismiss() },
                onForward: confirmBooking
            )
        }
        .bookingFlowBackground()
        .navigationBarBackButtonHidden(true)
        .safeAreaPadding(.top, 8)
        .alert("Taxi bestellt", isPresented: $showConfirmedAlert) {
            Button("OK", role: .cancel) { }
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

    private var confirmButtonTitle: String {
        if isSubmitting { return "Bitte warten…" }
        return "Taxi bestellen"
    }

    private var summaryCard: some View {
        VStack(spacing: 10) {
            pickupMapPreview

            summaryRow(label: "Abholort", value: summary.pickupLocation.addressLine)
            if !summary.pickupLocation.destinationAddressLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                summaryRow(label: "Ziel", value: summary.pickupLocation.destinationAddressLine)
            }
            summaryRow(label: "Abholzeit", value: pickupTimeText)
            summaryRow(label: "Datum", value: pickupDateText)
            summaryRow(label: "Fahrtpreis", value: summary.fareDisplayText)

            if summary.nightSurchargeApplies {
                summaryRow(
                    label: "Nachtzuschlag",
                    value: "Möglich (\(NightSurcharge.windowLabel))"
                )
            }

            if summary.tipAmount > 0 {
                summaryRow(
                    label: "Trinkgeld-Wunsch",
                    value: String(format: "%.2f €", summary.tipAmount)
                )
            }

            if summary.useVoucher, summary.voucherAmount > 0 {
                summaryRow(
                    label: "Gutschein-Hinweis",
                    value: String(format: "%.2f €", summary.voucherAmount)
                )
            }

            summaryRow(label: "Zahlungsart", value: summary.paymentMethodLabel)

            Divider()
                .padding(.vertical, 4)

            HStack {
                Text("Jetzt fällig")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Brand.primary)
                Spacer()
                Text(summary.totalDisplayText)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Brand.primary)
            }

            Text("Endbetrag nach Taxameter — Zahlung beim Fahrer bzw. nach der Fahrt in der App.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 12, y: 6)
        .lightShimmer(cornerRadius: 18, tone: .onLight, intensity: 0.9)
    }

    private var pickupMapPreview: some View {
        let pin = PickupMapPin(location: summary.pickupLocation)
        return Map(
            coordinateRegion: .constant(
                MKCoordinateRegion(
                    center: summary.pickupLocation.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
                )
            ),
            interactionModes: [],
            annotationItems: [pin]
        ) { item in
            MapMarker(coordinate: item.location.coordinate, tint: Brand.primary)
        }
        .frame(height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(white: 0.38))
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(white: 0.22))
                .multilineTextAlignment(.trailing)
        }
    }

    private var pickupTimeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = centralStore.regionTimeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: summary.pickupDate)
    }

    private var pickupDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = centralStore.regionTimeZone
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: summary.pickupDate)
    }

    private func confirmBooking() {
        guard !isSubmitting else { return }
        isSubmitting = true

        Task {
            let result = await bookingService.submitBooking(summary: summary)
            await MainActor.run {
                isSubmitting = false
                if result.savedLocallyOnly {
                    confirmedMessage =
                        "Ihr Taxi wurde lokal gespeichert. Die Zentrale ist gerade offline — bitte später erneut buchen oder Backend prüfen."
                } else if summary.paymentMethodLabel == "Bar" {
                    confirmedMessage =
                        "Ihr Taxi ist bestellt. Der Fahrtpreis steht nach der Fahrt auf dem Taxameter — bar beim Fahrer bezahlen."
                } else {
                    confirmedMessage =
                        "Ihr Taxi ist bestellt. Kartenzahlung in der App folgt nach der Fahrt, sobald der Taxameter-Betrag feststeht."
                }
                showConfirmedAlert = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        PaymentView()
            .environmentObject(CentralConfigStore())
    }
}
