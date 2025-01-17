import Foundation
import SwiftUI
import Combine

class TimelineViewModel: ObservableObject {
    @Published private(set) var tasks: [TodoTask] = []
    @Published var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @Published var timelineStartHour: Int = 6
    @Published var timelineEndHour: Int = 22
    private let taskManager = TaskManager.shared
    
    private let tasksKey = "saved_tasks"
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        selectedDate = Calendar.current.startOfDay(for: Date())
        taskManager.$tasks
            .sink { [weak self] tasks in
                self?.tasks = tasks
            }
            .store(in: &cancellables)
    }
    
    func refresh() {
        // Force a refresh of the tasks
        tasks = taskManager.tasks
        // Update selected date to ensure proper date-based calculations
        selectedDate = Calendar.current.startOfDay(for: selectedDate)
    }
    
    func addTask(_ task: TodoTask) {
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
        tasks
            .filter { isTaskOnSelectedDate($0) }
            .sorted { $0.startTime < $1.startTime }
    }
    
    var monthYearString: String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: selectedDate)
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
            TaskIndicator(color: task.category.color)
        }
    }
    
    private func tasksForDate(_ date: Date) -> [TodoTask] {
        tasks.filter { task in
            Calendar.current.isDate(task.startTime, inSameDayAs: date)
        }
    }
    
    var dueTasks: [TodoTask] {
        let calendar = Calendar.current
        let now = Date()
        
        return tasks.filter { task in
            // Get completion status for today
            let completion = getCompletion(for: task.id, on: now)
            let isCompleted = completion?.isCompleted ?? false
            
            // Include task if:
            // 1. It's not completed AND
            // 2. Either:
            //    - It's due today
            //    - It's overdue
            //    - It's a recurring task that should appear today
            if !isCompleted {
                if calendar.isDateInToday(task.startTime) || task.startTime < now {
                    return true
                }
                
                // Check recurrence
                if let recurrence = task.recurrence {
                    return shouldTaskAppear(task, with: recurrence, on: now)
                }
            }
            return false
        }.sorted { $0.startTime < $1.startTime }
    }
    
    private func shouldTaskAppear(_ task: TodoTask, with recurrence: Recurrence, on date: Date) -> Bool {
        if let endDate = recurrence.endDate, date > endDate {
            return false
        }
        
        switch recurrence.type {
        case .daily:
            return true
        case .weekly(let days):
            let weekday = Calendar.current.component(.weekday, from: date)
            return days.contains(weekday)
        case .monthly(let days):
            let day = Calendar.current.component(.day, from: date)
            return days.contains(day)
        }
    }
    
    private func isTaskOnSelectedDate(_ task: TodoTask) -> Bool {
        let calendar = Calendar.current
        
        // Check if task starts on selected date
        if calendar.isDate(task.startTime, inSameDayAs: selectedDate) {
            return true
        }
        
        // Check recurrence
        if let recurrence = task.recurrence {
            return shouldTaskAppear(task, with: recurrence, on: selectedDate)
        }
        
        return false
    }
    
    var effectiveStartHour: Int {
        if tasks.isEmpty {
            return timelineStartHour
        }
        let earliestTask = tasks
            .filter { isTaskOnSelectedDate($0) }
            .min { task1, task2 in
                Calendar.current.component(.hour, from: task1.startTime) <
                Calendar.current.component(.hour, from: task2.startTime)
            }
        return earliestTask.map { Calendar.current.component(.hour, from: $0.startTime) } ?? timelineStartHour
    }
    
    var effectiveEndHour: Int {
        if tasks.isEmpty {
            return timelineEndHour
        }
        let latestTask = tasks
            .filter { isTaskOnSelectedDate($0) }
            .max { task1, task2 in
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
} 