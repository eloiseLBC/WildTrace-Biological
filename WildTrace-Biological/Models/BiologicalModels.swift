import Foundation

struct BiologicalDayPayload: Codable {
    let schemaVersion: String
    let source: BiologicalSource
    let date: String
    let timezone: String
    let generatedAt: String
    let range: TimeRange
    let biologicalData: BiologicalData
    let syncMetadata: SyncMetadata
    
    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case source
        case date
        case timezone
        case generatedAt = "generated_at"
        case range
        case biologicalData = "biological_data"
        case syncMetadata = "sync_metadata"
    }
}

struct BiologicalSource: Codable {
    let device: String
    let platform: String
    let app: String
}

struct TimeRange: Codable {
    let start: String
    let end: String
}

struct BiologicalData: Codable {
    let heartRate5Min: [StatisticsBucket]
    let hrvSamples: [QuantitySample]
    let oxygenSaturationSamples: [QuantitySample]
    let respiratoryRateSamples: [QuantitySample]
    let stepsHourly: [StatisticsBucket]
    let activeEnergyHourly: [StatisticsBucket]
    let basalEnergyHourly: [StatisticsBucket]
    let distanceWalkingRunningHourly: [StatisticsBucket]
    let sleepSegments: [SleepSegment]
    let workouts: [Workout]
    
    enum CodingKeys: String, CodingKey {
        case heartRate5Min = "heart_rate_5min"
        case hrvSamples = "hrv_samples"
        case oxygenSaturationSamples = "oxygen_saturation_samples"
        case respiratoryRateSamples = "respiratory_rate_samples"
        case stepsHourly = "steps_hourly"
        case activeEnergyHourly = "active_energy_hourly"
        case basalEnergyHourly = "basal_energy_hourly"
        case distanceWalkingRunningHourly = "distance_walking_running_hourly"
        case sleepSegments = "sleep_segments"
        case workouts
    }
}

struct QuantitySample: Codable {
    let start: String
    let end: String
    let value: Double
    let unit: String
    let source: String
}

struct StatisticsBucket: Codable {
    let start: String
    let end: String
    let average: Double?
    let min: Double?
    let max: Double?
    let sum: Double?
    let unit: String
}

struct SleepSegment: Codable {
    let start: String
    let end: String
    let stage: String
    let durationMinutes: Double
    let source: String
    
    enum CodingKeys: String, CodingKey {
        case start
        case end
        case stage
        case durationMinutes = "duration_minutes"
        case source
    }
}

struct Workout: Codable {
    let start: String
    let end: String
    let activityType: String
    let durationMinutes: Double
    let totalEnergyKcal: Double?
    let totalDistanceMeters: Double?
    let source: String
    
    enum CodingKeys: String, CodingKey {
        case start
        case end
        case activityType = "activity_type"
        case durationMinutes = "duration_minutes"
        case totalEnergyKcal = "total_energy_kcal"
        case totalDistanceMeters = "total_distance_meters"
        case source
    }
}

struct SyncMetadata: Codable {
    let syncType: String
    let targetRawObjectPath: String
    let targetComputedObjectPath: String
    
    enum CodingKeys: String, CodingKey {
        case syncType = "sync_type"
        case targetRawObjectPath = "target_raw_object_path"
        case targetComputedObjectPath = "target_computed_object_path"
    }
}
