import Foundation

enum BookingServiceError: LocalizedError {
    case invalidBackendURL
    case invalidResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidBackendURL:
            return "Ungültige Backend-URL in TaxiConfig."
        case .invalidResponse:
            return "Ungültige Antwort vom Buchungsserver."
        case .serverError(let message):
            return message
        }
    }
}

enum BookingSubmitResult {
    case success(bookingId: String)
    case failure(String)
}

struct BookingService {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 12
        return URLSession(configuration: config)
    }()

    private struct BookingPayload: Encodable {
        let pickupDate: String
        let latitude: Double
        let longitude: Double
        let addressLine: String
        let destinationAddressLine: String?
        let paymentMethod: String
        let passengerEmail: String?
        let totalAmount: Double
        let tariffAmount: Double
        let tipAmount: Double
        let operatorSlug: String?
        let postalCode: String?
    }

    private struct BookingResponse: Decodable {
        let bookingId: String
    }

    /// Sendet an die Zentrale — bei Fehler keine Schein-Bestätigung.
    func submitBooking(summary: TaxiBookingSummary) async -> BookingSubmitResult {
        do {
            let bookingId = try await submitToServer(summary: summary)
            return .success(bookingId: bookingId)
        } catch let error as BookingServiceError {
            return .failure(error.localizedDescription)
        } catch {
            return .failure(
                "Die Zentrale ist nicht erreichbar. Bitte Internet prüfen oder die Zentrale anrufen."
            )
        }
    }

    private func submitToServer(summary: TaxiBookingSummary) async throws -> String {
        guard let url = URL(string: "\(TaxiConfig.stripeBackendURL)/api/bookings") else {
            throw BookingServiceError.invalidBackendURL
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let destination = summary.pickupLocation.destinationAddressLine.trimmingCharacters(in: .whitespacesAndNewlines)
        let postal = Self.extractPostalCode(from: summary.pickupLocation.addressLine)

        let payload = BookingPayload(
            pickupDate: formatter.string(from: summary.pickupDate),
            latitude: summary.pickupLocation.latitude,
            longitude: summary.pickupLocation.longitude,
            addressLine: summary.pickupLocation.addressLine,
            destinationAddressLine: destination.isEmpty ? nil : destination,
            paymentMethod: summary.paymentMethodLabel,
            passengerEmail: summary.passengerEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : summary.passengerEmail.trimmingCharacters(in: .whitespacesAndNewlines),
            totalAmount: summary.totalAmount,
            tariffAmount: summary.tariffAmount,
            tipAmount: summary.tipAmount,
            operatorSlug: TaxiConfig.defaultOperatorSlug.isEmpty ? nil : TaxiConfig.defaultOperatorSlug,
            postalCode: postal
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await Self.session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BookingServiceError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            if let errorBody = try? JSONDecoder().decode([String: String].self, from: data),
               let message = errorBody["error"] {
                throw BookingServiceError.serverError(message)
            }
            throw BookingServiceError.serverError(
                "Zentrale nicht erreichbar. Bitte später erneut versuchen oder anrufen."
            )
        }

        return try JSONDecoder().decode(BookingResponse.self, from: data).bookingId
    }

    private static func extractPostalCode(from address: String) -> String? {
        let pattern = #"\b(\d{5})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(address.startIndex..<address.endIndex, in: address)
        guard let match = regex.firstMatch(in: address, range: range),
              let swiftRange = Range(match.range(at: 1), in: address) else { return nil }
        return String(address[swiftRange])
    }
}
