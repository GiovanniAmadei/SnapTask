import Foundation
import SwiftUI
import Combine

// Filter enums
enum TimelineViewMode: String, CaseIterable {
    case list = "list"
    case timeline = "timeline"
    
    var displayName: String {
        switch self {
        case .list: return "list_view".localized
        case .timeline: return "timeline_view".localized
        }
    }
    
    var icon: String {
        switch self {
        case .list: return "list.bullet"
        case .timeline: return "clock"
        }
    }
}

enum TimelineOrganization: String, CaseIterable {
    case time = "time"
    case category = "category" 
    case priority = "priority"
    case none = "none"
    
    var displayName: String {
        switch self {
        case .time: return "by_time".localized
        case .category: return "by_category".localized
        case .priority: return "by_priority".localized
        case .none: return "default".localized
        }
    }
    
    var icon: String {
        switch self {
        case .time: return "clock"
        case .category: return "folder"
        case .priority: return "exclamationmark.triangle"
        case .none: return "list.bullet"
        }
    }
}

enum TimeSortOrder: String, CaseIterable {
    case ascending = "ascending"
    case descending = "descending"
    
    var displayName: String {
        switch self {
        case .ascending: return "early_to_late".localized
        case .descending: return "late_to_early".localized
        }
    }
}

@MainActor
class TimelineViewModel: ObservableObject {
    @Published private(set) var tasks: [TodoTask] = []
    @Published var selectedDate: Date = Date()
    @Published var timelineStartHour: Int = 6
    @Published var timelineEndHour: Int = 22
    private let taskManager = TaskManager.shared
    
    // New view mode and organization properties
    @Published var viewMode: TimelineViewMode = .list
    @Published var organization: TimelineOrganization = .none
    @Published var timeSortOrder: TimeSortOrder = .ascending
    @Published var showingFilterSheet = false
    @Published var showingTimelineView = false
    
    @Published var openSwipeTaskId: UUID? = nil
    
    private let tasksKey = "saved_tasks"
    private var cancellables = Set<AnyCancellable>()
    
    @Published private(set) var monthYearString: String = ""
    
    init() {
        updateMonthYearString()
        
        // Observe TaskManager changes
        NotificationCenter.default.publisher(for: .tasksDidUpdate)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshTasks()
            }
            .store(in: &cancellables)
        
        // Observe selected date changes
        $selectedDate
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateMonthYearString()
                self?.refreshTasks()
            }
            .store(in: &cancellables)
            
        // Initial load
        refreshTasks()
    }
    
    private func refreshTasks() {
        let calendar = Calendar.current
        _ = calendar.startOfDay(for: selectedDate)
        
        tasks = taskManager.tasks.filter { task in
            // Include tasks specifically for this day
            if calendar.isDate(task.startTime, inSameDayAs: selectedDate) {
                return true
            }
            
            // Include recurring tasks
            if let recurrence = task.recurrence {
                // Check if task has started
                if selectedDate < calendar.startOfDay(for: task.startTime) {
                    return false
                }
                
                // Check end date if it exists
                if let endDate = recurrence.endDate, selectedDate > endDate {
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
                case .monthlyOrdinal(let patterns):
                    return recurrence.shouldOccurOn(date: selectedDate)
                case .yearly:
                    return recurrence.shouldOccurOn(date: selectedDate)
                }
            }
            
            return false
        }
        .sorted { task1, task2 in
            // First, sort by start time
            if task1.startTime != task2.startTime {
                return task1.startTime < task2.startTime
            }
            // Then by creation date - older tasks first (new tasks go to bottom)
            return task1.creationDate < task2.creationDate
        }
        
        objectWillChange.send()
    }
    
    func addTask(_ task: TodoTask) {
        print("Adding task: \(task.name)")
        print("Start time: \(task.startTime)")
        print("Recurrence: \(String(describing: task.recurrence))")
        Task {
            await taskManager.addTask(task)
        }
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
        selectedDate = Calendar.current.date(
            byAdding: .day,
            value: offset,
            to: Date()
        ) ?? Date()
    }
    
    func organizedTasksForSelectedDate() -> OrganizedTasks {
        let calendar = Calendar.current
        let selectedStartOfDay = calendar.startOfDay(for: selectedDate)
        
        let filteredTasks = tasks.filter { task in
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
            case .monthlyOrdinal(let patterns):
                return recurrence.shouldOccurOn(date: selectedDate)
            case .yearly:
                return recurrence.shouldOccurOn(date: selectedDate)
            }
        }
        
        // Organize tasks based on organization mode
        switch organization {
        case .none:
            return OrganizedTasks.single(filteredTasks.sorted { $0.startTime < $1.startTime })
            
        case .time:
            let sortedTasks = filteredTasks.sorted { task1, task2 in
                let time1 = calendar.component(.hour, from: task1.startTime) * 60 + calendar.component(.minute, from: task1.startTime)
                let time2 = calendar.component(.hour, from: task2.startTime) * 60 + calendar.component(.minute, from: task2.startTime)
                return timeSortOrder == .ascending ? time1 < time2 : time1 > time2
            }
            return OrganizedTasks.single(sortedTasks)
            
        case .category:
            return organizeByCategory(filteredTasks)
            
        case .priority:
            return organizeByPriority(filteredTasks)
        }
    }
    
    private func organizeByCategory(_ tasks: [TodoTask]) -> OrganizedTasks {
        let grouped = Dictionary(grouping: tasks) { task in
            task.category?.name ?? "no_category".localized
        }
        
        let sections = grouped.map { categoryName, tasks in
            let category = tasks.first?.category
            return TaskSection(
                id: category?.id.uuidString ?? "no-category",
                title: categoryName,
                color: category?.color,
                icon: "folder", 
                tasks: tasks.sorted { $0.startTime < $1.startTime }
            )
        }.sorted { $0.title < $1.title }
        
        return OrganizedTasks.sections(sections)
    }
    
    private func organizeByPriority(_ tasks: [TodoTask]) -> OrganizedTasks {
        let priorityOrder: [Priority] = [.high, .medium, .low]
        let grouped = Dictionary(grouping: tasks) { $0.priority }
        
        let sections = priorityOrder.compactMap { priority -> TaskSection? in 
            guard let tasks = grouped[priority], !tasks.isEmpty else { return nil }
            return TaskSection(
                id: priority.rawValue,
                title: priority.displayName + " " + "priority".localized,
                color: priority.color,
                icon: priority.icon,
                tasks: tasks.sorted { $0.startTime < $1.startTime }
            )
        }
        
        return OrganizedTasks.sections(sections)
    }
    
    func tasksForSelectedDate() -> [TodoTask] {
        switch organizedTasksForSelectedDate() {
        case .single(let tasks):
            return tasks
        case .sections(let sections):
            return sections.flatMap { $0.tasks }
        }
    }
    
    var availableCategories: [Category] {
        let taskCategories = tasks.compactMap { $0.category }
        return Array(Set(taskCategories)).sorted { $0.name < $1.name }
    }
    
    func resetView() {
        organization = .none
        timeSortOrder = .ascending
        viewMode = .list
    }
    
    var organizationStatusText: String {
        switch organization {
        case .none:
            return "default_view".localized
        case .time:
            return "by_time".localized + " (\(timeSortOrder.displayName))"
        case .category:
            return "by_category".localized
        case .priority:
            return "by_priority".localized
        }
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
            TaskIndicator(color: task.category?.color ?? "#808080")
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
            case .monthlyOrdinal(let patterns):
                return recurrence.shouldOccurOn(date: date)
            case .yearly:
                return recurrence.shouldOccurOn(date: date)
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
                case .monthlyOrdinal(let patterns):
                    return recurrence.shouldOccurOn(date: now)
                case .yearly:
                    return recurrence.shouldOccurOn(date: now)
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
    
    func setOpenSwipeTask(_ taskId: UUID?) {
        if openSwipeTaskId != taskId {
            openSwipeTaskId = taskId
        }
    }
    
    func closeAllSwipeMenus() {
        openSwipeTaskId = nil
    }
    
    func isSwipeMenuOpen(for taskId: UUID) -> Bool {
        return openSwipeTaskId == taskId
    }
    
}

enum OrganizedTasks {
    case single([TodoTask])
    case sections([TaskSection])
}

struct TaskSection: Identifiable {
    let id: String
    let title: String
    let color: String?
    let icon: String?
    let tasks: [TodoTask]
}