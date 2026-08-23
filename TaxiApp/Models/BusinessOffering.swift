import Foundation

/// Angebot & Preise — synchron halten mit `backend/offering.json`.
enum BusinessOffering {
    static let productName = "Luckys Taxi App"
    static let tagline = "Taxi bestellen. Fahren. Bezahlen."
    static let billingNote = "Alle Unternehmer-Tarife monatlich kündbar — keine Mindestlaufzeit."
    static let partnerEmail = "luckypc81@gmail.com"

    /// Startseite mit Unternehmer-Tarifen (Browser-Buchung / Anfrage-Formular).
    static var operatorsWebURL: URL? {
        URL(string: "\(TaxiConfig.stripeBackendURL)/index.html#operators")
    }

    static let customerPriceNote =
        "Kein Festpreis in der App — der Fahrtbetrag steht nach der Fahrt auf dem Taxameter."

    static let customerHighlights: [String] = [
        "Taxi in wenigen Schritten bestellen",
        "Abholzeit und Abholort festlegen",
        "Fahrtpreis nach Taxameter — bar beim Fahrer",
        "Kartenzahlung in der App nach der Fahrt (folgt)",
        "Trinkgeld optional als Wunsch mitteilen",
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
        let subject = "Luckys Taxi App \(name) — Anfrage"
        let body = """
        Hallo TaxiApp-Team,

        ich interessiere mich für den Tarif \(name) (\(formattedMonthlyPrice)).

        Firma:
        Stadt:
        Fahrzeuge:

        """
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?")
        guard
            let subjectEncoded = subject.addingPercentEncoding(withAllowedCharacters: allowed),
            let bodyEncoded = body.addingPercentEncoding(withAllowedCharacters: allowed)
        else { return nil }
        return URL(string: "mailto:\(BusinessOffering.partnerEmail)?subject=\(subjectEncoded)&body=\(bodyEncoded)")
    }

    /// Vollständiges Angebot mit Formular auf der Web-Startseite.
    var webOfferingURL: URL? {
        BusinessOffering.operatorsWebURL
    }
}
