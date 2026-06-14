import SwiftUI
import MapKit
import CoreLocation

fileprivate struct IdentifiableMapItem: Identifiable {
    let id = UUID()
    let mapItem: MKMapItem
}

struct TaxiAppPro: View {
    @State private var searchText = ""
    @State private var searchResults: [IdentifiableMapItem] = []
    @State private var route: MKRoute?

    @State private var userLocation = CLLocationCoordinate2D(latitude: 52.520, longitude: 13.405)
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 52.520, longitude: 13.405),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    var body: some View {
        VStack {
            TextField("Wohin geht's?", text: $searchText)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding()
                .onChange(of: searchText) { _, newValue in
                    if newValue.isEmpty {
                        searchResults = []
                    } else {
                        performSearch()
                    }
                }

            ZStack {
                Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: searchResults) { item in
                    MapMarker(coordinate: item.mapItem.placemark.coordinate, tint: .red)
                }
                .ignoresSafeArea()

                if !searchResults.isEmpty && route == nil {
                    List(searchResults) { item in
                        Button(action: {
                            selectDestination(item)
                        }) {
                            VStack(alignment: .leading) {
                                Text(item.mapItem.name ?? "").bold()
                                Text(item.mapItem.placemark.title ?? "")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                    .background(Color.white)
                }
            }
        }
    }

    func performSearch() {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            self.searchResults = (response?.mapItems ?? []).map { IdentifiableMapItem(mapItem: $0) }
        }
    }

    fileprivate func selectDestination(_ item: IdentifiableMapItem) {
        let mapItem = item.mapItem
        searchResults = []
        searchText = mapItem.name ?? ""

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation))
        request.destination = mapItem
        request.transportType = .automobile

        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            if let route = response?.routes.first {
                self.route = route
                withAnimation {
                    region.center = mapItem.placemark.coordinate
                }
                print("Route gefunden: \(route.distance / 1000) km")
            }
        }
    }
}
