//
//  FahrerTheme.swift
//  Luckys Taxi Fahrer
//

import SwiftUI
import UIKit

enum FahrerTheme {
    /// Taxi-Gelb wie auf luckystaxiapp.de (#FFCC00)
    static let taxiYellow = Color(red: 1, green: 0.8, blue: 0)
    /// Marine wie Fahrgast-App / Web (#0C1C34)
    static let navy = Color(red: 12 / 255, green: 28 / 255, blue: 52 / 255)
    static let card = Color.white.opacity(0.94)
    /// Gleiches Foto wie die Fahrgast-App (`TaxiApp` → Assets → app_background).
    static let backgroundImageNames = ["app_background", "fahrer_background"]

    static var backgroundImageName: String? {
        backgroundImageNames.first { UIImage(named: $0) != nil }
    }
}

/// Gleicher gelber TAXI-Hintergrund wie in der Fahrgast-App.
struct TaxiYellowBackground: View {
    var body: some View {
        ZStack {
            FahrerTheme.taxiYellow

            if let name = FahrerTheme.backgroundImageName {
                Image(name)
                    .resizable()
                    .scaledToFill()
                    .overlay(FahrerTheme.taxiYellow.opacity(0.08))
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "car.side.fill")
                        .font(.system(size: 170))
                        .foregroundStyle(FahrerTheme.navy.opacity(0.14))
                        .padding(.bottom, 56)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
