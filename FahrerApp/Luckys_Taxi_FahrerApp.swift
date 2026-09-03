//
//  Luckys_Taxi_FahrerApp.swift
//  Luckys Taxi Fahrer
//

import SwiftUI
import FirebaseCore

@main
struct Luckys_Taxi_FahrerApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            LoginView()
                .preferredColorScheme(.light)
                .tint(FahrerTheme.navy)
        }
    }
}
