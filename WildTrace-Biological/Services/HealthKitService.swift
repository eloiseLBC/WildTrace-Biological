import Foundation
import HealthKit

final class HealthKitService {
    
    private let healthStore = HKHealthStore()
    
    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        
        let quantityIdentifiers: [HKQuantityTypeIdentifier] = [
            HKQuantityTypeIdentifier.heartRate,
            HKQuantityTypeIdentifier.heartRateVariabilitySDNN,
            HKQuantityTypeIdentifier.oxygenSaturation,
            HKQuantityTypeIdentifier.respiratoryRate,
            HKQuantityTypeIdentifier.stepCount,
            HKQuantityTypeIdentifier.activeEnergyBurned,
            HKQuantityTypeIdentifier.basalEnergyBurned,
            HKQuantityTypeIdentifier.distanceWalkingRunning
        ]
        
        for identifier in quantityIdentifiers {
            if let type = HKObjectType.quantityType(forIdentifier: identifier) {
                types.insert(type)
            }
        }
        
        if let sleepType = HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier.sleepAnalysis) {
            types.insert(sleepType)
        }
        
        types.insert(HKObjectType.workoutType())
        
        return types
    }
    
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw WildTraceError.healthDataUnavailable
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(
                toShare: Set<HKSampleType>(),
                read: readTypes
            ) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: WildTraceError.authorizationDenied)
                }
            }
        }
    }
    
    func collectBiologicalDay(for day: Date) async throws -> BiologicalDayPayload {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            throw WildTraceError.invalidDateRange
        }
        
        let heartRate5Min = try await statisticsSeries(
            identifier: HKQuantityTypeIdentifier.heartRate,
            unit: HKUnit.count().unitDivided(by: HKUnit.minute()),
            options: HKStatisticsOptions([
                HKStatisticsOptions.discreteAverage,
                HKStatisticsOptions.discreteMin,
                HKStatisticsOptions.discreteMax
            ]),
            start: start,
            end: end,
            interval: DateComponents(minute: 5)
        )
        
        let stepsHourly = try await statisticsSeries(
            identifier: HKQuantityTypeIdentifier.stepCount,
            unit: HKUnit.count(),
            options: HKStatisticsOptions.cumulativeSum,
            start: start,
            end: end,
            interval: DateComponents(hour: 1)
        )
        
        let activeEnergyHourly = try await statisticsSeries(
            identifier: HKQuantityTypeIdentifier.activeEnergyBurned,
            unit: HKUnit.kilocalorie(),
            options: HKStatisticsOptions.cumulativeSum,
            start: start,
            end: end,
            interval: DateComponents(hour: 1)
        )
        
        let basalEnergyHourly = try await statisticsSeries(
            identifier: HKQuantityTypeIdentifier.basalEnergyBurned,
            unit: HKUnit.kilocalorie(),
            options: HKStatisticsOptions.cumulativeSum,
            start: start,
            end: end,
            interval: DateComponents(hour: 1)
        )
        
        let distanceHourly = try await statisticsSeries(
            identifier: HKQuantityTypeIdentifier.distanceWalkingRunning,
            unit: HKUnit.meter(),
            options: HKStatisticsOptions.cumulativeSum,
            start: start,
            end: end,
            interval: DateComponents(hour: 1)
        )
        
        let hrvSamples = try await quantitySamples(
            identifier: HKQuantityTypeIdentifier.heartRateVariabilitySDNN,
            unit: HKUnit.secondUnit(with: HKMetricPrefix.milli),
            start: start,
            end: end,
            multiplier: 1.0
        )
        
        let oxygenSaturationSamples = try await quantitySamples(
            identifier: HKQuantityTypeIdentifier.oxygenSaturation,
            unit: HKUnit.percent(),
            start: start,
            end: end,
            multiplier: 100.0
        )
        
        let respiratoryRateSamples = try await quantitySamples(
            identifier: HKQuantityTypeIdentifier.respiratoryRate,
            unit: HKUnit.count().unitDivided(by: HKUnit.minute()),
            start: start,
            end: end,
            multiplier: 1.0
        )
        
        let sleepSegments = try await sleepSamples(start: start, end: end)
        let workouts = try await workoutSamples(start: start, end: end)
        
        let dayString = DateUtils.dayFormatter.string(from: start)
        
        return BiologicalDayPayload(
            schemaVersion: "1.0.0",
            source: BiologicalSource(
                device: "Apple Watch / iPhone",
                platform: "HealthKit",
                app: "WildTrace Biological iOS"
            ),
            date: dayString,
            timezone: TimeZone.current.identifier,
            generatedAt: DateUtils.isoFormatter.string(from: Date()),
            range: TimeRange(
                start: DateUtils.isoFormatter.string(from: start),
                end: DateUtils.isoFormatter.string(from: end)
            ),
            biologicalData: BiologicalData(
                heartRate5Min: heartRate5Min,
                hrvSamples: hrvSamples,
                oxygenSaturationSamples: oxygenSaturationSamples,
                respiratoryRateSamples: respiratoryRateSamples,
                stepsHourly: stepsHourly,
                activeEnergyHourly: activeEnergyHourly,
                basalEnergyHourly: basalEnergyHourly,
                distanceWalkingRunningHourly: distanceHourly,
                sleepSegments: sleepSegments,
                workouts: workouts
            ),
            syncMetadata: SyncMetadata(
                syncType: "manual_date_range",
                targetRawObjectPath: "collected/to_compute/biological_raw_\(dayString).json",
                targetComputedObjectPath: "collected/computed/biological_daily_\(dayString).json"
            )
        )
    }
    
    private func quantitySamples(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date,
        multiplier: Double
    ) async throws -> [QuantitySample] {
        
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            throw WildTraceError.missingHealthKitType(identifier.rawValue)
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: HKQueryOptions.strictStartDate
        )
        
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: true
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let result = (samples as? [HKQuantitySample] ?? []).map { sample in
                    QuantitySample(
                        start: DateUtils.isoFormatter.string(from: sample.startDate),
                        end: DateUtils.isoFormatter.string(from: sample.endDate),
                        value: sample.quantity.doubleValue(for: unit) * multiplier,
                        unit: Self.displayUnit(for: identifier),
                        source: sample.sourceRevision.source.name
                    )
                }
                
                continuation.resume(returning: result)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func statisticsSeries(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        options: HKStatisticsOptions,
        start: Date,
        end: Date,
        interval: DateComponents
    ) async throws -> [StatisticsBucket] {
        
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            throw WildTraceError.missingHealthKitType(identifier.rawValue)
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: HKQueryOptions.strictStartDate
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: options,
                anchorDate: start,
                intervalComponents: interval
            )
            
            query.initialResultsHandler = { _, collection, error in
                
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let collection else {
                    continuation.resume(returning: [])
                    return
                }
                
                var buckets: [StatisticsBucket] = []
                
                collection.enumerateStatistics(from: start, to: end) { statistics, _ in
                    let average = statistics.averageQuantity()?.doubleValue(for: unit)
                    let min = statistics.minimumQuantity()?.doubleValue(for: unit)
                    let max = statistics.maximumQuantity()?.doubleValue(for: unit)
                    let sum = statistics.sumQuantity()?.doubleValue(for: unit)
                    
                    if average != nil || min != nil || max != nil || sum != nil {
                        buckets.append(
                            StatisticsBucket(
                                start: DateUtils.isoFormatter.string(from: statistics.startDate),
                                end: DateUtils.isoFormatter.string(from: statistics.endDate),
                                average: average,
                                min: min,
                                max: max,
                                sum: sum,
                                unit: Self.displayUnit(for: identifier)
                            )
                        )
                    }
                }
                
                continuation.resume(returning: buckets)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func sleepSamples(start: Date, end: Date) async throws -> [SleepSegment] {
        guard let type = HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier.sleepAnalysis) else {
            throw WildTraceError.missingHealthKitType("sleepAnalysis")
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: []
        )
        
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: true
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let result = (samples as? [HKCategorySample] ?? []).map { sample in
                    SleepSegment(
                        start: DateUtils.isoFormatter.string(from: sample.startDate),
                        end: DateUtils.isoFormatter.string(from: sample.endDate),
                        stage: Self.sleepStageName(sample.value),
                        durationMinutes: sample.endDate.timeIntervalSince(sample.startDate) / 60.0,
                        source: sample.sourceRevision.source.name
                    )
                }
                
                continuation.resume(returning: result)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func workoutSamples(start: Date, end: Date) async throws -> [Workout] {
        let type = HKObjectType.workoutType()
        
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: HKQueryOptions.strictStartDate
        )
        
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: true
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let result = (samples as? [HKWorkout] ?? []).map { workout in
                    Workout(
                        start: DateUtils.isoFormatter.string(from: workout.startDate),
                        end: DateUtils.isoFormatter.string(from: workout.endDate),
                        activityType: workout.workoutActivityType.wildTraceName,
                        durationMinutes: workout.duration / 60.0,
                        totalEnergyKcal: workout.totalEnergyBurned?.doubleValue(for: HKUnit.kilocalorie()),
                        totalDistanceMeters: workout.totalDistance?.doubleValue(for: HKUnit.meter()),
                        source: workout.sourceRevision.source.name
                    )
                }
                
                continuation.resume(returning: result)
            }
            
            healthStore.execute(query)
        }
    }
    
    private static func displayUnit(for identifier: HKQuantityTypeIdentifier) -> String {
        switch identifier {
        case HKQuantityTypeIdentifier.heartRate:
            return "count/min"
        case HKQuantityTypeIdentifier.heartRateVariabilitySDNN:
            return "ms"
        case HKQuantityTypeIdentifier.oxygenSaturation:
            return "%"
        case HKQuantityTypeIdentifier.respiratoryRate:
            return "count/min"
        case HKQuantityTypeIdentifier.stepCount:
            return "count"
        case HKQuantityTypeIdentifier.activeEnergyBurned:
            return "kcal"
        case HKQuantityTypeIdentifier.basalEnergyBurned:
            return "kcal"
        case HKQuantityTypeIdentifier.distanceWalkingRunning:
            return "m"
        default:
            return "unknown"
        }
    }
    
    private static func sleepStageName(_ value: Int) -> String {
        switch value {
        case HKCategoryValueSleepAnalysis.inBed.rawValue:
            return "in_bed"
        case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
            return "asleep_unspecified"
        case HKCategoryValueSleepAnalysis.awake.rawValue:
            return "awake"
        case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
            return "asleep_core"
        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
            return "asleep_deep"
        case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
            return "asleep_rem"
        default:
            return "unknown_\(value)"
        }
    }
}

private extension HKWorkoutActivityType {
    
    var wildTraceName: String {
        switch self {
        case HKWorkoutActivityType.walking:
            return "walking"
        case HKWorkoutActivityType.running:
            return "running"
        case HKWorkoutActivityType.cycling:
            return "cycling"
        case HKWorkoutActivityType.hiking:
            return "hiking"
        case HKWorkoutActivityType.swimming:
            return "swimming"
        case HKWorkoutActivityType.yoga:
            return "yoga"
        case HKWorkoutActivityType.traditionalStrengthTraining:
            return "strength_training"
        case HKWorkoutActivityType.functionalStrengthTraining:
            return "functional_strength_training"
        case HKWorkoutActivityType.mindAndBody:
            return "mind_and_body"
        case HKWorkoutActivityType.dance:
            return "dance"
        case HKWorkoutActivityType.elliptical:
            return "elliptical"
        case HKWorkoutActivityType.rowing:
            return "rowing"
        case HKWorkoutActivityType.stairClimbing:
            return "stair_climbing"
        case HKWorkoutActivityType.cooldown:
            return "cooldown"
        case HKWorkoutActivityType.pilates:
            return "pilates"
        default:
            return "other_\(rawValue)"
        }
    }
}
