import Foundation
import SwiftUI

class TaskFormViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var icon: String = "checkmark.circle"
    @Published var startTime: Date
    @Published var duration: TimeInterval = 1800 // 30 minutes in seconds
    @Published var hasDuration: Bool = false
    @Published var category: Category?
    @Published var priority: Priority = .medium
    @Published var isRecurring: Bool = false
    @Published var recurrenceType: String = "daily"
    @Published var selectedDaysOfWeek: Set<Int> = []
    @Published var selectedDaysOfMonth: Set<Int> = []
    @Published var pomodoroSettings: PomodoroSettings?
    @Published var subtasks: [Subtask] = []
    
    var editingTask: TodoTask?
    private let taskManager = TaskManager.shared
    
    init(task: TodoTask? = nil, initialDate: Date = Date()) {
        self.startTime = initialDate
        
        if let task = task {
            self.editingTask = task
            self.name = task.name
            self.icon = task.icon
            self.startTime = task.startTime
            self.duration = task.duration
            self.hasDuration = task.hasDuration
            self.category = task.category
            self.priority = task.priority
            self.isRecurring = task.recurrence != nil
            self.recurrence = task.recurrence
            self.pomodoroSettings = task.pomodoroSettings
            self.subtasks = task.subtasks
            
            if let recurrence = task.recurrence {
                switch recurrence.type {
                case .daily:
                    self.recurrenceType = "daily"
                    self.selectedDaysOfWeek = []
                    self.selectedDaysOfMonth = []
                case .weekly(let days):
                    self.recurrenceType = "weekly"
                    self.selectedDaysOfWeek = days
                    self.selectedDaysOfMonth = []
                case .monthly(let days):
                    self.recurrenceType = "monthly"
                    self.selectedDaysOfWeek = []
                    self.selectedDaysOfMonth = days
                }
            }
        }
    }
    
    var recurrence: Recurrence? {
        get {
            guard isRecurring else { return nil }
            
            let recurrenceStartDate = Calendar.current.startOfDay(for: self.startTime)
            
            switch recurrenceType {
            case "daily":
                return Recurrence(type: .daily, startDate: recurrenceStartDate, endDate: nil)
            case "weekly":
                return Recurrence(type: .weekly(days: selectedDaysOfWeek), startDate: recurrenceStartDate, endDate: nil)
            case "monthly":
                return Recurrence(type: .monthly(days: selectedDaysOfMonth), startDate: recurrenceStartDate, endDate: nil)
            default:
                return nil
            }
        }
        set {
            if let newValue = newValue {
                isRecurring = true
                switch newValue.type {
                case .daily:
                    recurrenceType = "daily"
                    selectedDaysOfWeek = []
                    selectedDaysOfMonth = []
                case .weekly(let days):
                    recurrenceType = "weekly"
                    selectedDaysOfWeek = days
                    selectedDaysOfMonth = []
                case .monthly(let days):
                    recurrenceType = "monthly"
                    selectedDaysOfWeek = []
                    selectedDaysOfMonth = days
                }
            } else {
                isRecurring = false
                recurrenceType = "daily"
                selectedDaysOfWeek = []
                selectedDaysOfMonth = []
            }
        }
    }
    
    func addSubtask(_ name: String) {
        let newSubtask = Subtask(id: UUID(), name: name, isCompleted: false)
        subtasks.append(newSubtask)
        objectWillChange.send()
    }
    
    func removeSubtask(at index: Int) {
        guard index >= 0 && index < subtasks.count else { return }
        subtasks.remove(at: index)
        objectWillChange.send()
    }
    
    func moveSubtask(from source: IndexSet, to destination: Int) {
        subtasks.move(fromOffsets: source, toOffset: destination)
        objectWillChange.send()
    }
    
    func updateSubtask(_ subtask: Subtask) {
        if let index = subtasks.firstIndex(where: { $0.id == subtask.id }) {
            subtasks[index] = subtask
            objectWillChange.send()
        }
    }
    
    @discardableResult
    func saveTask() -> TodoTask {
        if let editingTask = editingTask {
            // Editing existing task
            var updatedTask = TodoTask(
                id: editingTask.id,
                name: name,
                description: nil,
                startTime: startTime,
                duration: duration,
                hasDuration: hasDuration,
                category: category,
                priority: priority,
                icon: icon,
                recurrence: recurrence,
                pomodoroSettings: pomodoroSettings,
                subtasks: subtasks
            )
            
            // Preserve completions and completion dates
            updatedTask.completions = editingTask.completions
            updatedTask.completionDates = editingTask.completionDates
            
            // Update subtask completion states
            for subtask in subtasks {
                if let existingSubtask = editingTask.subtasks.first(where: { $0.id == subtask.id }) {
                    for (date, completion) in editingTask.completions {
                        if completion.completedSubtasks.contains(existingSubtask.id) {
                            updatedTask.completions[date]?.completedSubtasks.insert(subtask.id)
                        }
                    }
                }
            }
            
            taskManager.updateTask(updatedTask)
            return updatedTask
        } else {
            // Creating new task
            let newTask = TodoTask(
                id: UUID(),
                name: name,
                description: nil,
                startTime: startTime,
                duration: duration,
                hasDuration: hasDuration,
                category: category,
                priority: priority,
                icon: icon,
                recurrence: recurrence,
                pomodoroSettings: pomodoroSettings,
                subtasks: subtasks
            )
            
            taskManager.addTask(newTask)
            return newTask
        }
    }
    
    func configurePomodoroSettings(workDuration: Int, breakDuration: Int, longBreakDuration: Int, sessionsUntilLongBreak: Int) {
        pomodoroSettings = PomodoroSettings(
            workDuration: Double(workDuration) * 60.0, // Convert to seconds
            breakDuration: Double(breakDuration) * 60.0, // Convert to seconds
            longBreakDuration: Double(longBreakDuration) * 60.0, // Convert to seconds
            sessionsUntilLongBreak: sessionsUntilLongBreak
        )
    }
    
    func removePomodoroSettings() {
        pomodoroSettings = nil
    }
} 