import SwiftUI
import UIKit

/// Prototyp-Startseite: Abholung und Aktionen unten — mit Vollbild-Hintergrund.
struct TaxiPickupView: View {
    @EnvironmentObject private var profileStore: DriverProfileStore
    @EnvironmentObject private var centralStore: CentralConfigStore
    @State private var showCancelAlert = false
    @State private var showNextScreen = false
    @State private var showBusinessPlans = false
    @State private var showDriverProfile = false
    @State private var estimatedMinutes = 8

    private var assignedDriver: TaxiDriver { TaxiConfig.defaultDriver }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 10) {
                        Button(action: { showDriverProfile = true }) {
                            VStack(alignment: .leading, spacing: 6) {
                                DriverAvatarView(
                                    profileImage: profileStore.profileImage,
                                    fallbackImageName: assignedDriver.photoImageName,
                                    size: 92,
                                    showBorder: true,
                                    faceZoom: 0.88
                                )
                                .circleRingShimmer(lineWidth: 3, intensity: 0.9)

                                Text(
                                    profileStore.resolvedDisplayName.isEmpty
                                        ? "Profil & Zentrale"
                                        : profileStore.resolvedDisplayName
                                )
                                .font(.callout.weight(.bold))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
                                .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Profil und Zentrale-Nummer")

                        Button(action: { showBusinessPlans = true }) {
                            Text("Für Unternehmen")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Brand.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .lightShimmer(cornerRadius: 10, tone: .onLight, intensity: 0.85)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Brand.primary.opacity(0.88))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .lightShimmer(cornerRadius: 16, tone: .onDark, intensity: 0.9)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                Text("Abholung in ca. \(estimatedMinutes) Min. möglich")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
                    .padding(.horizontal, 24)

                Spacer()

                VStack(spacing: 14) {
                    CentralCallButton(style: .outline)

                    outlineActionButton(
                        title: "Taxi abbestellen",
                        systemImage: "xmark.circle.fill",
                        action: { showCancelAlert = true }
                    )

                    Button(action: { showNextScreen = true }) {
                        Text("Taxi bestellen")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Brand.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .lightShimmer(cornerRadius: 14, intensity: 1.25)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .safeAreaPadding(.top, 4)
            .bookingFlowBackground(
                imageOffsetY: 40,
                imageScale: 1.05,
                overlayStyle: .pickup,
                imageAlignment: .bottom
            )
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .onReceive(NotificationCenter.default.publisher(for: .taxiBookingCompleted)) { _ in
                showNextScreen = false
            }
            .navigationDestination(isPresented: $showNextScreen) {
                TaxiPickupLocationView()
            }
            .sheet(isPresented: $showBusinessPlans) {
                NavigationStack {
                    TaxiBusinessPlansView()
                }
                .presentationBackground(Brand.background)
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showDriverProfile) {
                DriverProfileView(store: profileStore)
                    .environmentObject(centralStore)
                    .presentationBackground(Brand.background)
                    .presentationDragIndicator(.visible)
            }
            .alert("Taxi abbestellen?", isPresented: $showCancelAlert) {
                Button("Zentrale anrufen") {
                    Task { await centralStore.callCentral() }
                }
                Button("Schließen", role: .cancel) { }
            } message: {
                Text("Es ist noch keine Fahrt aus dieser Sitzung gebucht. Bei einer laufenden Fahrt bitte die Zentrale anrufen.")
            }
            .onAppear {
                estimatedMinutes = Int.random(in: 5...12)
            }
            .task {
                await centralStore.refreshFromBackend()
            }
        }
    }

    private func outlineActionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Brand.primary.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .lightShimmer(cornerRadius: 14, tone: .onDark, intensity: 1.15)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TaxiPickupView()
        .environmentObject(DriverProfileStore())
        .environmentObject(CentralConfigStore())
}
