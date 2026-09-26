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

    var payoutMultiplier: Decimal {
        switch self {
        case .gianluca: return 200
        case .isabella: return 150
        case .yacht: return 100
        case .sailboat: return 50
        case .cocktail: return 20
        case .deckchair: return 10
        case .sunglasses: return 5
        case .capriSun: return 25
        case .beachJoker: return 0
        }
    }
}

// ==========================================
// 2. VIEWMODEL (SPIELLOGIK)
// ==========================================
@Observable
final class CapriGameViewModel {
    var balance: Decimal = 150
    var stake: Decimal = 1

    enum State {
        case idle, spinning, won, riskLadder
    }

    var gameState: State = .idle
    var lastWin: Decimal = 0
    var activeMessage: String = "Willkommen in Capri! Gianluca & Isabella warten auf Gewinne."

    var grid: [[CapriSymbolType]] = [
        [.sunglasses, .isabella, .cocktail],
        [.sailboat, .gianluca, .yacht],
        [.deckchair, .beachJoker, .capriSun]
    ]

    let ladderSteps: [Decimal] = [0, 0.20, 0.50, 1, 2.50, 5, 10, 25, 50, 100]
    var currentLadderIndex: Int = 3
    var isPromenadeBlinking: Bool = false
    private var blinkTimer: Timer?

    init() {
        startPromenadeAnimation()
    }

    deinit {
        blinkTimer?.invalidate()
    }

    func spin() {
        guard balance >= stake else {
            activeMessage = "Nicht genügend Guthaben im Portemonnaie!"
            return
        }

        balance -= stake
        gameState = .spinning
        activeMessage = "Die Yacht legt ab... Walzen drehen sich!"

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            guard let self else { return }

            let allSymbols = CapriSymbolType.allCases
            self.grid = (0..<3).map { _ in
                (0..<3).map { _ in allSymbols.randomElement()! }
            }

            let hasGianluca = self.grid.contains { $0.contains(.gianluca) }
            let hasJoker = self.grid.contains { $0.contains(.beachJoker) }

            let winChance = Int.random(in: 0..<100)
            if winChance < 50 || hasGianluca {
                self.lastWin = self.stake * Decimal(Int.random(in: 5...20)) * (hasGianluca ? 2 : 1)
                self.balance += self.lastWin
                self.gameState = .won

                let winText = self.lastWin.formatted(.currency(code: "EUR"))
                if hasGianluca {
                    self.activeMessage = "🔥 MEGA-WIN! Gianluca bringt den Luxus-Gewinn von \(winText)!"
                } else if hasJoker {
                    self.activeMessage = "🏄‍♂️ Strand-Joker hilft! Gewinn: \(winText)"
                } else {
                    self.activeMessage = "Traumhafter Gewinn: \(winText)!"
                }
            } else {
                self.gameState = .idle
                self.lastWin = 0
                self.activeMessage = "Sonne, Strand und Meer. Neuer Versuch!"
            }
        }
    }

    func startRisk() {
        guard lastWin > 0 else { return }
        balance -= lastWin
        currentLadderIndex = 4
        gameState = .riskLadder
        activeMessage = "Aufstieg an der Klippentreppe zum Monte Solaro!"
    }

    func stepLadder() {
        let success = Int.random(in: 0..<100) < 58
        if success {
            if currentLadderIndex < ladderSteps.count - 1 {
                currentLadderIndex += 1
                activeMessage = "Stufe geschafft! Der Blick von oben wird besser."
            }
        } else {
            currentLadderIndex = max(0, currentLadderIndex - 2)
            if currentLadderIndex == 0 {
                activeMessage = "Eine steife Brise hat dich erwischt! Abgestürzt."
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    self?.gameState = .idle
                    self?.lastWin = 0
                }
            } else {
                activeMessage = "Welle erwischt! Ein paar Stufen runtergerutscht."
            }
        }
    }

    func collectRisk() {
        let amount = ladderSteps[currentLadderIndex]
        balance += amount
        lastWin = 0
        gameState = .idle
        activeMessage = "Sicher im Hafen! \(amount.formatted(.currency(code: "EUR"))) gutgeschrieben."
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
// 3. UI
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

    private var riskLadderView: some View {
        VStack(spacing: 8) {
            Text("☀️ MONTE SOLARO KLIPPENTREPPE ☀️")
                .font(.headline)
                .foregroundStyle(.yellow)

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
                Button("RISIKO KLETTERN") { vm.stepLadder() }
                    .buttonStyle(CapriButtonStyle(color: .yellow, textColor: .black))
                    .disabled(vm.currentLadderIndex == 0)

                Button("SICHERN") { vm.collectRisk() }
                    .buttonStyle(CapriButtonStyle(color: .green, textColor: .white))
            }
            .padding(.horizontal, 20)
        }
    }

    private var reelsView: some View {
        VStack(spacing: 10) {
            Text(vm.activeMessage)
                .font(.subheadline)
                .bold()
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(height: 40)
                .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { col in
                            reelCell(symbol: vm.grid[col][row])
                        }
                    }
                }
            }
            .padding(12)
            .background(Color.brown.opacity(0.6))
            .cornerRadius(16)
            .shadow(radius: 10)

            Spacer()

            VStack(spacing: 10) {
                if vm.lastWin > 0 && vm.gameState == .won {
                    Button("GEWINN AUF DIE KLIPPENTREPPE RISIKIEREN") {
                        vm.startRisk()
                    }
                    .buttonStyle(CapriButtonStyle(color: .orange, textColor: .white))
                }

                Button(vm.gameState == .spinning ? "SCHIFF LÄUFT EIN..." : "SPIN (LA DOLCE VITA)") {
                    vm.spin()
                }
                .buttonStyle(CapriButtonStyle(color: .yellow, textColor: .black))
                .disabled(vm.gameState == .spinning)
            }
            .padding(.horizontal, 20)
        }
    }

    private func reelCell(symbol: CapriSymbolType) -> some View {
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
                Text(symbol.displayName.split(separator: " ").first.map(String.init) ?? "")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(isGianluca ? .black : .gray)
            }
        }
        .scaleEffect(isGianluca ? 1.05 : 1.0)
    }

    private var footer: some View {
        HStack {
            Text("🌊 Wellenrauschen")
            Spacer()
            Text("🤵 Gianluca Online")
            Spacer()
            Text("🏄‍♂️ Wild Active")
        }
        .font(.caption2)
        .foregroundStyle(.white.opacity(0.8))
        .padding(.horizontal, 30)
        .padding(.bottom, 10)
    }
}

// ==========================================
// 4. BUTTON-STYLE
// ==========================================
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
