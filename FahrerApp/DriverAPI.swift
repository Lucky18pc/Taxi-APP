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
    static func openBookings(operatorSlug: String) async throws -> [DriverBooking] {
        guard var components = URLComponents(string: "\(BackendConfig.baseURL)/api/driver/open-bookings") else {
            throw DriverAPIError.badURL
        }
        components.queryItems = [URLQueryItem(name: "operator", value: operatorSlug)]
        guard let url = components.url else { throw DriverAPIError.badURL }

        let (data, response) = try await URLSession.shared.data(from: url)
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
        guard var components = URLComponents(string: "\(BackendConfig.baseURL)/api/driver/bookings/\(bookingId)/accept") else {
            throw DriverAPIError.badURL
        }
        components.queryItems = [URLQueryItem(name: "operator", value: operatorSlug)]
        guard let url = components.url else { throw DriverAPIError.badURL }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(BackendConfig.driverApiKey, forHTTPHeaderField: "X-Driver-Key")
        request.setValue("Bearer \(BackendConfig.driverApiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "driverUid": driverUid,
            "driverName": driverName,
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            throw DriverAPIError.http(code, String(data: data, encoding: .utf8) ?? "")
        }
    }

    static func completeBooking(
        bookingId: String,
        driverUid: String,
        operatorSlug: String,
        totalAmount: Double? = nil
    ) async throws -> CompleteBookingResponse {
        guard var components = URLComponents(string: "\(BackendConfig.baseURL)/api/driver/bookings/\(bookingId)/complete") else {
            throw DriverAPIError.badURL
        }
        components.queryItems = [URLQueryItem(name: "operator", value: operatorSlug)]
        guard let url = components.url else { throw DriverAPIError.badURL }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(BackendConfig.driverApiKey, forHTTPHeaderField: "X-Driver-Key")
        request.setValue("Bearer \(BackendConfig.driverApiKey)", forHTTPHeaderField: "Authorization")
        var body: [String: Any] = ["driverUid": driverUid]
        if let totalAmount {
            body["totalAmount"] = totalAmount
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            throw DriverAPIError.http(code, String(data: data, encoding: .utf8) ?? "")
        }
        if let decoded = try? JSONDecoder().decode(CompleteBookingResponse.self, from: data) {
            return decoded
        }
        return CompleteBookingResponse(payUrl: nil)
    }
}

struct CompleteBookingResponse: Decodable {
    let payUrl: String?
}
