import Foundation

/// Angebot & Preise — synchron halten mit `backend/offering.json`.
enum BusinessOffering {
    static let productName = "TaxiApp"
    static let tagline = "Taxi buchen. Bezahlen. Fertig."
    static let billingNote = "Alle Unternehmer-Tarife monatlich kündbar — keine Mindestlaufzeit."
    static let partnerEmail = "partner@taxiapp.de"

    static let customerHighlights: [String] = [
        "Taxi in wenigen Schritten buchen",
        "Abholzeit wählen oder sofort fahren",
        "Bezahlen per Bankkarte (Stripe), Bar oder Gutschein",
        "Trinkgeld frei wählbar",
        "Keine Reservierungsgebühr in der App"
    ]

    static let operatorPlans: [OperatorPlan] = [
        OperatorPlan(
            id: "starter",
            name: "Starter",
            priceEuroPerMonth: 49,
            vehicleLimit: "bis 5 Fahrzeuge",
            cardPlatformFeePercent: 2.0,
            features: [
                "Eigene App mit Firmenlogo",
                "Online-Kartenzahlung (Stripe)",
                "Fahrtenübersicht (Basis)",
                "E-Mail-Support"
            ],
            highlighted: false
        ),
        OperatorPlan(
            id: "business",
            name: "Business",
            priceEuroPerMonth: 99,
            vehicleLimit: "unbegrenzt",
            cardPlatformFeePercent: 1.5,
            features: [
                "Alles aus Starter",
                "Mehrere Standorte / Filialen",
                "Prioritäts-Support",
                "Monatliche Abrechnungsübersicht"
            ],
            highlighted: true
        )
    ]

    static let platformFeeExplanation =
        "Die Plattformgebühr gilt nur auf erfolgreiche Kartenzahlungen in der App und wird bei Auszahlung an das Unternehmen einbehalten."

    /// Provision in Cent für Stripe Connect (`application_fee_amount`), sobald Connect aktiv ist.
    static func platformFeeInCents(forCardAmountInCents amount: Int, planId: String = "business") -> Int {
        let percent = operatorPlans.first { $0.id == planId }?.cardPlatformFeePercent ?? 1.5
        return Int((Double(amount) * percent / 100.0).rounded())
    }
}

struct OperatorPlan: Identifiable, Hashable {
    let id: String
    let name: String
    let priceEuroPerMonth: Int
    let vehicleLimit: String
    let cardPlatformFeePercent: Double
    let features: [String]
    let highlighted: Bool

    var formattedMonthlyPrice: String {
        "\(priceEuroPerMonth) € / Monat"
    }

    var formattedPlatformFee: String {
        String(format: "%.1f %% auf Kartenzahlungen", cardPlatformFeePercent)
    }

    var mailtoPartnerURL: URL? {
        let subject = "TaxiApp \(name) — Anfrage"
        let body = """
        Hallo TaxiApp-Team,

        ich interessiere mich für den Tarif \(name) (\(formattedMonthlyPrice)).

        Firma:
        Stadt:
        Fahrzeuge:

        """
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = BusinessOffering.partnerEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url
    }
}
