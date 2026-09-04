//
//  TaxiUI.swift
//  Luckys Taxi Fahrer
//
// Nur TaxiHintergrund für FahrerHomeView.
// TaxiBild / TaxiHeroFoto liegen in LoginView.swift (keine Doppel-Typen!).
// Asset-Name: app_background
//

import SwiftUI
import UIKit

struct TaxiHintergrund: View {
    private let yellow = Color(red: 1, green: 0.8, blue: 0)

    private var backgroundImage: UIImage? {
        if let named = UIImage(named: "app_background") {
            return named
        }
        if let url = Bundle.main.url(forResource: "app_background", withExtension: "jpg"),
           let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            return image
        }
        return nil
    }

    var body: some View {
        ZStack {
            yellow.allowsHitTesting(false)
            if let image = backgroundImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .clipped()
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
