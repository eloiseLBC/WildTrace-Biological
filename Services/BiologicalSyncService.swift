import Foundation

@MainActor
final class BiologicalSyncService {
    
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
        
        for day in days {
            let dayString = DateUtils.dayFormatter.string(from: day)
            
            let rawObjectPath = "collected/to_compute/biological_raw_\(dayString).json"
            let dailyObjectPath = "collected/computed/biological_daily_\(dayString).json"
            
            if skipAlreadySynced && syncHistoryService.contains(rawObjectPath) {
                onLog("\(dayString) déjà synchronisé localement, ignoré.")
                continue
            }
            
            onLog("Lecture HealthKit pour \(dayString)…")
            
            let payload = try await healthKitService.collectBiologicalDay(for: day)
            let rawData = try JSONUtils.encoder.encode(payload)
            
            try await oracleStorageService.upload(
                data: rawData,
                objectPath: rawObjectPath,
                parBaseURL: parBaseURL
            )
            
            syncHistoryService.mark(rawObjectPath)
            onLog("Upload OK : \(rawObjectPath)")
            
            if uploadDailyComputed {
                let dailySummary = BiologicalDailySummary.from(payload)
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
