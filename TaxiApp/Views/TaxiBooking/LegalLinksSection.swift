import SwiftUI

enum LegalLink: String, CaseIterable, Identifiable {
    case impressum
    case datenschutz
    case agb
    case widerruf
    case kuendigung

    var id: String { rawValue }

    var title: String {
        switch self {
        case .impressum: return "Impressum"
        case .datenschutz: return "Datenschutz"
        case .agb: return "AGB"
        case .widerruf: return "Widerruf"
        case .kuendigung: return "Vertrag kündigen"
        }
    }

    var path: String { "\(rawValue).html" }

    var url: URL? {
        URL(string: "\(TaxiConfig.stripeBackendURL)/\(path)")
    }
}

/// Links zu Impressum, Datenschutz, AGB usw. auf dem Cloud-Backend.
struct LegalLinksSection: View {
    var links: [LegalLink] = LegalLink.allCases
    var onNavyBackground: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rechtliches")
                .font(.caption.weight(.semibold))
                .foregroundStyle(onNavyBackground ? Color.white : Brand.secondary)

            ForEach(links) { link in
                if let url = link.url {
                    Link(destination: url) {
                        HStack(spacing: 8) {
                            Text(link.title)
                                .font(.subheadline.weight(.medium))
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(onNavyBackground ? .white : Brand.primary)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(onNavyBackground ? Color.white.opacity(0.12) : Brand.card)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(
                                    onNavyBackground ? Color.white.opacity(0.35) : Brand.primary.opacity(0.15),
                                    lineWidth: 1
                                )
                        }
                    }
                }
            }
        }
    }
}

/// Kurzhinweis vor Buchungsabschluss (AGB + Datenschutz).
struct BookingLegalFootnote: View {
    var confirmActionLabel: String = "Taxi bestellen"

    var body: some View {
        VStack(spacing: 4) {
            Text("Mit „\(confirmActionLabel)“ bestätigen Sie Ihre Fahrtanfrage.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                if let agb = LegalLink.agb.url {
                    Link("AGB", destination: agb)
                        .font(.caption2.weight(.semibold))
                }
                if let privacy = LegalLink.datenschutz.url {
                    Link("Datenschutz", destination: privacy)
                        .font(.caption2.weight(.semibold))
                }
            }
            .foregroundStyle(.white.opacity(0.95))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
    }
}

#Preview {
    LegalLinksSection()
        .padding()
        .background(Brand.background)
}
