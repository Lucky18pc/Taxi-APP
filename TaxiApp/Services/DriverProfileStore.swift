import SwiftUI
import UIKit

@MainActor
final class DriverProfileStore: ObservableObject {
    @Published private(set) var profileImage: UIImage?
    @Published private(set) var displayName: String

    let fallbackImageName: String

    private static let imageFileName = "driver_profile.jpg"
    private static let displayNameKey = "driver_profile_display_name"

    /// Anzeigename — leerer gespeicherter Wert fällt auf Standard zurück.
    var resolvedDisplayName: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? TaxiConfig.defaultDriver.name : trimmed
    }

    init(
        fallbackImageName: String = TaxiConfig.driverPhotoImageName
    ) {
        self.fallbackImageName = fallbackImageName
        self.displayName = Self.loadSavedDisplayName() ?? TaxiConfig.defaultDriver.name
        self.profileImage = Self.loadSavedImage()
    }

    func updateDisplayName(_ name: String) {
        displayName = name
        UserDefaults.standard.set(name, forKey: Self.displayNameKey)
    }

    func saveProfileImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        let url = Self.profileImageURL
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
            profileImage = image
        } catch {
            print("DriverProfileStore save failed: \(error)")
        }
    }

    func resetToDefault() {
        try? FileManager.default.removeItem(at: Self.profileImageURL)
        profileImage = nil
        updateDisplayName(TaxiConfig.defaultDriver.name)
    }

    private static var profileImageURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent(imageFileName)
    }

    private static func loadSavedDisplayName() -> String? {
        UserDefaults.standard.string(forKey: displayNameKey)
    }

    private static func loadSavedImage() -> UIImage? {
        let url = profileImageURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }
}
