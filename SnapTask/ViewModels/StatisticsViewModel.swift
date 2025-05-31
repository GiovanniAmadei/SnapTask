import SwiftUI
import Combine
import os.log
import Foundation

@MainActor
class StatisticsViewModel: ObservableObject {
    struct CategoryStat: Identifiable, Equatable {
        let id = UUID()
        let name: String
        let color: String
        let hours: Double
        
        static func == (lhs: CategoryStat, rhs: CategoryStat) -> Bool {
            return lhs.name == rhs.name &&
                   lhs.color == rhs.color &&
                   lhs.hours == rhs.hours
        }
    }
    
    struct WeeklyStat: Identifiable, Equatable {
        let id = UUID()
        let day: String
        let completedTasks: Int
        let totalTasks: Int
        let completionRate: Double
        
        static func == (lhs: WeeklyStat, rhs: WeeklyStat) -> Bool {
            return lhs.day == rhs.day &&
                   lhs.completedTasks == rhs.completedTasks &&
                   lhs.totalTasks == rhs.totalTasks
        }
    }
    
    struct TaskStreak: Identifiable, Equatable {
        let id = UUID()
        let taskId: UUID
        let taskName: String
        let categoryName: String?
        let categoryColor: String?
        let currentStreak: Int
        let bestStreak: Int
        let totalOccurrences: Int
        let completedOccurrences: Int
        let completionRate: Double
        let streakHistory: [StreakPoint]
        
        static func == (lhs: TaskStreak, rhs: TaskStreak) -> Bool {
            return lhs.taskId == rhs.taskId &&
                   lhs.currentStreak == rhs.currentStreak &&
                   lhs.bestStreak == rhs.bestStreak
        }
    }
    
    struct StreakPoint: Identifiable, Equatable {
        let id = UUID()
        let date: Date
        let streakValue: Int
        let wasCompleted: Bool
        
        static func == (lhs: StreakPoint, rhs: StreakPoint) -> Bool {
            return lhs.date == rhs.date &&
                   lhs.streakValue == rhs.streakValue &&
                   lhs.wasCompleted == rhs.wasCompleted
        }
    }
    
    enum TimeRange: String, CaseIterable {
        case today = "Today"
        case week = "Week"
        case month = "Month"
        case year = "Year"
        
        var dateRange: (start: Date, end: Date) {
            let calendar = Calendar.current
            let now = Date()
            switch self {
            case .today:
                return (calendar.startOfDay(for: now), now)
            case .week:
                let weekStart = calendar.date(byAdding: .day, value: -7, to: now)!
                return (weekStart, now)
            case .month:
                let monthStart = calendar.date(byAdding: .month, value: -1, to: now)!
                return (monthStart, now)
            case .year:
                let yearStart = calendar.date(byAdding: .year, value: -1, to: now)!
                return (yearStart, now)
            }
        }
    }
    
    @Published private(set) var categoryStats: [CategoryStat] = []
    @Published private(set) var weeklyStats: [WeeklyStat] = []
    @Published private(set) var currentStreak: Int = 0
    @Published private(set) var bestStreak: Int = 0
    @Published private(set) var taskStreaks: [TaskStreak] = []
    @Published var selectedTimeRange: TimeRange = .today
    @Published private(set) var recurringTasks: [TodoTask] = []
    
    var trackedRecurringTasks: [TodoTask] {
        recurringTasks.filter { task in
            if let recurrence = task.recurrence {
                return recurrence.trackInStatistics
            }
            return false
        }
    }
    
    var consistency: [TodoTask] {
        recurringTasks
    }
    
    private var cancellables = Set<AnyCancellable>()
    private let taskManager: TaskManager
    private let categoryManager = CategoryManager.shared
    private let cloudKitService = CloudKitService.shared
    
    init(taskManager: TaskManager = .shared) {
        self.taskManager = taskManager
        setupObservers()
    }
    
    func refreshStats() {
        DispatchQueue.main.async { [weak self] in
            self?.updateStats()
        }
    }
    
    func refreshAfterSync() {
        DispatchQueue.main.async { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.updateStats()
            }
        }
    }
    
    private func setupObservers() {
        NotificationCenter.default.publisher(for: .tasksDidUpdate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("📊 Tasks updated, refreshing statistics")
                self?.updateStats()
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: .categoriesDidUpdate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("📊 Categories updated, refreshing statistics")
                self?.updateStats()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .timeTrackingUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("📊 Time tracking updated, refreshing statistics")
                self?.updateStats()
            }
            .store(in: &cancellables)
        
        categoryManager.$categories
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("📊 Category manager updated, refreshing statistics")
                self?.updateStats()
            }
            .store(in: &cancellables)
        
        taskManager.$tasks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("📊 Task manager updated, refreshing statistics")
                self?.updateStats()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .cloudKitDataChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("📊 CloudKit data changed, refreshing statistics")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.updateStats()
                }
            }
            .store(in: &cancellables)
        
        cloudKitService.$syncStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                if status == .success {
                    print("📊 CloudKit sync completed, refreshing statistics")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self?.refreshAfterSync()
                    }
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("📊 App became active, refreshing statistics")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.updateStats()
                }
            }
            .store(in: &cancellables)
        
        $selectedTimeRange
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("📊 Time range changed, refreshing statistics")
                self?.updateStats()
            }
            .store(in: &cancellables)
    }
    
    private func updateStats() {
        updateCategoryStats()
        updateWeeklyStats()
        updateStreakStats()
        updateTaskStreaks()
        updateRecurringTasks()
        objectWillChange.send()
    }
    
    private func updateCategoryStats() {
        let categories = categoryManager.categories
        let allTasks = taskManager.tasks
        let (startDate, endDate) = selectedTimeRange.dateRange
        
        print("📊 Date range: \(startDate) to \(endDate)")
        print("📊 Available categories: \(categories.map { "\($0.name) (ID: \($0.id.uuidString.prefix(8)))" })")
        
        let timeTrackingData = UserDefaults.standard.dictionary(forKey: "timeTracking") as? [String: [String: Double]] ?? [:]
        let taskMetadata = UserDefaults.standard.dictionary(forKey: "taskMetadata") as? [String: [String: String]] ?? [:]
        
        var categoryStatsList: [CategoryStat] = []
        
        for category in categories {
            let categoryTasks = allTasks.filter { task in
                if task.category?.id == category.id {
                    return true
                }
                if let taskCategoryName = task.category?.name,
                   taskCategoryName.lowercased() == category.name.lowercased() {
                    print("📊 Found task '\(task.name)' with category name match: '\(taskCategoryName)' -> '\(category.name)'")
                    return true
                }
                return false
            }
            
            print("📊 Category '\(category.name)': found \(categoryTasks.count) tasks")
            
            let taskHours = categoryTasks.reduce(0.0) { total, task in
                let completionHours = task.completions
                    .compactMap { (date, completion) -> Double? in
                        let startOfStartDate = Calendar.current.startOfDay(for: startDate)
                        let endOfEndDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate))!
                        
                        print("📊 Checking task '\(task.name)': date=\(date), startRange=\(startOfStartDate), endRange=\(endOfEndDate), isCompleted=\(completion.isCompleted)")
                        
                        guard date >= startOfStartDate &&
                              date < endOfEndDate &&
                              completion.isCompleted else {
                            print("📊   -> Excluded: outside date range or not completed")
                            return nil
                        }
                        
                        if task.hasDuration && task.duration > 0 {
                            print("📊   -> Included: Task '\(task.name)' completed on \(date) with duration: \(task.duration/3600.0)h")
                            return task.duration / 3600.0
                        } else {
                            print("📊   -> Excluded: Task '\(task.name)' completed on \(date) but has NO duration set")
                            return nil
                        }
                    }
                    .reduce(0.0, +)
                
                return total + completionHours
            }
            
        let calendar = Calendar.current
        var trackedHours = 0.0
            
        var currentDate = startDate
        while currentDate <= endDate {
            let dateKey = ISO8601DateFormatter().string(from: calendar.startOfDay(for: currentDate))
            if let dayData = timeTrackingData[dateKey],
               let categoryHours = dayData[category.id.uuidString] {
                trackedHours += categoryHours
                print("📊 Category \(category.name) on \(dateKey): \(categoryHours)h from Pomodoro tracking")
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate.addingTimeInterval(86400)
        }
            
        let totalHours = taskHours + trackedHours
            
        if totalHours > 0 {
            categoryStatsList.append(CategoryStat(
                name: category.name,
                color: category.color,
                hours: totalHours
            ))
            print("📊 Category \(category.name): \(String(format: "%.2f", taskHours))h from task durations + \(String(format: "%.2f", trackedHours))h from Pomodoro = \(String(format: "%.2f", totalHours))h total")
        } else {
            print("📊 Category \(category.name): 0 hours (no tasks with duration or Pomodoro sessions)")
        }
        }
        
        let calendar = Calendar.current
        var currentDate = startDate
        var taskTracking: [String: Double] = [:]
        
        while currentDate <= endDate {
            let dateKey = ISO8601DateFormatter().string(from: calendar.startOfDay(for: currentDate))
            if let dayData = timeTrackingData[dateKey] {
                for (key, hours) in dayData {
                    if key.hasPrefix("task_") {
                        taskTracking[key, default: 0] += hours
                    }
                }
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate.addingTimeInterval(86400)
        }
        
        for (taskKey, hours) in taskTracking {
            if hours > 0, let metadata = taskMetadata[taskKey] {
                categoryStatsList.append(CategoryStat(
                    name: metadata["name"] ?? "Unknown Task",
                    color: metadata["color"] ?? "#6366F1",
                    hours: hours
                ))
                print("📊 Individual task \(metadata["name"] ?? "Unknown"): \(String(format: "%.2f", hours))h from Pomodoro tracking")
            }
        }
        
        categoryStats = categoryStatsList
        print("📊 FINAL STATISTICS: \(categoryStatsList.count) categories with total hours: \(String(format: "%.2f", categoryStatsList.reduce(0) { $0 + $1.hours }))")
        print("📊 All tasks in system: \(allTasks.count)")
        print("📊 Tasks with duration set: \(allTasks.filter { $0.hasDuration && $0.duration > 0 }.count)")
    }
    
    private func updateWeeklyStats() {
        let calendar = Calendar.current
        let today = Date()
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today)!
        
        weeklyStats = (0...6).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart)!
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!.addingTimeInterval(-1)
            
            let singleDayTasks = taskManager.tasks.filter { task in
                task.recurrence == nil && calendar.isDate(task.startTime, inSameDayAs: date)
            }
            
            let recurringDayTasks = taskManager.tasks.filter { task in
                guard let recurrence = task.recurrence else { return false }
                
                if task.startTime > endOfDay { return false }
                
                if let endDate = recurrence.endDate, endDate < startOfDay { return false }
                
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
            
            let allDayTasks = singleDayTasks + recurringDayTasks
            
            let completedCount = allDayTasks.filter { task in
                if let completion = task.completions[startOfDay], completion.isCompleted {
                    return true
                }
                return false
            }.count
            
            let totalCount = allDayTasks.count
            let completionRate = totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0.0
            
            return WeeklyStat(
                day: date.formatted(.dateTime.weekday(.abbreviated)),
                completedTasks: completedCount,
                totalTasks: totalCount,
                completionRate: completionRate
            )
        }
    }
    
    private func updateStreakStats() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let yearAgo = calendar.date(byAdding: .year, value: -1, to: today) else {
            Logger.stats("Date calculation failed", level: .error)
            return
        }
        
        var currentDate = yearAgo
        var dates: [Date] = []
        
        while currentDate <= today {
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            dates.append(currentDate)
            currentDate = nextDate
        }
        
        var currentStreak = 0
        var bestStreak = 0
        var tempStreak = 0
        
        for date in dates.reversed() {
            let startOfDay = calendar.startOfDay(for: date)
            
            let dayTasks = taskManager.tasks.filter { task in
                guard task.startTime <= startOfDay else { return false }
                
                if calendar.isDate(task.startTime, inSameDayAs: date) {
                    return true
                }
                
                if let recurrence = task.recurrence {
                    if let endDate = recurrence.endDate, endDate < startOfDay { return false }
                    
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
                return false
            }
            
            let allCompletedForDay = !dayTasks.isEmpty && dayTasks.allSatisfy { task in
                if let completion = task.completions[startOfDay] {
                    return completion.isCompleted
                }
                return false
            }
            
            if allCompletedForDay {
                tempStreak += 1
                bestStreak = max(bestStreak, tempStreak)
                
                if calendar.isDateInToday(date) {
                    currentStreak = tempStreak
                }
            } else {
                if tempStreak > 0 && calendar.isDateInToday(date) {
                    currentStreak = 0
                }
                tempStreak = 0
            }
        }
        
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
    }
    
    private func updateTaskStreaks() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today)!
        
        var taskStreaksList: [TaskStreak] = []
        
        for task in recurringTasks {
            guard let recurrence = task.recurrence else { continue }
            
            var streakHistory: [StreakPoint] = []
            var currentStreak = 0
            var bestStreak = 0
            var tempStreak = 0
            var totalOccurrences = 0
            var completedOccurrences = 0
            
            var dates: [Date] = []
            var currentDate = thirtyDaysAgo
            while currentDate <= today {
                dates.append(currentDate)
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            }
            
            for date in dates {
                let startOfDay = calendar.startOfDay(for: date)
                
                if shouldTaskOccurOnDate(task: task, date: startOfDay) {
                    totalOccurrences += 1
                    let isCompleted = task.completions[startOfDay]?.isCompleted == true
                    
                    if isCompleted {
                        tempStreak += 1
                        completedOccurrences += 1
                        bestStreak = max(bestStreak, tempStreak)
                        
                        if calendar.isDate(date, inSameDayAs: today) {
                            currentStreak = tempStreak
                        }
                    } else {
                        if tempStreak > 0 && calendar.isDate(date, inSameDayAs: today) {
                            currentStreak = 0
                        }
                        tempStreak = 0
                    }
                    
                    streakHistory.append(StreakPoint(
                        date: startOfDay,
                        streakValue: tempStreak,
                        wasCompleted: isCompleted
                    ))
                }
            }
            
            let completionRate = totalOccurrences > 0 ? Double(completedOccurrences) / Double(totalOccurrences) : 0.0
            
            let taskStreak = TaskStreak(
                taskId: task.id,
                taskName: task.name,
                categoryName: task.category?.name,
                categoryColor: task.category?.color,
                currentStreak: currentStreak,
                bestStreak: bestStreak,
                totalOccurrences: totalOccurrences,
                completedOccurrences: completedOccurrences,
                completionRate: completionRate,
                streakHistory: streakHistory
            )
            
            taskStreaksList.append(taskStreak)
        }
        
        taskStreaks = taskStreaksList.sorted { $0.currentStreak > $1.currentStreak }
    }
    
    private func updateRecurringTasks() {
        recurringTasks = taskManager.tasks.filter { task in
            task.recurrence != nil
        }
    }
    
    func consistencyPoints(for task: TodoTask, in timeRange: ConsistencyTimeRange) -> [(x: CGFloat, y: CGFloat)] {
        guard let recurrence = task.recurrence else { return [] }
        
        let calendar = Calendar.current
        let today = Date()
        var points: [(x: CGFloat, y: CGFloat)] = []
        
        let daysToAnalyze: Int
        switch timeRange {
        case .week:
            daysToAnalyze = 7
        case .month:
            daysToAnalyze = 30
        case .year:
            daysToAnalyze = 365
        }
        
        var cumulativeProgress: Double = 0
        
        for dayOffset in (1-daysToAnalyze)...0 {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: today)!.startOfDay
            
            if shouldTaskOccurOnDate(task: task, date: date) {
                let isCompleted = task.completions[date]?.isCompleted == true
                
                if isCompleted {
                    cumulativeProgress += 1
                } else {
                    cumulativeProgress = max(0, cumulativeProgress - 0.5)
                }
                
                let xPosition = CGFloat(dayOffset + daysToAnalyze) / CGFloat(daysToAnalyze)
                points.append((x: xPosition, y: CGFloat(cumulativeProgress)))
            }
        }
        
        return points
    }
    
    private func shouldTaskOccurOnDate(task: TodoTask, date: Date) -> Bool {
        guard let recurrence = task.recurrence else { return false }
        
        let calendar = Calendar.current
        
        if date < calendar.startOfDay(for: task.startTime) {
            return false
        }
        
        if let endDate = recurrence.endDate, date > endDate {
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
}

extension Logger {
    static func stats(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        Logger.shared.log(message, level: level, subsystem: "statistics", file: file, function: function, line: line)
    }
}
