import Foundation

/// Persistiert OTP-Session des Fahrgasts (Phase 4).
@MainActor
final class PassengerSessionStore: ObservableObject {
    @Published var isAuthenticated: Bool
    @Published var phone: String

    private let phoneKey = "passenger.phone"
    private let tokenKey = "passenger.otpSession"

    init() {
        let savedPhone = UserDefaults.standard.string(forKey: phoneKey) ?? ""
        let token = UserDefaults.standard.string(forKey: tokenKey) ?? ""
        phone = savedPhone
        isAuthenticated = !savedPhone.isEmpty && !token.isEmpty
    }

    func apply(phone: String, sessionToken: String) {
        self.phone = phone
        UserDefaults.standard.set(phone, forKey: phoneKey)
        UserDefaults.standard.set(sessionToken, forKey: tokenKey)
        isAuthenticated = true
    }

    func signOut() {
        phone = ""
        UserDefaults.standard.removeObject(forKey: phoneKey)
        UserDefaults.standard.removeObject(forKey: tokenKey)
        isAuthenticated = false
    }
}

enum PassengerOTPService {
    struct RequestResult {
        let phone: String
        let devCode: String?
    }

    static func requestCode(phone: String) async throws -> RequestResult {
        guard let url = URL(string: "\(TaxiConfig.stripeBackendURL)/api/auth/otp/request") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["phone": phone])
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        guard (200..<300).contains(code) else {
            throw NSError(
                domain: "PassengerOTP",
                code: code,
                userInfo: [NSLocalizedDescriptionKey: json["error"] as? String ?? "SMS fehlgeschlagen"]
            )
        }
        return RequestResult(
            phone: json["phone"] as? String ?? phone,
            devCode: json["devCode"] as? String
        )
    }

    static func verify(phone: String, code: String) async throws -> String {
        guard let url = URL(string: "\(TaxiConfig.stripeBackendURL)/api/auth/otp/verify") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "phone": phone,
            "code": code,
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        let http = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        guard (200..<300).contains(http), let token = json["sessionToken"] as? String else {
            throw NSError(
                domain: "PassengerOTP",
                code: http,
                userInfo: [NSLocalizedDescriptionKey: json["error"] as? String ?? "Code ungültig"]
            )
        }
        return token
    }
}
