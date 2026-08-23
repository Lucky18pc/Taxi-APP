import CoreLocation
import MapKit

struct ParsedAddress: Equatable {
    var street: String
    var houseNumber: String
    var postalCode: String
    var city: String

    var isEmpty: Bool {
        [street, houseNumber, postalCode, city].allSatisfy {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var formattedLine: String {
        AddressComposer.formattedLine(
            street: street,
            houseNumber: houseNumber,
            postalCode: postalCode,
            city: city
        )
    }
}

enum AddressComposer {
    static func formattedLine(
        street: String,
        houseNumber: String,
        postalCode: String,
        city: String
    ) -> String {
        let streetName = street.trimmingCharacters(in: .whitespacesAndNewlines)
        let number = houseNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let postal = postalCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let locality = city.trimmingCharacters(in: .whitespacesAndNewlines)

        let streetPart = [streetName, number].filter { !$0.isEmpty }.joined(separator: " ")
        let cityPart = [postal, locality].filter { !$0.isEmpty }.joined(separator: " ")
        return [streetPart, cityPart].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

enum GeocodingService {
    static func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> String {
        let parsed = await reverseGeocodeParsed(coordinate: coordinate)
        if !parsed.formattedLine.isEmpty {
            return parsed.formattedLine
        }
        return String(format: "Standort (%.5f, %.5f)", coordinate.latitude, coordinate.longitude)
    }

    static func reverseGeocodeParsed(coordinate: CLLocationCoordinate2D) async -> ParsedAddress {
        if #available(iOS 26.0, *) {
            if let parsed = await reverseGeocodeWithMapKit(coordinate: coordinate), !parsed.isEmpty {
                return parsed
            }
        }

        return await reverseGeocodeWithCoreLocation(coordinate: coordinate)
    }

    /// Adresse → Koordinaten — nur Treffer in Europa (keine US-Staaten).
    static func forwardGeocode(addressLine: String) async -> CLLocationCoordinate2D? {
        let query = addressLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 3 else { return nil }
        return await searchCoordinate(query: query, preferLocality: query)
    }

    private static func searchCoordinate(query: String, preferLocality: String) async -> CLLocationCoordinate2D? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = europeBiasedQuery(query)
        request.region = TaxiConfig.europeSearchRegion

        do {
            let response = try await MKLocalSearch(request: request).start()
            if let item = bestEuropeanMatch(in: response.mapItems, preferring: preferLocality) {
                return item.placemark.coordinate
            }
        } catch {
            return nil
        }
        return nil
    }

    private static func bestEuropeanMatch(in items: [MKMapItem], preferring query: String) -> MKMapItem? {
        let europeanItems = items.filter { item in
            let coordinate = item.placemark.coordinate
            return CLLocationCoordinate2DIsValid(coordinate)
                && TaxiConfig.isInEurope(coordinate)
                && !TaxiConfig.isInAmericas(coordinate)
        }
        guard !europeanItems.isEmpty else { return nil }

        let needles = queryTokens(query)

        if let exactCity = europeanItems.first(where: { item in
            let tokens = placeTokens(for: item)
            return needles.contains(where: { tokens.contains($0) })
        }) {
            return exactCity
        }

        if let partialCity = europeanItems.first(where: { item in
            let tokens = placeTokens(for: item)
            return needles.contains(where: { needle in
                tokens.contains(where: { $0.contains(needle) || needle.contains($0) })
            })
        }) {
            return partialCity
        }

        return europeanItems.first
    }

    private static func queryTokens(_ query: String) -> [String] {
        query
            .split { $0 == "," || $0 == " " }
            .map { normalizedPlaceToken(String($0)) }
            .filter { $0.count >= 3 && $0 != "deutschland" }
    }

    private static func placeTokens(for item: MKMapItem) -> [String] {
        let placemark = item.placemark
        return [
            placemark.locality,
            placemark.subLocality,
            placemark.administrativeArea,
            placemark.name,
            item.name
        ]
        .compactMap { $0 }
        .map(normalizedPlaceToken)
        .filter { !$0.isEmpty }
    }

    private static func normalizedPlaceToken(_ value: String) -> String {
        value
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: TaxiConfig.mapLocale)
            .replacingOccurrences(of: ", deutschland", with: "")
            .replacingOccurrences(of: " deutschland", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func europeBiasedQuery(_ query: String) -> String {
        let lower = query.lowercased()
        if lower.contains("deutschland")
            || lower.contains("germany")
            || lower.range(of: #"\b\d{5}\b"#, options: .regularExpression) != nil {
            return query
        }
        return "\(query), Deutschland"
    }

    /// Beste verfügbare Koordinate: zuerst Adresse suchen, sonst Karten-Pin.
    static func resolvePickupCoordinate(
        mapCenter: CLLocationCoordinate2D,
        addressLine: String
    ) async -> CLLocationCoordinate2D {
        let trimmed = addressLine.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmed.isEmpty, let searched = await forwardGeocode(addressLine: trimmed) {
            return searched
        }

        if TaxiConfig.isInEurope(mapCenter),
           !TaxiConfig.isInAmericas(mapCenter),
           !TaxiConfig.isLikelyUnsetPickupCoordinate(mapCenter) {
            return mapCenter
        }

        return TaxiConfig.defaultMapCenter
    }

    @available(iOS 26.0, *)
    private static func reverseGeocodeWithMapKit(coordinate: CLLocationCoordinate2D) async -> ParsedAddress? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
        request.preferredLocale = TaxiConfig.mapLocale

        do {
            let mapItems = try await request.mapItems
            guard let mapItem = mapItems.first else { return nil }
            return parsedAddress(from: mapItem)
        } catch {
            return nil
        }
    }

    private static func reverseGeocodeWithCoreLocation(coordinate: CLLocationCoordinate2D) async -> ParsedAddress {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            let places = try await geocoder.reverseGeocodeLocation(
                location,
                preferredLocale: Locale(identifier: "de_DE")
            )
            if let place = places.first {
                return parsedAddress(from: place)
            }
        } catch {
            // Fallback unten
        }

        return ParsedAddress(street: "", houseNumber: "", postalCode: "", city: "")
    }

    static func parsedAddress(from place: CLPlacemark) -> ParsedAddress {
        ParsedAddress(
            street: place.thoroughfare ?? "",
            houseNumber: place.subThoroughfare ?? "",
            postalCode: place.postalCode ?? "",
            city: place.locality ?? place.subAdministrativeArea ?? place.administrativeArea ?? ""
        )
    }

    @available(iOS 26.0, *)
    static func parsedAddress(from mapItem: MKMapItem) -> ParsedAddress {
        let placemark = mapItem.placemark
        let fromPlacemark = parsedAddress(from: placemark as CLPlacemark)
        if !fromPlacemark.isEmpty {
            return fromPlacemark
        }

        return parsedAddress(
            shortAddress: mapItem.address?.shortAddress,
            fullAddress: mapItem.address?.fullAddress,
            cityName: mapItem.addressRepresentations?.cityName
        )
    }

    static func parsedAddress(
        shortAddress: String?,
        fullAddress: String?,
        cityName: String?
    ) -> ParsedAddress {
        let short = shortAddress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let full = fullAddress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let city = cityName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        var postalCode = ""
        var street = short
        let source = full.isEmpty ? short : full

        if let match = source.range(of: #"\b\d{5}\b"#, options: .regularExpression) {
            postalCode = String(source[match])
        }

        if street.isEmpty, !full.isEmpty {
            street = full
                .components(separatedBy: ",")
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? full
        }

        var resolvedCity = city
        if resolvedCity.isEmpty, !full.isEmpty {
            let parts = full
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            if parts.count >= 2 {
                let cityPart = parts[parts.count - (parts.last?.contains(postalCode) == true ? 2 : 1)]
                resolvedCity = cityPart.replacingOccurrences(of: postalCode, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        let (parsedStreet, parsedHouseNumber) = splitStreetAndHouseNumber(street)

        return ParsedAddress(
            street: parsedStreet,
            houseNumber: parsedHouseNumber,
            postalCode: postalCode,
            city: resolvedCity
        )
    }

    private static func splitStreetAndHouseNumber(_ value: String) -> (String, String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ("", "") }

        guard let regex = try? NSRegularExpression(pattern: #"^(.+?)\s+(\d+\w*)$"#),
              let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
              match.numberOfRanges == 3,
              let streetRange = Range(match.range(at: 1), in: trimmed),
              let numberRange = Range(match.range(at: 2), in: trimmed)
        else {
            return (trimmed, "")
        }

        return (String(trimmed[streetRange]), String(trimmed[numberRange]))
    }
}
