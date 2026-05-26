import Foundation

struct BiologicalDailySummary: Codable {
    let schemaVersion: String
    let date: String
    let timezone: String
    let generatedAt: String
    let sourceRawFile: String
    let summary: SummaryValues
    
    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case date
        case timezone
        case generatedAt = "generated_at"
        case sourceRawFile = "source_raw_file"
        case summary
    }
    
    static func from(_ payload: BiologicalDayPayload) -> BiologicalDailySummary {
        let data = payload.biologicalData
        
        let heartRateAverage = average(
            data.heartRate5Min.compactMap { $0.average }
        )
        
        let heartRateMin = data.heartRate5Min
            .compactMap { $0.min }
            .min()
        
        let heartRateMax = data.heartRate5Min
            .compactMap { $0.max }
            .max()
        
        let hrvAverage = average(
            data.hrvSamples.map { $0.value }
        )
        
        let oxygenSaturationAverage = average(
            data.oxygenSaturationSamples.map { $0.value }
        )
        
        let respiratoryRateAverage = average(
            data.respiratoryRateSamples.map { $0.value }
        )
        
        let stepsTotal = data.stepsHourly
            .compactMap { $0.sum }
            .reduce(0, +)
        
        let activeEnergyTotal = data.activeEnergyHourly
            .compactMap { $0.sum }
            .reduce(0, +)
        
        let basalEnergyTotal = data.basalEnergyHourly
            .compactMap { $0.sum }
            .reduce(0, +)
        
        let distanceTotal = data.distanceWalkingRunningHourly
            .compactMap { $0.sum }
            .reduce(0, +)
        
        let asleepStages: Set<String> = [
            "asleep_unspecified",
            "asleep_core",
            "asleep_deep",
            "asleep_rem"
        ]
        
        let sleepDurationHours = data.sleepSegments
            .filter { asleepStages.contains($0.stage) }
            .map { $0.durationMinutes }
            .reduce(0, +) / 60.0
        
        return BiologicalDailySummary(
            schemaVersion: "1.0.0",
            date: payload.date,
            timezone: payload.timezone,
            generatedAt: DateUtils.isoFormatter.string(from: Date()),
            sourceRawFile: payload.syncMetadata.targetRawObjectPath,
            summary: SummaryValues(
                heartRateAvg: heartRateAverage,
                heartRateMin: heartRateMin,
                heartRateMax: heartRateMax,
                hrvAvgMs: hrvAverage,
                oxygenSaturationAvgPercent: oxygenSaturationAverage,
                respiratoryRateAvg: respiratoryRateAverage,
                stepsTotal: stepsTotal,
                activeEnergyKcal: activeEnergyTotal,
                basalEnergyKcal: basalEnergyTotal,
                distanceWalkingRunningMeters: distanceTotal,
                sleepDurationHours: sleepDurationHours,
                workoutCount: data.workouts.count
            )
        )
    }
    
    private static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else {
            return nil
        }
        
        return values.reduce(0, +) / Double(values.count)
    }
}

struct SummaryValues: Codable {
    let heartRateAvg: Double?
    let heartRateMin: Double?
    let heartRateMax: Double?
    let hrvAvgMs: Double?
    let oxygenSaturationAvgPercent: Double?
    let respiratoryRateAvg: Double?
    let stepsTotal: Double
    let activeEnergyKcal: Double
    let basalEnergyKcal: Double
    let distanceWalkingRunningMeters: Double
    let sleepDurationHours: Double
    let workoutCount: Int
    
    enum CodingKeys: String, CodingKey {
        case heartRateAvg = "heart_rate_avg"
        case heartRateMin = "heart_rate_min"
        case heartRateMax = "heart_rate_max"
        case hrvAvgMs = "hrv_avg_ms"
        case oxygenSaturationAvgPercent = "oxygen_saturation_avg_percent"
        case respiratoryRateAvg = "respiratory_rate_avg"
        case stepsTotal = "steps_total"
        case activeEnergyKcal = "active_energy_kcal"
        case basalEnergyKcal = "basal_energy_kcal"
        case distanceWalkingRunningMeters = "distance_walking_running_meters"
        case sleepDurationHours = "sleep_duration_hours"
        case workoutCount = "workout_count"
    }
}
