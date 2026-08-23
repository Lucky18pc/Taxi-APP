import SwiftUI
import UIKit

/// Lucky's Taxi Logo mit marineblauem, schrägem Diamant-Schimmer (iPhone-Prototyp).
struct BrandLogoView: View {
    var imageName: String
    var size: CGFloat
    var cornerRadius: CGFloat
    var shimmerIntensity: CGFloat
    var showLabel: Bool

    init(
        imageName: String = TaxiConfig.logoImageName ?? "luckys_taxi_logo",
        size: CGFloat = 132,
        cornerRadius: CGFloat = 20,
        shimmerIntensity: CGFloat = 1.55,
        showLabel: Bool = true
    ) {
        self.imageName = imageName
        self.size = size
        self.cornerRadius = cornerRadius
        self.shimmerIntensity = shimmerIntensity
        self.showLabel = showLabel
    }

    var body: some View {
        VStack(spacing: 10) {
            Group {
                if UIImage(named: imageName) != nil {
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                        }
                        .diamondShimmer(
                            active: true,
                            cornerRadius: cornerRadius,
                            intensity: shimmerIntensity
                        )
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.yellow)
                        .frame(width: size, height: size)
                        .overlay {
                            Image(systemName: "car.fill")
                                .font(.system(size: size * 0.35))
                                .foregroundStyle(Brand.primary)
                        }
                        .diamondShimmer(
                            active: true,
                            cornerRadius: cornerRadius,
                            intensity: shimmerIntensity
                        )
                }
            }
            .shadow(color: .black.opacity(0.28), radius: 14, y: 6)

            if showLabel {
                Text("Lucky's Taxi App")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.45), radius: 4, y: 2)
            }
        }
    }
}

/// Header mit Uhrzeit und optionalem Firmenlogo/Name.
struct TaxiCompanyHeaderView: View {
    /// Anzeigename des Taxi-Betriebs.
    var companyName: String = ""
    /// Asset-Name für das Logo in Assets.xcassets.
    var logoImageName: String? = nil
    /// Uhrzeit anzeigen (oben rechts, im Stil 9:41).
    var showTime: Bool = true
    /// Halbtransparenter Hintergrund, damit ein Hintergrundbild durchscheint.
    var isTransparent: Bool = false

    private var showsBranding: Bool {
        if let name = logoImageName, UIImage(named: name) != nil {
            return true
        }
        return !companyName.isEmpty
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            if showTime {
                HStack {
                    Spacer()
                    Text(Self.timeFormatter.string(from: Date()))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(isTransparent && !showsBranding ? .white : .primary)
                        .shadow(
                            color: isTransparent && !showsBranding ? .black.opacity(0.45) : .clear,
                            radius: 2,
                            y: 1
                        )
                        .padding(.trailing, 8)
                        .padding(.top, 6)
                }
                .frame(height: 24)
            }

            if showsBranding {
                HStack(spacing: 12) {
                    if let name = logoImageName, UIImage(named: name) != nil {
                        BrandLogoView(
                            imageName: name,
                            size: 44,
                            cornerRadius: 10,
                            shimmerIntensity: 1.5,
                            showLabel: false
                        )
                    }
                    if !companyName.isEmpty {
                        Text(companyName)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(isTransparent ? Color.white.opacity(0.85) : Color(.systemBackground))
            }
        }
    }
}

#Preview {
    VStack {
        BrandLogoView()
        TaxiCompanyHeaderView(logoImageName: TaxiConfig.logoImageName, showTime: true)
        Spacer()
    }
    .bookingFlowBackground(overlayStyle: .pickup)
}
