import Foundation

enum TaxiPaymentMethod: String, CaseIterable, Identifiable {
    case cash = "Bar"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .cash: return "banknote.fill"
        }
    }
}
