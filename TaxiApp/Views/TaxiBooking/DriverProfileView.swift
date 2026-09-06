import PhotosUI
import SwiftUI
import UIKit

struct DriverProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var centralStore: CentralConfigStore
    @ObservedObject var store: DriverProfileStore

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var nameDraft = ""
    @State private var centralPhoneDraft = ""
    @FocusState private var focusedField: Field?

    private enum Field {
        case name, centralPhone
    }

    private var canUseCamera: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    profileHero

                    VStack(alignment: .leading, spacing: 8) {
                        profileLabel("Fahrername")
                        profileFieldRow(
                            text: $nameDraft,
                            placeholder: "z. B. Lucky",
                            field: .name,
                            onClear: {
                                nameDraft = ""
                                store.updateDisplayName("")
                            }
                        )
                    }
                    .profileNavyCard()
                    .padding(.horizontal, 20)

                    VStack(alignment: .leading, spacing: 8) {
                        profileLabel("Leitstellen-Nummer")
                        profileFieldRow(
                            text: $centralPhoneDraft,
                            placeholder: "z. B. +49 30 12345678",
                            field: .centralPhone,
                            keyboard: .phonePad,
                            onClear: {
                                centralPhoneDraft = ""
                                centralStore.resetLocalPhone()
                            }
                        )
                        Text("Leer = Nummer aus der Cloud-Leitstelle (settings.html)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.82))
                    }
                    .profileNavyCard()
                    .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            ProfilePrimaryButtonLabel(
                                title: "Aus Galerie wählen",
                                systemImage: "photo.on.rectangle"
                            )
                        }

                        if canUseCamera {
                            Button {
                                showCamera = true
                            } label: {
                                ProfilePrimaryButtonLabel(
                                    title: "Foto aufnehmen",
                                    systemImage: "camera.fill"
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        if store.profileImage != nil {
                            Button(role: .destructive) {
                                store.removeProfileImage()
                            } label: {
                                Label("Profilfoto entfernen", systemImage: "trash")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .foregroundStyle(.red)
                                    .background(Brand.card)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color.red.opacity(0.35), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }

                        Button(role: .destructive) {
                            store.resetToDefault()
                            centralStore.resetLocalPhone()
                            nameDraft = store.displayName
                            centralPhoneDraft = ""
                        } label: {
                            Text("Standard wiederherstellen")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Brand.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)

                    LegalLinksSection(onNavyBackground: true)
                        .profileNavyCard()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                }
            }
            .background(Brand.background.ignoresSafeArea())
            .navigationTitle("Profil & Zentrale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Brand.primary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        focusedField = nil
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                }
            }
            .onAppear {
                nameDraft = store.displayName
                centralPhoneDraft = centralStore.localPhoneOverride
            }
            .onChange(of: nameDraft) { _, newValue in
                store.updateDisplayName(newValue)
            }
            .onChange(of: centralPhoneDraft) { _, newValue in
                centralStore.updateLocalPhone(newValue)
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        store.saveProfileImage(image)
                    }
                    selectedPhotoItem = nil
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraImagePicker { image in
                    store.saveProfileImage(image)
                }
                .ignoresSafeArea()
            }
        }
    }

    private var profileHero: some View {
        VStack(spacing: 10) {
            DriverAvatarView(
                profileImage: store.profileImage,
                fallbackImageName: store.fallbackImageName,
                size: 148,
                showBorder: true,
                faceZoom: 0.88
            )
            .circleRingShimmer(lineWidth: 4, intensity: 0.95)
            .shadow(color: Brand.primary.opacity(0.35), radius: 10, y: 4)
            .padding(.top, 8)

            if store.resolvedDisplayName.isEmpty {
                Text("Name und Foto für die Startseite")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Brand.secondary)
            } else {
                Text(store.resolvedDisplayName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Brand.primary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private func profileLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
    }

    private func profileFieldRow(
        text: Binding<String>,
        placeholder: String,
        field: Field,
        keyboard: UIKeyboardType = .default,
        onClear: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: text)
                .textInputAutocapitalization(field == .name ? .words : .never)
                .autocorrectionDisabled()
                .keyboardType(keyboard)
                .textContentType(field == .centralPhone ? .telephoneNumber : .name)
                .focused($focusedField, equals: field)
                .submitLabel(field == .name ? .next : .done)
                .onSubmit {
                    focusedField = field == .name ? .centralPhone : nil
                }
                .profileTextField()

            if !text.wrappedValue.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Brand.primary.opacity(0.55))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Eingabe löschen")
            }
        }
    }

}

private struct ProfilePrimaryButtonLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(.white)
            .background(Brand.primary)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: Brand.primary.opacity(0.25), radius: 6, y: 2)
    }
}

private struct ProfileNavyCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Brand.primary)
            .clipShape(RoundedRectangle(cornerRadius: Brand.cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.14), radius: 8, y: 3)
    }
}

private struct ProfileTextFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.body.weight(.medium))
            .foregroundStyle(Brand.primary)
            .tint(Brand.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Brand.card)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private extension View {
    func profileNavyCard() -> some View {
        modifier(ProfileNavyCardModifier())
    }

    func profileTextField() -> some View {
        modifier(ProfileTextFieldModifier())
    }
}

#Preview {
    DriverProfileView(store: DriverProfileStore())
        .environmentObject(CentralConfigStore())
}
