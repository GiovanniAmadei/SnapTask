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