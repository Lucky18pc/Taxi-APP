//
//  DriverBooking.swift
//  Luckys Taxi Fahrer
//

import Foundation

struct DriverBooking: Identifiable, Decodable {
    let bookingId: String
    let pickupDate: String?
    let addressLine: String
    let destinationAddressLine: String?
    let paymentMethod: String?
    let latitude: Double?
    let longitude: Double?
    let status: String
    let createdAt: String?

    var id: String { bookingId }

    var titleLine: String {
        if let destinationAddressLine, !destinationAddressLine.isEmpty {
            return "\(addressLine) → \(destinationAddressLine)"
        }
        return addressLine
    }
}

struct OpenBookingsResponse: Decodable {
    let bookings: [DriverBooking]
}
