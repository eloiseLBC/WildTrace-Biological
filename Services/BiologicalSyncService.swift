import Foundation

@MainActor
final class BiologicalSyncService {
    
    private let locationService = CollectionLocationService()
    private let healthKitService: HealthKitService
    private let oracleStorageService: OracleStorageService
    private let syncHistoryService: SyncHistoryService
    
    init(
        healthKitService: HealthKitService,
        oracleStorageService: OracleStorageService,
        syncHistoryService: SyncHistoryService
    ) {
        self.healthKitService = healthKitService
        self.oracleStorageService = oracleStorageService
        self.syncHistoryService = syncHistoryService
    }
    
    func requestHealthAuthorization() async throws {
        try await healthKitService.requestAuthorization()
    }
    
    func sync(
        startDate: Date,
        endDate: Date,
        parBaseURL: String,
        uploadDailyComputed: Bool,
        skipAlreadySynced: Bool,
        onLog: @escaping (String) -> Void
    ) async throws {
        
        let normalizedStartDate = Calendar.current.startOfDay(for: startDate)
        let normalizedEndDate = Calendar.current.startOfDay(for: endDate)
        
        let days = DateUtils.daysBetween(
            start: normalizedStartDate,
            end: normalizedEndDate
        )
        
        guard !days.isEmpty else {
            onLog("Aucune date à synchroniser.")
            return
        }
        
        onLog("Début synchronisation : \(days.count) jour(s).")
        
        var capturedLocation: CollectionLocation?
        var cityCountry = CityCountry()
        let calendar = Calendar.current
        if days.contains(where: { calendar.isDateInToday($0) }) {
            onLog("Capture de la position de l’iPhone…")
            do {
                capturedLocation = try await locationService.capture()
                onLog("Position enregistrée pour aujourd’hui.")
            } catch {
                onLog("Localisation indisponible : \(error.localizedDescription). La collecte continue.")
            }
            if let capturedLocation {
                do {
                    cityCountry = try await locationService.resolve(capturedLocation)
                } catch {
                    onLog("Géocodage indisponible : \(error.localizedDescription). Coordonnées conservées dans le raw.")
                }
            }
        }

        for day in days {
            let dayString = DateUtils.dayFormatter.string(from: day)
            
            let rawObjectPath = "collected/to_compute/biological_raw_\(dayString).json"
            let dailyObjectPath = "collected/computed/biological_daily_\(dayString).json"
            
            // Today's data is mutable; retry incomplete computed uploads independently.
            if skipAlreadySynced && !calendar.isDateInToday(day) &&
                syncHistoryService.contains(rawObjectPath) &&
                (!uploadDailyComputed || syncHistoryService.contains(dailyObjectPath)) {
                onLog("\(dayString) déjà synchronisé localement, ignoré.")
                continue
            }
            
            onLog("Lecture HealthKit pour \(dayString)…")
            
            var payload = try await healthKitService.collectBiologicalDay(for: day)
            if let location = capturedLocation,
               let timestamp = DateUtils.isoFormatter.date(from: location.timestamp),
               let start = DateUtils.isoFormatter.date(from: payload.range.start),
               let end = DateUtils.isoFormatter.date(from: payload.range.end),
               timestamp >= start && timestamp < end {
                payload.location = location
            }
            let rawData = try JSONUtils.encoder.encode(payload)
            
            try await oracleStorageService.upload(
                data: rawData,
                objectPath: rawObjectPath,
                parBaseURL: parBaseURL
            )
            
            syncHistoryService.mark(rawObjectPath)
            onLog("Upload OK : \(rawObjectPath)")
            
            if uploadDailyComputed {
                var dailySummary = BiologicalDailySummary.from(payload)
                if let location = payload.location {
                    dailySummary.cityCountry = cityCountry
                    dailySummary.locationMetadata = LocationMetadata(location)
                }
                let dailyData = try JSONUtils.encoder.encode(dailySummary)
                
                try await oracleStorageService.upload(
                    data: dailyData,
                    objectPath: dailyObjectPath,
                    parBaseURL: parBaseURL
                )
                
                syncHistoryService.mark(dailyObjectPath)
                onLog("Upload OK : \(dailyObjectPath)")
            }
        }
        
        onLog("Synchronisation terminée.")
    }
    
    func clearSyncHistory() {
        syncHistoryService.clear()
    }
}

