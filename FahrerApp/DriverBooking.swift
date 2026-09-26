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
    let destinationLatitude: Double?
    let destinationLongitude: Double?
    let status: String
    let createdAt: String?
    let estimatedFare: Double?
    let estimatedEarnings: Double?
    let offerExpiresAt: String?
    let dispatch: DispatchInfo?

    var id: String { bookingId }

    var titleLine: String {
        if let destinationAddressLine, !destinationAddressLine.isEmpty {
            return "\(addressLine) → \(destinationAddressLine)"
        }
        return addressLine
    }

    var isActiveOffer: Bool {
        dispatch?.status == "offering" || offerExpiresAt != nil
    }

    struct DispatchInfo: Decodable {
        let status: String?
        let offerDriverId: String?
        let expiresAt: String?
        let timeoutMs: Int?
        let attempt: Int?
    }
}

struct OpenBookingsResponse: Decodable {
    let bookings: [DriverBooking]
}
