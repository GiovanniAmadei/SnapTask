import Foundation

struct Recurrence: Codable, Equatable, Hashable {
    struct WeekdayTimeOverride: Codable, Equatable, Hashable {
        let weekday: Int
        let hour: Int
        let minute: Int
    }

    struct MonthDayTimeOverride: Codable, Equatable, Hashable {
        let day: Int
        let hour: Int
        let minute: Int
    }

    struct MonthOrdinalTimeOverride: Codable, Equatable, Hashable {
        let ordinal: Int
        let weekday: Int
        let hour: Int
        let minute: Int
    }

    struct YearlyTimeOverride: Codable, Equatable, Hashable {
        let hour: Int
        let minute: Int
    }

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
        case dayInterval
        case weekInterval, weekModuloK, weekModuloOffset, weekSelectedOrdinals
        case monthInterval, monthSelectedMonths
        case yearInterval, yearModuloK, yearModuloOffset
        case weekdayTimeOverrides
        case monthDayTimeOverrides
        case monthOrdinalTimeOverrides
        case yearlyTimeOverride
    }
    
    let type: RecurrenceType
    let startDate: Date
    let endDate: Date?
    let trackInStatistics: Bool
    
    var dayInterval: Int? = nil
    var weekInterval: Int? = nil
    var weekModuloK: Int? = nil
    var weekModuloOffset: Int? = nil
    var weekSelectedOrdinals: Set<Int>? = nil // 1..5 and -1 for last

    var weekdayTimeOverrides: [WeekdayTimeOverride]? = nil

    var monthDayTimeOverrides: [MonthDayTimeOverride]? = nil
    var monthOrdinalTimeOverrides: [MonthOrdinalTimeOverride]? = nil
    var yearlyTimeOverride: YearlyTimeOverride? = nil
    
    var monthInterval: Int? = nil
    var monthSelectedMonths: Set<Int>? = nil // 1..12
    
    var yearInterval: Int? = nil
    var yearModuloK: Int? = nil
    var yearModuloOffset: Int? = nil
    
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
        trackInStatistics = try container.decodeIfPresent(Bool.self, forKey: .trackInStatistics) ?? true
        
        weekInterval = try container.decodeIfPresent(Int.self, forKey: .weekInterval)
        weekModuloK = try container.decodeIfPresent(Int.self, forKey: .weekModuloK)
        weekModuloOffset = try container.decodeIfPresent(Int.self, forKey: .weekModuloOffset)
        weekSelectedOrdinals = try container.decodeIfPresent(Set<Int>.self, forKey: .weekSelectedOrdinals)
        
        monthInterval = try container.decodeIfPresent(Int.self, forKey: .monthInterval)
        monthSelectedMonths = try container.decodeIfPresent(Set<Int>.self, forKey: .monthSelectedMonths)
        
        yearInterval = try container.decodeIfPresent(Int.self, forKey: .yearInterval)
        yearModuloK = try container.decodeIfPresent(Int.self, forKey: .yearModuloK)
        yearModuloOffset = try container.decodeIfPresent(Int.self, forKey: .yearModuloOffset)
        dayInterval = try container.decodeIfPresent(Int.self, forKey: .dayInterval)

        weekdayTimeOverrides = try container.decodeIfPresent([WeekdayTimeOverride].self, forKey: .weekdayTimeOverrides)

        monthDayTimeOverrides = try container.decodeIfPresent([MonthDayTimeOverride].self, forKey: .monthDayTimeOverrides)
        monthOrdinalTimeOverrides = try container.decodeIfPresent([MonthOrdinalTimeOverride].self, forKey: .monthOrdinalTimeOverrides)
        yearlyTimeOverride = try container.decodeIfPresent(YearlyTimeOverride.self, forKey: .yearlyTimeOverride)
    }
}

extension Recurrence {
    func shouldOccurOn(date: Date) -> Bool {
        let calendar = Calendar.current
        
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
            // Day-level gating (interval)
            if let interval = dayInterval, interval > 1 {
                if let days = calendar.dateComponents([.day], from: recurrenceStart, to: targetDay).day, days >= 0 {
                    return days % interval == 0
                } else {
                    return false
                }
            }
            return true
            
        case .weekly(let days):
            // Week-level gating (interval/modulo)
            if !passesWeekLevelGating(targetDay, calendar: calendar) {
                return false
            }
            // Day-of-week match
            let weekday = calendar.component(.weekday, from: date)
            return days.contains(weekday)
            
        case .monthly(let days):
            // Month-level gating (interval/specific months)
            if !passesMonthLevelGating(targetDay, calendar: calendar) {
                return false
            }
            // Day-of-month match
            let day = calendar.component(.day, from: date)
            return days.contains(day)
            
        case .monthlyOrdinal(let patterns):
            // Month-level gating (interval/specific months)
            if !passesMonthLevelGating(targetDay, calendar: calendar) {
                return false
            }
            return patterns.contains { pattern in
                return matchesOrdinalPattern(date: date, pattern: pattern, calendar: calendar)
            }
            
        case .yearly:
            // Year-level gating (interval/modulo)
            if !passesYearLevelGating(targetDay, calendar: calendar) {
                return false
            }
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
            let range = calendar.range(of: .day, in: .month, for: date)!
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
    
    
    private func passesWeekLevelGating(_ date: Date, calendar: Calendar) -> Bool {
        // Compute weeks since anchor start-week
        let anchorWeek = calendar.startOfWeek(for: startDate)
        let targetWeek = calendar.startOfWeek(for: date)
        guard let weeks = calendar.dateComponents([.weekOfYear], from: anchorWeek, to: targetWeek).weekOfYear, weeks >= 0 else {
            return false
        }
        if let k = weekModuloK, k > 1 {
            let offset = weekModuloOffset ?? 0
            if weeks % k != offset { return false }
        }
        if let interval = weekInterval, interval > 1 {
            if weeks % interval != 0 { return false }
        }
        return true
    }
    
    private func passesMonthLevelGating(_ date: Date, calendar: Calendar) -> Bool {
        let anchorMonth = calendar.startOfMonth(for: startDate)
        let targetMonth = calendar.startOfMonth(for: date)
        if let months = calendar.dateComponents([.month], from: anchorMonth, to: targetMonth).month, months >= 0 {
            if let interval = monthInterval, interval > 1, months % interval != 0 {
                return false
            }
        }
        if let allowed = monthSelectedMonths, !allowed.isEmpty {
            let m = calendar.component(.month, from: date)
            if !allowed.contains(m) { return false }
        }
        return true
    }
    
    private func passesYearLevelGating(_ date: Date, calendar: Calendar) -> Bool {
        let startYear = calendar.startOfYear(for: startDate)
        let targetYear = calendar.startOfYear(for: date)
        if let years = calendar.dateComponents([.year], from: startYear, to: targetYear).year, years >= 0 {
            if let k = yearModuloK, k > 1 {
                let offset = yearModuloOffset ?? 0
                if years % k != offset { return false }
            }
            if let interval = yearInterval, interval > 1, years % interval != 0 {
                return false
            }
        }
        return true
    }
}