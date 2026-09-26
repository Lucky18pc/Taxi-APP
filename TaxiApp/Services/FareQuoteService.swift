import Foundation
import CoreLocation

struct FareQuote: Hashable {
    let fare: Double
    let distanceMeters: Double
    let durationSeconds: Double
    let distanceText: String
    let durationText: String
    let isNight: Bool
    let basePrice: Double
    let pricePerKm: Double
    let provider: String
    let formula: String

    var distanceKm: Double { distanceMeters / 1000 }
}

enum FareQuoteService {
    static func quote(
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D
    ) async throws -> FareQuote {
        guard let url = URL(string: "\(TaxiConfig.stripeBackendURL)/api/fare/quote") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "origin": ["latitude": origin.latitude, "longitude": origin.longitude],
            "destination": ["latitude": destination.latitude, "longitude": destination.longitude],
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        guard (200..<300).contains(code) else {
            throw NSError(
                domain: "FareQuote",
                code: code,
                userInfo: [NSLocalizedDescriptionKey: json["error"] as? String ?? "Tarif nicht verfügbar"]
            )
        }

        // Server liefert Distance Matrix + Formel; lokal zusätzlich absichern
        let distanceMeters = 0.0
        if let n = json["distanceMeters"] as? Double {
            distanceMeters = n
        } else if let n = json["distanceMeters"] as? Int {
            distanceMeters = Double(n)
        }
        let serverFare = json["fare"] as? Double
        let local = FareCalculator().calculateFare(distanceInMeters: distanceMeters)
        let fare = serverFare ?? local.price

        var durationSeconds = 0.0
        if let n = json["durationSeconds"] as? Double {
            durationSeconds = n
        } else if let n = json["durationSeconds"] as? Int {
            durationSeconds = Double(n)
        }

        return FareQuote(
            fare: fare,
            distanceMeters: distanceMeters,
            durationSeconds: durationSeconds,
            distanceText: json["distanceText"] as? String ?? String(format: "%.1f km", distanceMeters / 1000),
            durationText: json["durationText"] as? String ?? "",
            isNight: json["isNight"] as? Bool ?? local.isNight,
            basePrice: json["basePrice"] as? Double ?? (local.isNight ? 4.9 : 3.9),
            pricePerKm: json["pricePerKm"] as? Double ?? (local.isNight ? 2.6 : 2.3),
            provider: json["provider"] as? String ?? "unknown",
            formula: json["formula"] as? String ?? "Grundpreis + (Kilometer * Kilometertarif)"
        )
    }
}
