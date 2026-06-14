import SwiftUI

struct DriverBottomSheet: View {
    @EnvironmentObject private var profileStore: DriverProfileStore
    let driver: TaxiDriver
    /// Wird ausgeführt, wenn der Nutzer „Weiter“ tippt (z. B. Fahrt verfolgen / MovingTaxiView).
    var onWeiterTapped: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .frame(width: 40, height: 6)
                .foregroundColor(.secondary)
                .padding(.top, 10)

            HStack {
                VStack(alignment: .leading) {
                    Text("Dein Fahrer ist unterwegs")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Text(profileStore.resolvedDisplayName)
                        .font(.largeTitle)
                        .bold()
                }
                Spacer()
                DriverAvatarView(
                    profileImage: profileStore.profileImage,
                    fallbackImageName: driver.photoImageName,
                    size: 60
                )
            }

            Divider()

            HStack(spacing: 40) {
                VStack {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Brand.secondary)
                    Text("4.9").bold()
                }
                VStack {
                    Image(systemName: "car.fill").foregroundStyle(Brand.secondary)
                    Text("B-TX 2026").bold()
                }
                VStack {
                    Image(systemName: "clock.fill").foregroundStyle(Brand.secondary)
                    Text("4 Min.").bold()
                }
            }

            Button(action: {
                guard let phone = driver.phoneNumber,
                      !phone.isEmpty,
                      let url = URL(string: "tel:\(phone)"),
                      UIApplication.shared.canOpenURL(url) else { return }
                UIApplication.shared.open(url)
            }) {
                Label("Fahrer kontaktieren", systemImage: "phone.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Brand.secondary)
                    .cornerRadius(15)
            }
            .disabled(driver.phoneNumber == nil || driver.phoneNumber?.isEmpty == true)

            if onWeiterTapped != nil {
                Button(action: { onWeiterTapped?() }) {
                    Text("Weiter")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Brand.primary)
                        .cornerRadius(15)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 25)
        .padding(.bottom, 40)
    }
}
