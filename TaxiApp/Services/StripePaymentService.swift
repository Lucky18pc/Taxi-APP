import UIKit
@preconcurrency import StripePaymentSheet

enum StripePaymentError: LocalizedError {
    case invalidBackendURL
    case invalidResponse
    case backendError(String)
    case noViewController

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

    @MainActor
    private func configureStripeIfNeeded() {
        if StripeAPI.defaultPublishableKey != TaxiConfig.stripePublishableKey {
            StripeAPI.defaultPublishableKey = TaxiConfig.stripePublishableKey
        }
    }

    func fetchClientSecret(
        amountInCents: Int,
        currency: String = "eur",
        receiptEmail: String? = nil
    ) async throws -> String {
        await configureStripeIfNeeded()
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
        configureStripeIfNeeded()
        guard let viewController = Self.topViewController() else {
            completion(false)
            return
        }

        var configuration = PaymentSheet.Configuration()
        configuration.merchantDisplayName = "TaxiApp"

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
