import Foundation
import Combine

@MainActor
final class BiologicalSyncViewModel: ObservableObject {
    
    @Published var startDate: Date
    @Published var endDate: Date
    @Published var uploadDailyComputed: Bool
    @Published var skipAlreadySynced: Bool
    @Published private(set) var logs: [String]
    @Published private(set) var isSyncing: Bool
    
    private let syncService: BiologicalSyncService
    private let defaults: UserDefaults
    
    var canSync: Bool {
        !AppConfig.oraclePARBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    init(
        syncService: BiologicalSyncService,
        defaults: UserDefaults = .standard
    ) {
        self.syncService = syncService
        self.defaults = defaults
        
        let today = Calendar.current.startOfDay(for: Date())
        
        self.startDate = today
        self.endDate = today
        self.uploadDailyComputed = defaults.object(forKey: UserDefaultsKeys.uploadDailyComputed) as? Bool ?? true
        self.skipAlreadySynced = defaults.object(forKey: UserDefaultsKeys.skipAlreadySynced) as? Bool ?? true
        self.logs = []
        self.isSyncing = false
    }
    
    func requestHealthAuthorization() async {
        do {
            try await syncService.requestHealthAuthorization()
            appendLog("Autorisation HealthKit demandée avec succès.")
        } catch {
            appendLog("Erreur HealthKit : \(error.localizedDescription)")
        }
    }
    
    func sync() async {
        guard !isSyncing else { return }
        
        guard canSync else {
            appendLog("URL PAR Oracle Cloud manquante dans AppConfig.")
            return
        }
        
        saveSettings()
        isSyncing = true
        
        defer {
            isSyncing = false
        }
        
        do {
            try await syncService.sync(
                startDate: startDate,
                endDate: endDate,
                parBaseURL: AppConfig.oraclePARBaseURL,
                uploadDailyComputed: uploadDailyComputed,
                skipAlreadySynced: skipAlreadySynced,
                onLog: { [weak self] message in
                    self?.appendLog(message)
                }
            )
        } catch {
            appendLog("Erreur synchronisation : \(error.localizedDescription)")
        }
    }
    
    func selectToday() {
        let today = Calendar.current.startOfDay(for: Date())
        startDate = today
        endDate = today
    }
    
    func selectLastSevenDays() {
        let today = Calendar.current.startOfDay(for: Date())
        startDate = Calendar.current.date(byAdding: .day, value: -6, to: today) ?? today
        endDate = today
    }
    
    func clearLocalHistory() {
        syncService.clearSyncHistory()
        appendLog("Historique local de synchronisation réinitialisé.")
    }
    
    func saveSettings() {
        defaults.set(uploadDailyComputed, forKey: UserDefaultsKeys.uploadDailyComputed)
        defaults.set(skipAlreadySynced, forKey: UserDefaultsKeys.skipAlreadySynced)
    }
    
    private func appendLog(_ message: String) {
        let timestamp = DateUtils.logFormatter.string(from: Date())
        logs.append("[\(timestamp)] \(message)")
    }
}

private enum UserDefaultsKeys {
    static let uploadDailyComputed = "wildtrace.biological.uploadDailyComputed"
    static let skipAlreadySynced = "wildtrace.biological.skipAlreadySynced"
}
