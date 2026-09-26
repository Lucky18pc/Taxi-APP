import SwiftUI

@main
struct TaxiApp: App {
    @StateObject private var profileStore = DriverProfileStore()
    @StateObject private var centralStore = CentralConfigStore()
    @StateObject private var passengerSession = PassengerSessionStore()
    @State private var showOTPGate = false

    init() {
        Brand.configureGlobalUIKitAppearance()
    }

    var body: some Scene {
        WindowGroup {
            TaxiPickupView()
                .environmentObject(profileStore)
                .environmentObject(centralStore)
                .environmentObject(passengerSession)
                .environment(\.locale, TaxiConfig.mapLocale)
                .task {
                    await centralStore.refreshFromBackend()
                    if !passengerSession.isAuthenticated {
                        showOTPGate = true
                    }
                }
                .sheet(isPresented: $showOTPGate) {
                    PassengerOTPLoginView(onSkip: { showOTPGate = false })
                        .environmentObject(passengerSession)
                        .onChange(of: passengerSession.isAuthenticated) { _, ok in
                            if ok { showOTPGate = false }
                        }
                }
        }
    }
}
