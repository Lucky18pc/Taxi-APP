import SwiftUI

/// Angebot für Taxi-Unternehmer — monatliche Tarife, kündbar.
struct TaxiBusinessPlansView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
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
        .navigationTitle("Angebot")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Schließen") { dismiss() }
            }
        }
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
                .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)

            Text(plan.formattedPlatformFee)
                .font(.caption.weight(.medium))
                .foregroundStyle(Brand.secondary)

            ForEach(plan.features, id: \.self) { feature in
                Label(feature, systemImage: "checkmark")
                    .font(.subheadline)
                    .foregroundStyle(Brand.secondary)
            }

            if let url = plan.mailtoPartnerURL {
                Link(destination: url) {
                    Text("Tarif anfragen")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(plan.highlighted ? Brand.primary : Brand.primary.opacity(0.12))
                        .foregroundStyle(plan.highlighted ? Color.white : Brand.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
            .foregroundStyle(.secondary)
            .padding(.bottom, 8)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline.weight(.semibold))
            .foregroundStyle(Brand.primary)
    }
}

#Preview {
    NavigationStack {
        TaxiBusinessPlansView()
    }
}
