//
//  TaxiUI.swift
//  Luckys Taxi Fahrer
//
// NEU — TaxiBild / TaxiHeroFoto / TaxiHintergrund.
// In Xcode als EIGENE Datei anlegen (nicht in LoginView lassen!).
// Asset-Name: app_background
//

import SwiftUI
import UIKit

enum TaxiBild {
    static var uiImage: UIImage? {
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
}

struct TaxiHeroFoto: View {
    private let navy = Color(red: 12 / 255, green: 28 / 255, blue: 52 / 255)
    private let yellow = Color(red: 1, green: 0.8, blue: 0)

    var body: some View {
        ZStack {
            yellow
            if let image = TaxiBild.uiImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .clipped()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "car.side.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(navy)
                    Text("TAXI")
                        .font(.system(size: 48, weight: .black))
                        .foregroundStyle(navy)
                    Text("Asset „app_background“ in Xcode Assets einfügen")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(navy)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
    }
}

struct TaxiHintergrund: View {
    private let yellow = Color(red: 1, green: 0.8, blue: 0)

    var body: some View {
        ZStack {
            yellow.allowsHitTesting(false)
            if let image = TaxiBild.uiImage {
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
