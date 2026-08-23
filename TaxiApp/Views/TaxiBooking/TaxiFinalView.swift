import SwiftUI
import MapKit
import CoreLocation

struct TaxiFinalView: View {
    @State private var route: MKRoute?
    @State private var showPaymentSheet = false

    private let fareCalculator = FareCalculator()

    private var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 52.520, longitude: 13.405),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    }

    init(route: MKRoute? = nil) {
        _route = State(initialValue: route)
    }

    var body: some View {
        VStack(spacing: 0) {
            TaxiCompanyHeaderView(logoImageName: TaxiConfig.logoImageName, showTime: true)

            Map(coordinateRegion: .constant(region), showsUserLocation: true)
                .frame(height: 200)
                .ignoresSafeArea(edges: .top)

            if let calculatedRoute = route {
                let result = fareCalculator.calculateFare(distanceInMeters: calculatedRoute.distance)
                VStack(spacing: 15) {
                    HStack {
                        Image(systemName: result.isNight ? "moon.stars.fill" : "sun.max.fill")
                            .font(.title2)
                            .foregroundStyle(Brand.primary)
                        VStack(alignment: .leading) {
                            Text(result.isNight ? "Nachttarif aktiv" : "Tagtarif aktiv")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(String(format: "%.2f", result.price)) €")
                                .font(.title2).bold()
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Distanz")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Text("\(String(format: "%.1f", calculatedRoute.distance / 1000)) km")
                                .font(.title3)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(15)

                    Button(action: {
                        showPaymentSheet = true
                    }) {
                        HStack {
                            Image(systemName: "car.fill")
                            Text("Taxi bestellen")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Brand.primary)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                    }
                }
                .padding()
                .transition(.move(edge: .bottom))
            } else {
                Text("Route wird berechnet…")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .sheet(isPresented: $showPaymentSheet) {
            PaymentView()
        }
    }
}
