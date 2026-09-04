//
//  FahrerBackendConfig.swift
//  Luckys Taxi Fahrer
//
// EINZIGE Config-Datei. Alte BackendConfig.swift in Xcode LÖSCHEN!
//

import Foundation

enum FahrerBackendConfig {
    /// Live-Backend (Render). Lokal: http://127.0.0.1:4242
    static let baseURL = "https://taxiapp-api.onrender.com"

    /// Multi-Tenant-Slug (Pilot).
    static let defaultOperatorSlug = "mannheim"

    /// Muss mit Backend DRIVER_API_KEY übereinstimmen.
    static let driverApiKey = "luckys-fahrer-pilot-k7m2p9qx"
}
