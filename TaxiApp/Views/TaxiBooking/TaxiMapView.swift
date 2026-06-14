import SwiftUI
import MapKit
import CoreLocation

struct TaxiMapView: View {
    @EnvironmentObject private var profileStore: DriverProfileStore
    @EnvironmentObject private var centralStore: CentralConfigStore
    @StateObject var locationManager = LocationManager()

    // Beispiel-Taxi in deiner Nähe (mit Telefonnummer für „Fahrer kontaktieren“)
    @State private var drivers = [
        TaxiDriver(
            name: "Jamie",
            coordinate: CLLocationCoordinate2D(latitude: 52.520, longitude: 13.405),
            phoneNumber: "+493012345678"
        )
    ]

    // Startregion der Karte (Berlin als Platzhalter)
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 52.52, longitude: 13.40),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    @State private var showDriverDetails = false
    @State private var showMovingTaxiView = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: drivers) { driver in
                MapAnnotation(coordinate: driver.coordinate) {
                    VStack {
                        Image(systemName: "car.circle.fill")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .foregroundStyle(Brand.primary)
                            .background(Brand.background.clipShape(Circle()))
                        Text(profileStore.resolvedDisplayName).font(.caption).bold()
                    }
                }
            }
            .ignoresSafeArea()

            // UI Overlay
            VStack(spacing: 0) {
                TaxiCompanyHeaderView(logoImageName: TaxiConfig.logoImageName, showTime: true)

                HStack {
                    VStack(alignment: .leading) {
                        Text("Wohin soll es gehen?")
                            .font(.title2).bold()
                        Text("Dein Standort wurde erkannt")
                            .font(.subheadline).foregroundColor(.gray)
                    }
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .padding()
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(radius: 5)
                }
                .padding()
                .background(Color.white.opacity(0.9))
                .cornerRadius(15)
                .padding()

                Button(action: {
                    showDriverDetails = true
                }) {
                    Text("JETZT TAXI BESTELLEN")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
.background(Brand.primary)
                    .cornerRadius(15)
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $showDriverDetails) {
            if let driver = drivers.first {
                DriverBottomSheet(driver: driver, onWeiterTapped: {
                    showDriverDetails = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showMovingTaxiView = true
                    }
                })
                .environmentObject(profileStore)
                .environmentObject(centralStore)
                .presentationDetents([.height(380), .medium])
            }
        }
        .fullScreenCover(isPresented: $showMovingTaxiView) {
            NavigationStack {
                MovingTaxiView()
                    .environmentObject(centralStore)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Schließen") {
                                showMovingTaxiView = false
                            }
                        }
                    }
            }
        }
    }
}
