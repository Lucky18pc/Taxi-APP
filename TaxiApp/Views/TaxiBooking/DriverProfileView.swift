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
            VStack(spacing: 20) {
                DriverAvatarView(
                    profileImage: store.profileImage,
                    fallbackImageName: store.fallbackImageName,
                    size: 88,
                    showBorder: true
                )
                .padding(.top, 8)

                if store.resolvedDisplayName.isEmpty {
                    Text("Name und Foto für die Startseite")
                        .font(.caption)
                        .foregroundStyle(Brand.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Fahrername")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Brand.secondary)

                    HStack(spacing: 8) {
                        TextField("Name eingeben", text: $nameDraft)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .name)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .centralPhone }

                        if !nameDraft.isEmpty {
                            Button {
                                nameDraft = ""
                                store.updateDisplayName("")
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Name löschen")
                        }
                    }
                    .brandTextField()
                }
                .brandCard()
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Leitstellen-Nummer")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Brand.secondary)

                    HStack(spacing: 8) {
                        TextField("z. B. 030 12345678", text: $centralPhoneDraft)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                            .focused($focusedField, equals: .centralPhone)
                            .submitLabel(.done)
                            .onSubmit { focusedField = nil }

                        if !centralPhoneDraft.isEmpty {
                            Button {
                                centralPhoneDraft = ""
                                centralStore.resetLocalPhone()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Nummer löschen")
                        }
                    }
                    .brandTextField()

                    Text("Leer = Nummer aus der Cloud-Leitstelle (settings.html)")
                        .font(.caption2)
                        .foregroundStyle(Brand.secondary.opacity(0.9))
                }
                .brandCard()
                .padding(.horizontal, 20)

                VStack(spacing: 12) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("Aus Galerie wählen", systemImage: "photo.on.rectangle")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Brand.primary.opacity(0.1))
                            .foregroundStyle(Brand.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    if canUseCamera {
                        Button {
                            showCamera = true
                        } label: {
                            Label("Foto aufnehmen", systemImage: "camera.fill")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Brand.primary)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .background(Brand.background)
            .navigationTitle("Profil & Zentrale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        focusedField = nil
                        dismiss()
                    }
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
}

private struct BrandTextFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.body.weight(.medium))
            .foregroundStyle(Brand.primary)
            .tint(Brand.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Brand.primary.opacity(0.22), lineWidth: 1)
            }
    }
}

private extension View {
    func brandTextField() -> some View {
        modifier(BrandTextFieldModifier())
    }
}

#Preview {
    DriverProfileView(store: DriverProfileStore())
        .environmentObject(CentralConfigStore())
}
