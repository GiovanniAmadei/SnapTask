import Foundation

struct Recurrence: Codable, Equatable {
    enum RecurrenceType: Codable, Equatable {
        case daily
        case weekly(days: Set<Int>)
        case monthly(days: Set<Int>)
    }
    
    private enum CodingKeys: String, CodingKey {
        case type, endDate, trackInStatistics
    }
    
    let type: RecurrenceType
    let endDate: Date?
    let trackInStatistics: Bool
    
    init(type: RecurrenceType, endDate: Date?, trackInStatistics: Bool = true) {
        self.type = type
        self.endDate = endDate
        self.trackInStatistics = trackInStatistics
    }
    
    // Custom decoder to handle missing trackInStatistics in older data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(RecurrenceType.self, forKey: .type)
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
        }
    }
}