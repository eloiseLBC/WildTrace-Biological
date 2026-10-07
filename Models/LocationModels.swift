import Foundation

struct CollectionLocation: Codable {
    let timestamp: String
    let latitude: Double
    let longitude: Double
    let horizontalAccuracyMeters: Double
    let source: String

    enum CodingKeys: String, CodingKey {
        case timestamp, latitude, longitude, source
        case horizontalAccuracyMeters = "horizontal_accuracy_meters"
    }
}

struct CityCountry: Codable {
    var city: String? = nil
    var country: String? = nil
    var formattedAddress: String? = nil
    var aquaticLocation: String? = nil

    enum CodingKeys: String, CodingKey {
        case city, country
        case formattedAddress = "formatted_address"
        case aquaticLocation = "aquatic_location"
    }
}

struct LocationMetadata: Codable {
    let capturedAt: String
    let source: String
    let method: String
    let horizontalAccuracyMeters: Double

    init(_ location: CollectionLocation) {
        capturedAt = location.timestamp
        source = location.source
        method = "capture_at_collection"
        horizontalAccuracyMeters = location.horizontalAccuracyMeters
    }

    enum CodingKeys: String, CodingKey {
        case source, method
        case capturedAt = "captured_at"
        case horizontalAccuracyMeters = "horizontal_accuracy_meters"
    }
}
