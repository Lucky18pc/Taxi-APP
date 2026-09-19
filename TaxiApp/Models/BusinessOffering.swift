import Foundation

/// Angebot & Preise — synchron halten mit `backend/offering.json`.
enum BusinessOffering {
    static let productName = "Luckys Taxi App"
    static let tagline = "Taxi bestellen. Fahren. Bezahlen."
    static let billingNote = "14 Tage unverbindlich testen — danach monatlich kündbar, keine Mindestlaufzeit."
    static let partnerEmail = "luckypc81@gmail.com"

    /// 1. Auto 9,90 € · jedes weitere +9,00 € (2 Autos = 18,90 €).
    static let firstVehicleEuroPerMonth = 9.9
    static let additionalVehicleEuroPerMonth = 9.0
    static let platformFeePercent = 1.9

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
        "Kartenzahlung möglich",
        "Trinkgeld optional als Wunsch mitteilen",
        "Keine Reservierungsgebühr in der App"
    ]

    static let operatorPlans: [OperatorPlan] = [
        OperatorPlan(
            id: "fleet",
            name: "Pro Fahrzeug",
            priceEuroPerMonth: firstVehicleEuroPerMonth,
            vehicleLimit: "pro Fahrzeug (1. Auto 9,90 € · 2. Auto 18,90 € · jedes weitere +9 €)",
            cardPlatformFeePercent: platformFeePercent,
            cashPlatformFeePercent: platformFeePercent,
            features: [
                "Eigene App mit Firmenlogo",
                "Online-Kartenzahlung (Stripe)",
                "Fahrtenübersicht & Leitstelle",
                "E-Mail-Support"
            ],
            highlighted: true
        )
    ]

    static let platformFeeExplanation =
        "Die Plattformgebühr beträgt 1,9 % auf Bar- und Kartenzahlungen der vermittelten Fahrten und wird monatlich abgerechnet bzw. bei Kartenzahlung bei Auszahlung einbehalten."

    /// Monatliches Abo für `vehicleCount` Fahrzeuge.
    static func monthlyPriceEuro(forVehicleCount vehicleCount: Int) -> Double {
        let n = max(1, vehicleCount)
        return firstVehicleEuroPerMonth + Double(n - 1) * additionalVehicleEuroPerMonth
    }

    /// Provision in Cent für Stripe Connect (`application_fee_amount`), sobald Connect aktiv ist.
    static func platformFeeInCents(forCardAmountInCents amount: Int, planId: String = "fleet") -> Int {
        let percent = operatorPlans.first { $0.id == planId }?.cardPlatformFeePercent ?? platformFeePercent
        return Int((Double(amount) * percent / 100.0).rounded())
    }
}

struct OperatorPlan: Identifiable, Hashable {
    let id: String
    let name: String
    let priceEuroPerMonth: Double
    let vehicleLimit: String
    let cardPlatformFeePercent: Double
    let cashPlatformFeePercent: Double
    let features: [String]
    let highlighted: Bool

    var formattedMonthlyPrice: String {
        String(format: "ab %.2f € / Monat", priceEuroPerMonth)
            .replacingOccurrences(of: ".", with: ",")
    }

    var formattedPlatformFee: String {
        String(format: "%.1f %% auf Bar- und Kartenzahlungen", cardPlatformFeePercent)
            .replacingOccurrences(of: ".", with: ",")
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
