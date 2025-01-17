import Foundation

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
        lhs.subtasks == rhs.subtasks
    }
}