import Foundation

enum VehicleType: String, CaseIterable, Identifiable {
    case small = "Kleinwagen"
    case large = "Großraum"

    var id: String { rawValue }

    /// Bildname in Assets (z. B. taxi_small, taxi_large)
    var imageName: String {
        switch self {
        case .small: return "taxi_small"
        case .large: return "taxi_large"
        }
    }

    /// SF Symbol als Fallback, wenn kein Asset vorhanden
    var icon: String {
        switch self {
        case .small: return "car.fill"
        case .large: return "bus.fill"
        }
    }

    var surcharge: Double {
        switch self {
        case .small: return 0.0
        case .large: return 7.50
        }
    }
}
