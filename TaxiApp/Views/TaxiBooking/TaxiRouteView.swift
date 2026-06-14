import SwiftUI
import MapKit
import CoreLocation

struct TaxiRouteView: View {
    @State private var userLocation = CLLocationCoordinate2D(latitude: 52.520, longitude: 13.405)
    @State private var taxiLocation = CLLocationCoordinate2D(latitude: 52.530, longitude: 13.415)

    @State private var route: MKRoute?
    @State private var position = MapCameraPosition.region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 52.525, longitude: 13.410),
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    ))

    var body: some View {
        VStack(spacing: 0) {
            TaxiCompanyHeaderView(logoImageName: TaxiConfig.logoImageName, showTime: true)

        Map(position: $position) {
            if let route = route {
                MapPolyline(route)
                    .stroke(.blue, lineWidth: 5)
            }
            Annotation("Dein Taxi", coordinate: taxiLocation) {
                Image(systemName: "car.fill")
                    .font(.title2)
                    .foregroundStyle(Brand.primary)
                    .padding(6)
                    .background(Color(.systemGray2), in: Circle())
            }
            Marker("Du", coordinate: userLocation)
                .tint(.blue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onAppear {
            calculateRoute()
        }
        }
    }

    func calculateRoute() {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: taxiLocation))
        request.transportType = .automobile

        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            if let route = response?.routes.first {
                self.route = route
            }
        }
    }
}
