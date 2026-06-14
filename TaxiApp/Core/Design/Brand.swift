import SwiftUI
import UIKit

enum Brand {
    /// Editorial / Premium-Retail: tiefes Navy, kühles Slate — ohne Orange-/Pink-Kindergarten-Akzente.
    static let primary = Color(red: 0.11, green: 0.19, blue: 0.31)
    static let secondary = Color(red: 0.22, green: 0.30, blue: 0.38)
    static let background = Color(red: 0.96, green: 0.96, blue: 0.97)
    static let card = Color.white
    /// Produktkacheln & Warenkorb-Thumbnails (warmes Greige statt „schwarzes Loch“).
    static let productThumbFill = Color(red: 0.91, green: 0.90, blue: 0.88)
    static let productThumbStroke = Color(red: 0.78, green: 0.76, blue: 0.73)
    static let cornerRadius: CGFloat = 14
}

// MARK: - Schimmer / Blitzerstreifen (CTAs, Karten, Leisten)

enum ShimmerTone {
    /// Weiße Buttons, helle Flächen.
    case onLight
    /// Navy, farbige Buttons, Gesamt-Balken.
    case onDark
    /// Halbtransparente Buttons (z. B. Zurück).
    case onGlass
}

private struct LightShimmerModifier: ViewModifier {
    var active: Bool
    var cornerRadius: CGFloat
    var tone: ShimmerTone
    var intensity: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay {
                if active {
                    GeometryReader { geometry in
                        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                            let t = timeline.date.timeIntervalSinceReferenceDate
                            let mainPeriod: Double = 2.2
                            let flashPeriod: Double = 4.4
                            let mainProgress = (t.truncatingRemainder(dividingBy: mainPeriod)) / mainPeriod
                            let flashProgress = (t.truncatingRemainder(dividingBy: flashPeriod)) / flashPeriod

                            let mainBand = geometry.size.width * 0.52
                            let flashBand = geometry.size.width * 0.22
                            let mainTravel = geometry.size.width + mainBand
                            let flashTravel = geometry.size.width + flashBand
                            let mainX = mainProgress * mainTravel - mainBand * 0.35
                            let flashX = flashProgress * flashTravel - flashBand * 0.35

                            let (soft, mid, peak, flashPeak) = gradientStops(for: tone, intensity: intensity)

                            ZStack {
                                LinearGradient(
                                    colors: [.clear, soft, mid, soft, .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: mainBand, height: geometry.size.height)
                                .offset(x: mainX)

                                LinearGradient(
                                    colors: [.clear, mid, flashPeak, mid, .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: flashBand, height: geometry.size.height)
                                .offset(x: flashX)
                                .blur(radius: 0.5)
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .allowsHitTesting(false)
                }
            }
    }

    private func gradientStops(for tone: ShimmerTone, intensity: CGFloat) -> (Color, Color, Color, Color) {
        let i = min(1.4, max(0.2, intensity))
        switch tone {
        case .onLight:
            return (
                .white.opacity(0.35 * i),
                .white.opacity(0.65 * i),
                .white.opacity(0.85 * i),
                .white.opacity(1.0 * i)
            )
        case .onDark:
            return (
                .white.opacity(0.2 * i),
                .white.opacity(0.45 * i),
                .white.opacity(0.7 * i),
                .white.opacity(0.95 * i)
            )
        case .onGlass:
            return (
                .white.opacity(0.25 * i),
                .white.opacity(0.5 * i),
                .white.opacity(0.75 * i),
                .white.opacity(0.9 * i)
            )
        }
    }
}

extension View {
    /// Licht-Schimmer mit Blitzerstreifen — Buttons, Balken, Karten.
    func lightShimmer(
        active: Bool = true,
        cornerRadius: CGFloat = 12,
        tone: ShimmerTone = .onLight,
        intensity: CGFloat = 1.0
    ) -> some View {
        modifier(
            LightShimmerModifier(
                active: active,
                cornerRadius: cornerRadius,
                tone: tone,
                intensity: intensity
            )
        )
    }
}

/// Kompakte Zurück/Weiter-Leiste für iPhone (Buchungsflow).
struct BookingBottomBar: View {
    var backTitle: String = "Zurück"
    var forwardTitle: String
    var forwardDisabled: Bool = false
    let onBack: () -> Void
    let onForward: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onBack) {
                Text(backTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.white.opacity(0.16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.55), lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .lightShimmer(active: true, cornerRadius: 12, tone: .onGlass, intensity: 1.15)
            }
            .buttonStyle(.plain)

            Button(action: onForward) {
                Text(forwardTitle)
                    .font(.headline.weight(.bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(forwardDisabled ? Brand.primary.opacity(0.35) : Brand.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white, lineWidth: forwardDisabled ? 0 : 2)
                    }
                    .shadow(color: .black.opacity(forwardDisabled ? 0.06 : 0.22), radius: 5, y: 2)
                    .lightShimmer(active: !forwardDisabled, cornerRadius: 12, tone: .onLight, intensity: 1.25)
            }
            .buttonStyle(.plain)
            .disabled(forwardDisabled)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background {
            Brand.primary
                .lightShimmer(active: true, cornerRadius: 0, tone: .onDark, intensity: 1.1)
                .shadow(color: .black.opacity(0.25), radius: 8, y: -2)
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

enum BookingScreenStyle {
    static let titleFont: Font = .system(size: 22, weight: .bold, design: .rounded)
    static let subtitleFont: Font = .caption.weight(.bold)
}

enum BookingBackgroundOverlayStyle {
    /// Gleichmäßiges Abdunkeln — Folgeseiten im Buchungsflow.
    case standard
    /// Leichtes Gesamt-Overlay + Verlauf unten — Startseite, Foto oben klar sichtbar.
    case pickup
}

/// Einheitlicher Foto-Hintergrund — Inhalt bleibt im Bildschirm, Hintergrund füllt nur den sichtbaren Bereich.
struct BookingBackgroundView: View {
    var imageName: String = TaxiConfig.backgroundImageName
    var overlayStyle: BookingBackgroundOverlayStyle = .standard
    var overlayOpacity: Double = 0.32
    var imageOffsetY: CGFloat = 0
    var imageScale: CGFloat = 1.0
    var imageAlignment: Alignment = .center

    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFill()
            .scaleEffect(imageScale)
            .offset(y: imageOffsetY)
            .frame(
                minWidth: 0, maxWidth: .infinity,
                minHeight: 0, maxHeight: .infinity,
                alignment: imageAlignment
            )
            .clipped()
            .overlay { overlayLayer }
            .ignoresSafeArea()
    }

    @ViewBuilder
    private var overlayLayer: some View {
        switch overlayStyle {
        case .standard:
            Color.black.opacity(overlayOpacity)
        case .pickup:
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                LinearGradient(
                    colors: [.clear, .black.opacity(0.38)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 100)
            }
            .allowsHitTesting(false)
        }
    }
}

extension View {
    /// Legt Foto-Hintergrund unter den Inhalt; Inhalt wird auf Bildschirmgröße begrenzt.
    func bookingFlowBackground(
        imageOffsetY: CGFloat = 0,
        imageScale: CGFloat = 1.0,
        overlayOpacity: Double = 0.32,
        overlayStyle: BookingBackgroundOverlayStyle = .standard,
        imageAlignment: Alignment = .center
    ) -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background {
                BookingBackgroundView(
                    overlayStyle: overlayStyle,
                    overlayOpacity: overlayOpacity,
                    imageOffsetY: imageOffsetY,
                    imageScale: imageScale,
                    imageAlignment: imageAlignment
                )
            }
            .clipped()
    }
}

struct DriverAvatarView: View {
    var profileImage: UIImage?
    var fallbackImageName: String
    var size: CGFloat = 44
    var showBorder: Bool = false

    var body: some View {
        Group {
            if let profileImage {
                Image(uiImage: profileImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(fallbackImageName)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            if showBorder {
                Circle()
                    .stroke(Color.white.opacity(0.85), lineWidth: 2)
            }
        }
    }
}

struct BrandButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Brand.primary.opacity(configuration.isPressed ? 0.75 : 1.0))
            .foregroundStyle(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#if canImport(UIKit)
import UIKit

extension Brand {
    /// Gleiche RGB-Werte wie `Brand.primary` — für `UITabBarAppearance` / `UISearchBar` usw.
    static var uiPrimary: UIColor {
        UIColor(red: 0.11, green: 0.19, blue: 0.31, alpha: 1.0)
    }

    /// Tab-Badge, Tab-Tint und Suchfeld: sonst oft weiterhin Orange/Systemrot trotz `.tint(Brand.primary)`.
    static func configureGlobalUIKitAppearance() {
        UITabBar.appearance().tintColor = uiPrimary

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()

        let item = UITabBarItemAppearance()
        item.normal.iconColor = UIColor.secondaryLabel
        item.selected.iconColor = uiPrimary
        if #available(iOS 15.0, *) {
            item.normal.badgeBackgroundColor = uiPrimary
            item.selected.badgeBackgroundColor = uiPrimary
            item.normal.badgeTextAttributes = [.foregroundColor: UIColor.white]
            item.selected.badgeTextAttributes = [.foregroundColor: UIColor.white]
        }
        tabAppearance.stackedLayoutAppearance = item
        tabAppearance.inlineLayoutAppearance = item
        tabAppearance.compactInlineLayoutAppearance = item

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        UISearchBar.appearance().tintColor = uiPrimary
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).tintColor = uiPrimary
    }
}
#endif
