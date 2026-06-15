import Foundation

struct TenantConfigResponse: Decodable {
    let companyName: String
    let centralPhone: String
    let centralPhoneDisplay: String?
    let dispatchHours: String?
    let dispatchNote: String?
    let country: String?
    let timeZone: String?
    let currency: String?
    let nightSurchargeEnabled: Bool?
    let nightSurchargeFromHour: Int?
    let nightSurchargeToHour: Int?
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

    var regionCountryCode: String {
        let code = remoteConfig?.country?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
        return code.count == 2 ? code : "DE"
    }

    var regionTimeZone: TimeZone {
        if let id = remoteConfig?.timeZone?.trimmingCharacters(in: .whitespacesAndNewlines),
           let timeZone = TimeZone(identifier: id) {
            return timeZone
        }
        return TimeZone(identifier: "Europe/Berlin") ?? .current
    }

    /// ISO-4217 für Apple Pay (z. B. EUR).
    var paymentCurrencyCode: String {
        let code = (remoteConfig?.currency ?? "eur").uppercased()
        return code.count == 3 ? code : "EUR"
    }

    /// Kleinbuchstaben für Stripe (z. B. eur).
    var stripeCurrencyCode: String {
        (remoteConfig?.currency ?? "eur").lowercased()
    }

    var nightSurchargeEnabled: Bool {
        remoteConfig?.nightSurchargeEnabled ?? false
    }

    var nightSurchargeFromHour: Int {
        remoteConfig?.nightSurchargeFromHour ?? NightSurcharge.defaultFromHour
    }

    var nightSurchargeToHour: Int {
        remoteConfig?.nightSurchargeToHour ?? NightSurcharge.defaultToHour
    }

    func nightSurchargeApplies(for pickupDate: Date) -> Bool {
        NightSurcharge.applies(
            pickupDate: pickupDate,
            enabled: nightSurchargeEnabled,
            fromHour: nightSurchargeFromHour,
            toHour: nightSurchargeToHour,
            timeZone: regionTimeZone
        )
    }

    var telURLString: String {
        let dialable = dialablePhoneForCall
        guard !dialable.isEmpty else { return "" }
        return "tel:\(dialable)"
    }

    /// Nummer, die beim Anruf wirklich gewählt wird (E.164).
    var dialablePhoneForCall: String {
        PhoneDialer.dialableNumber(
            rawPhone: resolvedPhone,
            regionCountryCode: regionCountryCode
        )
    }

    var usesLocalPhoneOverride: Bool {
        !localPhoneOverride.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Startet Anruf zur Zentrale.
    func callCentral() async -> Bool {
        await PhoneDialer.call(rawPhone: resolvedPhone, regionCountryCode: regionCountryCode)
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
        if normalized.hasPrefix("+") {
            return normalized
        }
        return raw
    }
}
