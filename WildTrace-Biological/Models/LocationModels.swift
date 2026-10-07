import Foundation

struct LocationSample: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let latitude: Double
    let longitude: Double
    let horizontalAccuracyMeters: Double
    let source: String

    enum CodingKeys: String, CodingKey {
        case id, timestamp, latitude, longitude, source
        case horizontalAccuracyMeters = "horizontal_accuracy_meters"
    }
}

struct CityCountry: Codable {
    let city: String?
    let country: String?
    let formattedAddress: String?
    let aquaticLocation: String?

    static let empty = CityCountry(
        city: nil,
        country: nil,
        formattedAddress: nil,
        aquaticLocation: nil
    )

    enum CodingKeys: String, CodingKey {
        case city, country
        case formattedAddress = "formatted_address"
        case aquaticLocation = "aquatic_location"
    }

    var groupingKey: String? {
        if let city, let country {
            return "city:\(country.lowercased())|\(city.lowercased())"
        }

        if let aquaticLocation {
            return "water:\(aquaticLocation.lowercased())"
        }

        return nil
    }
}
