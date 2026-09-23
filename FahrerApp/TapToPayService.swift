//
//  TapToPayService.swift
//  Luckys Taxi Fahrer
//
//  Backend + Stripe Terminal SDK (Tap to Pay on iPhone).
//  Voraussetzung: Apple-Entitlement, SPM stripe-terminal-ios, STRIPE_TERMINAL_LOCATION_ID auf Render.
//

import Foundation

#if canImport(StripeTerminal)
import StripeTerminal
#endif

enum TapToPayError: LocalizedError {
    case notConfigured
    case sdkMissing
    case backend(String)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Tap to Pay nicht konfiguriert (STRIPE_TERMINAL_LOCATION_ID auf Render)."
        case .sdkMissing:
            return "Stripe Terminal SDK fehlt — in Xcode SPM hinzufügen (siehe Anleitung)."
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
        request.setValue(FahrerBackendConfig.driverApiKey, forHTTPHeaderField: "X-Driver-Key")
        request.setValue("Bearer \(FahrerBackendConfig.driverApiKey)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return request
    }

    static func isEnabled(operatorSlug: String) async -> Bool {
        guard var components = URLComponents(string: "\(FahrerBackendConfig.baseURL)/api/terminal/config") else {
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

    static func prepareTapToPay(
        bookingId: String,
        driverUid: String,
        operatorSlug: String,
        totalAmount: Double
    ) async throws -> TapToPaySession {
        guard var components = URLComponents(
            string: "\(FahrerBackendConfig.baseURL)/api/driver/bookings/\(bookingId)/tap-pay"
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
        guard var components = URLComponents(string: "\(FahrerBackendConfig.baseURL)/api/terminal/connection-token") else {
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
        guard let clientSecret = session.clientSecret, !clientSecret.isEmpty else {
            throw TapToPayError.failed("Kein clientSecret vom Server — Render/Stripe prüfen.")
        }
        guard let locationId = session.locationId, !locationId.isEmpty else {
            throw TapToPayError.notConfigured
        }
        try await TerminalTapToPayRunner.run(
            operatorSlug: operatorSlug,
            clientSecret: clientSecret,
            locationId: locationId
        )
        return session
        #else
        throw TapToPayError.sdkMissing
        #endif
    }
}

#if canImport(StripeTerminal)

/// Langlebiger Token-Provider (Terminal.initWithTokenProvider behält nur eine weak/unowned Referenz-Semantik — wir halten ihn selbst).
@MainActor
private final class TerminalTokenHolder: NSObject, ConnectionTokenProvider {
    static let shared = TerminalTokenHolder()
    var operatorSlug: String = ""

    func fetchConnectionToken(_ completion: @escaping ConnectionTokenCompletionBlock) {
        let slug = operatorSlug
        Task {
            do {
                let secret = try await TapToPayService.fetchConnectionToken(operatorSlug: slug)
                completion(secret, nil)
            } catch {
                completion(nil, error)
            }
        }
    }
}

/// Einmaliger Collect-Lauf für Tap to Pay (Stripe Terminal SDK 5.x).
@MainActor
private final class TerminalTapToPayRunner: NSObject, DiscoveryDelegate, TapToPayReaderDelegate {
    private var discoverContinuation: CheckedContinuation<Reader, Error>?
    private var discoverCancelable: Cancelable?

    static func run(operatorSlug: String, clientSecret: String, locationId: String) async throws {
        TerminalTokenHolder.shared.operatorSlug = operatorSlug
        if !Terminal.isInitialized() {
            Terminal.initWithTokenProvider(TerminalTokenHolder.shared)
        }

        let runner = TerminalTapToPayRunner()
        let reader = try await runner.discoverTapToPayReader()
        let config = try TapToPayConnectionConfigurationBuilder(delegate: runner, locationId: locationId).build()

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            Terminal.shared.connectReader(reader, connectionConfig: config) { connected, error in
                if let error {
                    cont.resume(throwing: TapToPayError.failed(error.localizedDescription))
                } else if connected != nil {
                    cont.resume()
                } else {
                    cont.resume(throwing: TapToPayError.failed("Reader-Verbindung fehlgeschlagen."))
                }
            }
        }

        let intent = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<PaymentIntent, Error>) in
            Terminal.shared.retrievePaymentIntent(clientSecret: clientSecret) { pi, error in
                if let error {
                    cont.resume(throwing: TapToPayError.failed(error.localizedDescription))
                } else if let pi {
                    cont.resume(returning: pi)
                } else {
                    cont.resume(throwing: TapToPayError.failed("PaymentIntent nicht geladen."))
                }
            }
        }

        let collected = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<PaymentIntent, Error>) in
            _ = Terminal.shared.collectPaymentMethod(intent) { pi, error in
                if let error {
                    cont.resume(throwing: TapToPayError.failed(error.localizedDescription))
                } else if let pi {
                    cont.resume(returning: pi)
                } else {
                    cont.resume(throwing: TapToPayError.failed("Kartenerfassung abgebrochen."))
                }
            }
        }

        _ = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<PaymentIntent, Error>) in
            Terminal.shared.confirmPaymentIntent(collected) { pi, error in
                if let error {
                    cont.resume(throwing: TapToPayError.failed(error.localizedDescription))
                } else if let pi {
                    cont.resume(returning: pi)
                } else {
                    cont.resume(throwing: TapToPayError.failed("Zahlungsbestätigung fehlgeschlagen."))
                }
            }
        }

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            Terminal.shared.disconnectReader { _ in cont.resume() }
        }
    }

    private func discoverTapToPayReader() async throws -> Reader {
        if let cancelable = discoverCancelable {
            try? await cancelable.cancel()
        }
        let config = try TapToPayDiscoveryConfigurationBuilder()
            .setSimulated(false)
            .build()

        return try await withCheckedThrowingContinuation { cont in
            self.discoverContinuation = cont
            self.discoverCancelable = Terminal.shared.discoverReaders(config, delegate: self) { error in
                if let error {
                    self.discoverContinuation?.resume(throwing: TapToPayError.failed(error.localizedDescription))
                    self.discoverContinuation = nil
                } else if self.discoverContinuation != nil {
                    self.discoverContinuation?.resume(throwing: TapToPayError.failed("Kein Tap-to-Pay-Reader gefunden (echtes iPhone nötig)."))
                    self.discoverContinuation = nil
                }
            }
        }
    }

    // MARK: DiscoveryDelegate

    func terminal(_ terminal: Terminal, didUpdateDiscoveredReaders readers: [Reader]) {
        guard let cont = discoverContinuation, let reader = readers.first else { return }
        discoverContinuation = nil
        let cancelable = discoverCancelable
        discoverCancelable = nil
        cont.resume(returning: reader)
        if let cancelable {
            Task { try? await cancelable.cancel() }
        }
    }

    // MARK: TapToPayReaderDelegate

    func tapToPayReader(_ reader: Reader, didStartInstallingUpdate update: ReaderSoftwareUpdate, cancelable: Cancelable?) {}

    func tapToPayReader(_ reader: Reader, didReportReaderSoftwareUpdateProgress progress: Float) {}

    func tapToPayReader(_ reader: Reader, didFinishInstallingUpdate update: ReaderSoftwareUpdate?, error: Error?) {}

    func tapToPayReader(_ reader: Reader, didRequestReaderInput inputOptions: ReaderInputOptions) {}

    func tapToPayReader(_ reader: Reader, didRequestReaderDisplayMessage displayMessage: ReaderDisplayMessage) {}
}

#endif
