//
//  FahrerSpiele.swift
//  Luckys Taxi Fahrer
//
// Pause-Spiele für lange Wartezeiten. In Xcode als neue Datei ins Target legen.
//

import SwiftUI

// MARK: - Hub

struct FahrerSpieleHubView: View {
    private let taxiYellow = Color(red: 1, green: 0.8, blue: 0)
    private let cream = Color(red: 1.0, green: 0.96, blue: 0.82)
    private let navy = Color(red: 12 / 255, green: 28 / 255, blue: 52 / 255)

    var body: some View {
        ZStack {
            taxiYellow.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                Text("Pause-Spiele")
                    .font(.largeTitle.weight(.black))
                    .foregroundStyle(navy)

                Text("Für lange Wartezeiten. Bei neuer Fahrt bitte zurück zur Liste.")
                    .font(.subheadline)
                    .foregroundStyle(navy.opacity(0.8))

                NavigationLink {
                    TaxiTippSpielView()
                } label: {
                    spielKarte(
                        title: "Taxi tippen",
                        subtitle: "Gelbe Taxis antippen, bevor sie weg sind."
                    )
                }

                NavigationLink {
                    TaxiMemorySpielView()
                } label: {
                    spielKarte(
                        title: "Taxi Memory",
                        subtitle: "Paare finden — 8 Karten, ruhiges Tempo."
                    )
                }

                NavigationLink {
                    TarifRechenSpielView()
                } label: {
                    spielKarte(
                        title: "Tarif rechnen",
                        subtitle: "Schnelle Kopfrechnung wie am Taxameter."
                    )
                }

                Spacer()
            }
            .padding(20)
        }
        .navigationTitle("Spiele")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(taxiYellow.opacity(0.9), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func spielKarte(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(navy)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(navy.opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(cream)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(navy.opacity(0.3), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Taxi tippen

private struct TippTaxi: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
}

struct TaxiTippSpielView: View {
    @State private var score = 0
    @State private var lives = 3
    @State private var taxis: [TippTaxi] = []
    @State private var isRunning = false
    @State private var highScore = UserDefaults.standard.integer(forKey: "fahrer.taxiTipp.highscore")
    @State private var spawnTask: Task<Void, Never>?

    private let taxiYellow = Color(red: 1, green: 0.8, blue: 0)
    private let cream = Color(red: 1.0, green: 0.96, blue: 0.82)
    private let navy = Color(red: 12 / 255, green: 28 / 255, blue: 52 / 255)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 12 / 255, green: 28 / 255, blue: 52 / 255).ignoresSafeArea()

                VStack {
                    HStack {
                        Text("Punkte \(score)")
                        Spacer()
                        Text("Leben \(lives)")
                        Spacer()
                        Text("Rekord \(highScore)")
                    }
                    .font(.headline.weight(.bold))
                    .foregroundStyle(taxiYellow)
                    .padding()

                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.25))

                        ForEach(taxis) { taxi in
                            Button {
                                tippen(taxi)
                            } label: {
                                Text("TAXI")
                                    .font(.system(size: 14, weight: .black))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(taxiYellow)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .position(x: taxi.x, y: taxi.y)
                        }

                        if !isRunning {
                            VStack(spacing: 12) {
                                Text(lives == 0 ? "Game Over" : "Taxi tippen")
                                    .font(.title.weight(.black))
                                    .foregroundStyle(taxiYellow)
                                Text("Tippe die gelben Taxis, bevor sie verschwinden.")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.85))
                                    .multilineTextAlignment(.center)
                                Button(lives == 0 ? "Nochmal" : "Start") {
                                    startGame(in: geo.size)
                                }
                                .font(.headline.weight(.bold))
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(taxiYellow)
                                .foregroundStyle(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .padding()
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Taxi tippen")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { stopGame() }
    }

    private func startGame(in size: CGSize) {
        stopGame()
        score = 0
        lives = 3
        taxis = []
        isRunning = true
        spawnTask = Task { @MainActor in
            while !Task.isCancelled, isRunning, lives > 0 {
                spawnTaxi(in: size)
                try? await Task.sleep(nanoseconds: 900_000_000)
            }
        }
    }

    private func stopGame() {
        spawnTask?.cancel()
        spawnTask = nil
        isRunning = false
        taxis = []
    }

    private func spawnTaxi(in size: CGSize) {
        let margin: CGFloat = 50
        let taxi = TippTaxi(
            x: CGFloat.random(in: margin...(max(margin + 1, size.width - margin))),
            y: CGFloat.random(in: margin...(max(margin + 1, size.height - 180)))
        )
        taxis.append(taxi)
        let id = taxi.id
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            guard isRunning else { return }
            if let idx = taxis.firstIndex(where: { $0.id == id }) {
                taxis.remove(at: idx)
                lives -= 1
                if lives <= 0 {
                    if score > highScore {
                        highScore = score
                        UserDefaults.standard.set(highScore, forKey: "fahrer.taxiTipp.highscore")
                    }
                    stopGame()
                }
            }
        }
    }

    private func tippen(_ taxi: TippTaxi) {
        guard let idx = taxis.firstIndex(where: { $0.id == taxi.id }) else { return }
        taxis.remove(at: idx)
        score += 1
    }
}

// MARK: - Memory

struct TaxiMemorySpielView: View {
    private struct Karte: Identifiable {
        let id: Int
        let symbol: String
        var aufgedeckt: Bool
        var gefunden: Bool
    }

    @State private var karten: [Karte] = []
    @State private var ersteWahl: Int?
    @State private var gesperrt = false
    @State private var zuege = 0
    @State private var fertig = false

    private let taxiYellow = Color(red: 1, green: 0.8, blue: 0)
    private let cream = Color(red: 1.0, green: 0.96, blue: 0.82)
    private let navy = Color(red: 12 / 255, green: 28 / 255, blue: 52 / 255)
    private let symbole = ["🚕", "🚖", "🟡", "⬛"]

    private let spalten = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    var body: some View {
        ZStack {
            taxiYellow.ignoresSafeArea()

            VStack(spacing: 16) {
                HStack {
                    Text("Züge: \(zuege)")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(navy)
                    Spacer()
                    Button("Neu") { neuStarten() }
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(navy)
                }

                LazyVGrid(columns: spalten, spacing: 10) {
                    ForEach(karten) { karte in
                        Button {
                            tippeKarte(karte.id)
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(karte.gefunden || karte.aufgedeckt ? cream : navy)
                                if karte.gefunden || karte.aufgedeckt {
                                    Text(karte.symbol)
                                        .font(.system(size: 28))
                                } else {
                                    Text("?")
                                        .font(.title.weight(.black))
                                        .foregroundStyle(taxiYellow)
                                }
                            }
                            .frame(height: 72)
                        }
                        .disabled(karte.gefunden || karte.aufgedeckt || gesperrt)
                    }
                }

                if fertig {
                    Text("Geschafft in \(zuege) Zügen!")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(navy)
                }

                Spacer()
            }
            .padding(20)
        }
        .navigationTitle("Taxi Memory")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if karten.isEmpty { neuStarten() } }
    }

    private func neuStarten() {
        var deck: [Karte] = []
        var id = 0
        for symbol in symbole {
            deck.append(Karte(id: id, symbol: symbol, aufgedeckt: false, gefunden: false))
            id += 1
            deck.append(Karte(id: id, symbol: symbol, aufgedeckt: false, gefunden: false))
            id += 1
        }
        karten = deck.shuffled()
        ersteWahl = nil
        gesperrt = false
        zuege = 0
        fertig = false
    }

    private func tippeKarte(_ id: Int) {
        guard let index = karten.firstIndex(where: { $0.id == id }) else { return }
        karten[index].aufgedeckt = true

        if let erste = ersteWahl {
            zuege += 1
            gesperrt = true
            let a = erste
            let b = id
            let symbolA = karten.first(where: { $0.id == a })?.symbol
            let symbolB = karten.first(where: { $0.id == b })?.symbol

            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 550_000_000)
                if symbolA == symbolB {
                    if let i = karten.firstIndex(where: { $0.id == a }) { karten[i].gefunden = true }
                    if let j = karten.firstIndex(where: { $0.id == b }) { karten[j].gefunden = true }
                } else {
                    if let i = karten.firstIndex(where: { $0.id == a }) { karten[i].aufgedeckt = false }
                    if let j = karten.firstIndex(where: { $0.id == b }) { karten[j].aufgedeckt = false }
                }
                ersteWahl = nil
                gesperrt = false
                fertig = karten.allSatisfy(\.gefunden)
            }
        } else {
            ersteWahl = id
        }
    }
}

// MARK: - Tarif rechnen

struct TarifRechenSpielView: View {
    @State private var frage = ""
    @State private var antwort = 0
    @State private var eingabe = ""
    @State private var score = 0
    @State private var feedback = "Berechne den Fahrpreis."
    @State private var highScore = UserDefaults.standard.integer(forKey: "fahrer.tarif.highscore")

    private let taxiYellow = Color(red: 1, green: 0.8, blue: 0)
    private let cream = Color(red: 1.0, green: 0.96, blue: 0.82)
    private let navy = Color(red: 12 / 255, green: 28 / 255, blue: 52 / 255)

    var body: some View {
        ZStack {
            taxiYellow.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Richtig: \(score)")
                    Spacer()
                    Text("Rekord: \(highScore)")
                }
                .font(.headline.weight(.bold))
                .foregroundStyle(navy)

                Text(frage)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(navy)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(cream)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                TextField("Antwort in €", text: $eingabe)
                    .keyboardType(.numberPad)
                    .padding()
                    .background(cream)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(navy, lineWidth: 2)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Button("Prüfen") { pruefen() }
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(navy)
                    .foregroundStyle(taxiYellow)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text(feedback)
                    .foregroundStyle(navy.opacity(0.85))

                Spacer()
            }
            .padding(20)
        }
        .navigationTitle("Tarif rechnen")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { neueFrage() }
    }

    private func neueFrage() {
        let km = Int.random(in: 2...18)
        let grund = 3
        let proKm = Int.random(in: 2...3)
        antwort = grund + km * proKm
        frage = "Grundpreis \(grund) € + \(km) km × \(proKm) € = ?"
        eingabe = ""
        feedback = "Wie viel kostet die Fahrt?"
    }

    private func pruefen() {
        guard let wert = Int(eingabe.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            feedback = "Bitte eine ganze Zahl eingeben."
            return
        }
        if wert == antwort {
            score += 1
            if score > highScore {
                highScore = score
                UserDefaults.standard.set(highScore, forKey: "fahrer.tarif.highscore")
            }
            feedback = "Richtig!"
            neueFrage()
        } else {
            feedback = "Leider falsch. Richtig wäre \(antwort) €."
            score = max(0, score - 1)
            neueFrage()
        }
    }
}
