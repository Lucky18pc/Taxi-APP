import SwiftUI

// ==========================================
// 1. SYMBOLE — edel, kein Comic-Sticker-Look
// ==========================================
enum CapriSymbolType: String, CaseIterable, Identifiable {
    case sunglasses, deckchair, cocktail, sailboat, yacht
    case isabella, gianluca, capriSun, beachJoker

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sunglasses: return "Brille"
        case .deckchair: return "Liege"
        case .cocktail: return "Cocktail"
        case .sailboat: return "Segel"
        case .yacht: return "Yacht"
        case .isabella: return "Isabella"
        case .gianluca: return "Gianluca"
        case .capriSun: return "Sonne"
        case .beachJoker: return "Joker"
        }
    }

    /// SF Symbol — wirkt hochwertiger als Emoji-Comic
    var systemImage: String {
        switch self {
        case .sunglasses: return "sunglasses"
        case .deckchair: return "beach.umbrella"
        case .cocktail: return "wineglass.fill"
        case .sailboat: return "sailboat.fill"
        case .yacht: return "ferry.fill"
        case .isabella: return "crown.fill"
        case .gianluca: return "person.fill"
        case .capriSun: return "sun.max.fill"
        case .beachJoker: return "sparkles"
        }
    }

    var accent: Color {
        switch self {
        case .gianluca: return Color(red: 0.95, green: 0.78, blue: 0.28)
        case .isabella: return Color(red: 0.85, green: 0.55, blue: 0.75)
        case .yacht: return Color(red: 0.35, green: 0.65, blue: 0.95)
        case .beachJoker: return Color(red: 0.95, green: 0.55, blue: 0.2)
        case .capriSun: return Color(red: 1.0, green: 0.75, blue: 0.2)
        default: return Color(red: 0.75, green: 0.82, blue: 0.88)
        }
    }
}

// ==========================================
// 2. VIEWMODEL
// ==========================================
@Observable
final class CapriGameViewModel {
    var balance: Decimal = 150
    var stake: Decimal = 1

    enum State { case idle, spinning, won, riskLadder }

    var gameState: State = .idle
    var lastWin: Decimal = 0
    var activeMessage: String = "Capri Island — Walzen bereit"

    var grid: [[CapriSymbolType]] = [
        [.sunglasses, .isabella, .cocktail],
        [.sailboat, .gianluca, .yacht],
        [.deckchair, .beachJoker, .capriSun]
    ]

    var spinGeneration: Int = 0
    var reelSpinning: [Bool] = [false, false, false]

    let ladderSteps: [Decimal] = [0, 0.20, 0.50, 1, 2.50, 5, 10, 25, 50, 100]
    var currentLadderIndex: Int = 3
    var isPromenadeBlinking: Bool = false
    private var blinkTimer: Timer?

    /// Stop-Zeiten der drei Trommeln (links → rechts)
    static let stopDelays: [Double] = [2.5, 3.3, 4.1]

    deinit { blinkTimer?.invalidate() }

    func spin() {
        guard gameState != .spinning else { return }
        guard balance >= stake else {
            activeMessage = "Nicht genügend Guthaben"
            return
        }

        balance -= stake
        lastWin = 0
        gameState = .spinning
        activeMessage = "Walzen laufen…"

        let all = CapriSymbolType.allCases
        grid = (0..<3).map { _ in (0..<3).map { _ in all.randomElement()! } }

        reelSpinning = [true, true, true]
        spinGeneration += 1

        for col in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.stopDelays[col]) { [weak self] in
                guard let self, self.gameState == .spinning else { return }
                self.reelSpinning[col] = false
                if col == 2 { self.finishSpinEvaluation() }
            }
        }
    }

    private func finishSpinEvaluation() {
        let hasGianluca = grid.contains { $0.contains(.gianluca) }
        let hasJoker = grid.contains { $0.contains(.beachJoker) }

        if Int.random(in: 0..<100) < 45 || hasGianluca {
            lastWin = stake * Decimal(Int.random(in: 5...20)) * (hasGianluca ? 2 : 1)
            balance += lastWin
            gameState = .won
            let win = lastWin.formatted(.currency(code: "EUR"))
            activeMessage = hasGianluca ? "Gianluca — \(win)" : (hasJoker ? "Joker — \(win)" : "Gewinn \(win)")
        } else {
            lastWin = 0
            gameState = .idle
            activeMessage = "Kein Treffer"
        }
    }

    func keepWinAndContinue() {
        lastWin = 0
        gameState = .idle
        activeMessage = "Gewinn gesichert"
    }

    func startRisk() {
        guard lastWin > 0, gameState == .won else { return }
        balance -= lastWin
        currentLadderIndex = 4
        gameState = .riskLadder
        activeMessage = "Monte Solaro — optional"
        startPromenadeAnimation()
    }

    func stepLadder() {
        guard gameState == .riskLadder else { return }
        if Int.random(in: 0..<100) < 58 {
            if currentLadderIndex < ladderSteps.count - 1 {
                currentLadderIndex += 1
                activeMessage = "Weiter oben"
            }
        } else {
            currentLadderIndex = max(0, currentLadderIndex - 2)
            if currentLadderIndex == 0 {
                activeMessage = "Abgestürzt"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
                    self?.exitRisk()
                    self?.activeMessage = "Zurück zu den Walzen"
                }
            } else {
                activeMessage = "Zurückgerutscht"
            }
        }
    }

    func collectRisk() {
        guard gameState == .riskLadder else { return }
        let amount = ladderSteps[currentLadderIndex]
        balance += amount
        exitRisk()
        activeMessage = "Gesichert · \(amount.formatted(.currency(code: "EUR")))"
    }

    private func exitRisk() {
        blinkTimer?.invalidate()
        blinkTimer = nil
        lastWin = 0
        gameState = .idle
    }

    private func startPromenadeAnimation() {
        blinkTimer?.invalidate()
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.25)) {
                    self?.isPromenadeBlinking.toggle()
                }
            }
        }
    }
}

// ==========================================
// 3. FARBEN / DESIGN-TOKENS
// ==========================================
private enum CapriTheme {
    static let deep = Color(red: 0.05, green: 0.12, blue: 0.22)
    static let sea = Color(red: 0.08, green: 0.28, blue: 0.42)
    static let gold = Color(red: 0.86, green: 0.70, blue: 0.32)
    static let goldDark = Color(red: 0.55, green: 0.40, blue: 0.14)
    static let brass = Color(red: 0.72, green: 0.55, blue: 0.28)
    static let panel = Color(red: 0.10, green: 0.14, blue: 0.20)
    static let ink = Color(red: 0.92, green: 0.93, blue: 0.94)
}

// ==========================================
// 4. 3D-WALZE
// ==========================================
private let capriCell: CGFloat = 84
private let capriRows = 3

struct CapriReelView: View {
    let finalSymbols: [CapriSymbolType]
    let isSpinning: Bool
    let spinGeneration: Int
    let stopDelay: Double

    @State private var offsetY: CGFloat = 0
    @State private var strip: [CapriSymbolType] = CapriSymbolType.allCases
    @State private var motionBlur: CGFloat = 0

    private var windowH: CGFloat { capriCell * CGFloat(capriRows) }

    var body: some View {
        ZStack {
            // Trommel-Innenraum
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.06, green: 0.07, blue: 0.09),
                            Color(red: 0.14, green: 0.15, blue: 0.18),
                            Color(red: 0.06, green: 0.07, blue: 0.09)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            VStack(spacing: 0) {
                ForEach(Array(strip.enumerated()), id: \.offset) { _, symbol in
                    CapriMedallion(symbol: symbol)
                        .frame(width: capriCell - 6, height: capriCell)
                }
            }
            .offset(y: offsetY)
            .blur(radius: motionBlur)

            // Zylinder-Rundung
            HStack(spacing: 0) {
                LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 12)
                Spacer(minLength: 0)
                LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 12)
            }
            .allowsHitTesting(false)

            // Mittel-Glanz
            LinearGradient(
                colors: [.clear, .white.opacity(0.08), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                LinearGradient(colors: [.black.opacity(0.7), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 26)
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 26)
            }
            .allowsHitTesting(false)

            // Messing-Rahmen
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    LinearGradient(
                        colors: [CapriTheme.gold, CapriTheme.goldDark, CapriTheme.gold],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )
        }
        .frame(width: capriCell + 6, height: windowH)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .rotation3DEffect(.degrees(-5), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
        .shadow(color: .black.opacity(0.45), radius: 6, x: 3, y: 4)
        .onAppear { snap() }
        .onChange(of: spinGeneration) { _, _ in
            guard isSpinning else { return }
            runSpin()
        }
        .onChange(of: isSpinning) { _, spinning in
            if !spinning { settle() }
        }
    }

    private func buildStrip() -> [CapriSymbolType] {
        var band = finalSymbols
        for _ in 0..<20 { band.append(CapriSymbolType.allCases.randomElement()!) }
        band.append(contentsOf: finalSymbols)
        return band
    }

    private func snap() {
        strip = finalSymbols
        offsetY = 0
        motionBlur = 0
    }

    private func runSpin() {
        strip = buildStrip()
        offsetY = 0
        motionBlur = 1.0
        let target = -CGFloat(strip.count - capriRows) * capriCell

        withAnimation(.linear(duration: max(1.7, stopDelay - 0.8))) {
            offsetY = target * 0.9
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + max(1.6, stopDelay - 0.85)) {
            withAnimation(.timingCurve(0.1, 0.9, 0.2, 1, duration: 0.8)) {
                offsetY = target
                motionBlur = 0
            }
        }
    }

    private func settle() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            strip = finalSymbols
            offsetY = 0
            motionBlur = 0
        }
    }
}

/// Medaillon statt Comic-Kachel
struct CapriMedallion: View {
    let symbol: CapriSymbolType

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(white: 0.22),
                            Color(white: 0.10)
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: 36
                    )
                )
                .padding(10)

            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [symbol.accent.opacity(0.95), CapriTheme.goldDark.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .padding(10)

            VStack(spacing: 3) {
                Image(systemName: symbol.systemImage)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, symbol.accent],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .symbolRenderingMode(.hierarchical)

                Text(symbol.title.uppercased())
                    .font(.system(size: 7, weight: .semibold, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(CapriTheme.ink.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// ==========================================
// 5. BUTTONS — fein, nicht plakativ
// ==========================================
struct CapriPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .tracking(1.2)
            .foregroundStyle(Color(red: 0.12, green: 0.09, blue: 0.04))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.95, green: 0.82, blue: 0.42),
                                CapriTheme.gold,
                                CapriTheme.goldDark
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(color: CapriTheme.gold.opacity(0.35), radius: configuration.isPressed ? 2 : 8, y: 3)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct CapriSecondaryButton: ButtonStyle {
    var tone: Color = CapriTheme.sea

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(CapriTheme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                Capsule()
                    .fill(tone.opacity(configuration.isPressed ? 0.45 : 0.28))
                    .overlay(
                        Capsule()
                            .strokeBorder(CapriTheme.ink.opacity(0.22), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct CapriGhostButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .regular, design: .rounded))
            .foregroundStyle(CapriTheme.gold.opacity(0.9))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                Capsule()
                    .strokeBorder(CapriTheme.gold.opacity(0.45), lineWidth: 1)
                    .background(Capsule().fill(Color.white.opacity(configuration.isPressed ? 0.06 : 0.03)))
            )
    }
}

// ==========================================
// 6. HAUPT-VIEW
// ==========================================
struct CapriIslandSlotView: View {
    @State private var vm = CapriGameViewModel()

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                Text(vm.activeMessage)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(CapriTheme.ink.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)

                if vm.gameState == .riskLadder {
                    riskPanel
                } else {
                    machine
                    controls
                }

                Spacer(minLength: 8)
            }
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [CapriTheme.deep, CapriTheme.sea, CapriTheme.deep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // dezente Lichtfläche
            RadialGradient(
                colors: [CapriTheme.gold.opacity(0.12), .clear],
                center: .top,
                startRadius: 10,
                endRadius: 320
            )
            .ignoresSafeArea()
        }
    }

    private var topBar: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("CAPRI ISLAND")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(CapriTheme.gold)
                Text("SLOT")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(CapriTheme.ink.opacity(0.55))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(vm.balance.formatted(.currency(code: "EUR")))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(CapriTheme.ink)
                Text("Einsatz \(vm.stake.formatted(.currency(code: "EUR")))")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(CapriTheme.ink.opacity(0.5))
            }
        }
    }

    private var machine: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.16, green: 0.14, blue: 0.12),
                            Color(red: 0.08, green: 0.07, blue: 0.06)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            LinearGradient(
                                colors: [CapriTheme.gold.opacity(0.7), CapriTheme.goldDark.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: .black.opacity(0.5), radius: 18, y: 10)

            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { col in
                    CapriReelView(
                        finalSymbols: vm.grid[col],
                        isSpinning: vm.reelSpinning[col],
                        spinGeneration: vm.spinGeneration,
                        stopDelay: CapriGameViewModel.stopDelays[col]
                    )
                }
            }
            .padding(16)
        }
        .padding(.horizontal, 18)
        .rotation3DEffect(.degrees(6), axis: (x: 1, y: 0, z: 0), perspective: 0.75)
    }

    private var controls: some View {
        VStack(spacing: 10) {
            if vm.gameState == .won && vm.lastWin > 0 {
                Button("Gewinn behalten") {
                    vm.keepWinAndContinue()
                }
                .buttonStyle(CapriSecondaryButton(tone: Color(red: 0.15, green: 0.45, blue: 0.35)))

                Button("Optional · Monte Solaro") {
                    vm.startRisk()
                }
                .buttonStyle(CapriGhostButton())
            }

            Button(vm.gameState == .spinning ? "Läuft…" : "Drehen") {
                vm.spin()
            }
            .buttonStyle(CapriPrimaryButton())
            .disabled(vm.gameState == .spinning || vm.gameState == .won)
            .opacity(vm.gameState == .spinning || vm.gameState == .won ? 0.45 : 1)
        }
        .padding(.horizontal, 28)
        .padding(.top, 18)
    }

    private var riskPanel: some View {
        VStack(spacing: 12) {
            Text("Monte Solaro")
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(CapriTheme.gold)

            Text(vm.activeMessage)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(CapriTheme.ink.opacity(0.75))

            VStack(spacing: 3) {
                ForEach(Array(vm.ladderSteps.enumerated().reversed()), id: \.offset) { index, amount in
                    let active = index == vm.currentLadderIndex
                    HStack {
                        Spacer()
                        Text(amount.formatted(.currency(code: "EUR")))
                            .font(.system(size: 14, weight: active ? .bold : .regular, design: .rounded))
                            .foregroundStyle(active ? CapriTheme.deep : CapriTheme.ink.opacity(0.75))
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(active ? (vm.isPromenadeBlinking ? CapriTheme.gold : CapriTheme.brass) : Color.white.opacity(0.06))
                    )
                }
            }
            .padding(.horizontal, 36)

            HStack(spacing: 10) {
                Button("Klettern") { vm.stepLadder() }
                    .buttonStyle(CapriGhostButton())
                    .disabled(vm.currentLadderIndex == 0)

                Button("Sichern") { vm.collectRisk() }
                    .buttonStyle(CapriPrimaryButton())
            }
            .padding(.horizontal, 28)
        }
        .padding(.top, 8)
    }
}

#Preview {
    CapriIslandSlotView()
}
