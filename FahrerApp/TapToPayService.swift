//
//  TapToPayService.swift
//  Luckys Taxi Fahrer
//
//  Backend-Anbindung für Tap to Pay (Stripe Terminal).
//  NFC-UI: Stripe Terminal iOS SDK in Xcode hinzufügen — siehe README + docs/TAP-TO-PAY.md
//

import Foundation

enum TapToPayError: LocalizedError {
    case notConfigured
    case sdkMissing
    case backend(String)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Tap to Pay ist auf dem Server nicht konfiguriert (STRIPE_TERMINAL_LOCATION_ID)."
        case .sdkMissing:
            return "Stripe Terminal SDK noch nicht in Xcode eingebunden — Link-Zahlung nutzen oder SDK laut README hinzufügen."
        case .backend(let message):
            return message
        case .failed(let message):
            return message
        }
    }
}

struct TapToPaySession: Decodable {
    let bookingId: String
    let totalAmount: Double
    let paymentIntentId: String?
    let clientSecret: String?
    let locationId: String?
    let paymentStatus: String?
    let alreadyPaid: Bool?
}

enum TapToPayService {
    private static func driverRequest(_ url: URL, method: String = "GET", body: [String: Any]? = nil) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(BackendConfig.driverApiKey, forHTTPHeaderField: "X-Driver-Key")
        request.setValue("Bearer \(BackendConfig.driverApiKey)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return request
    }

    static func isEnabled(operatorSlug: String) async -> Bool {
        guard var components = URLComponents(string: "\(BackendConfig.baseURL)/api/terminal/config") else {
            return false
        }
        components.queryItems = [URLQueryItem(name: "operator", value: operatorSlug)]
        guard let url = components.url else { return false }
        do {
            let request = try driverRequest(url)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return false
            }
            struct Config: Decodable { let enabled: Bool }
            return try JSONDecoder().decode(Config.self, from: data).enabled
        } catch {
            return false
        }
    }

    /// Erzeugt Terminal-PaymentIntent auf dem Server (Karte tippen vorbereiten).
    static func prepareTapToPay(
        bookingId: String,
        driverUid: String,
        operatorSlug: String,
        totalAmount: Double
    ) async throws -> TapToPaySession {
        guard var components = URLComponents(
            string: "\(BackendConfig.baseURL)/api/driver/bookings/\(bookingId)/tap-pay"
        ) else {
            throw TapToPayError.backend("Ungültige URL")
        }
        components.queryItems = [URLQueryItem(name: "operator", value: operatorSlug)]
        guard let url = components.url else { throw TapToPayError.backend("Ungültige URL") }

        let request = try driverRequest(url, method: "POST", body: [
            "driverUid": driverUid,
            "totalAmount": totalAmount,
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if !(200..<300).contains(code) {
            if let err = try? JSONDecoder().decode([String: String].self, from: data), let message = err["error"] {
                throw TapToPayError.backend(message)
            }
            throw TapToPayError.backend(String(data: data, encoding: .utf8) ?? "Tap to Pay fehlgeschlagen")
        }
        return try JSONDecoder().decode(TapToPaySession.self, from: data)
    }

    static func fetchConnectionToken(operatorSlug: String) async throws -> String {
        guard var components = URLComponents(string: "\(BackendConfig.baseURL)/api/terminal/connection-token") else {
            throw TapToPayError.backend("Ungültige URL")
        }
        components.queryItems = [URLQueryItem(name: "operator", value: operatorSlug)]
        guard let url = components.url else { throw TapToPayError.backend("Ungültige URL") }

        let request = try driverRequest(url, method: "POST")
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            throw TapToPayError.backend(String(data: data, encoding: .utf8) ?? "Connection token fehlgeschlagen")
        }
        struct Token: Decodable { let secret: String }
        return try JSONDecoder().decode(Token.self, from: data).secret
    }

    /// Vollständiges NFC-Collect braucht Stripe Terminal SDK (siehe docs/TAP-TO-PAY.md Phase B).
    @MainActor
    static func collectWithSdkIfAvailable(
        bookingId: String,
        driverUid: String,
        operatorSlug: String,
        totalAmount: Double
    ) async throws -> TapToPaySession {
        let session = try await prepareTapToPay(
            bookingId: bookingId,
            driverUid: driverUid,
            operatorSlug: operatorSlug,
            totalAmount: totalAmount
        )
        if session.alreadyPaid == true {
            return session
        }
        #if canImport(StripeTerminal)
        // SDK-Integration: ConnectionTokenProvider + discover TapToPay + collectPaymentMethod
        // Siehe Stripe Docs „Tap to Pay on iPhone“ — hier bewusst serverseitig vorbereitet.
        _ = try await fetchConnectionToken(operatorSlug: operatorSlug)
        throw TapToPayError.failed(
            "SDK angebunden, Collect-UI folgt — bitte Stripe Terminal laut docs/TAP-TO-PAY.md fertig verdrahten."
        )
        #else
        throw TapToPayError.sdkMissing
        #endif
    }
}
