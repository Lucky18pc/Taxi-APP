import SwiftUI

/// Seite 3: Jetzt oder später — danach Fahrt prüfen, zum Schluss die Kasse.
struct TaxiCustomerCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var centralStore: CentralConfigStore
    let pickupLocation: PickupLocation

    @State private var pickupDate = Date()
    @State private var showReview = false
    @State private var reviewIsImmediate = false

    var body: some View {
        VStack(spacing: 0) {
            titleBlock
                .padding(.top, 10)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    BookingTripOverviewCard(
                        pickupLocation: pickupLocation,
                        pickupDate: pickupDate,
                        isImmediate: false
                    )
                    .padding(.horizontal, 20)

                    immediateCard
                        .padding(.horizontal, 20)

                    laterSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }
                .padding(.top, 12)
            }

            Spacer(minLength: 0)
        }
        .bookingFlowBackground()
        .navigationBarBackButtonHidden(true)
        .safeAreaPadding(.top, 8)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BookingBottomBar(
                forwardTitle: "Fahrt prüfen",
                onBack: { dismiss() },
                onForward: {
                    reviewIsImmediate = false
                    showReview = true
                }
            )
        }
        .navigationDestination(isPresented: $showReview) {
            TaxiConfirmationView(summary: buildSummary(immediate: reviewIsImmediate))
        }
    }

    // MARK: - Kopfbereich

    private var titleBlock: some View {
        VStack(spacing: 2) {
            Text("Jetzt oder später?")
                .font(BookingScreenStyle.titleFont)
                .foregroundStyle(.white)

            Text("Abholzeit wählen")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    // MARK: - Sofort

    private var immediateCard: some View {
        Button {
            pickupDate = Date()
            reviewIsImmediate = true
            showReview = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "bolt.fill")
                    .font(.title3)
                    .foregroundStyle(Brand.primary)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Sofort")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Brand.primary)

                    Text("Fahrt prüfen — danach Kasse mit Trinkgeld")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Brand.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Brand.primary.opacity(0.55))
            }
            .padding(16)
            .background(Brand.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.10), radius: 16, y: 8)
        }
        .buttonStyle(.plain)
        .colorScheme(.light)
    }

    // MARK: - Später: Kalender

    private var laterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Oder Termin wählen")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.leading, 4)

            VStack(spacing: 0) {
                fittedCalendar
                    .padding(.horizontal, 6)
                    .padding(.top, 4)

                Divider()
                    .padding(.horizontal, 16)

                timeRow
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                Divider()
                    .padding(.horizontal, 16)

                confirmationRow
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .background(Brand.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.10), radius: 16, y: 8)
            .colorScheme(.light)
        }
    }

    private var fittedCalendar: some View {
        GeometryReader { geometry in
            let calendarHeight: CGFloat = 300
            let scale = min(1, geometry.size.width / 340, 240 / calendarHeight)

            DatePicker(
                "Abholdatum",
                selection: $pickupDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(Brand.primary)
            .labelsHidden()
            .colorScheme(.light)
            .scaleEffect(scale, anchor: .top)
            .frame(width: geometry.size.width, height: calendarHeight * scale, alignment: .top)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(height: 240)
    }

    private var timeRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.fill")
                .foregroundStyle(Brand.primary)

            Text("Abholzeit")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Brand.primary)

            Spacer()

            DatePicker(
                "Abholzeit",
                selection: $pickupDate,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .tint(Brand.primary)
            .colorScheme(.light)
        }
    }

    private var confirmationRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Termin-Vormerkung", systemImage: "calendar")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Brand.primary)

            Text("Danach Fahrt prüfen — Trinkgeld und Zahlungswunsch an der Kasse.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Brand.primary)

            Text(confirmationSummary)
                .font(.caption)
                .foregroundStyle(Brand.secondary)

            Text(confirmationCode)
                .font(.subheadline.weight(.bold).monospaced())
                .foregroundStyle(Brand.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func buildSummary(immediate: Bool) -> TaxiBookingSummary {
        TaxiBookingSummary(
            pickupDate: immediate ? Date() : pickupDate,
            pickupLocation: pickupLocation,
            tariffAmount: 0,
            tipAmount: 0,
            voucherAmount: 0,
            useVoucher: false,
            paymentMethodLabel: "Bar",
            nightSurchargeApplies: centralStore.nightSurchargeApplies(for: immediate ? Date() : pickupDate),
            isImmediatePickup: immediate
        )
    }

    private var confirmationCode: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "yyMMddHHmm"
        return "Vormerkung: TAXI-\(formatter.string(from: pickupDate))"
    }

    private var confirmationSummary: String {
        let dateText = pickupDate.formatted(
            .dateTime.day().month(.wide).year()
                .locale(Locale(identifier: "de_DE"))
        )
        let timeText = pickupDate.formatted(
            .dateTime.hour().minute()
                .locale(Locale(identifier: "de_DE"))
        )
        return "Abholung am \(dateText) um \(timeText) Uhr"
    }
}

#Preview {
    NavigationStack {
        TaxiCustomerCalendarView(pickupLocation: .defaultPlaceholder)
            .environmentObject(CentralConfigStore())
    }
}
