import Foundation
import CoreLocation

struct PlacePrediction: Identifiable, Hashable {
    var id: String { placeId }
    let placeId: String
    let description: String
    let mainText: String
    let secondaryText: String
    let latitude: Double?
    let longitude: Double?
}

struct ResolvedPlace {
    let placeId: String
    let address: String
    let coordinate: CLLocationCoordinate2D
}

enum PlacesAutocompleteService {
    static func autocomplete(query: String) async throws -> [PlacePrediction] {
        var components = URLComponents(string: "\(TaxiConfig.stripeBackendURL)/api/places/autocomplete")
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        guard let url = components?.url else { throw URLError(.badURL) }
        let (data, response) = try await URLSession.shared.data(from: url)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            throw URLError(.badServerResponse)
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let list = json["predictions"] as? [[String: Any]] ?? []
        return list.compactMap { item in
            guard let placeId = item["placeId"] as? String else { return nil }
            return PlacePrediction(
                placeId: placeId,
                description: item["description"] as? String ?? "",
                mainText: item["mainText"] as? String ?? "",
                secondaryText: item["secondaryText"] as? String ?? "",
                latitude: item["latitude"] as? Double,
                longitude: item["longitude"] as? Double
            )
        }
    }

    static func resolve(prediction: PlacePrediction) async throws -> ResolvedPlace {
        if let lat = prediction.latitude, let lng = prediction.longitude {
            return ResolvedPlace(
                placeId: prediction.placeId,
                address: prediction.description,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng)
            )
        }
        var components = URLComponents(string: "\(TaxiConfig.stripeBackendURL)/api/places/details")
        components?.queryItems = [
            URLQueryItem(name: "placeId", value: prediction.placeId),
            URLQueryItem(name: "description", value: prediction.description),
        ]
        guard let url = components?.url else { throw URLError(.badURL) }
        let (data, response) = try await URLSession.shared.data(from: url)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else { throw URLError(.badServerResponse) }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        guard let lat = json["latitude"] as? Double, let lng = json["longitude"] as? Double else {
            throw URLError(.cannotParseResponse)
        }
        return ResolvedPlace(
            placeId: prediction.placeId,
            address: (json["address"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? prediction.description,
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng)
        )
    }
}
