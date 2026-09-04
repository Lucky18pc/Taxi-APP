//
//  FahrerBenachrichtigung.swift
//  Luckys Taxi Fahrer
//
// In-App + lokale Benachrichtigungen für neue offene Fahrten (MVP ohne FCM/APNs).
//

import Foundation
import UserNotifications
import AudioToolbox

/// Zentrale Stelle für Fahrt-Alerts: Permission, Sound, lokale Notification, Banner-Text.
enum FahrerBenachrichtigung {
    static let pollIntervalNanoseconds: UInt64 = 18_000_000_000 // ~18 Sekunden

    /// Einmalig Notification-Permission anfragen (idempotent).
    @MainActor
    static func requestPermissionIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        default:
            break
        }
        // Vordergrund: Banner trotzdem anzeigen (Delegate einmal setzen).
        if center.delegate == nil {
            center.delegate = ForegroundNotificationDelegate.shared
        }
    }

    /// System-Sound + lokale Notification (funktioniert auch wenn App im Vordergrund ist).
    static func announceNewRide(count: Int, preview: String?) {
        AudioServicesPlaySystemSound(1007) // SMS-artiger Alert-Ton

        let title = count == 1 ? "Neue Fahrt!" : "\(count) neue Fahrten!"
        let body = preview?.isEmpty == false
            ? (preview ?? "Offene Buchung prüfen.")
            : "Eine neue offene Buchung ist verfügbar."

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let id = "new-ride-\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// Kurztext für Banner / Notification-Body.
    static func bannerMessage(newBookings: [DriverBooking]) -> String {
        if newBookings.count == 1, let first = newBookings.first {
            return "Neue Fahrt: \(first.titleLine)"
        }
        return "\(newBookings.count) neue offene Fahrten!"
    }
}

/// Zeigt lokale Notifications auch im Vordergrund als Banner an.
final class ForegroundNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ForegroundNotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}
