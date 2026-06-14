import Foundation

struct TenantConfigResponse: Decodable {
    let companyName: String
    let centralPhone: String
    let centralPhoneDisplay: String?
    let dispatchHours: String?
    let dispatchNote: String?
}

@MainActor
final class CentralConfigStore: ObservableObject {
    @Published private(set) var remoteConfig: TenantConfigResponse?
    @Published private(set) var isLoading = false
    @Published private(set) var localPhoneOverride: String

    private static let localPhoneKey = "central_phone_local_override"

    init() {
        localPhoneOverride = UserDefaults.standard.string(forKey: Self.localPhoneKey) ?? ""
    }

    /// Nummer für tel:-Links (Ziffern, optional führendes +).
    var resolvedPhone: String {
        let local = localPhoneOverride.trimmingCharacters(in: .whitespacesAndNewlines)
        if !local.isEmpty { return Self.normalizePhone(local) }
        if let remote = remoteConfig?.centralPhone.trimmingCharacters(in: .whitespacesAndNewlines), !remote.isEmpty {
            return Self.normalizePhone(remote)
        }
        return Self.normalizePhone(TaxiConfig.centralPhoneNumber)
    }

    /// Anzeige unter „Zentrale anrufen“.
    var formattedDisplayPhone: String {
        let local = localPhoneOverride.trimmingCharacters(in: .whitespacesAndNewlines)
        if !local.isEmpty { return Self.formatForDisplay(local) }
        if let display = remoteConfig?.centralPhoneDisplay, !display.isEmpty { return display }
        if let remote = remoteConfig?.centralPhone { return Self.formatForDisplay(remote) }
        return Self.formatForDisplay(TaxiConfig.centralPhoneNumber)
    }

    var companyName: String {
        remoteConfig?.companyName ?? "TaxiApp"
    }

    var telURLString: String {
        "tel:\(resolvedPhone.replacingOccurrences(of: " ", with: ""))"
    }

    func updateLocalPhone(_ phone: String) {
        localPhoneOverride = phone
        UserDefaults.standard.set(phone, forKey: Self.localPhoneKey)
    }

    func resetLocalPhone() {
        localPhoneOverride = ""
        UserDefaults.standard.removeObject(forKey: Self.localPhoneKey)
    }

    func refreshFromBackend() async {
        isLoading = true
        defer { isLoading = false }

        guard let url = URL(string: "\(TaxiConfig.stripeBackendURL)/api/config") else { return }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return }
            remoteConfig = try JSONDecoder().decode(TenantConfigResponse.self, from: data)
        } catch {
            print("CentralConfigStore refresh failed: \(error)")
        }
    }

    private static func normalizePhone(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasPlus = trimmed.hasPrefix("+")
        let digits = trimmed.filter(\.isNumber)
        return hasPlus ? "+\(digits)" : digits
    }

    private static func formatForDisplay(_ raw: String) -> String {
        let normalized = normalizePhone(raw)
        guard normalized.hasPrefix("+49"), normalized.count >= 12 else { return raw }
        let rest = String(normalized.dropFirst(3))
        if rest.hasPrefix("30"), rest.count >= 10 {
            return "030 \(rest.dropFirst(2))"
        }
        return "+\(rest)"
    }
}
