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
    static let backgroundImageName = "fahrer_background"
}

/// Gelber Taxi-Hintergrund. Nutzt das Asset `fahrer_background`, sonst reines Taxi-Gelb.
struct TaxiYellowBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 1, green: 0.88, blue: 0.28),
                    FahrerTheme.taxiYellow,
                    Color(red: 0.93, green: 0.70, blue: 0.04),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            if UIImage(named: FahrerTheme.backgroundImageName) != nil {
                Image(FahrerTheme.backgroundImageName)
                    .resizable()
                    .scaledToFill()
                    .overlay(FahrerTheme.taxiYellow.opacity(0.18))
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
