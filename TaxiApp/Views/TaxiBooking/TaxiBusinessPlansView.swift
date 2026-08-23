import SwiftUI
import SafariServices

/// Angebot für Taxi-Unternehmer — monatliche Tarife, kündbar.
struct TaxiBusinessPlansView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var safariURL: IdentifiableURL?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                webOfferCard
                customerSection
                operatorSection
                platformFeeSection
                LegalLinksSection(links: [.agb, .widerruf, .kuendigung, .impressum, .datenschutz])
                    .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Brand.background.ignoresSafeArea())
        .navigationTitle("Für Unternehmer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Brand.primary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Schließen") { dismiss() }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Angebot online") {
                    openOperatorsWebPage()
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
            }
        }
        .sheet(item: $safariURL) { item in
            SafariWebView(url: item.url)
                .ignoresSafeArea()
        }
    }

    private func openOperatorsWebPage() {
        guard let url = BusinessOffering.operatorsWebURL else { return }
        safariURL = IdentifiableURL(url: url)
    }

    private var webOfferCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tarife & Anfrage online")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Brand.primary)
            Text("Die vollständige Angebotsseite mit Formular (Tarif anfragen oder abonnieren) öffnet sich im Browser.")
                .font(.caption)
                .foregroundStyle(Brand.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: openOperatorsWebPage) {
                Label("Zur Angebotsseite", systemImage: "safari")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(.white)
                    .background(Brand.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.card)
        .clipShape(RoundedRectangle(cornerRadius: Brand.cornerRadius, style: .continuous))
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(BusinessOffering.productName)
                .font(.title.bold())
                .foregroundStyle(Brand.primary)
            Text(BusinessOffering.tagline)
                .font(.headline)
                .foregroundStyle(Brand.secondary)
            Text(BusinessOffering.billingNote)
                .font(.subheadline)
                .foregroundStyle(Brand.secondary)
        }
    }

    private var customerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Für Fahrgäste")
            Text("App kostenlos")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Brand.primary)

            Text(BusinessOffering.customerPriceNote)
                .font(.caption)
                .foregroundStyle(Brand.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(BusinessOffering.customerHighlights, id: \.self) { item in
                Label(item, systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(Brand.secondary)
                    .labelStyle(.titleAndIcon)
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.card)
        .clipShape(RoundedRectangle(cornerRadius: Brand.cornerRadius, style: .continuous))
    }

    private var operatorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Für Taxi-Unternehmer")

            ForEach(BusinessOffering.operatorPlans) { plan in
                planCard(plan)
            }
        }
    }

    private func planCard(_ plan: OperatorPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(plan.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Brand.primary)
                Spacer()
                if plan.highlighted {
                    Text("Beliebt")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Brand.primary.opacity(0.12))
                        .foregroundStyle(Brand.primary)
                        .clipShape(Capsule())
                }
            }

            Text(plan.formattedMonthlyPrice)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Brand.primary)

            Text("Monatlich kündbar · \(plan.vehicleLimit)")
                .font(.caption)
                .foregroundStyle(Brand.secondary)

            Text(plan.formattedPlatformFee)
                .font(.caption.weight(.medium))
                .foregroundStyle(Brand.secondary)

            ForEach(plan.features, id: \.self) { feature in
                Label(feature, systemImage: "checkmark")
                    .font(.subheadline)
                    .foregroundStyle(Brand.secondary)
            }

            if let url = plan.webOfferingURL {
                Button {
                    safariURL = IdentifiableURL(url: url)
                } label: {
                    Text("Tarif anfragen")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(.white)
                        .background(Brand.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                if let mailURL = plan.mailtoPartnerURL {
                    Button {
                        openURL(mailURL)
                    } label: {
                        Text("Stattdessen per E-Mail")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Brand.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.card)
        .overlay(
            RoundedRectangle(cornerRadius: Brand.cornerRadius, style: .continuous)
                .stroke(plan.highlighted ? Brand.primary.opacity(0.35) : Color.clear, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: Brand.cornerRadius, style: .continuous))
    }

    private var platformFeeSection: some View {
        Text(BusinessOffering.platformFeeExplanation)
            .font(.footnote)
            .foregroundStyle(Brand.secondary)
            .padding(.bottom, 8)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline.weight(.semibold))
            .foregroundStyle(Brand.primary)
    }
}

private struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

private struct SafariWebView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        TaxiBusinessPlansView()
    }
}
