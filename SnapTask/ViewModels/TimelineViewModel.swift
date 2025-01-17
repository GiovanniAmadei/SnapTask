import Foundation
import SwiftUI
import Combine

class TimelineViewModel: ObservableObject {
    @Published private(set) var tasks: [TodoTask] = []
    @Published var selectedDate: Date
    @Published var timelineStartHour: Int = 6
    @Published var timelineEndHour: Int = 22
    private let taskManager = TaskManager.shared
    
    private let tasksKey = "saved_tasks"
    private var cancellables = Set<AnyCancellable>()
    
    @Published private(set) var monthYearString: String = ""
    
    init() {
        selectedDate = Date()
        updateMonthYearString()
        
        // Update month string whenever selected date changes
        $selectedDate
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateMonthYearString()
            }
            .store(in: &cancellables)
            
        taskManager.$tasks
            .sink { [weak self] tasks in
                self?.tasks = tasks
            }
            .store(in: &cancellables)
    }
    
    func addTask(_ task: TodoTask) {
        print("Adding task: \(task.name)")
        print("Start time: \(task.startTime)")
        print("Recurrence: \(String(describing: task.recurrence))")
        taskManager.addTask(task)
    }
    
    func toggleTaskCompletion(_ taskId: UUID) {
        TaskManager.shared.toggleTaskCompletion(taskId, on: selectedDate)
    }
    
    func toggleSubtask(taskId: UUID, subtaskId: UUID) {
        TaskManager.shared.toggleSubtask(taskId: taskId, subtaskId: subtaskId, on: selectedDate)
    }
    
    func getCompletion(for taskId: UUID, on date: Date) -> TaskCompletion? {
        if let task = tasks.first(where: { $0.id == taskId }) {
            return task.completions[date.startOfDay]
        }
        return nil
    }
    
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: selectedDate)
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }
    
    func selectDate(_ offset: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: offset, to: Date()) {
            selectedDate = newDate
        }
    }
    
    func tasksForSelectedDate() -> [TodoTask] {
        let calendar = Calendar.current
        let selectedStartOfDay = calendar.startOfDay(for: selectedDate)
        
        return tasks.filter { task in
            // For non-recurring tasks
            if task.recurrence == nil {
                return calendar.isDate(task.startTime, inSameDayAs: selectedDate)
            }
            
            // For recurring tasks
            guard let recurrence = task.recurrence else { return false }
            let taskStartOfDay = calendar.startOfDay(for: task.startTime)
            
            // Only show tasks that have started
            if selectedStartOfDay < taskStartOfDay {
                return false
            }
            
            // Check recurrence pattern
            switch recurrence.type {
            case .daily:
                return true
            case .weekly(let days):
                let weekday = calendar.component(.weekday, from: selectedDate)
                return days.contains(weekday)
            case .monthly(let days):
                let day = calendar.component(.day, from: selectedDate)
                return days.contains(day)
            }
        }
        .sorted { $0.startTime < $1.startTime }
    }
    
    func weekdayString(for offset: Int) -> String {
        guard let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).lowercased()
    }
    
    func dayString(for offset: Int) -> String {
        guard let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    struct TaskIndicator: Identifiable {
        let id = UUID()
        let color: String
    }
    
    func taskIndicators(for offset: Int) -> [TaskIndicator] {
        guard let date = Calendar.current.date(byAdding: .day, value: offset, to: selectedDate) else {
            return []
        }
        
        return tasksForDate(date).map { task in
            TaskIndicator(color: task.category!.color)
        }
    }
    
    private func categoryColor(for task: TodoTask) -> Color {
        if let category = task.category {
            return Color(hex: category.color)
        }
        return .gray // Default color when no category is set
    }
    
    private func tasksForDate(_ date: Date) -> [TodoTask] {
        let calendar = Calendar.current
        let dateStartOfDay = calendar.startOfDay(for: date)
        
        return tasks.filter { task in
            // For non-recurring tasks
            if task.recurrence == nil {
                return calendar.isDate(task.startTime, inSameDayAs: date)
            }
            
            // For recurring tasks
            guard let recurrence = task.recurrence else { return false }
            let taskStartOfDay = calendar.startOfDay(for: task.startTime)
            
            // Only show tasks that have started
            if dateStartOfDay < taskStartOfDay {
                return false
            }
            
            // Check recurrence pattern without end date limitation
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
        .sorted { $0.startTime < $1.startTime }
    }
    
    var dueTasks: [TodoTask] {
        let calendar = Calendar.current
        let now = Date()
        _ = calendar.startOfDay(for: now)
        
        return tasks.filter { task in
            // Get completion status for today
            let completion = getCompletion(for: task.id, on: now)
            let isCompleted = completion?.isCompleted ?? false
            
            // Skip if task is completed
            if isCompleted {
                return false
            }
            
            // Check if task is due today or overdue
            if calendar.isDateInToday(task.startTime) || task.startTime < now {
                return true
            }
            
            // Check recurring tasks
            if let recurrence = task.recurrence {
                // Check if task has started
                if now < calendar.startOfDay(for: task.startTime) {
                    return false
                }
                
                // Check end date if it exists
                if let endDate = recurrence.endDate, now > endDate {
                    return false
                }
                
                // Check recurrence pattern
                switch recurrence.type {
                case .daily:
                    return true
                case .weekly(let days):
                    let weekday = calendar.component(.weekday, from: now)
                    return days.contains(weekday)
                case .monthly(let days):
                    let day = calendar.component(.day, from: now)
                    return days.contains(day)
                }
            }
            
            return false
        }.sorted { $0.startTime < $1.startTime }
    }
    
    var effectiveStartHour: Int {
        if tasks.isEmpty {
            return timelineStartHour
        }
        
        let tasksForDay = tasksForSelectedDate()
        let earliestTask = tasksForDay.min { task1, task2 in
            Calendar.current.component(.hour, from: task1.startTime) <
            Calendar.current.component(.hour, from: task2.startTime)
        }
        
        return earliestTask.map { Calendar.current.component(.hour, from: $0.startTime) } ?? timelineStartHour
    }
    
    var effectiveEndHour: Int {
        if tasks.isEmpty {
            return timelineEndHour
        }
        
        let tasksForDay = tasksForSelectedDate()
        let latestTask = tasksForDay.max { task1, task2 in
            let hour1 = Calendar.current.component(.hour, from: task1.startTime)
            let hour2 = Calendar.current.component(.hour, from: task2.startTime)
            return (hour1 + Int(task1.duration/3600)) <
                   (hour2 + Int(task2.duration/3600))
        }
        
        if let task = latestTask {
            let endHour = Calendar.current.component(.hour, from: task.startTime) +
                         Int(task.duration/3600)
            return min(max(endHour + 1, timelineStartHour), timelineEndHour)
        }
        return timelineEndHour
    }
    
    private func updateMonthYearString() {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        monthYearString = formatter.string(from: selectedDate)
    }
} 
