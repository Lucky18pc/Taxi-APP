import SwiftUI

// ==========================================
// 1. SYMBOL-DEFINITIONEN (CAPRI ISLAND)
// ==========================================
enum CapriSymbolType: String, CaseIterable, Identifiable {
    case sunglasses = "🕶️"    // Sonnenbrille
    case deckchair = "🏖️"     // Liegestuhl & Schirm
    case cocktail = "🍹"      // Capri-Cocktail
    case sailboat = "⛵"      // Segelboot
    case yacht = "🛥️"         // Luxus-Yacht
    case isabella = "👒"      // Isabella (Glamouröse Urlauberin)
    case gianluca = "🤵"      // Gianluca (High-Pay Bonvivant)
    case capriSun = "☀️"      // Capri Sonne / Scatter
    case beachJoker = "🏄‍♂️"   // Strand-Joker (WILD)

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
        case .gianluca: return 200.0
        case .isabella: return 150.0
        case .yacht: return 100.0
        case .sailboat: return 50.0
        case .cocktail: return 20.0
        case .deckchair: return 10.0
        case .sunglasses: return 5.0
        case .capriSun: return 25.0
        case .beachJoker: return 0.0
        }
    }
}

// ==========================================
// 2. VIEWMODEL (SPIELLOGIK)
// ==========================================
@Observable
class CapriGameViewModel {
    var balance: Decimal = 150.00
    var stake: Decimal = 1.00

    enum State { case idle, spinning, won, riskLadder }
    var gameState: State = .idle
    var lastWin: Decimal = 0.00
    var activeMessage: String = "Willkommen in Capri! Gianluca & Isabella warten auf Gewinne."

    // 3x3 Walzen-Grid
    var grid: [[CapriSymbolType]] = [
        [.sunglasses, .isabella, .cocktail],
        [.sailboat, .gianluca, .yacht],
        [.deckchair, .beachJoker, .capriSun]
    ]

    // Klippen-Risikoleiter ("Monte Solaro")
    let ladderSteps: [Decimal] = [0.00, 0.20, 0.50, 1.00, 2.50, 5.00, 10.00, 25.00, 50.00, 100.00]
    var currentLadderIndex: Int = 3
    var isPromenadeBlinking: Bool = false
    private var blinkTimer: Timer?

    init() {
        startPromenadeAnimation()
    }

    func spin() {
        guard balance >= stake else {
            activeMessage = "Nicht genügend Guthaben im Portemonnaie!"
            return
        }

        balance -= stake
        gameState = .spinning
        activeMessage = "Die Yacht legt ab... Walzen drehen sich!"

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            let allSymbols = CapriSymbolType.allCases
            self.grid = (0..<3).map { _ in
                (0..<3).map { _ in allSymbols.randomElement()! }
            }

            let hasGianluca = self.grid.contains { col in col.contains(.gianluca) }
            let hasJoker = self.grid.contains { col in col.contains(.beachJoker) }

            let winChance = Int.random(in: 0..<100)
            if winChance < 50 || hasGianluca {
                self.lastWin = self.stake * Decimal(Int.random(in: 5...20)) * (hasGianluca ? 2 : 1)
                self.balance += self.lastWin
                self.gameState = .won

                if hasGianluca {
                    self.activeMessage = "🔥 MEGA-WIN! Gianluca bringt den Luxus-Gewinn von \(self.lastWin.formatted(.currency(code: "EUR")))!"
                } else if hasJoker {
                    self.activeMessage = "🏄‍♂️ Strand-Joker hilft! Gewinn: \(self.lastWin.formatted(.currency(code: "EUR")))"
                } else {
                    self.activeMessage = "Traumhafter Gewinn: \(self.lastWin.formatted(.currency(code: "EUR")))!"
                }
            } else {
                self.gameState = .idle
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
        let success = Int.random(in: 0..<100) < 58 // 58% Chance
        if success {
            if currentLadderIndex < ladderSteps.count - 1 {
                currentLadderIndex += 1
                activeMessage = "Stufe geschafft! Der Blick von oben wird besser."
            }
        } else {
            currentLadderIndex = max(0, currentLadderIndex - 2)
            if currentLadderIndex == 0 {
                activeMessage = "Eine steife Brise hat dich erwischt! Abgestürzt."
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.gameState = .idle
                    self.lastWin = 0
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
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            withAnimation { self.isPromenadeBlinking.toggle() }
        }
    }

    deinit { blinkTimer?.invalidate() }
}

// ==========================================
// 3. UI VIEW KOMPONENTE (SWIFTUI)
// ==========================================
struct CapriIslandSlotView: View {
    @State private var vm = CapriGameViewModel()

    var body: some View {
        ZStack {
            // Hintergrund: Azurblaues Mittelmeer mit Farbverlauf
            LinearGradient(
                colors: [Color.cyan.opacity(0.85), Color.blue.opacity(0.9), Color.indigo.opacity(0.95)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                // Header Branding
                VStack(spacing: 4) {
                    Text("🏝️ CAPRI ISLAND SLOT 🍋")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(.yellow)
                        .shadow(color: .orange, radius: 4)

                    HStack {
                        Label("\(vm.balance, specifier: "%.2f") €", systemImage: "wallet.pass")
                            .foregroundStyle(.green)
                        Spacer()
                        Label("Einsatz: \(vm.stake, specifier: "%.2f") €", systemImage: "dice")
                            .foregroundStyle(.orange)
                    }
                    .font(.subheadline)
                    .bold()
                    .padding(.horizontal, 24)
                }
                .padding(.top, 10)

                if vm.gameState == .riskLadder {
                    // ------------------------------------
                    // ANSICHT B: KLIPPEN-RISIKOLEITER
                    // ------------------------------------
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
                                let isActive = (index == vm.currentLadderIndex)
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
                                        .fill(isActive ? (vm.isPromenadeBlinking ? Color.yellow : Color.orange) : Color.white.opacity(0.15))
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
                } else {
                    // ------------------------------------
                    // ANSICHT A: HAUPT-WALZEN
                    // ------------------------------------
                    VStack(spacing: 10) {
                        Text(vm.activeMessage)
                            .font(.subheadline)
                            .bold()
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .frame(height: 40)
                            .padding(.horizontal)

                        // Walzen Matrix
                        VStack(spacing: 8) {
                            ForEach(0..<3, id: \.self) { row in
                                HStack(spacing: 8) {
                                    ForEach(0..<3, id: \.self) { col in
                                        let symbol = vm.grid[col][row]
                                        let isGianluca = (symbol == .gianluca)
                                        let isJoker = (symbol == .beachJoker)

                                        ZStack {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(isGianluca ? Color.yellow.opacity(0.9) : (isJoker ? Color.orange.opacity(0.8) : Color.white.opacity(0.9)))
                                                .frame(width: 95, height: 95)
                                                .shadow(color: isGianluca ? .yellow : .black.opacity(0.3), radius: isGianluca ? 8 : 4)

                                            VStack(spacing: 2) {
                                                Text(symbol.rawValue)
                                                    .font(.system(size: 40))
                                                Text(symbol.displayName.split(separator: " ").first ?? "")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(isGianluca ? .black : .gray)
                                            }
                                        }
                                        .scaleEffect(isGianluca ? 1.05 : 1.0)
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.brown.opacity(0.6))
                        .cornerRadius(16)
                        .shadow(radius: 10)

                        Spacer()

                        // Aktionsknöpfe
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

                // Footer
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
            .font(.headline)
            .bold()
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity)
            .padding()
            .background(color)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .shadow(color: color.opacity(0.6), radius: 6)
    }
}

// ==========================================
// 5. XCODE PREVIEW
// ==========================================
#Preview {
    CapriIslandSlotView()
}
