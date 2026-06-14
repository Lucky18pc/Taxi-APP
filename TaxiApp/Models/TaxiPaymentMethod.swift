import Foundation

enum TaxiPaymentMethod: String, CaseIterable, Identifiable {
    case cash = "Bargeld"
    case card = "Karte / Kontaktlos"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .cash: return "banknote.fill"
        case .card: return "creditcard.and.123"
        }
    }
}
