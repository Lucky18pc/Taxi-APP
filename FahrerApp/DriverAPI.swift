//
//  DriverAPI.swift
//  Luckys Taxi Fahrer
//

import Foundation

enum DriverAPIError: LocalizedError {
    case badURL
    case http(Int, String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .badURL: return "Ungültige Backend-URL."
        case .http(let code, let body): return "Server \(code): \(body)"
        case .decoding: return "Antwort konnte nicht gelesen werden."
        }
    }
}

enum DriverAPI {
    private static func authorizedRequest(url: URL, method: String = "GET", jsonBody: [String: Any]? = nil) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(FahrerBackendConfig.driverApiKey)", forHTTPHeaderField: "Authorization")
        if let jsonBody {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: jsonBody)
        }
        return request
    }

    static func openBookings(operatorSlug: String) async throws -> [DriverBooking] {
        var components = URLComponents(string: "\(FahrerBackendConfig.baseURL)/api/driver/open-bookings")
        components?.queryItems = [URLQueryItem(name: "operator", value: operatorSlug)]
        guard let url = components?.url else { throw DriverAPIError.badURL }

        let request = try authorizedRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            throw DriverAPIError.http(code, String(data: data, encoding: .utf8) ?? "")
        }
        do {
            return try JSONDecoder().decode(OpenBookingsResponse.self, from: data).bookings
        } catch {
            throw DriverAPIError.decoding
        }
    }

    static func acceptBooking(bookingId: String, driverUid: String, driverName: String, operatorSlug: String) async throws {
        guard var components = URLComponents(string: "\(FahrerBackendConfig.baseURL)/api/driver/bookings/\(bookingId)/accept") else {
            throw DriverAPIError.badURL
        }
        components.queryItems = [URLQueryItem(name: "operator", value: operatorSlug)]
        // Nach guard var ist components kein Optional mehr → kein ?.url
        guard let url = components.url else { throw DriverAPIError.badURL }

        let request = try authorizedRequest(
            url: url,
            method: "PATCH",
            jsonBody: [
                "driverUid": driverUid,
                "driverName": driverName,
            ]
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            throw DriverAPIError.http(code, String(data: data, encoding: .utf8) ?? "")
        }
    }

    static func completeBooking(bookingId: String, driverUid: String, operatorSlug: String) async throws {
        guard var components = URLComponents(string: "\(FahrerBackendConfig.baseURL)/api/driver/bookings/\(bookingId)/complete") else {
            throw DriverAPIError.badURL
        }
        components.queryItems = [URLQueryItem(name: "operator", value: operatorSlug)]
        guard let url = components.url else { throw DriverAPIError.badURL }

        let request = try authorizedRequest(
            url: url,
            method: "PATCH",
            jsonBody: [
                "driverUid": driverUid,
            ]
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            throw DriverAPIError.http(code, String(data: data, encoding: .utf8) ?? "")
        }
    }

    /// GPS an Backend für Live-Tracking (Fahrgast-Karte).
    static func postLocation(
        driverUid: String,
        latitude: Double,
        longitude: Double,
        bookingId: String?,
        operatorSlug: String
    ) async throws {
        guard var components = URLComponents(string: "\(FahrerBackendConfig.baseURL)/api/driver/location") else {
            throw DriverAPIError.badURL
        }
        components.queryItems = [URLQueryItem(name: "operator", value: operatorSlug)]
        guard let url = components.url else { throw DriverAPIError.badURL }

        var body: [String: Any] = [
            "driverUid": driverUid,
            "latitude": latitude,
            "longitude": longitude,
        ]
        if let bookingId = bookingId, !bookingId.isEmpty {
            body["bookingId"] = bookingId
        }

        let request = try authorizedRequest(url: url, method: "POST", jsonBody: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            throw DriverAPIError.http(code, String(data: data, encoding: .utf8) ?? "")
        }
    }
}
