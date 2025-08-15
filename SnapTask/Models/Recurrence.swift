import Foundation

struct Recurrence: Codable, Equatable, Hashable {
    enum RecurrenceType: Codable, Equatable, Hashable {
        case daily
        case weekly(days: Set<Int>)            // 1 = Sunday ... 7 = Saturday
        case monthly(days: Set<Int>)           // 1...31
        case monthlyOrdinal(patterns: Set<OrdinalPattern>)
        case yearly
    }
    
    struct OrdinalPattern: Codable, Equatable, Hashable {
        let ordinal: Int // 1=first, 2=second, 3=third, 4=fourth, -1=last
        let weekday: Int // 1=Sunday ... 7=Saturday
        
        var displayText: String {
            let ordinalText: String
            switch ordinal {
            case 1: ordinalText = "first".localized
            case 2: ordinalText = "second".localized
            case 3: ordinalText = "third".localized
            case 4: ordinalText = "fourth".localized
            case -1: ordinalText = "last".localized
            default: ordinalText = "\(ordinal)th"
            }
            
            let weekdayText: String
            switch weekday {
            case 1: weekdayText = "sunday".localized
            case 2: weekdayText = "monday".localized
            case 3: weekdayText = "tuesday".localized
            case 4: weekdayText = "wednesday".localized
            case 5: weekdayText = "thursday".localized
            case 6: weekdayText = "friday".localized
            case 7: weekdayText = "saturday".localized
            default: weekdayText = "Day"
            }
            
            return "\(ordinalText) \(weekdayText)"
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case type, endDate, trackInStatistics, startDate
        case interval
        case selectedMonths
        case weekModuloK, weekModuloOffset
        case yearModuloK, yearModuloOffset
    }
    
    let type: RecurrenceType
    let startDate: Date
    let endDate: Date?
    let trackInStatistics: Bool
    
    // Interval and pattern metadata
    // interval semantics by type:
    // - daily: every N days
    // - weekly: every N weeks (anchored to start week)
    // - monthly/monthlyOrdinal: every N months (anchored to start month)
    // - yearly: every N years (anchored to start year)
    var interval: Int? = nil
    
    // Weekly modulo pattern (e.g. even/odd weeks)
    var weekModuloK: Int? = nil
    var weekModuloOffset: Int? = nil // 0...(k-1), based on weeks since anchor
    
    // Month selection (months-of-year, 1...12)
    var selectedMonths: Set<Int>? = nil
    
    // Year modulo pattern (even/odd years or generic modulo)
    var yearModuloK: Int? = nil
    var yearModuloOffset: Int? = nil
    
    init(
        type: RecurrenceType,
        startDate: Date,
        endDate: Date?,
        trackInStatistics: Bool = true,
        interval: Int? = nil,
        selectedMonths: Set<Int>? = nil,
        weekModuloK: Int? = nil,
        weekModuloOffset: Int? = nil,
        yearModuloK: Int? = nil,
        yearModuloOffset: Int? = nil
    ) {
        self.type = type
        self.startDate = startDate
        self.endDate = endDate
        self.trackInStatistics = trackInStatistics
        self.interval = interval
        self.selectedMonths = selectedMonths
        self.weekModuloK = weekModuloK
        self.weekModuloOffset = weekModuloOffset
        self.yearModuloK = yearModuloK
        self.yearModuloOffset = yearModuloOffset
    }
    
    // Custom decoder to handle old data (backward compatible)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(RecurrenceType.self, forKey: .type)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        trackInStatistics = try container.decodeIfPresent(Bool.self, forKey: .trackInStatistics) ?? true
        
        interval = try container.decodeIfPresent(Int.self, forKey: .interval)
        selectedMonths = try container.decodeIfPresent(Set<Int>.self, forKey: .selectedMonths)
        weekModuloK = try container.decodeIfPresent(Int.self, forKey: .weekModuloK)
        weekModuloOffset = try container.decodeIfPresent(Int.self, forKey: .weekModuloOffset)
        yearModuloK = try container.decodeIfPresent(Int.self, forKey: .yearModuloK)
        yearModuloOffset = try container.decodeIfPresent(Int.self, forKey: .yearModuloOffset)
    }
}

extension Recurrence {
    func shouldOccurOn(date: Date) -> Bool {
        let calendar = Calendar.current
        let dateStart = calendar.startOfDay(for: date)
        let startDay = calendar.startOfDay(for: startDate)
        
        if dateStart < startDay { return false }
        if let end = endDate, dateStart > calendar.startOfDay(for: end) { return false }
        
        let targetDay = calendar.startOfDay(for: date)
        let recurrenceStart = calendar.startOfDay(for: startDate)
        if targetDay < recurrenceStart {
            return false
        }
        if let endDate {
            let recurrenceEnd = calendar.startOfDay(for: endDate)
            if targetDay > recurrenceEnd {
                return false
            }
        }
        
        switch self.type {
        case .daily:
            let days = calendar.dateComponents([.day], from: startDay, to: dateStart).day ?? 0
            if let every = interval, every > 1 {
                guard days % every == 0 else { return false }
            }
            return true
            
        case .weekly(let days):
            let weekday = calendar.component(.weekday, from: dateStart)
            guard days.contains(weekday) else { return false }
            
            // Calcolo settimane dalla data di inizio
            let anchorWeek = calendar.startOfWeek(for: startDay)
            let currentWeek = calendar.startOfWeek(for: dateStart)
            let weeksPassed = calendar.dateComponents([.weekOfYear], from: anchorWeek, to: currentWeek).weekOfYear ?? 0
            
            // Controllo intervallo (ogni N settimane)
            if let every = interval, every > 1, weeksPassed % every != 0 { 
                return false 
            }
            
            // Controllo pattern modulo (settimane pari/dispari/personalizzate)
            if let k = weekModuloK, k >= 2 {
                let offset = weekModuloOffset ?? 0
                // Il pattern si ripete ogni k settimane, iniziando dall'offset specificato
                if (weeksPassed % k) != offset { 
                    return false 
                }
            }
            return true
            
        case .monthly(let daySet):
            // Filtro mesi dell'anno (opzionale)
            if let months = selectedMonths, !months.isEmpty {
                let currentMonth = calendar.component(.month, from: dateStart)
                if !months.contains(currentMonth) { return false }
            }
            
            let dayOfMonth = calendar.component(.day, from: dateStart)
            guard daySet.contains(dayOfMonth) else { return false }
            
            // Calcolo mesi dalla data di inizio
            let startMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: startDay))!
            let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: dateStart))!
            let monthsPassed = calendar.dateComponents([.month], from: startMonth, to: currentMonth).month ?? 0
            
            // Controllo ogni N mesi
            if let every = interval, every > 1, monthsPassed % every != 0 { 
                return false 
            }
            return true
            
        case .monthlyOrdinal(let patterns):
            // Calcolo mesi dalla data di inizio per l'intervallo
            let startMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: startDay))!
            let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: dateStart))!
            let monthsPassed = calendar.dateComponents([.month], from: startMonth, to: currentMonth).month ?? 0
            
            if let every = interval, every > 1, monthsPassed % every != 0 { 
                return false 
            }
            
            return patterns.contains { pattern in
                matchesOrdinalPattern(date: dateStart, pattern: pattern, calendar: calendar)
            }
            
        case .yearly:
            // Deve essere stesso mese e giorno della data di inizio
            let startComponents = calendar.dateComponents([.month, .day], from: startDay)
            let dateComponents = calendar.dateComponents([.month, .day], from: dateStart)
            guard startComponents.month == dateComponents.month && 
                  startComponents.day == dateComponents.day else {
                return false
            }
            
            // Calcolo anni dalla data di inizio
            let yearsPassed = calendar.dateComponents([.year], from: startDay, to: dateStart).year ?? 0
            
            // Controllo ogni N anni
            if let every = interval, every > 1, yearsPassed % every != 0 { 
                return false 
            }
            
            // Controllo pattern modulo anni (anni pari/dispari/personalizzati)
            if let k = yearModuloK, k >= 2 {
                let offset = yearModuloOffset ?? 0
                // Il pattern si ripete ogni k anni, iniziando dall'offset specificato
                if (yearsPassed % k) != offset { 
                    return false 
                }
            }
            return true
        }
    }
    
    private func matchesOrdinalPattern(date: Date, pattern: OrdinalPattern, calendar: Calendar) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        guard weekday == pattern.weekday else { return false }
        
        let day = calendar.component(.day, from: date)
        
        if pattern.ordinal == -1 {
            // last occurrence of weekday in month
            guard let range = calendar.range(of: .day, in: .month, for: date) else { return false }
            let lastDayOfMonth = range.upperBound - 1
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
            let occurrence = (day - 1) / 7 + 1
            return occurrence == pattern.ordinal
        }
    }
}