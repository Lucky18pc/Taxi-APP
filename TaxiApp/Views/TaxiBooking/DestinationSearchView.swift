import SwiftUI
import MapKit

struct DestinationSearchView: View {
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []

    var body: some View {
        VStack {
            TextField("Wo soll es hingehen?", text: $searchText, onCommit: {
                performSearch()
            })
            .padding()
            .background(Brand.background)
            .cornerRadius(10)
            .padding()

            if !searchResults.isEmpty {
                List(Array(searchResults.enumerated()), id: \.offset) { _, item in
                    Button(action: {
                        print("Ziel ausgewählt: \(item.name ?? "Unbekannt")")
                    }) {
                        VStack(alignment: .leading) {
                            Text(item.name ?? "").font(.headline)
                            Text(item.placemark.title ?? "").font(.subheadline).foregroundColor(.gray)
                        }
                    }
                }
                .frame(height: 200)
            }
        }
    }

    func performSearch() {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText

        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            self.searchResults = response?.mapItems ?? []
        }
    }
}
