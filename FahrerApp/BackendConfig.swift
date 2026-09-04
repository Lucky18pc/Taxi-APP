//
//  BackendConfig.swift
//  Luckys Taxi Fahrer
//
// Enum: FahrerBackendConfig (nicht BackendConfig).
// Wenn Xcode „Invalid redeclaration of BackendConfig“ zeigt:
// alle alten BackendConfig.swift löschen, nur DIESE Datei behalten.
//

import Foundation

enum FahrerBackendConfig {
    /// Live-Backend (Render). Für lokales Backend: http://127.0.0.1:4242
    static let baseURL = "https://taxiapp-api.onrender.com"

    /// Standard-Betrieb für den Pilot (Multi-Tenant-Slug).
    static let defaultOperatorSlug = "mannheim"

    /// Muss mit Backend `DRIVER_API_KEY` übereinstimmen (Render Environment).
    static let driverApiKey = "luckys-fahrer-pilot-k7m2p9qx"
}
