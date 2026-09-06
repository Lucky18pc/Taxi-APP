import SwiftUI
import CoreLocation

struct TaxiBookingView: View {
    @State private var nearestDriver = TaxiDriver(
        name: "Markus",
        coordinate: CLLocationCoordinate2D(latitude: 52.52, longitude: 13.40)
    )

    @State private var isSearching = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Deine Taxi App")
                .font(.largeTitle)
                .bold()

            Spacer()

            VStack {
                Image(systemName: "car.fill")
                    .resizable()
                    .frame(width: 100, height: 60)
                    .foregroundStyle(Brand.primary)

                Text(nearestDriver.name)
                    .font(.title2)
            }
            .padding()
            .background(Brand.background)
            .cornerRadius(20)

            Spacer()

            Button(action: {
                isSearching.toggle()
            }) {
                Text(isSearching ? "Suche Fahrer..." : "Jetzt Taxi rufen")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isSearching ? Color.gray : Color(.systemGray2))
                    .cornerRadius(15)
            }
        }
        .padding()
    }
}
