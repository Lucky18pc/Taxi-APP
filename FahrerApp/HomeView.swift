//
//  HomeView.swift
//  Luckys Taxi Fahrer
//

import SwiftUI

struct HomeView: View {
    let driverName: String
    @State private var isOnline = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Hallo, \(driverName)")
                .font(.title2.bold())

            Toggle("Online / Schicht", isOn: $isOnline)
                .padding()
                .background(.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(isOnline ? "Du bist online." : "Du bist offline.")
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
    }
}
