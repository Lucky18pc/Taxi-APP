import Foundation

struct FareCalculator {
    let basePriceDay = 3.90
    let pricePerKmDay = 2.30

    let basePriceNight = 4.90
    let pricePerKmNight = 2.60

    /// Phase-4-Formel: Grundpreis + (Kilometer * Kilometertarif).
    /// Nachtfenster 22–6 Uhr in Europe/Berlin (wie Backend `FARE_TIMEZONE`).
    func calculateFare(distanceInMeters: Double) -> (price: Double, isNight: Bool) {
        let distanceInKm = distanceInMeters / 1000
        let berlin = TimeZone(identifier: "Europe/Berlin") ?? .current
        let isNight = NightSurcharge.applies(
            pickupDate: Date(),
            enabled: true,
            timeZone: berlin
        )

        let finalPrice: Double
        if isNight {
            finalPrice = basePriceNight + (distanceInKm * pricePerKmNight)
        } else {
            finalPrice = basePriceDay + (distanceInKm * pricePerKmDay)
        }

        return (finalPrice, isNight)
    }

    func calculateFinalFare(distanceInMeters: Double, isNight: Bool, vehicle: VehicleType) -> Double {
        let distanceInKm = distanceInMeters / 1000
        let basePrice = isNight ? basePriceNight : basePriceDay
        let pricePerKm = isNight ? pricePerKmNight : pricePerKmDay
        return basePrice + (distanceInKm * pricePerKm) + vehicle.surcharge
    }
}
