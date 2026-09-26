import SwiftUI

/// Adresssuche mit Places Autocomplete (Backend → Google Places oder Nominatim).
struct DestinationSearchView: View {
    var title: String = "Wohin soll es gehen?"
    var onSelect: ((ResolvedPlace) -> Void)?

    @State private var searchText = ""
    @State private var predictions: [PlacePrediction] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(title, text: $searchText)
                .padding()
                .background(Brand.background)
                .cornerRadius(10)
                .onChange(of: searchText) { _, newValue in
                    scheduleSearch(newValue)
                }

            if isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if !predictions.isEmpty {
                List(predictions) { item in
                    Button {
                        Task { await select(item) }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.mainText.isEmpty ? item.description : item.mainText)
                                .font(.headline)
                                .foregroundStyle(Brand.primary)
                            if !item.secondaryText.isEmpty {
                                Text(item.secondaryText)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(height: min(CGFloat(predictions.count) * 56, 220))
            }
        }
        .padding(.horizontal)
    }

    private func scheduleSearch(_ query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            predictions = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { isSearching = true; errorMessage = nil }
            do {
                let list = try await PlacesAutocompleteService.autocomplete(query: trimmed)
                await MainActor.run {
                    predictions = list
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    @MainActor
    private func select(_ prediction: PlacePrediction) async {
        do {
            let place = try await PlacesAutocompleteService.resolve(prediction: prediction)
            searchText = place.address
            predictions = []
            onSelect?(place)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
