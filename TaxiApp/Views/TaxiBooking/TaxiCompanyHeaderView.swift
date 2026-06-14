import SwiftUI

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
                        Image(name)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
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
        TaxiCompanyHeaderView(showTime: true)
        Spacer()
    }
}
