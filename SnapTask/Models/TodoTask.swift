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
        
        while true {
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