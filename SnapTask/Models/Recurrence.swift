import Foundation

struct Recurrence: Codable, Equatable {
    enum RecurrenceType: Codable, Equatable {
        case daily
        case weekly(days: Set<Int>)
        case monthly(days: Set<Int>)
    }
    
    let type: RecurrenceType
    let endDate: Date?
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