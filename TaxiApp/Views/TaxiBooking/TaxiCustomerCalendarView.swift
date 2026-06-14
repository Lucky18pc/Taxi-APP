import SwiftUI

/// Seite 2: Kundenkalender — Abholdatum und Abholzeit wählen.
struct TaxiCustomerCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pickupDate = Date()
    @State private var showNextScreen = false

    var body: some View {
        VStack(spacing: 0) {
            titleBlock
                .padding(.top, 10)

            ScrollView(showsIndicators: false) {
                mainCard
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
            }

            Spacer(minLength: 0)
        }
        .bookingFlowBackground()
        .navigationBarBackButtonHidden(true)
        .safeAreaPadding(.top, 8)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BookingBottomBar(forwardTitle: "Weiter", onBack: { dismiss() }, onForward: { showNextScreen = true })
        }
        .navigationDestination(isPresented: $showNextScreen) {
            TaxiPickupLocationView(pickupDate: pickupDate)
        }
    }

    // MARK: - Kopfbereich

    private var titleBlock: some View {
        VStack(spacing: 2) {
            Text("Kunde Kalender")
                .font(BookingScreenStyle.titleFont)
                .foregroundStyle(.white)

            Text("mit Abholzeit")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    // MARK: - Kalender-Karte

    private var mainCard: some View {
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
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 16, y: 8)
        .lightShimmer(cornerRadius: 22, tone: .onLight, intensity: 0.9)
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
            Label("Taxi-Bestätigung", systemImage: "car.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Brand.primary)

            Text("Ein Taxi wird für diesen Termin vorgemerkt.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)

            Text(confirmationSummary)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(confirmationCode)
                .font(.subheadline.weight(.bold).monospaced())
                .foregroundStyle(Brand.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Unten: Zurück links, Weiter rechts

    private var confirmationCode: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "yyMMddHHmm"
        return "Bestätigungscode: TAXI-\(formatter.string(from: pickupDate))"
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
        TaxiCustomerCalendarView()
    }
}
