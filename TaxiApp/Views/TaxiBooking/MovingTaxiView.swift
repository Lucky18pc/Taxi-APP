import SwiftUI
import MapKit
import CoreLocation

struct MovingTaxiView: View {
    @EnvironmentObject private var centralStore: CentralConfigStore
    // Startposition des Taxis
    @State private var taxiCoordinate = CLLocationCoordinate2D(latitude: 52.510, longitude: 13.400)

    // Zielposition (dein Standort)
    let destination = CLLocationCoordinate2D(latitude: 52.525, longitude: 13.415)

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 52.518, longitude: 13.408),
        span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
    )

    @State private var showCancelAlert = false
    @State private var showPaymentView = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            // Hintergrundbild: Karte (Google-Maps-ähnlich)
            Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: [TaxiDriver(name: "Dein Taxi", coordinate: taxiCoordinate)]) { driver in
                MapAnnotation(coordinate: driver.coordinate) {
                    Image(systemName: "car.side.fill")
                        .resizable()
                        .frame(width: 40, height: 25)
                        .foregroundStyle(Brand.primary)
                        .shadow(radius: 3)
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // 9:41 + Header
                TaxiCompanyHeaderView(logoImageName: TaxiConfig.logoImageName, showTime: true)

                Spacer()

                // Unteres Panel: Start, Zentrale anrufen, Taxi abbestellen, Weiter
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundStyle(Brand.secondary)
                        Text("Start")
                            .font(.headline)
                        Spacer()
                        Text("Fahrt gestartet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    CentralCallButton(style: .filled)

                    Button(action: { showCancelAlert = true }) {
                        Label("Taxi abbestellen", systemImage: "xmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(Brand.primary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(15)
                    }
                    .buttonStyle(.plain)

                    Button(action: continueToNext) {
                        Text("Weiter")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Brand.primary)
                            .cornerRadius(15)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(20)
                .shadow(radius: 10)
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .alert("Taxi abbestellen?", isPresented: $showCancelAlert) {
            Button("Ja, Fahrt stornieren", role: .destructive) {
                dismiss()
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Möchtest du die Fahrt wirklich abbrechen?")
        }
        .sheet(isPresented: $showPaymentView) {
            NavigationStack {
                PaymentView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Fertig") {
                                showPaymentView = false
                                dismiss()
                            }
                        }
                    }
            }
        }
    }

    private func continueToNext() {
        showPaymentView = true
    }

    func startTaxiAnimation() {
        let steps = 100
        let startLat = taxiCoordinate.latitude
        let startLon = taxiCoordinate.longitude
        let latStep = (destination.latitude - startLat) / Double(steps)
        let lonStep = (destination.longitude - startLon) / Double(steps)

        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                withAnimation(.linear(duration: 0.05)) {
                    self.taxiCoordinate = CLLocationCoordinate2D(
                        latitude: startLat + Double(i) * latStep,
                        longitude: startLon + Double(i) * lonStep
                    )
                }
            }
        }
    }
}
