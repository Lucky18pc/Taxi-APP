import SwiftUI

@main
struct TaxiApp: App {
    @StateObject private var profileStore = DriverProfileStore()
    @StateObject private var centralStore = CentralConfigStore()

    init() {
        Brand.configureGlobalUIKitAppearance()
    }

    var body: some Scene {
        WindowGroup {
            TaxiPickupView()
                .environmentObject(profileStore)
                .environmentObject(centralStore)
                .task {
                    await centralStore.refreshFromBackend()
                }
        }
    }
}
