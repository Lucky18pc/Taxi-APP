import SwiftUI
import UIKit
import MapKit

enum Brand {
    /// Editorial / Premium-Retail: tiefes Navy, kühles Slate — ohne Orange-/Pink-Kindergarten-Akzente.
    static let primary = Color(red: 0.11, green: 0.19, blue: 0.31)
    static let secondary = Color(red: 0.22, green: 0.30, blue: 0.38)
    /// Web-Marketing-Akzent (styles.css --accent), sparsam in der App.
    static let accent = Color(red: 0.58, green: 0.38, blue: 0.88)
    static let accentDark = Color(red: 0.38, green: 0.18, blue: 0.72)
    static let background = Color(red: 1.0, green: 0.8, blue: 0.0) // #ffcc00
    static let card = Color(red: 1.0, green: 0.973, blue: 0.8) // #fff8cc
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

    /// Lesbare Eingabefelder im Buchungsflow — dunkler Text auf hellem Grund (auch bei Dark Mode).
    func bookingFormTextField() -> some View {
        modifier(BookingFormTextFieldModifier())
    }

    /// Dezenter Schimmer entlang des Kreisrands — z. B. Profilbild.
    func circleRingShimmer(
        active: Bool = true,
        lineWidth: CGFloat = 2.5,
        intensity: CGFloat = 0.55
    ) -> some View {
        modifier(
            CircularRingShimmerModifier(
                active: active,
                lineWidth: lineWidth,
                intensity: intensity
            )
        )
    }

    /// Marineblauer Diamant-Schimmer (schräg) — z. B. Firmenlogo im Header.
    func diamondShimmer(
        active: Bool = true,
        cornerRadius: CGFloat = 10,
        intensity: CGFloat = 1.0
    ) -> some View {
        modifier(
            DiamondShimmerModifier(
                active: active,
                cornerRadius: cornerRadius,
                intensity: intensity
            )
        )
    }
}

private struct DiamondShimmerModifier: ViewModifier {
    var active: Bool
    var cornerRadius: CGFloat
    var intensity: CGFloat

    private static let marineDeep = Color(red: 0.05, green: 0.14, blue: 0.28)
    private static let marineMid = Color(red: 0.09, green: 0.22, blue: 0.42)
    private static let marineBright = Color(red: 0.14, green: 0.34, blue: 0.58)
    private static let diagonalAngle: Double = -38

    func body(content: Content) -> some View {
        content
            .overlay {
                if active {
                    GeometryReader { geometry in
                        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                            let t = timeline.date.timeIntervalSinceReferenceDate
                            let period: Double = 2.4
                            let progress = (t.truncatingRemainder(dividingBy: period)) / period
                            let i = min(1.6, max(0.35, intensity))
                            let w: CGFloat = geometry.size.width
                            let h: CGFloat = geometry.size.height

                            let beamWidth: CGFloat = max(w, h) * 0.38
                            let beamHeight: CGFloat = max(w, h) * 2.4
                            let travelX: CGFloat = w + beamWidth * 1.4
                            let travelY: CGFloat = h * 0.75
                            let x: CGFloat = CGFloat(progress) * travelX - beamWidth * 0.65
                            let y: CGFloat = CGFloat(progress) * travelY - travelY * 0.5

                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            .clear,
                                            Self.marineDeep.opacity(0.45 * i),
                                            Self.marineMid.opacity(0.88 * i),
                                            Self.marineBright.opacity(1.0 * i),
                                            Self.marineMid.opacity(0.88 * i),
                                            Self.marineDeep.opacity(0.45 * i),
                                            .clear
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: beamWidth, height: beamHeight)
                                .rotationEffect(.degrees(Self.diagonalAngle))
                                .offset(
                                    x: x - w * 0.05,
                                    y: y + (h - beamHeight) / 2.0
                                )
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .allowsHitTesting(false)
                }
            }
    }
}

private struct BookingFormTextFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.body.weight(.medium))
            .foregroundStyle(Brand.primary)
            .tint(Brand.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(Color(red: 0.97, green: 0.97, blue: 0.98))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Brand.primary.opacity(0.22), lineWidth: 1)
            }
    }
}

private struct CircularRingShimmerModifier: ViewModifier {
    var active: Bool
    var lineWidth: CGFloat
    var intensity: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay {
                if active {
                    TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        let rotation = (t.truncatingRemainder(dividingBy: 2.8) / 2.8) * 360

                        Circle()
                            .stroke(
                                AngularGradient(
                                    colors: [
                                        .white.opacity(0.04 * intensity),
                                        .white.opacity(0.22 * intensity),
                                        .white.opacity(0.62 * intensity),
                                        .white.opacity(0.22 * intensity),
                                        .white.opacity(0.04 * intensity),
                                    ],
                                    center: .center
                                ),
                                lineWidth: lineWidth
                            )
                            .rotationEffect(.degrees(rotation))
                            .allowsHitTesting(false)
                    }
                }
            }
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
    /// Etwas unter 1.0 — zeigt mehr vom Gesicht (weniger starker Zuschnitt).
    var faceZoom: CGFloat = 0.9

    var body: some View {
        Group {
            if let profileImage {
                Image(uiImage: profileImage)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(faceZoom)
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
            .clipShape(RoundedRectangle(cornerRadius: Brand.cornerRadius))
    }
}

private struct BrandCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(Brand.card)
            .clipShape(RoundedRectangle(cornerRadius: Brand.cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }
}

extension View {
    /// Helle Karte mit einheitlichem Radius und Schatten.
    func brandCard() -> some View {
        modifier(BrandCardModifier())
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

extension TaxiConfig {
    static func pickupMapCamera(center: CLLocationCoordinate2D) -> MapCameraPosition {
        .camera(
            MapCamera(
                centerCoordinate: center,
                distance: pickupMapCameraDistance,
                heading: 0,
                pitch: 0
            )
        )
    }

    static func cityMapCamera(center: CLLocationCoordinate2D) -> MapCameraPosition {
        .camera(
            MapCamera(
                centerCoordinate: center,
                distance: cityMapCameraDistance,
                heading: 0,
                pitch: 0
            )
        )
    }
}

extension View {
    /// Deutsche Beschriftung, europäischer Kartenkontext im Buchungsflow.
    func europeanBookingMap() -> some View {
        environment(\.locale, TaxiConfig.mapLocale)
    }
}
