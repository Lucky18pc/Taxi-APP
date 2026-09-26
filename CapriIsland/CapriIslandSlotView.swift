import SwiftUI

// ==========================================
// 1. SYMBOL-DEFINITIONEN (CAPRI ISLAND)
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

    var displayName: String {
        switch self {
        case .sunglasses: return "Sonnenbrille"
        case .deckchair: return "Strandliege"
        case .cocktail: return "Capri Cocktail"
        case .sailboat: return "Segelboot"
        case .yacht: return "Luxus-Yacht"
        case .isabella: return "Isabella"
        case .gianluca: return "Gianluca (High-Pay)"
        case .capriSun: return "Sonne von Capri"
        case .beachJoker: return "Strand Joker"
        }
    }
}

// ==========================================
// 2. VIEWMODEL — Hauptspiel = WALZEN
// ==========================================
@Observable
final class CapriGameViewModel {
    var balance: Decimal = 150
    var stake: Decimal = 1

    enum State {
        case idle, spinning, won, riskLadder
    }

    /// Start immer bei den Walzen — Treppe nur nach optionalem Risiko.
    var gameState: State = .idle
    var lastWin: Decimal = 0
    var activeMessage: String = "Dreh die Walzen — Capri wartet!"

    var grid: [[CapriSymbolType]] = [
        [.sunglasses, .isabella, .cocktail],
        [.sailboat, .gianluca, .yacht],
        [.deckchair, .beachJoker, .capriSun]
    ]

    /// Nur für optionales Risiko nach einem Gewinn.
    let ladderSteps: [Decimal] = [0, 0.20, 0.50, 1, 2.50, 5, 10, 25, 50, 100]
    var currentLadderIndex: Int = 3
    var isPromenadeBlinking: Bool = false

    private var blinkTimer: Timer?
    private var spinTickTimer: Timer?

    deinit {
        blinkTimer?.invalidate()
        spinTickTimer?.invalidate()
    }

    func spin() {
        guard gameState != .spinning else { return }
        guard balance >= stake else {
            activeMessage = "Nicht genügend Guthaben im Portemonnaie!"
            return
        }

        // Zurück zu den Walzen (falls man vorher in Risiko war)
        balance -= stake
        lastWin = 0
        gameState = .spinning
        activeMessage = "🎰 Die Walzen drehen sich..."

        // Sichtbares Durchlaufen der Symbole (= „drehen“)
        spinTickTimer?.invalidate()
        spinTickTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.gameState == .spinning else { return }
                let all = CapriSymbolType.allCases
                self.grid = (0..<3).map { _ in
                    (0..<3).map { _ in all.randomElement()! }
                }
            }
        }

        // Nach ~1,4 s anhalten und Ergebnis festlegen
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            guard let self else { return }
            self.spinTickTimer?.invalidate()
            self.spinTickTimer = nil
            self.finishSpin()
        }
    }

    private func finishSpin() {
        let allSymbols = CapriSymbolType.allCases
        grid = (0..<3).map { _ in
            (0..<3).map { _ in allSymbols.randomElement()! }
        }

        let hasGianluca = grid.contains { $0.contains(.gianluca) }
        let hasJoker = grid.contains { $0.contains(.beachJoker) }
        let winChance = Int.random(in: 0..<100)

        if winChance < 45 || hasGianluca {
            lastWin = stake * Decimal(Int.random(in: 5...20)) * (hasGianluca ? 2 : 1)
            balance += lastWin
            gameState = .won

            let winText = lastWin.formatted(.currency(code: "EUR"))
            if hasGianluca {
                activeMessage = "🔥 MEGA-WIN! Gianluca: \(winText)"
            } else if hasJoker {
                activeMessage = "🏄‍♂️ Joker hilft! Gewinn: \(winText)"
            } else {
                activeMessage = "Gewinn: \(winText) — behalten oder optional riskieren?"
            }
        } else {
            lastWin = 0
            gameState = .idle
            activeMessage = "Kein Treffer — nochmal drehen!"
        }
    }

    /// Gewinn behalten und weiter an den Walzen spielen.
    func keepWinAndContinue() {
        lastWin = 0
        gameState = .idle
        activeMessage = "Gewinn gesichert. Walzen bereit!"
    }

    /// Optional: nur nach Gewinn — Risikotreppe.
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
        let success = Int.random(in: 0..<100) < 58
        if success {
            if currentLadderIndex < ladderSteps.count - 1 {
                currentLadderIndex += 1
                activeMessage = "Stufe geschafft!"
            }
        } else {
            currentLadderIndex = max(0, currentLadderIndex - 2)
            if currentLadderIndex == 0 {
                activeMessage = "Abgestürzt — zurück zu den Walzen."
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                    self?.exitRisk(lost: true)
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
        exitRisk(lost: false)
        activeMessage = "Gesichert: \(amount.formatted(.currency(code: "EUR"))) — zurück zu den Walzen."
    }

    private func exitRisk(lost: Bool) {
        blinkTimer?.invalidate()
        blinkTimer = nil
        lastWin = 0
        gameState = .idle
        if lost {
            activeMessage = "Risiko verloren — wieder Walzen drehen!"
        }
    }

    private func startPromenadeAnimation() {
        blinkTimer?.invalidate()
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                withAnimation {
                    self?.isPromenadeBlinking.toggle()
                }
            }
        }
    }
}

// ==========================================
// 3. UI — Walzen zuerst, Treppe nur optional
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
                colors: [
                    Color.cyan.opacity(0.85),
                    Color.blue.opacity(0.9),
                    Color.indigo.opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                header

                // Hauptspiel = immer Walzen, außer man wählt bewusst Risiko
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
            .font(.subheadline)
            .bold()
            .padding(.horizontal, 24)
        }
        .padding(.top, 10)
    }

    // MARK: Walzen (Hauptspiel)

    private var reelsView: some View {
        VStack(spacing: 10) {
            Text(vm.activeMessage)
                .font(.subheadline)
                .bold()
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(minHeight: 40)
                .padding(.horizontal)

            // 3×3 Walzen
            VStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { col in
                            reelCell(symbol: vm.grid[col][row], spinning: vm.gameState == .spinning)
                        }
                    }
                }
            }
            .padding(12)
            .background(Color.brown.opacity(0.6))
            .cornerRadius(16)
            .shadow(radius: 10)
            .opacity(vm.gameState == .spinning ? 0.95 : 1.0)

            Spacer(minLength: 8)

            VStack(spacing: 10) {
                // Nach Gewinn: behalten ODER optional riskieren
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

                Button(vm.gameState == .spinning ? "WALZEN DREHEN..." : "SPIN — WALZEN DREHEN") {
                    vm.spin()
                }
                .buttonStyle(CapriButtonStyle(color: .yellow, textColor: .black))
                .disabled(vm.gameState == .spinning || vm.gameState == .won)
            }
            .padding(.horizontal, 20)
        }
    }

    private func reelCell(symbol: CapriSymbolType, spinning: Bool) -> some View {
        let isGianluca = symbol == .gianluca
        let isJoker = symbol == .beachJoker

        return ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    isGianluca
                    ? Color.yellow.opacity(0.9)
                    : (isJoker ? Color.orange.opacity(0.8) : Color.white.opacity(0.9))
                )
                .frame(width: 95, height: 95)
                .shadow(
                    color: isGianluca ? .yellow : .black.opacity(0.3),
                    radius: isGianluca ? 8 : 4
                )

            VStack(spacing: 2) {
                Text(symbol.rawValue)
                    .font(.system(size: 40))
                    .symbolEffect(.pulse, isActive: spinning)
                Text(symbol.displayName.split(separator: " ").first.map(String.init) ?? "")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(isGianluca ? .black : .gray)
            }
        }
        .scaleEffect(spinning ? 0.98 : (isGianluca ? 1.05 : 1.0))
        .animation(.easeInOut(duration: 0.08), value: symbol.rawValue)
    }

    // MARK: Risikotreppe (nur optional, nach Gewinn)

    private var riskLadderView: some View {
        VStack(spacing: 8) {
            Text("OPTIONAL: MONTE SOLARO")
                .font(.headline)
                .foregroundStyle(.yellow)

            Text("Nur Risikospiel — zurück zu den Walzen mit „Sichern“")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))

            Text(vm.activeMessage)
                .font(.caption)
                .foregroundStyle(.white)
                .frame(height: 25)

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
            Text(vm.gameState == .riskLadder ? "⚠️ Risiko-Modus" : "🎰 Walzen-Modus")
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
