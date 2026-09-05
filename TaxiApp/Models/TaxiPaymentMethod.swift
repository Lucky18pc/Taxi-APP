import Foundation

enum TaxiPaymentMethod: String, CaseIterable, Identifiable {
    case cash = "Bar"
    case card = "Karte"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .cash: return "banknote.fill"
        case .card: return "creditcard.fill"
        }
    }

    var title: String {
        switch self {
        case .cash: return "Bar beim Fahrer"
        case .card: return "Karte (nach der Fahrt)"
        }
    }

    var detail: String {
        switch self {
        case .cash:
            return "Fahrtpreis laut Taxameter am Ende der Fahrt — bar beim Fahrer."
        case .card:
            return "Nach der Fahrt erhältst du einen Zahlungslink (Karte / Apple Pay)."
        }
    }
}
