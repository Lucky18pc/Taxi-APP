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
                            VStack(alignment: .leading, spacing: 4) {
                                DriverAvatarView(
                                    profileImage: profileStore.profileImage,
                                    fallbackImageName: assignedDriver.photoImageName,
                                    size: 44,
                                    showBorder: true
                                )
                                if !profileStore.resolvedDisplayName.isEmpty {
                                    Text(profileStore.resolvedDisplayName)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .shadow(color: .black.opacity(0.55), radius: 3, y: 1)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Fahrer-Profil")

                        Button(action: { showBusinessPlans = true }) {
                            Text("Für Unternehmen")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.12))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Brand.accent.opacity(0.9), lineWidth: 1.5)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.25))
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
            .navigationDestination(isPresented: $showNextScreen) {
                TaxiCustomerCalendarView()
            }
            .sheet(isPresented: $showBusinessPlans) {
                NavigationStack {
                    TaxiBusinessPlansView()
                }
            }
            .sheet(isPresented: $showDriverProfile) {
                DriverProfileView(store: profileStore)
                    .environmentObject(centralStore)
            }
            .alert("Taxi abbestellen?", isPresented: $showCancelAlert) {
                Button("Ja, abbrechen", role: .destructive) { }
                Button("Behalten", role: .cancel) { }
            } message: {
                Text("Möchtest du die Abholung wirklich stornieren?")
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
