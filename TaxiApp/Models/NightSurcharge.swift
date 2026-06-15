import Foundation

/// Nachtzuschlag-Zeitraum (Standard 22:00–06:00) — Einstellung pro Taxi-Betrieb.
enum NightSurcharge {
    static let defaultFromHour = 22
    static let defaultToHour = 6

    /// `true`, wenn der Betrieb Nachtzuschlag nutzt und die Abholzeit im Fenster liegt.
    static func applies(
        pickupDate: Date,
        enabled: Bool,
        fromHour: Int = defaultFromHour,
        toHour: Int = defaultToHour,
        timeZone: TimeZone = .current
    ) -> Bool {
        guard enabled else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let hour = calendar.component(.hour, from: pickupDate)
        if fromHour > toHour {
            return hour >= fromHour || hour < toHour
        }
        return hour >= fromHour && hour < toHour
    }

    static let windowLabel = "22:00 – 06:00 Uhr"
}
