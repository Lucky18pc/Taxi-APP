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

struct BookingSubmitResult {
    let bookingId: String
    /// true = Zentrale offline, Buchung nur lokal zwischengespeichert.
    let savedLocallyOnly: Bool
}

/// Zwischenspeicher, wenn die Zentrale nicht erreichbar ist (z. B. iPhone ohne Mac-Backend).
enum LocalBookingStore {
    private static let key = "local_pending_bookings"

    static func save(summary: TaxiBookingSummary, bookingId: String) {
        var entries = loadRaw()
        let entry: [String: Any] = [
            "bookingId": bookingId,
            "addressLine": summary.pickupLocation.addressLine,
            "destinationAddressLine": summary.pickupLocation.destinationAddressLine,
            "paymentMethod": summary.paymentMethodLabel,
            "totalAmount": summary.totalAmount,
            "createdAt": ISO8601DateFormatter().string(from: Date())
        ]
        entries.insert(entry, at: 0)
        UserDefaults.standard.set(entries, forKey: key)
    }

    private static func loadRaw() -> [[String: Any]] {
        UserDefaults.standard.array(forKey: key) as? [[String: Any]] ?? []
    }
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
        let totalAmount: Double
        let tariffAmount: Double
        let tipAmount: Double
    }

    private struct BookingResponse: Decodable {
        let bookingId: String
    }

    /// Sendet an die Zentrale; bei Netzwerkfehler speichert lokal (Demo), damit „Bestätigen“ am iPhone funktioniert.
    func submitBooking(summary: TaxiBookingSummary) async -> BookingSubmitResult {
        do {
            let bookingId = try await submitToServer(summary: summary)
            return BookingSubmitResult(bookingId: bookingId, savedLocallyOnly: false)
        } catch {
            let bookingId = UUID().uuidString
            LocalBookingStore.save(summary: summary, bookingId: bookingId)
            return BookingSubmitResult(bookingId: bookingId, savedLocallyOnly: true)
        }
    }

    private func submitToServer(summary: TaxiBookingSummary) async throws -> String {
        guard let url = URL(string: "\(TaxiConfig.stripeBackendURL)/api/bookings") else {
            throw BookingServiceError.invalidBackendURL
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let destination = summary.pickupLocation.destinationAddressLine.trimmingCharacters(in: .whitespacesAndNewlines)

        let payload = BookingPayload(
            pickupDate: formatter.string(from: summary.pickupDate),
            latitude: summary.pickupLocation.latitude,
            longitude: summary.pickupLocation.longitude,
            addressLine: summary.pickupLocation.addressLine,
            destinationAddressLine: destination.isEmpty ? nil : destination,
            paymentMethod: summary.paymentMethodLabel,
            totalAmount: summary.totalAmount,
            tariffAmount: summary.tariffAmount,
            tipAmount: summary.tipAmount
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
                "Zentrale nicht erreichbar (Port 4242). Backend starten: cd backend && npm start"
            )
        }

        return try JSONDecoder().decode(BookingResponse.self, from: data).bookingId
    }
}
