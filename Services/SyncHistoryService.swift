import Foundation

final class SyncHistoryService {
    
    private let defaults: UserDefaults
    private let key = "wildtrace.biological.syncedObjectPaths"
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
    
    func contains(_ objectPath: String) -> Bool {
        load().contains(objectPath)
    }
    
    func mark(_ objectPath: String) {
        var current = load()
        current.insert(objectPath)
        save(current)
    }
    
    func clear() {
        defaults.removeObject(forKey: key)
    }
    
    private func load() -> Set<String> {
        guard let data = defaults.data(forKey: key),
              let values = try? JSONDecoder().decode(Set<String>.self, from: data) else {
            return []
        }
        
        return values
    }
    
    private func save(_ values: Set<String>) {
        guard let data = try? JSONEncoder().encode(values) else {
            return
        }
        
        defaults.set(data, forKey: key)
    }
}
