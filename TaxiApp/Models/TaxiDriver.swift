import Foundation
import CoreLocation

struct TaxiDriver: Identifiable {
    let id = UUID()
    let name: String
    var coordinate: CLLocationCoordinate2D
    var phoneNumber: String? = nil
    var photoImageName: String = TaxiConfig.driverPhotoImageName
}
