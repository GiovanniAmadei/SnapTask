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
    case eisenhower = "eisenhower"
    case none = "none"
    
    var displayName: String {
        switch self {
        case .time: return "by_time".localized
        case .category: return "by_category".localized
        case .priority: return "by_priority".localized
        case .eisenhower: return "eisenhower_matrix".localized
        case .none: return "default".localized
        }
    }
    
    var icon: String {
        switch self {
        case .time: return "clock"
        case .category: return "folder"
        case .priority: return "exclamationmark.triangle"
        case .eisenhower: return "square.grid.2x2"
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
    @Published var organization: TimelineOrganization = .time
    @Published var timeSortOrder: TimeSortOrder = .ascending
    @Published var showingFilterSheet = false
    @Published var showingTimelineView = false
    
    // MARK: - TimeScope Properties
    @Published var selectedTimeScope: TaskTimeScope = .today
    @Published var currentWeek: Date = Date()
    @Published var currentMonth: Date = Date()
    @Published var currentYear: Date = Date()
    
    @Published var openSwipeTaskId: UUID? = nil

    @Published var showAllHistory: Bool = false
    
    private let tasksKey = "saved_tasks"
    private var cancellables = Set<AnyCancellable>()

    @Published private(set) var monthYearString: String = ""
    
    var currentPeriodString: String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        
        switch selectedTimeScope {
        case .today:
            if calendar.isDateInToday(selectedDate) {
                return "scope_today".localized
            } else {
                formatter.dateStyle = .medium
                return formatter.string(from: selectedDate)
            }
        case .week:
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: currentWeek)!
            formatter.dateFormat = "dd MMM"
            let startString = formatter.string(from: currentWeek)
            let endString = formatter.string(from: weekEnd)
            return "\(startString) - \(endString)"
        case .month:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: currentMonth)
        case .year:
            formatter.dateFormat = "yyyy"
            return formatter.string(from: currentYear)
        case .longTerm:
            return "scope_long_term".localized
        case .all:
            return "all_goals".localized
        }
    }
    
    var scopeSubtitle: String {
        return ""
    }
    
    init() {
        updateMonthYearString()
        initializePeriods()
        
        // Observe TaskManager changes
        NotificationCenter.default.publisher(for: .tasksDidUpdate)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshTasks()
            }
            .store(in: &cancellables)
        
        // Observe selected date and scope changes
        $selectedDate
            .combineLatest($selectedTimeScope)
            .combineLatest($currentWeek)
            .combineLatest($currentMonth)
            .combineLatest($currentYear)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateMonthYearString()
                self?.refreshTasks()
            }
            .store(in: &cancellables)
        
        $showAllHistory
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshTasks()
            }
            .store(in: &cancellables)
        
        // Initial load
        refreshTasks()
    }
    
    private func initializePeriods() {
        let calendar = Calendar.current
        currentWeek = calendar.startOfWeek(for: Date())
        currentMonth = calendar.startOfMonth(for: Date())
        currentYear = calendar.startOfYear(for: Date())
    }
    
    private func refreshTasks() {
        tasks = filteredTasksForScope()
            .sorted { task1, task2 in
                // First, sort by start time
                if task1.startTime != task2.startTime {
                    return task1.startTime < task2.startTime
                }
                // Stable tie-breakers to avoid reordering on updates
                if task1.creationDate != task2.creationDate {
                    return task1.creationDate < task2.creationDate
                }
                let n1 = task1.name.lowercased()
                let n2 = task2.name.lowercased()
                if n1 != n2 { return n1 < n2 }
                return task1.id.uuidString < task2.id.uuidString
            }
        
        objectWillChange.send()
    }
    
    // MARK: - TimeScope Filtering
    
    private func filteredTasksForScope() -> [TodoTask] {
        let allTasks = taskManager.tasks
        
        print("=== FILTERING TASKS FOR SCOPE: \(selectedTimeScope) ===")
        print("Total tasks available: \(allTasks.count)")
        
        let filtered: [TodoTask]
        
        switch selectedTimeScope {
        case .today:
            filtered = tasksForDay(selectedDate, from: allTasks)
        case .week:
            filtered = tasksForWeek(currentWeek, from: allTasks)
        case .month:
            filtered = tasksForMonth(currentMonth, from: allTasks)
        case .year:
            filtered = tasksForYear(currentYear, from: allTasks)
        case .longTerm:
            filtered = longTermTasks(from: allTasks)
        case .all:
            if showAllHistory {
                filtered = allTasks
            } else {
                let day = tasksForDay(selectedDate, from: allTasks).filter { $0.timeScope == .today }
                let week = tasksForWeek(currentWeek, from: allTasks).filter { $0.timeScope == .week }
                let month = tasksForMonth(currentMonth, from: allTasks).filter { $0.timeScope == .month }
                let year = tasksForYear(currentYear, from: allTasks).filter { $0.timeScope == .year }
                let longTerm = longTermTasks(from: allTasks) // long term sempre visibili
                filtered = day + week + month + year + longTerm
            }
        }
        
        print("Final filtered tasks count: \(filtered.count)")
        for task in filtered {
            print("- \(task.name) (\(task.timeScope))")
        }
        print("=== END FILTERING ===")
        
        return filtered
    }

    private func tasksForDay(_ date: Date, from tasks: [TodoTask]) -> [TodoTask] {
        let calendar = Calendar.current
        return tasks.filter { task in
            if task.timeScope == .today {
                if task.recurrence != nil {
                    return task.occurs(on: date)
                } else {
                    return calendar.isDate(task.startTime, inSameDayAs: date)
                }
            }
            return false
        }
    }
    
    private func tasksForWeek(_ weekStart: Date, from tasks: [TodoTask]) -> [TodoTask] {
        let calendar = Calendar.current
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
        
        print("=== FILTERING WEEK TASKS ===")
        print("Target week: \(weekStart) to \(weekEnd)")
        
        let filteredTasks = tasks.filter { task in
            guard task.timeScope == .week else { return false }
            
            print("Checking task: \(task.name)")
            print("  - timeScope: \(task.timeScope)")
            print("  - scopeStartDate: \(String(describing: task.scopeStartDate))")
            print("  - scopeEndDate: \(String(describing: task.scopeEndDate))")
            print("  - recurrence: \(String(describing: task.recurrence))")
            
            if task.recurrence != nil {
                let occurs = task.occurs(inWeekStarting: weekStart)
                print("  - Recurs in this week: \(occurs)")
                return occurs
            } else {
                if let taskScopeStart = task.scopeStartDate, let taskScopeEnd = task.scopeEndDate {
                    let matches = calendar.isDate(taskScopeStart, inSameDayAs: weekStart) &&
                                  calendar.isDate(taskScopeEnd, inSameDayAs: weekEnd)
                    print("  - Week match: \(matches)")
                    return matches
                } else {
                    print("  - Missing scope dates, excluding")
                    return false
                }
            }
        }
        
        print("Filtered \(filteredTasks.count) tasks for this week")
        return filteredTasks
    }
    
    private func tasksForMonth(_ monthStart: Date, from tasks: [TodoTask]) -> [TodoTask] {
        let calendar = Calendar.current
        
        print("=== FILTERING MONTH TASKS ===")
        print("Target month: \(monthStart)")
        
        let filteredTasks = tasks.filter { task in
            guard task.timeScope == .month else { return false }
            
            print("Checking task: \(task.name)")
            print("  - timeScope: \(task.timeScope)")
            print("  - scopeStartDate: \(String(describing: task.scopeStartDate))")
            print("  - recurrence: \(String(describing: task.recurrence))")
            
            if task.recurrence != nil {
                let occurs = task.occurs(inMonth: monthStart)
                print("  - Recurs this month: \(occurs)")
                return occurs
            } else {
                if let taskScopeStart = task.scopeStartDate {
                    let matches = calendar.isDate(taskScopeStart, equalTo: monthStart, toGranularity: .month)
                    print("  - Month match: \(matches)")
                    return matches
                } else {
                    print("  - Missing scope start date, excluding")
                    return false
                }
            }
        }
        
        print("Filtered \(filteredTasks.count) tasks for this month")
        return filteredTasks
    }
    
    private func tasksForYear(_ yearStart: Date, from tasks: [TodoTask]) -> [TodoTask] {
        let calendar = Calendar.current
        
        print("=== FILTERING YEAR TASKS ===")
        print("Target year: \(yearStart)")
        
        let filteredTasks = tasks.filter { task in
            guard task.timeScope == .year else { return false }
            
            print("Checking task: \(task.name)")
            print("  - timeScope: \(task.timeScope)")
            print("  - scopeStartDate: \(String(describing: task.scopeStartDate))")
            print("  - recurrence: \(String(describing: task.recurrence))")
            
            if task.recurrence != nil {
                let occurs = task.occurs(inYear: yearStart)
                print("  - Recurs this year: \(occurs)")
                return occurs
            } else {
                if let taskScopeStart = task.scopeStartDate {
                    let matches = calendar.isDate(taskScopeStart, equalTo: yearStart, toGranularity: .year)
                    print("  - Year match: \(matches)")
                    return matches
                } else {
                    print("  - Missing scope start date, excluding")
                    return false
                }
            }
        }
        
        print("Filtered \(filteredTasks.count) tasks for this year")
        return filteredTasks
    }
    
    private func longTermTasks(from tasks: [TodoTask]) -> [TodoTask] {
        return tasks.filter { task in
            task.timeScope == .longTerm
        }
    }
    
    // MARK: - Navigation Methods
    
    func navigateToPrevious() {
        let calendar = Calendar.current
        
        switch selectedTimeScope {
        case .today:
            selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        case .week:
            currentWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeek) ?? currentWeek
        case .month:
            currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
        case .year:
            currentYear = calendar.date(byAdding: .year, value: -1, to: currentYear) ?? currentYear
        case .longTerm, .all:
            break
        }
    }
    
    func navigateToNext() {
        let calendar = Calendar.current
        
        switch selectedTimeScope {
        case .today:
            selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        case .week:
            currentWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeek) ?? currentWeek
        case .month:
            currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        case .year:
            currentYear = calendar.date(byAdding: .year, value: 1, to: currentYear) ?? currentYear
        case .longTerm, .all:
            break
        }
    }
    
    func navigateToToday() {
        let calendar = Calendar.current
        let today = Date()
        
        switch selectedTimeScope {
        case .today:
            selectedDate = today
        case .week:
            currentWeek = calendar.startOfWeek(for: today)
        case .month:
            currentMonth = calendar.startOfMonth(for: today)
        case .year:
            currentYear = calendar.startOfYear(for: today)
        case .longTerm, .all:
            break
        }
    }
    
    // MARK: - Display Properties
    
    var canNavigatePrevious: Bool {
        // Can always navigate previous (no limits for now)
        return selectedTimeScope != .longTerm
    }
    
    var canNavigateNext: Bool {
        // Can always navigate next (no limits for now)
        return selectedTimeScope != .longTerm
    }
    
    var progressText: String {
        if tasks.isEmpty {
            switch selectedTimeScope {
            case .today:
                if Calendar.current.isDateInToday(selectedDate) {
                    return "no_tasks_today".localized
                } else {
                    return "no_tasks_this_day".localized
                }
            case .week:
                return "no_tasks_this_week".localized
            case .month:
                return "no_tasks_this_month".localized
            case .year:
                return "no_tasks_this_year".localized
            case .all:
                return "0 " + "tasks".localized
            case .longTerm:
                return "no_tasks_long_term".localized
            }
        }
        
        // Only show progress for today scope, for other scopes just show the task count
        switch selectedTimeScope {
        case .today:
            let completedTasks = tasks.filter { task in
                let completion = getCompletion(for: task.id, on: selectedDate)
                return completion?.isCompleted ?? false
            }
            let totalTasks = tasks.count
            return "\(completedTasks.count)/\(totalTasks) " + "completed".localized
        default:
            let taskCount = tasks.count
            if taskCount == 1 {
                return "1 " + "task".localized
            } else {
                return "\(taskCount) " + "tasks".localized
            }
        }
    }
    
    func addTask(_ task: TodoTask) {
        print("Adding task: \(task.name)")
        print("TimeScope: \(task.timeScope)")
        print("Start time: \(task.startTime)")
        print("Scope start: \(String(describing: task.scopeStartDate))")
        print("Scope end: \(String(describing: task.scopeEndDate))")
        print("Recurrence: \(String(describing: task.recurrence))")
        Task {
            await taskManager.addTask(task)
        }
    }
    
    func toggleTaskCompletion(_ taskId: UUID) {
        let targetDate: Date
        let calendar = Calendar.current
        
        switch selectedTimeScope {
        case .today:
            targetDate = selectedDate
        case .week:
            targetDate = currentWeek
        case .month:
            targetDate = currentMonth
        case .year:
            targetDate = currentYear
        case .longTerm:
            targetDate = Date()
        case .all:
            if let t = (tasks.first { $0.id == taskId }) ?? (taskManager.tasks.first { $0.id == taskId }) {
                targetDate = completionTargetDate(for: t)
            } else {
                targetDate = calendar.startOfDay(for: Date())
            }
        }
        
        TaskManager.shared.toggleTaskCompletion(taskId, on: targetDate)
    }
    
    func toggleSubtask(taskId: UUID, subtaskId: UUID) {
        let targetDate: Date
        let calendar = Calendar.current
        
        switch selectedTimeScope {
        case .today:
            targetDate = selectedDate
        case .week:
            targetDate = currentWeek
        case .month:
            targetDate = currentMonth
        case .year:
            targetDate = currentYear
        case .longTerm:
            targetDate = Date()
        case .all:
            if let t = (tasks.first { $0.id == taskId }) ?? (taskManager.tasks.first { $0.id == taskId }) {
                targetDate = completionTargetDate(for: t)
            } else {
                targetDate = calendar.startOfDay(for: Date())
            }
        }
        
        TaskManager.shared.toggleSubtask(taskId: taskId, subtaskId: subtaskId, on: targetDate)
    }
    
    func getCompletion(for taskId: UUID, on date: Date) -> TaskCompletion? {
        if let task = tasks.first(where: { $0.id == taskId }) {
            let calendar = Calendar.current
            let keyDate: Date
            
            switch selectedTimeScope {
            case .today:
                keyDate = calendar.startOfDay(for: date)
            case .week:
                keyDate = calendar.startOfDay(for: currentWeek)
            case .month:
                keyDate = calendar.startOfDay(for: currentMonth)
            case .year:
                keyDate = calendar.startOfDay(for: currentYear)
            case .longTerm:
                keyDate = calendar.startOfDay(for: task.startTime)
            case .all:
                keyDate = calendar.startOfDay(for: completionTargetDate(for: task))
            }
            
            return task.completions[keyDate]
        }
        return nil
    }

    private func completionTargetDate(for task: TodoTask) -> Date {
        let calendar = Calendar.current
        switch task.timeScope {
        case .today:
            return selectedDate
        case .week:
            return currentWeek
        case .month:
            return currentMonth
        case .year:
            return currentYear
        case .longTerm:
            return calendar.startOfDay(for: task.startTime)
        case .all:
            return calendar.startOfDay(for: Date())
        }
    }

    private func targetDate(for task: TodoTask) -> Date {
        let calendar = Calendar.current
        switch task.timeScope {
        case .today:
            return selectedDate
        case .week:
            return currentWeek
        case .month:
            return currentMonth
        case .year:
            return currentYear
        case .longTerm:
            return calendar.startOfDay(for: task.startTime)
        case .all:
            return calendar.startOfDay(for: Date())
        }
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
        // Use already filtered tasks for the current scope
        let scopedTasks = tasks
        
        // Special grouping when viewing "All" scope: split by each task's own time scope
        if selectedTimeScope == .all {
            return organizeByTimeScope(scopedTasks)
        }

        switch organization {
        case .time:
            let sortedTasks = scopedTasks.sorted { task1, task2 in
                let calendar = Calendar.current
                let time1 = calendar.component(.hour, from: task1.startTime) * 60 + calendar.component(.minute, from: task1.startTime)
                let time2 = calendar.component(.hour, from: task2.startTime) * 60 + calendar.component(.minute, from: task2.startTime)
                if time1 != time2 {
                    return timeSortOrder == .ascending ? time1 < time2 : time1 > time2
                }
                // Stable tie-breakers when minute-of-day is equal
                if task1.creationDate != task2.creationDate {
                    return timeSortOrder == .ascending ? (task1.creationDate < task2.creationDate) : (task1.creationDate > task2.creationDate)
                }
                let n1 = task1.name.lowercased()
                let n2 = task2.name.lowercased()
                if n1 != n2 { return timeSortOrder == .ascending ? (n1 < n2) : (n1 > n2) }
                return timeSortOrder == .ascending ? (task1.id.uuidString < task2.id.uuidString) : (task1.id.uuidString > task2.id.uuidString)
            }
            return OrganizedTasks.single(sortedTasks)
        case .category:
            return organizeByCategory(scopedTasks)
        case .priority:
            return organizeByPriority(scopedTasks)
        case .eisenhower:
            let (q1, q2, q3, q4) = eisenhowerQuadrants(scopedTasks)
            let sections: [TaskSection] = [
                TaskSection(id: "q1", title: "urgent_important".localized, color: "#EF4444", icon: "flame.fill", tasks: q1),
                TaskSection(id: "q2", title: "not_urgent_important".localized, color: "#3B82F6", icon: "calendar", tasks: q2),
                TaskSection(id: "q3", title: "urgent_not_important".localized, color: "#F59E0B", icon: "bolt.fill", tasks: q3),
                TaskSection(id: "q4", title: "not_urgent_not_important".localized, color: "#9CA3AF", icon: "square.dashed", tasks: q4),
            ]
            return OrganizedTasks.sections(sections)
        case .none:
            return OrganizedTasks.single(scopedTasks)
        }
    }
    
    func tasksForSelectedDate() -> [TodoTask] {
        // Simply return the already filtered tasks for the current scope
        return tasks
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
                tasks: tasks.sorted { lhs, rhs in
                    if lhs.startTime != rhs.startTime { return lhs.startTime < rhs.startTime }
                    if lhs.creationDate != rhs.creationDate { return lhs.creationDate < rhs.creationDate }
                    let n1 = lhs.name.lowercased(); let n2 = rhs.name.lowercased()
                    if n1 != n2 { return n1 < n2 }
                    return lhs.id.uuidString < rhs.id.uuidString
                }
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
                tasks: tasks.sorted { lhs, rhs in
                    if lhs.startTime != rhs.startTime { return lhs.startTime < rhs.startTime }
                    if lhs.creationDate != rhs.creationDate { return lhs.creationDate < rhs.creationDate }
                    let n1 = lhs.name.lowercased(); let n2 = rhs.name.lowercased()
                    if n1 != n2 { return n1 < n2 }
                    return lhs.id.uuidString < rhs.id.uuidString
                }
            )
        }
        
        return OrganizedTasks.sections(sections)
    }

    // Group tasks by their time scope for the "All" view
    private func organizeByTimeScope(_ tasks: [TodoTask]) -> OrganizedTasks {
        // Desired order of sections
        let order: [TaskTimeScope] = [.today, .week, .month, .year, .longTerm]
        
        func colorHex(for scope: TaskTimeScope) -> String {
            switch scope {
            case .today: return "#3B82F6"   // blue
            case .week: return "#10B981"    // green
            case .month: return "#F59E0B"   // orange
            case .year: return "#8B5CF6"    // purple
            case .longTerm: return "#EC4899"// pink
            case .all: return "#14B8A6"     // teal (not used in sections)
            }
        }
        
        let grouped = Dictionary(grouping: tasks) { $0.timeScope }
        let sections: [TaskSection] = order.compactMap { scope in
            guard let list = grouped[scope], !list.isEmpty else { return nil }
            return TaskSection(
                id: scope.rawValue,
                title: scope.displayName,
                color: colorHex(for: scope),
                icon: scope.icon,
                tasks: list.sorted { lhs, rhs in
                    if lhs.startTime != rhs.startTime { return lhs.startTime < rhs.startTime }
                    return lhs.creationDate < rhs.creationDate
                }
            )
        }
        
        // If for some reason only one section exists, still return as sections to show headers
        return OrganizedTasks.sections(sections)
    }
    
    var availableCategories: [Category] {
        let taskCategories = tasks.compactMap { $0.category }
        return Array(Set(taskCategories)).sorted { $0.name < $1.name }
    }
    
    func resetView() {
        organization = .time
        timeSortOrder = .ascending
        viewMode = .list
    }
    
    var organizationStatusText: String {
        switch organization {
        case .time:
            return "by_time".localized
        case .category:
            return "by_category".localized
        case .priority:
            return "by_priority".localized
        case .eisenhower:
            return "eisenhower_matrix".localized
        case .none:
            return "default".localized
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
        guard let date = Calendar.current.date(byAdding: .day, value: offset, to: selectedDate) else {
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
            if task.recurrence == nil {
                return calendar.isDate(task.startTime, inSameDayAs: date)
            }
            guard let recurrence = task.recurrence else { return false }
            let taskStartOfDay = calendar.startOfDay(for: task.startTime)
            
            if dateStartOfDay < taskStartOfDay {
                return false
            }
            
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
        .sorted { lhs, rhs in
            if lhs.startTime != rhs.startTime { return lhs.startTime < rhs.startTime }
            if lhs.creationDate != rhs.creationDate { return lhs.creationDate < rhs.creationDate }
            let n1 = lhs.name.lowercased(); let n2 = rhs.name.lowercased()
            if n1 != n2 { return n1 < n2 }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }
    
    var dueTasks: [TodoTask] {
        let calendar = Calendar.current
        let now = Date()
        _ = calendar.startOfDay(for: now)
        
        return tasks.filter { task in
            let completion = getCompletion(for: task.id, on: now)
            let isCompleted = completion?.isCompleted ?? false
            
            if isCompleted {
                return false
            }
            
            if calendar.isDateInToday(task.startTime) || task.startTime < now {
                return true
            }
            
            if let recurrence = task.recurrence {
                if now < calendar.startOfDay(for: task.startTime) {
                    return false
                }
                
                if let endDate = recurrence.endDate, now > endDate {
                    return false
                }
                
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
        }.sorted { lhs, rhs in
            if lhs.startTime != rhs.startTime { return lhs.startTime < rhs.startTime }
            if lhs.creationDate != rhs.creationDate { return lhs.creationDate < rhs.creationDate }
            let n1 = lhs.name.lowercased(); let n2 = rhs.name.lowercased()
            if n1 != n2 { return n1 < n2 }
            return lhs.id.uuidString < rhs.id.uuidString
        }
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
    
    private func isImportant(_ task: TodoTask) -> Bool {
        return task.priority == .high
    }

    private func dueDate(for task: TodoTask) -> Date? {
        let cal = Calendar.current
        switch task.timeScope {
        case .today:
            if task.hasSpecificTime {
                return task.startTime
            } else {
                return cal.date(bySettingHour: 23, minute: 59, second: 59, of: cal.startOfDay(for: task.startTime))
            }
        case .week:
            let start = currentWeek
            let end = cal.date(byAdding: .day, value: 6, to: start) ?? start
            return task.scopeEndDate ?? end
        case .month:
            let start = currentMonth
            let end = (cal.date(byAdding: .month, value: 1, to: start) ?? start).addingTimeInterval(-1)
            return task.scopeEndDate ?? end
        case .year:
            let start = currentYear
            let end = (cal.date(byAdding: .year, value: 1, to: start) ?? start).addingTimeInterval(-1)
            return task.scopeEndDate ?? end
        case .longTerm:
            return nil
        case .all:
            return nil
        }
    }

    private func isUrgent(_ task: TodoTask) -> Bool {
        guard let due = dueDate(for: task) else { return false }
        let now = Date()
        if due <= now { return true }

        // Thresholds by scope (customizable via SettingsViewModel)
        let settings = SettingsViewModel.shared
        let threshold: TimeInterval
        switch selectedTimeScope {
        case .today:
            if settings.eisenhowerTodayRequireSpecificTime && !task.hasSpecificTime { return false }
            threshold = TimeInterval(settings.eisenhowerTodayUrgentHours) * 3600
        case .week:
            threshold = TimeInterval(settings.eisenhowerWeekUrgentHours) * 3600
        case .month:
            threshold = TimeInterval(settings.eisenhowerMonthUrgentDays) * 24 * 3600
        case .year:
            threshold = TimeInterval(settings.eisenhowerYearUrgentDays) * 24 * 3600
        case .longTerm:
            return false
        case .all:
            switch task.timeScope {
            case .today:
                if settings.eisenhowerTodayRequireSpecificTime && !task.hasSpecificTime { return false }
                threshold = TimeInterval(settings.eisenhowerTodayUrgentHours) * 3600
            case .week:
                threshold = TimeInterval(settings.eisenhowerWeekUrgentHours) * 3600
            case .month:
                threshold = TimeInterval(settings.eisenhowerMonthUrgentDays) * 24 * 3600
            case .year:
                threshold = TimeInterval(settings.eisenhowerYearUrgentDays) * 24 * 3600
            case .longTerm, .all:
                return false
            }
        }
        return due.timeIntervalSince(now) <= threshold
    }

    func eisenhowerQuadrants(_ source: [TodoTask]? = nil) -> ([TodoTask], [TodoTask], [TodoTask], [TodoTask]) {
        let scoped = source ?? tasks
        var q1: [TodoTask] = [] // Urgent + Important
        var q2: [TodoTask] = [] // Not Urgent + Important
        var q3: [TodoTask] = [] // Urgent + Not Important
        var q4: [TodoTask] = [] // Not Urgent + Not Important

        for task in scoped {
            let important = isImportant(task)
            let urgent = isUrgent(task)
            switch (urgent, important) {
            case (true, true): q1.append(task)
            case (false, true): q2.append(task)
            case (true, false): q3.append(task)
            case (false, false): q4.append(task)
            }
        }

        // Keep time order inside each quadrant
        let sorted: ([TodoTask]) -> [TodoTask] = { arr in
            arr.sorted { lhs, rhs in
                if lhs.startTime != rhs.startTime {
                    return lhs.startTime < rhs.startTime
                }
                return lhs.creationDate < rhs.creationDate
            }
        }

        return (sorted(q1), sorted(q2), sorted(q3), sorted(q4))
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

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
    
    func startOfYear(for date: Date) -> Date {
        let components = dateComponents([.year], from: date)
        return self.date(from: components) ?? date
    }
}