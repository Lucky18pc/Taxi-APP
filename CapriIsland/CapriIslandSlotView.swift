import SwiftUI

// ==========================================
// 1. SYMBOL-DEFINITIONEN
// ==========================================
enum CapriSymbolType: String, CaseIterable, Identifiable {
    case sunglasses = "🕶️"
    case deckchair = "🏖️"
    case cocktail = "🍹"
    case sailboat = "⛵"
    case yacht = "🛥️"
    case isabella = "👒"
    case gianluca = "🤵"
    case capriSun = "☀️"
    case beachJoker = "🏄‍♂️"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .sunglasses: return "Brille"
        case .deckchair: return "Liege"
        case .cocktail: return "Drink"
        case .sailboat: return "Segel"
        case .yacht: return "Yacht"
        case .isabella: return "Isabella"
        case .gianluca: return "Gianluca"
        case .capriSun: return "Sonne"
        case .beachJoker: return "Joker"
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
    var activeMessage: String = "Dreh die Walzen — Capri wartet!"

    /// grid[spalte][zeile] — 3 Walzen à 3 sichtbare Felder
    var grid: [[CapriSymbolType]] = [
        [.sunglasses, .isabella, .cocktail],
        [.sailboat, .gianluca, .yacht],
        [.deckchair, .beachJoker, .capriSun]
    ]

    /// Steigt bei jedem Spin — triggert echte Walzen-Animation
    var spinGeneration: Int = 0
    /// Welche Walze noch läuft (links → rechts stoppen)
    var reelSpinning: [Bool] = [false, false, false]

    let ladderSteps: [Decimal] = [0, 0.20, 0.50, 1, 2.50, 5, 10, 25, 50, 100]
    var currentLadderIndex: Int = 3
    var isPromenadeBlinking: Bool = false
    private var blinkTimer: Timer?

    deinit { blinkTimer?.invalidate() }

    func spin() {
        guard gameState != .spinning else { return }
        guard balance >= stake else {
            activeMessage = "Nicht genügend Guthaben im Portemonnaie!"
            return
        }

        balance -= stake
        lastWin = 0
        gameState = .spinning
        activeMessage = "🎰 Walzen drehen…"

        // Ergebnis zuerst setzen — die Animation scrollt sichtbar dorthin
        let all = CapriSymbolType.allCases
        grid = (0..<3).map { _ in
            (0..<3).map { _ in all.randomElement()! }
        }

        reelSpinning = [true, true, true]
        spinGeneration += 1

        // Gestaffeltes Stoppen: links → Mitte → rechts (wie echte Automaten)
        let stopDelays: [Double] = [1.35, 1.85, 2.35]
        for col in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + stopDelays[col]) { [weak self] in
                guard let self, self.gameState == .spinning else { return }
                self.reelSpinning[col] = false
                if col == 2 {
                    self.finishSpinEvaluation()
                }
            }
        }
    }

    private func finishSpinEvaluation() {
        let hasGianluca = grid.contains { $0.contains(.gianluca) }
        let hasJoker = grid.contains { $0.contains(.beachJoker) }
        let winChance = Int.random(in: 0..<100)

        if winChance < 45 || hasGianluca {
            lastWin = stake * Decimal(Int.random(in: 5...20)) * (hasGianluca ? 2 : 1)
            balance += lastWin
            gameState = .won
            let winText = lastWin.formatted(.currency(code: "EUR"))
            activeMessage = hasGianluca
                ? "🔥 MEGA-WIN! Gianluca: \(winText)"
                : (hasJoker ? "🏄 Joker! Gewinn: \(winText)" : "Gewinn: \(winText)")
        } else {
            lastWin = 0
            gameState = .idle
            activeMessage = "Kein Treffer — nochmal drehen!"
        }
    }

    func keepWinAndContinue() {
        lastWin = 0
        gameState = .idle
        activeMessage = "Gewinn gesichert. Walzen bereit!"
    }

    func startRisk() {
        guard lastWin > 0, gameState == .won else { return }
        balance -= lastWin
        currentLadderIndex = 4
        gameState = .riskLadder
        activeMessage = "Optionales Risiko: Monte Solaro!"
        startPromenadeAnimation()
    }

    func stepLadder() {
        guard gameState == .riskLadder else { return }
        if Int.random(in: 0..<100) < 58 {
            if currentLadderIndex < ladderSteps.count - 1 {
                currentLadderIndex += 1
                activeMessage = "Stufe geschafft!"
            }
        } else {
            currentLadderIndex = max(0, currentLadderIndex - 2)
            if currentLadderIndex == 0 {
                activeMessage = "Abgestürzt — zurück zu den Walzen."
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                    self?.exitRisk()
                    self?.activeMessage = "Risiko verloren — wieder Walzen drehen!"
                }
            } else {
                activeMessage = "Etwas runtergerutscht."
            }
        }
    }

    func collectRisk() {
        guard gameState == .riskLadder else { return }
        let amount = ladderSteps[currentLadderIndex]
        balance += amount
        exitRisk()
        activeMessage = "Gesichert: \(amount.formatted(.currency(code: "EUR"))) — Walzen bereit."
    }

    private func exitRisk() {
        blinkTimer?.invalidate()
        blinkTimer = nil
        lastWin = 0
        gameState = .idle
    }

    private func startPromenadeAnimation() {
        blinkTimer?.invalidate()
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                withAnimation { self?.isPromenadeBlinking.toggle() }
            }
        }
    }
}

// ==========================================
// 3. ECHTE WALZE (vertikaler Band-Scroll)
// ==========================================
private let capriCell: CGFloat = 88
private let capriVisibleRows = 3

/// Eine Walze: langes Symbolband, das nach oben durchläuft und ausläuft.
struct CapriReelView: View {
    let finalSymbols: [CapriSymbolType] // 3 sichtbare Symbole (oben→unten)
    let isSpinning: Bool
    let spinGeneration: Int
    let stopDelay: Double

    @State private var offsetY: CGFloat = 0
    @State private var strip: [CapriSymbolType] = CapriSymbolType.allCases
    @State private var blurAmount: CGFloat = 0

    private var windowHeight: CGFloat { capriCell * CGFloat(capriVisibleRows) }

    var body: some View {
        ZStack {
            // Gehäuse
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.12), Color(white: 0.22), Color(white: 0.12)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            // Symbolband
            VStack(spacing: 0) {
                ForEach(Array(strip.enumerated()), id: \.offset) { _, symbol in
                    CapriSymbolCell(symbol: symbol)
                        .frame(width: capriCell, height: capriCell)
                }
            }
            .offset(y: offsetY)
            .blur(radius: blurAmount)

            // Glas / Rahmen oben+unten abdunkeln (Fenster-Look)
            VStack(spacing: 0) {
                LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 18)
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 18)
            }
            .allowsHitTesting(false)

            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    LinearGradient(
                        colors: [.yellow.opacity(0.7), .orange.opacity(0.4), .yellow.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 2
                )
        }
        .frame(width: capriCell + 8, height: windowHeight)
        .clipped()
        .onAppear { snapToFinal() }
        .onChange(of: spinGeneration) { _, _ in
            guard isSpinning else { return }
            startMechanicalSpin()
        }
        .onChange(of: isSpinning) { _, spinning in
            if !spinning {
                settleOnFinal()
            }
        }
    }

    /// Band bauen: viele Zufallssymbole + am Ende die Zielsymbole
    private func buildStrip() -> [CapriSymbolType] {
        let all = CapriSymbolType.allCases
        var band: [CapriSymbolType] = []
        // Start: aktuelle Finals (nahtlos)
        band.append(contentsOf: finalSymbols)
        // Langer Spin-Bereich
        for _ in 0..<28 {
            band.append(all.randomElement()!)
        }
        // Ziel am Ende
        band.append(contentsOf: finalSymbols)
        return band
    }

    private func snapToFinal() {
        strip = finalSymbols
        offsetY = 0
        blurAmount = 0
    }

    private func startMechanicalSpin() {
        strip = buildStrip()
        offsetY = 0
        blurAmount = 2.5

        let cellTravel = capriCell
        // Bis kurz vor dem Ziel scrollen (die letzten 3 Zellen = finalSymbols)
        let targetIndex = strip.count - capriVisibleRows
        let targetOffset = -CGFloat(targetIndex) * cellTravel

        // Phase 1: schnell anlaufen + durchdrehen (linear)
        withAnimation(.linear(duration: max(0.8, stopDelay - 0.35))) {
            offsetY = targetOffset * 0.92
        }

        // Phase 2: auslaufen / einschnappen
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.75, stopDelay - 0.4)) {
            withAnimation(.timingCurve(0.15, 0.85, 0.25, 1.0, duration: 0.55)) {
                offsetY = targetOffset
                blurAmount = 0
            }
        }
    }

    private func settleOnFinal() {
        // Nach Stopp: Band auf die 3 Finals kürzen, Offset 0 (kein Sprung sichtbar)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            strip = finalSymbols
            offsetY = 0
            blurAmount = 0
        }
    }
}

struct CapriSymbolCell: View {
    let symbol: CapriSymbolType

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    symbol == .gianluca
                    ? Color.yellow.opacity(0.92)
                    : (symbol == .beachJoker ? Color.orange.opacity(0.85) : Color.white.opacity(0.95))
                )
                .padding(4)

            VStack(spacing: 1) {
                Text(symbol.rawValue)
                    .font(.system(size: 36))
                Text(symbol.shortName)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(symbol == .gianluca ? .black : .gray)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.15))
    }
}

// ==========================================
// 4. HAUPT-VIEW
// ==========================================
struct CapriIslandSlotView: View {
    @State private var vm = CapriGameViewModel()

    private var moneyLabel: String {
        "\(vm.balance.formatted(.number.precision(.fractionLength(2)))) €"
    }

    private var stakeLabel: String {
        "Einsatz: \(vm.stake.formatted(.number.precision(.fractionLength(2)))) €"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.cyan.opacity(0.85), Color.blue.opacity(0.9), Color.indigo.opacity(0.95)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                header

                if vm.gameState == .riskLadder {
                    riskLadderView
                } else {
                    reelsView
                }

                footer
            }
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("🏝️ CAPRI ISLAND SLOT 🍋")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(.yellow)
                .shadow(color: .orange, radius: 4)

            HStack {
                Label(moneyLabel, systemImage: "wallet.pass")
                    .foregroundStyle(.green)
                Spacer()
                Label(stakeLabel, systemImage: "dice")
                    .foregroundStyle(.orange)
            }
            .font(.subheadline.bold())
            .padding(.horizontal, 24)
        }
        .padding(.top, 10)
    }

    private var reelsView: some View {
        VStack(spacing: 12) {
            Text(vm.activeMessage)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(minHeight: 36)
                .padding(.horizontal)

            // Maschinen-Rahmen mit 3 echten Walzen
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { col in
                    CapriReelView(
                        finalSymbols: vm.grid[col],
                        isSpinning: vm.reelSpinning[col],
                        spinGeneration: vm.spinGeneration,
                        stopDelay: [1.35, 1.85, 2.35][col]
                    )
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [Color.brown.opacity(0.95), Color(red: 0.35, green: 0.18, blue: 0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.45), radius: 12, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.yellow.opacity(0.35), lineWidth: 1.5)
            )

            Spacer(minLength: 6)

            VStack(spacing: 10) {
                if vm.gameState == .won && vm.lastWin > 0 {
                    Button("GEWINN BEHALTEN — WEITER DREHEN") {
                        vm.keepWinAndContinue()
                    }
                    .buttonStyle(CapriButtonStyle(color: .green, textColor: .white))

                    Button("Optional: Klippentreppe riskieren") {
                        vm.startRisk()
                    }
                    .buttonStyle(CapriButtonStyle(color: .orange.opacity(0.85), textColor: .white))
                }

                Button(vm.gameState == .spinning ? "WALZEN DREHEN…" : "SPIN — WALZEN DREHEN") {
                    vm.spin()
                }
                .buttonStyle(CapriButtonStyle(color: .yellow, textColor: .black))
                .disabled(vm.gameState == .spinning || vm.gameState == .won)
            }
            .padding(.horizontal, 20)
        }
    }

    private var riskLadderView: some View {
        VStack(spacing: 8) {
            Text("OPTIONAL: MONTE SOLARO")
                .font(.headline)
                .foregroundStyle(.yellow)

            Text(vm.activeMessage)
                .font(.caption)
                .foregroundStyle(.white)

            VStack(spacing: 4) {
                ForEach(Array(vm.ladderSteps.enumerated().reversed()), id: \.offset) { index, amount in
                    let isActive = index == vm.currentLadderIndex
                    HStack {
                        Text(isActive ? "⛵" : "")
                        Spacer()
                        Text(amount.formatted(.currency(code: "EUR")))
                            .font(.system(size: 17, weight: isActive ? .bold : .regular))
                            .foregroundStyle(isActive ? .black : .white.opacity(0.8))
                        Spacer()
                        Text(isActive ? "🌴" : "")
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                isActive
                                ? (vm.isPromenadeBlinking ? Color.yellow : Color.orange)
                                : Color.white.opacity(0.15)
                            )
                    )
                }
            }
            .padding(.horizontal, 30)

            HStack(spacing: 12) {
                Button("KLETTERN") { vm.stepLadder() }
                    .buttonStyle(CapriButtonStyle(color: .yellow, textColor: .black))
                    .disabled(vm.currentLadderIndex == 0)

                Button("SICHERN → WALZEN") { vm.collectRisk() }
                    .buttonStyle(CapriButtonStyle(color: .green, textColor: .white))
            }
            .padding(.horizontal, 20)
        }
    }

    private var footer: some View {
        HStack {
            Text(vm.gameState == .riskLadder ? "⚠️ Risiko" : "🎰 Walzen")
            Spacer()
            Text("🤵 Gianluca")
            Spacer()
            Text("🏄‍♂️ Wild")
        }
        .font(.caption2)
        .foregroundStyle(.white.opacity(0.8))
        .padding(.horizontal, 30)
        .padding(.bottom, 10)
    }
}

struct CapriButtonStyle: ButtonStyle {
    var color: Color
    var textColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.bold())
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .padding()
            .background(color)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .shadow(color: color.opacity(0.6), radius: 6)
    }
}

#Preview {
    CapriIslandSlotView()
}
