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

    /// Farbakzent pro Zahlungsart — dezent, erkennbar.
    var accentColor: Color {
        switch self {
        case .card:
            return Color(red: 0.87, green: 0.11, blue: 0.18)
        case .cash:
            return Color(red: 0.76, green: 0.58, blue: 0.22)
        }
    }
}

private let voucherToggleGreen = Color(red: 0.22, green: 0.72, blue: 0.45)

struct TaxiBookingSummary: Hashable {
    var pickupDate: Date
    var pickupLocation: PickupLocation
    var tariffAmount: Double
    var tipAmount: Double
    var voucherAmount: Double
    var useVoucher: Bool
    var paymentMethodLabel: String

    var totalAmount: Double {
        max(0, tariffAmount + tipAmount - (useVoucher ? voucherAmount : 0))
    }
}

// MARK: - Payment View

/// Seite 4: Zahlung — Tarif, Trinkgeld, Gutschein, ZahlungsArt.
struct PaymentView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showConfirmation = false
    @State private var showCardPayment = false

    let pickupDate: Date
    let pickupLocation: PickupLocation
    let tariffAmount: Double = 18.00
    @State private var selectedTip: TipSelection = .fixed(1.50)
    @State private var useVoucher = true
    @State private var voucherText = "5,00"
    @State private var selectedMethod: CheckoutPaymentMethod = .cash

    private let percentTips: [TipSelection] = [.percent(5), .percent(10), .percent(15)]
    private let fixedTips: [TipSelection] = [.fixed(1.50), .fixed(2.00), .fixed(3.00)]

    init(pickupDate: Date = Date(), pickupLocation: PickupLocation = .defaultPlaceholder) {
        self.pickupDate = pickupDate
        self.pickupLocation = pickupLocation
    }

    private var tipAmount: Double {
        switch selectedTip {
        case .percent(let pct):
            return (tariffAmount * Double(pct)) / 100
        case .fixed(let amount):
            return amount
        }
    }

    private var voucherAmount: Double {
        let normalized = voucherText.replacingOccurrences(of: ",", with: ".")
        return Double(normalized) ?? 0
    }

    private var totalAmount: Double {
        max(0, tariffAmount + tipAmount - (useVoucher ? voucherAmount : 0))
    }

    private var tipSummaryText: String {
        switch selectedTip {
        case .percent:
            return String(format: "mit %.2f € Trinkgeld", tipAmount)
        case .fixed(let amount):
            return String(format: "mit %.2f € Trinkgeld", amount)
        }
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
            BookingBottomBar(forwardTitle: "Weiter zum Bezahlen", onBack: { dismiss() }, onForward: payTapped)
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
                Text("Tarif")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(String(format: "%.2f €", tariffAmount))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
            }
            Text("Taxi betrieb")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Brand.primary)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        .lightShimmer(cornerRadius: 18, tone: .onDark, intensity: 1.1)
    }

    private var tipCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trinkgeld:")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(percentTips + fixedTips, id: \.self) { tip in
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
            case .percent(let pct): return "\(pct)%"
            case .fixed(let amount): return String(format: "%.2f €", amount)
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
        HStack {
            Text("Gesamt")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
            Spacer()
            Text(String(format: "%.2f €", totalAmount))
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
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
            Text("ZahlungsArt")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Brand.primary)

            HStack(spacing: 10) {
                ForEach(CheckoutPaymentMethod.allCases) { method in
                    paymentMethodButton(method)
                }
            }

            if selectedMethod == .cash {
                Text("Betrag am Ende der Fahrt bar beim Fahrer — jetzt nur Fahrt vormerken, nicht vorab bezahlen.")
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
            showCardPayment = true
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
            paymentMethodLabel: selectedMethod.rawValue
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
                let clientSecret = try await stripeService.fetchClientSecret(amountInCents: amountInCents)
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

        applePayHandler.startPayment(summaryItems: items) { success, _ in
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
    @State private var showConfirmedAlert = false
    @State private var isSubmitting = false
    @State private var submitError: String?
    @State private var confirmedMessage = ""

    let summary: TaxiBookingSummary

    private let bookingService = BookingService()

    var body: some View {
        VStack(spacing: 0) {
            Text("Buchung prüfen")
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
                Text("Der Betrag wird nach der Fahrt bar bezahlt — unten nur die Buchung bestätigen, kein Zahlvorgang in der App.")
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
        .alert("Buchung bestätigt", isPresented: $showConfirmedAlert) {
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
        if summary.paymentMethodLabel == "Bar" { return "Bar buchen" }
        return "Bestätigen"
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
            summaryRow(label: "Tarif", value: String(format: "%.2f €", summary.tariffAmount))
            summaryRow(label: "Trinkgeld", value: String(format: "%.2f €", summary.tipAmount))

            if summary.useVoucher {
                summaryRow(
                    label: "Gutschein",
                    value: String(format: "-%.2f €", summary.voucherAmount)
                )
            }

            summaryRow(label: "Zahlungsart", value: summary.paymentMethodLabel)

            Divider()
                .padding(.vertical, 4)

            HStack {
                Text("Gesamt")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Brand.primary)
                Spacer()
                Text(String(format: "%.2f €", summary.totalAmount))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Brand.primary)
            }
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
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: summary.pickupDate)
    }

    private var pickupDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
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
                        "Ihr Taxi wurde vorgemerkt (lokal gespeichert). Die Zentrale ist gerade offline — starte das Backend auf dem Mac für Live-Buchungen."
                } else if summary.paymentMethodLabel == "Bar" {
                    confirmedMessage =
                        "Ihr Taxi wurde erfolgreich vorgemerkt. Der Betrag wird am Ende der Fahrt bar beim Fahrer bezahlt. Der Fahrer sieht den Abholpunkt — auch wenn Ihr Handy später aus ist."
                } else {
                    confirmedMessage =
                        "Ihr Taxi wurde erfolgreich vorgemerkt. Der Fahrer sieht den Abholpunkt — auch wenn Ihr Handy später aus ist."
                }
                showConfirmedAlert = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        PaymentView()
    }
}
