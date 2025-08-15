import Foundation
import Combine

// MARK: - TaskTimeScope Enum
enum TaskTimeScope: String, CaseIterable, Codable {
    case today = "today"
    case week = "week"
    case month = "month"
    case year = "year"
    case longTerm = "longTerm"
    
    var displayName: String {
        switch self {
        case .today: return "scope_today".localized
        case .week: return "scope_week".localized
        case .month: return "scope_month".localized
        case .year: return "scope_year".localized
        case .longTerm: return "scope_long_term".localized
        }
    }
    
    var icon: String {
        switch self {
        case .today: return "star.fill"
        case .week: return "target" 
        case .month: return "calendar"
        case .year: return "trophy.fill"
        case .longTerm: return "sparkles"
        }
    }
    
    var color: String {
        switch self {
        case .today: return "blue"
        case .week: return "green"
        case .month: return "orange"
        case .year: return "purple"
        case .longTerm: return "pink"
        }
    }
}

struct TodoTask: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var description: String?
    var location: TaskLocation?
    var startTime: Date
    var hasSpecificTime: Bool = true
    var duration: TimeInterval
    var hasDuration: Bool
    var category: Category?
    var priority: Priority
    var icon: String
    var recurrence: Recurrence?
    var pomodoroSettings: PomodoroSettings?
    var completions: [Date: TaskCompletion] = [:]
    var subtasks: [Subtask] = []
    var completionDates: [Date] = []
    var creationDate: Date = Date()
    var lastModifiedDate: Date = Date()
    // Reward points related properties
    var hasRewardPoints: Bool = false
    var rewardPoints: Int = 0
    // Time tracking properties
    var totalTrackedTime: TimeInterval = 0
    var lastTrackedDate: Date?
    // Notification properties
    var hasNotification: Bool = false
    var notificationId: String?
    
    var timeScope: TaskTimeScope = .today
    var scopeStartDate: Date? = nil
    var scopeEndDate: Date? = nil

    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        location: TaskLocation? = nil,
        startTime: Date,
        hasSpecificTime: Bool = true,
        duration: TimeInterval = 0,
        hasDuration: Bool = false,
        category: Category? = nil,
        priority: Priority = .medium,
        icon: String = "circle",
        recurrence: Recurrence? = nil,
        pomodoroSettings: PomodoroSettings? = nil,
        subtasks: [Subtask] = [],
        hasRewardPoints: Bool = false,
        rewardPoints: Int = 0,
        hasNotification: Bool = false,
        notificationId: String? = nil,
        timeScope: TaskTimeScope = .today,
        scopeStartDate: Date? = nil,
        scopeEndDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.location = location
        self.startTime = startTime
        self.hasSpecificTime = hasSpecificTime
        self.duration = duration
        self.hasDuration = hasDuration
        self.category = category
        self.priority = priority
        self.icon = icon
        self.recurrence = recurrence
        self.pomodoroSettings = pomodoroSettings
        self.subtasks = subtasks
        self.hasRewardPoints = hasRewardPoints
        self.rewardPoints = rewardPoints
        self.totalTrackedTime = 0
        self.lastTrackedDate = nil
        self.hasNotification = hasNotification
        self.notificationId = notificationId
        self.timeScope = timeScope
        self.scopeStartDate = scopeStartDate
        self.scopeEndDate = scopeEndDate
    }
    
    var displayPeriod: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        switch timeScope {
        case .today:
            formatter.dateStyle = .medium
            return formatter.string(from: startTime)
        case .week:
            if let start = scopeStartDate {
                let weekStart = calendar.startOfWeek(for: start)
                let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
                formatter.dateStyle = .short
                return "\(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))"
            }
            return "this_week".localized
        case .month:
            if let start = scopeStartDate {
                formatter.dateFormat = "MMMM yyyy"
                return formatter.string(from: start)
            }
            return "this_month".localized
        case .year:
            if let start = scopeStartDate {
                formatter.dateFormat = "yyyy"
                return formatter.string(from: start)
            }
            return "this_year".localized
        case .longTerm:
            return "long_term_objective".localized
        }
    }
    
    func shouldShow(for date: Date, scope: TaskTimeScope) -> Bool {
        guard timeScope == scope else { return false }
        
        let calendar = Calendar.current
        
        switch scope {
        case .today:
            return calendar.isDate(startTime, inSameDayAs: date)
        case .week:
            if let scopeStart = scopeStartDate, let scopeEnd = scopeEndDate {
                // Check if the date falls within the specific week range of this task
                return date >= scopeStart && date <= scopeEnd
            }
            // Fallback: check if it's the same day (shouldn't happen for week tasks)
            return calendar.isDate(startTime, inSameDayAs: date)
        case .month:
            if let scopeStart = scopeStartDate, let scopeEnd = scopeEndDate {
                // Check if the date falls within the specific month range of this task
                return date >= scopeStart && date <= scopeEnd
            }
            // Fallback: check same month/year
            return calendar.isDate(startTime, equalTo: date, toGranularity: .month)
        case .year:
            if let scopeStart = scopeStartDate, let scopeEnd = scopeEndDate {
                // Check if the date falls within the specific year range of this task
                return date >= scopeStart && date <= scopeEnd
            }
            // Fallback: check same year
            return calendar.isDate(startTime, equalTo: date, toGranularity: .year)
        case .longTerm:
            return true // Always show long-term tasks
        }
    }
    
    var completionProgress: Double {
        guard !subtasks.isEmpty else {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            if let completion = completions[today] {
                return completion.isCompleted ? 1.0 : 0.0
            }
            return 0.0
        }
        return Double(subtasks.filter(\.isCompleted).count) / Double(subtasks.count)
    }
    
    var formattedTrackedTime: String {
        let hours = Int(totalTrackedTime) / 3600
        let minutes = Int(totalTrackedTime) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var hasRecentTracking: Bool {
        guard let lastTracked = lastTrackedDate else { return false }
        return Calendar.current.isDate(lastTracked, inSameDayAs: Date())
    }
    
    func streakForDate(_ date: Date) -> Int {
        guard let recurrence = recurrence else { return 0 }
        
        let calendar = Calendar.current
        var currentDate = calendar.startOfDay(for: date)
        var streak = 0
        
        let today = calendar.startOfDay(for: Date())
        if currentDate > today {
            return 0
        }
        
        // Limit iterations to prevent infinite loops (max 1000 days back)
        var iterationCount = 0
        let maxIterations = 1000
        
        while iterationCount < maxIterations {
            if currentDate < calendar.startOfDay(for: startTime) {
                break
            }
            
            if let endDate = recurrence.endDate, currentDate > endDate {
                break
            }
            
            let shouldCheck = shouldCheckDate(currentDate, recurrence: recurrence)
            
            if shouldCheck {
                if let completion = completions[currentDate], completion.isCompleted {
                    streak += 1
                } else {
                    break
                }
            }
            
            guard let newDate = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
            currentDate = newDate
            iterationCount += 1
        }
        
        return streak
    }
    
    private func shouldCheckDate(_ date: Date, recurrence: Recurrence) -> Bool {
        let calendar = Calendar.current
        
        switch recurrence.type {
        case .daily:
            return true
        case .weekly(let days):
            let weekday = calendar.component(.weekday, from: date)
            return days.contains(weekday)
        case .monthly(let days):
            let day = calendar.component(.day, from: date)
            return days.contains(day)
        case .monthlyOrdinal(let patterns):
            return recurrence.shouldOccurOn(date: date)
        case .yearly:
            return recurrence.shouldOccurOn(date: date)
        }
    }
    
    var currentStreak: Int {
        streakForDate(Date())
    }
    
    func hasRatings(for date: Date) -> Bool {
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)
        return completions[targetDate]?.hasRatings == true
    }
    
    func actualDuration(for date: Date) -> TimeInterval? {
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)
        return completions[targetDate]?.actualDuration
    }
    
    func formattedActualDuration(for date: Date) -> String? {
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)
        return completions[targetDate]?.formattedActualDuration
    }
    
    func difficultyRating(for date: Date) -> Int? {
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)
        return completions[targetDate]?.difficultyRating
    }
    
    func qualityRating(for date: Date) -> Int? {
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)
        return completions[targetDate]?.qualityRating
    }
    
    var hasHistoricalRatings: Bool {
        let ratingsCount = completions.values.reduce(0) { count, completion in
            let hasQuality = completion.qualityRating != nil
            let hasDifficulty = completion.difficultyRating != nil
            return count + (hasQuality || hasDifficulty ? 1 : 0)
        }
        return ratingsCount >= 2 // At least 2 completions with ratings
    }
    
    static func == (lhs: TodoTask, rhs: TodoTask) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.description == rhs.description &&
        lhs.location == rhs.location &&
        lhs.startTime == rhs.startTime &&
        lhs.hasSpecificTime == rhs.hasSpecificTime &&
        lhs.duration == rhs.duration &&
        lhs.hasDuration == rhs.hasDuration &&
        lhs.category == rhs.category &&
        lhs.priority == rhs.priority &&
        lhs.icon == rhs.icon &&
        lhs.recurrence == rhs.recurrence &&
        lhs.pomodoroSettings == rhs.pomodoroSettings &&
        lhs.completions == rhs.completions &&
        lhs.subtasks == rhs.subtasks &&
        lhs.completionDates == rhs.completionDates &&
        lhs.hasRewardPoints == rhs.hasRewardPoints &&
        lhs.rewardPoints == rhs.rewardPoints &&
        lhs.totalTrackedTime == rhs.totalTrackedTime &&
        lhs.lastTrackedDate == rhs.lastTrackedDate &&
        lhs.hasNotification == rhs.hasNotification &&
        lhs.notificationId == rhs.notificationId &&
        lhs.timeScope == rhs.timeScope &&
        lhs.scopeStartDate == rhs.scopeStartDate &&
        lhs.scopeEndDate == rhs.scopeEndDate
    }
    
    // MARK: - Completion Key Helper
    func completionKey(for date: Date) -> Date {
        let calendar = Calendar.current
        
        switch timeScope {
        case .today:
            return calendar.startOfDay(for: date)
        case .week:
            if let scopeStart = scopeStartDate {
                return calendar.startOfWeek(for: scopeStart)
            }
            return calendar.startOfWeek(for: date)
        case .month:
            if let scopeStart = scopeStartDate {
                return calendar.dateInterval(of: .month, for: scopeStart)?.start ?? calendar.startOfDay(for: scopeStart)
            }
            return calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
        case .year:
            if let scopeStart = scopeStartDate {
                return calendar.dateInterval(of: .year, for: scopeStart)?.start ?? calendar.startOfDay(for: scopeStart)
            }
            return calendar.dateInterval(of: .year, for: date)?.start ?? calendar.startOfDay(for: date)
        case .longTerm:
            // Per obiettivi a lungo termine, usiamo una data fissa per permettere un singolo completamento
            return calendar.startOfDay(for: startTime)
        }
    }
}

// MARK: - Calendar Extensions
extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? date
    }
}

extension TodoTask {
    func occurs(on date: Date) -> Bool {
        if let recurrence {
            return recurrence.shouldOccurOn(date: date)
        } else {
            return Calendar.current.isDate(startTime, inSameDayAs: date)
        }
    }
    
    func occurs(inWeekStarting weekStart: Date) -> Bool {
        guard let recurrence = recurrence else {
            let calendar = Calendar.current
            if let scopeStart = scopeStartDate, let scopeEnd = scopeEndDate {
                return calendar.isDate(scopeStart, inSameDayAs: weekStart) &&
                       calendar.isDate(scopeEnd, inSameDayAs: calendar.date(byAdding: .day, value: 6, to: weekStart)!)
            }
            return Calendar.current.isDate(startTime, inSameDayAs: weekStart)
        }
        
        let calendar = Calendar.current
        // Boundaries
        let anchor = calendar.startOfWeek(for: recurrence.startDate)
        let target = calendar.startOfWeek(for: weekStart)
        if target < anchor { return false }
        if let end = recurrence.endDate, target > calendar.startOfWeek(for: end) { return false }
        
        // If week ordinals are specified, match ordinal of this week within its month
        if let ordinals = recurrence.weekSelectedOrdinals, !ordinals.isEmpty {
            let ord = calendar.component(.weekOfMonth, from: target)
            if ordinals.contains(-1) {
                // allow "last" week of month
                if isLastWeekOfMonth(target, calendar: calendar) { return true }
            }
            if ordinals.contains(ord) { return true }
            return false
        }
        
        // Modulo or interval on weeks since anchor
        if let weeks = calendar.dateComponents([.weekOfYear], from: anchor, to: target).weekOfYear, weeks >= 0 {
            if let k = recurrence.weekModuloK, k > 1 {
                let offset = recurrence.weekModuloOffset ?? 0
                if weeks % k != offset { return false }
            }
            if let iv = recurrence.weekInterval, iv > 1, weeks % iv != 0 {
                return false
            }
        }
        
        // If no week-level constraints, consider it occurs in this week if any day matches
        // Otherwise, also accept it (interval satisfied) without scanning days
        if recurrence.weekInterval != nil || recurrence.weekModuloK != nil {
            return true
        }
        
        // Fallback: scan week days for a daily occurrence
        var day = target
        for _ in 0..<7 {
            if recurrence.shouldOccurOn(date: day) { return true }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return false
    }
    
    func occurs(inMonth monthStart: Date) -> Bool {
        guard let recurrence = recurrence else {
            let calendar = Calendar.current
            if let scopeStart = scopeStartDate {
                return calendar.isDate(scopeStart, equalTo: monthStart, toGranularity: .month)
            }
            return Calendar.current.isDate(startTime, equalTo: monthStart, toGranularity: .month)
        }
        
        let calendar = Calendar.current
        // Boundaries
        let anchor = calendar.startOfMonth(for: recurrence.startDate)
        let target = calendar.startOfMonth(for: monthStart)
        if target < anchor { return false }
        if let end = recurrence.endDate, target > calendar.startOfMonth(for: end) { return false }
        
        // Month-level gating with interval/specific months
        if let months = calendar.dateComponents([.month], from: anchor, to: target).month, months >= 0 {
            if let iv = recurrence.monthInterval, iv > 1, months % iv != 0 { return false }
        }
        if let allowed = recurrence.monthSelectedMonths, !allowed.isEmpty {
            let m = calendar.component(.month, from: target)
            if !allowed.contains(m) { return false }
        }
        
        // If we reached here, accept; optional: ensure at least one day matches
        // To be strict, check a few candidate days
        switch recurrence.type {
        case .monthly, .monthlyOrdinal, .weekly, .daily, .yearly:
            var day = target
            let end = calendar.date(byAdding: .month, value: 1, to: target) ?? target
            while day < end {
                if recurrence.shouldOccurOn(date: day) { return true }
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
            return false
        }
    }
    
    func occurs(inYear yearStart: Date) -> Bool {
        guard let recurrence = recurrence else {
            let calendar = Calendar.current
            if let scopeStart = scopeStartDate {
                return calendar.isDate(scopeStart, equalTo: yearStart, toGranularity: .year)
            }
            return Calendar.current.isDate(startTime, equalTo: yearStart, toGranularity: .year)
        }
        
        let calendar = Calendar.current
        // Boundaries
        let anchor = calendar.startOfYear(for: recurrence.startDate)
        let target = calendar.startOfYear(for: yearStart)
        if target < anchor { return false }
        if let end = recurrence.endDate, target > calendar.startOfYear(for: end) { return false }
        
        // Year-level gating (interval/modulo)
        if let years = calendar.dateComponents([.year], from: anchor, to: target).year, years >= 0 {
            if let k = recurrence.yearModuloK, k > 1 {
                let offset = recurrence.yearModuloOffset ?? 0
                if years % k != offset { return false }
            }
            if let iv = recurrence.yearInterval, iv > 1, years % iv != 0 {
                return false
            }
        }
        
        // Candidate check: scan key dates (same month/day as anchor for yearly, or any matching day if other types)
        var day = target
        let end = calendar.date(byAdding: .year, value: 1, to: target) ?? target
        while day < end {
            if recurrence.shouldOccurOn(date: day) { return true }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return false
    }
    
    private func isLastWeekOfMonth(_ weekStart: Date, calendar: Calendar) -> Bool {
        guard let nextWeek = calendar.date(byAdding: .day, value: 7, to: weekStart) else { return false }
        return calendar.component(.month, from: nextWeek) != calendar.component(.month, from: weekStart)
    }
}

// MARK: - Codable Support for TodoTask
extension TodoTask {
    private enum CodingKeys: String, CodingKey {
        case id, name, description, location, startTime, hasSpecificTime, duration, hasDuration
        case category, priority, icon, recurrence, pomodoroSettings, completions, subtasks
        case completionDates, creationDate, lastModifiedDate, hasRewardPoints, rewardPoints
        case totalTrackedTime, lastTrackedDate, hasNotification, notificationId
        case timeScope, scopeStartDate, scopeEndDate
    }
}