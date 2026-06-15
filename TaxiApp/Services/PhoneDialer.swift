import UIKit

enum PhoneDialer {
    private static let callingCodes: [String: String] = [
        "DE": "49", "AT": "43", "CH": "41", "FR": "33", "IT": "39",
        "ES": "34", "GB": "44", "NL": "31", "BE": "32", "LU": "352",
        "PL": "48", "CZ": "420", "SK": "421", "HU": "36", "RO": "40",
        "BG": "359", "HR": "385", "SI": "386", "GR": "30", "SE": "46",
        "NO": "47", "DK": "45", "FI": "358", "IE": "353", "PT": "351",
        "EE": "372", "LV": "371", "LT": "370", "MT": "356", "CY": "357",
    ]

    static func dialableNumber(rawPhone: String, regionCountryCode: String) -> String {
        let trimmed = rawPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let compact = trimmed
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")

        if compact.hasPrefix("+") {
            let digits = compact.dropFirst().filter(\.isNumber)
            return digits.isEmpty ? "" : "+\(digits)"
        }

        let digits = compact.filter(\.isNumber)
        guard !digits.isEmpty else { return "" }

        if digits.hasPrefix("00") {
            let intl = String(digits.dropFirst(2))
            return intl.isEmpty ? "" : "+\(intl)"
        }

        if let code = callingCodes[regionCountryCode.uppercased()] {
            var local = digits
            if local.hasPrefix("0") {
                local = String(local.dropFirst())
            }
            return "+\(code)\(local)"
        }

        return digits
    }

    /// Öffnet die Telefon-App — zuerst `tel:`, sonst `telprompt:` (Bestätigungsdialog).
    @MainActor
    static func call(rawPhone: String, regionCountryCode: String = "DE") async -> Bool {
        let dialable = dialableNumber(rawPhone: rawPhone, regionCountryCode: regionCountryCode)
        guard !dialable.isEmpty else { return false }

        if await open(scheme: "tel", number: dialable) { return true }
        return await open(scheme: "telprompt", number: dialable)
    }

    @MainActor
    private static func open(scheme: String, number: String) async -> Bool {
        guard let url = URL(string: "\(scheme):\(number)") else { return false }
        return await withCheckedContinuation { continuation in
            UIApplication.shared.open(url, options: [:]) { success in
                continuation.resume(returning: success)
            }
        }
    }
}
