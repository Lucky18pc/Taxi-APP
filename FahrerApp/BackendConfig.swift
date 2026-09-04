//
//  BackendConfig.swift
//  Luckys Taxi Fahrer
//

import Foundation

enum BackendConfig {
    /// Live-Backend (Render). Für lokales Backend: http://127.0.0.1:4242
    static let baseURL = "https://taxiapp-api.onrender.com"

    /// Standard-Betrieb für den Pilot (Multi-Tenant-Slug).
    static let defaultOperatorSlug = "mannheim"

    /// Muss mit Backend `DRIVER_API_KEY` übereinstimmen (Render Environment).
    /// Default = Pilot-Key aus server.js — für Produktion eigenen Key setzen.
    static let driverApiKey = "luckys-fahrer-pilot-k7m2p9qx"
}
