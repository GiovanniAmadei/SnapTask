import Foundation
import Combine

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
        rewardPoints: Int = 0
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
    
    // Computed property for formatted tracked time
    var formattedTrackedTime: String {
        let hours = Int(totalTrackedTime) / 3600
        let minutes = Int(totalTrackedTime) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    // Check if task has been tracked recently
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
    
    // Check if task has historical rating data
    var hasHistoricalRatings: Bool {
        let ratingsCount = completions.values.reduce(0) { count, completion in
            let hasQuality = completion.qualityRating != nil
            let hasDifficulty = completion.difficultyRating != nil
            return count + (hasQuality || hasDifficulty ? 1 : 0)
        }
        return ratingsCount >= 2 // At least 2 completions with ratings
    }
    
    // These have been removed to force explicit date usage
    
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
        lhs.lastTrackedDate == rhs.lastTrackedDate
    }
}
