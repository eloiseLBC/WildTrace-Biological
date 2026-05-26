import Foundation

enum DateUtils {
    
    static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
    
    static func daysBetween(start: Date, end: Date) -> [Date] {
        let calendar = Calendar.current
        let normalizedStart = calendar.startOfDay(for: start)
        let normalizedEnd = calendar.startOfDay(for: end)
        
        guard normalizedStart <= normalizedEnd else {
            return []
        }
        
        var days: [Date] = []
        var current = normalizedStart
        
        while current <= normalizedEnd {
            days.append(current)
            
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else {
                break
            }
            
            current = next
        }
        
        return days
    }
}
