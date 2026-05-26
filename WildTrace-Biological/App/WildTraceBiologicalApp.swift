import SwiftUI

@main
struct WildTraceBiologicalApp: App {
    
    private let syncService = BiologicalSyncService(
        healthKitService: HealthKitService(),
        oracleStorageService: OracleStorageService(),
        syncHistoryService: SyncHistoryService()
    )
    
    var body: some Scene {
        WindowGroup {
            BiologicalSyncView(
                viewModel: BiologicalSyncViewModel(syncService: syncService)
            )
        }
    }
}
