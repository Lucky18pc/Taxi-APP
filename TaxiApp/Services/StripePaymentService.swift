import UIKit
@preconcurrency import StripePaymentSheet

enum StripePaymentError: LocalizedError {
    case invalidBackendURL
    case invalidResponse
    case backendError(String)
    case noViewController
    case paymentsDisabled

    var errorDescription: String? {
        switch self {
        case .invalidBackendURL:
            return "Ungültige Stripe-Backend-URL in TaxiConfig."
        case .invalidResponse:
            return "Ungültige Antwort vom Zahlungsserver."
        case .backendError(let message):
            return message
        case .noViewController:
            return "Zahlungsdialog konnte nicht geöffnet werden."
        case .paymentsDisabled:
            return "Kartenzahlung ist auf dem Server noch nicht aktiv (Stripe-Keys fehlen)."
        }
    }
}

struct StripePaymentService {
    private struct PaymentIntentRequest: Encodable {
        let amount: Int
        let currency: String
        let receiptEmail: String?

        enum CodingKeys: String, CodingKey {
            case amount
            case currency
            case receiptEmail
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(amount, forKey: .amount)
            try container.encode(currency, forKey: .currency)
            if let receiptEmail, !receiptEmail.isEmpty {
                try container.encode(receiptEmail, forKey: .receiptEmail)
            }
        }
    }

    private struct PaymentIntentResponse: Decodable {
        let clientSecret: String
    }

    private struct StripeConfigResponse: Decodable {
        let paymentsEnabled: Bool
        let publishableKey: String?
    }

    @MainActor
    private func configureStripeIfNeeded() async throws {
        let key = try await resolvePublishableKey()
        if StripeAPI.defaultPublishableKey != key {
            StripeAPI.defaultPublishableKey = key
        }
    }

    /// Nimmt einen echten Key aus TaxiConfig, sonst denselben Key wie `pay.html` vom Backend.
    private func resolvePublishableKey() async throws -> String {
        let configured = TaxiConfig.stripePublishableKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !configured.isEmpty, !configured.contains("PLACEHOLDER"), configured.hasPrefix("pk_") {
            return configured
        }

        guard let url = URL(string: "\(TaxiConfig.stripeBackendURL)/api/stripe/config") else {
            throw StripePaymentError.invalidBackendURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw StripePaymentError.invalidResponse
        }

        let cfg = try JSONDecoder().decode(StripeConfigResponse.self, from: data)
        guard cfg.paymentsEnabled, let key = cfg.publishableKey, key.hasPrefix("pk_") else {
            throw StripePaymentError.paymentsDisabled
        }
        return key
    }

    func fetchClientSecret(
        amountInCents: Int,
        currency: String = "eur",
        receiptEmail: String? = nil
    ) async throws -> String {
        try await configureStripeIfNeeded()
        guard let url = URL(string: "\(TaxiConfig.stripeBackendURL)/create-payment-intent") else {
            throw StripePaymentError.invalidBackendURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            PaymentIntentRequest(amount: amountInCents, currency: currency, receiptEmail: receiptEmail)
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw StripePaymentError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            if let errorBody = try? JSONDecoder().decode([String: String].self, from: data),
               let message = errorBody["error"] {
                throw StripePaymentError.backendError(message)
            }
            throw StripePaymentError.backendError(
                "Backend nicht erreichbar. Bitte starten: cd backend && npm install && npm start"
            )
        }

        return try JSONDecoder().decode(PaymentIntentResponse.self, from: data).clientSecret
    }

    @MainActor
    func presentPaymentSheet(clientSecret: String, completion: @escaping (Bool) -> Void) {
        Task {
            do {
                try await configureStripeIfNeeded()
            } catch {
                completion(false)
                return
            }

            guard let viewController = Self.topViewController() else {
                completion(false)
                return
            }

            var configuration = PaymentSheet.Configuration()
            configuration.merchantDisplayName = "Luckys Taxi"

            let paymentSheet = PaymentSheet(
                paymentIntentClientSecret: clientSecret,
                configuration: configuration
            )

            paymentSheet.present(from: viewController) { result in
                switch result {
                case .completed:
                    completion(true)
                case .canceled, .failed:
                    completion(false)
                }
            }
        }
    }

    @MainActor
    private static func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let root = base ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController

        if let nav = root as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = root as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(base: selected)
        }
        if let presented = root?.presentedViewController {
            return topViewController(base: presented)
        }
        return root
    }
}
