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
}
