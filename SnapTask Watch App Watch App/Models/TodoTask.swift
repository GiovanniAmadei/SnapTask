import Foundation
import Combine

struct TodoTask: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var description: String?
    var startTime: Date
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
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        startTime: Date,
        duration: TimeInterval = 0,
        hasDuration: Bool = false,
        category: Category? = nil,
        priority: Priority = .medium,
        icon: String = "circle",
        recurrence: Recurrence? = nil,
        pomodoroSettings: PomodoroSettings? = nil,
        subtasks: [Subtask] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.startTime = startTime
        self.duration = duration
        self.hasDuration = hasDuration
        self.category = category
        self.priority = priority
        self.icon = icon
        self.recurrence = recurrence
        self.pomodoroSettings = pomodoroSettings
        self.subtasks = subtasks
    }
    
    var completionProgress: Double {
        guard !subtasks.isEmpty else { 
            if let completion = completions[Date().startOfDay] {
                return completion.isCompleted ? 1.0 : 0.0
            }
            return 0.0
        }
        return Double(subtasks.filter(\.isCompleted).count) / Double(subtasks.count)
    }
    
    func streakForDate(_ date: Date) -> Int {
        guard let recurrence = recurrence else { return 0 }
        
        let calendar = Calendar.current
        var currentDate = date.startOfDay
        var streak = 0
        
        if currentDate > Date().startOfDay {
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
        }
    }
    
    var currentStreak: Int {
        streakForDate(Date())
    }
    
    static func == (lhs: TodoTask, rhs: TodoTask) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.description == rhs.description &&
        lhs.startTime == rhs.startTime &&
        lhs.duration == rhs.duration &&
        lhs.hasDuration == rhs.hasDuration &&
        lhs.category == rhs.category &&
        lhs.priority == rhs.priority &&
        lhs.icon == rhs.icon &&
        lhs.recurrence == rhs.recurrence &&
        lhs.pomodoroSettings == rhs.pomodoroSettings &&
        lhs.completions == rhs.completions &&
        lhs.subtasks == rhs.subtasks &&
        lhs.completionDates == rhs.completionDates
    }
}
