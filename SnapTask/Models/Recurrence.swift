import Foundation

struct Recurrence: Codable, Equatable, Hashable {
    enum RecurrenceType: Codable, Equatable, Hashable {
        case daily
        case weekly(days: Set<Int>)
        case monthly(days: Set<Int>)
        case monthlyOrdinal(patterns: Set<OrdinalPattern>)
        case yearly
    }
    
    struct OrdinalPattern: Codable, Equatable, Hashable {
        let ordinal: Int // 1 = first, 2 = second, 3 = third, 4 = fourth, -1 = last
        let weekday: Int // 1 = Sunday, 2 = Monday, etc.
        
        var displayText: String {
            let ordinalText: String
            switch ordinal {
            case 1: ordinalText = "First"
            case 2: ordinalText = "Second"
            case 3: ordinalText = "Third"
            case 4: ordinalText = "Fourth"
            case -1: ordinalText = "Last"
            default: ordinalText = "\(ordinal)th"
            }
            
            let weekdayText: String
            switch weekday {
            case 1: weekdayText = "Sunday"
            case 2: weekdayText = "Monday"
            case 3: weekdayText = "Tuesday"
            case 4: weekdayText = "Wednesday"
            case 5: weekdayText = "Thursday"
            case 6: weekdayText = "Friday"
            case 7: weekdayText = "Saturday"
            default: weekdayText = "Day"
            }
            
            return "\(ordinalText) \(weekdayText)"
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case type, endDate, trackInStatistics, startDate
    }
    
    let type: RecurrenceType
    let startDate: Date
    let endDate: Date?
    let trackInStatistics: Bool
    
    init(type: RecurrenceType, startDate: Date, endDate: Date?, trackInStatistics: Bool = true) {
        self.type = type
        self.startDate = startDate
        self.endDate = endDate
        self.trackInStatistics = trackInStatistics
    }
    
    // Custom decoder to handle missing trackInStatistics in older data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(RecurrenceType.self, forKey: .type)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        
        // Default to true if property doesn't exist in saved data
        trackInStatistics = try container.decodeIfPresent(Bool.self, forKey: .trackInStatistics) ?? true
    }
}

extension Recurrence {
    func shouldOccurOn(date: Date) -> Bool {
        let calendar = Calendar.current
        
        switch self.type {
        case .daily:
            return true
            
        case .weekly(let days):
            // Ottieni il giorno della settimana (1-7, dove 1 è Domenica)
            let weekday = calendar.component(.weekday, from: date)
            return days.contains(weekday)
            
        case .monthly(let days):
            // Ottieni il giorno del mese (1-31)
            let day = calendar.component(.day, from: date)
            return days.contains(day)
            
        case .monthlyOrdinal(let patterns):
            return patterns.contains { pattern in
                return matchesOrdinalPattern(date: date, pattern: pattern, calendar: calendar)
            }
            
        case .yearly:
            // Check if it's the same day and month as the start date
            let startComponents = calendar.dateComponents([.month, .day], from: startDate)
            let dateComponents = calendar.dateComponents([.month, .day], from: date)
            return startComponents.month == dateComponents.month && startComponents.day == dateComponents.day
        }
    }
    
    private func matchesOrdinalPattern(date: Date, pattern: OrdinalPattern, calendar: Calendar) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        guard weekday == pattern.weekday else { return false }
        
        let day = calendar.component(.day, from: date)
        
        if pattern.ordinal == -1 {
            // Last occurrence - check if this is the last occurrence of this weekday in the month
            let range = calendar.range(of: .day, in: .month, for: date)!
            let lastDayOfMonth = range.upperBound - 1
            
            // Find the last occurrence of this weekday
            for dayOffset in 0..<7 {
                let checkDay = lastDayOfMonth - dayOffset
                if checkDay < 1 { break }
                
                if let checkDate = calendar.date(bySetting: .day, value: checkDay, of: date) {
                    let checkWeekday = calendar.component(.weekday, from: checkDate)
                    if checkWeekday == pattern.weekday {
                        return day == checkDay
                    }
                }
            }
            return false
        } else {
            // Nth occurrence - calculate which occurrence this is
            let occurrence = (day - 1) / 7 + 1
            return occurrence == pattern.ordinal
        }
    }
}
