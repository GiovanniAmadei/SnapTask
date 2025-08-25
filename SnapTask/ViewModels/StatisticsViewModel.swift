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
        
        var localizedName: String {
            switch self {
            case .today: return "today".localized
            case .week: return "week".localized
            case .month: return "month".localized
            case .year: return "year".localized
            }
        }
        
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
    
    enum ConsistencyTimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
        
        var daysCount: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .year: return 365
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
    @Published private(set) var taskPerformanceAnalytics: [TaskPerformanceAnalytics] = []
    @Published private(set) var topPerformingTasks: [TaskPerformanceAnalytics] = []
    @Published private(set) var tasksNeedingImprovement: [TaskPerformanceAnalytics] = []
    
    private var updateTimer: Timer?
    private var lastUpdateTime: Date = Date()
    private let minUpdateInterval: TimeInterval = 2.0 
    private var pendingUpdate = false
    
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
    
    private var cancellables: Set<AnyCancellable> = []
    private let taskManager: TaskManager
    private let categoryManager = CategoryManager.shared
    private let cloudKitService = CloudKitService.shared
    
    init(taskManager: TaskManager = .shared) {
        self.taskManager = taskManager
        setupObservers()
    }
    
    func refreshStats() {
        scheduleUpdate()
    }
    
    func refreshAfterSync() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.scheduleUpdate()
        }
    }
    
    private func scheduleUpdate() {
        let now = Date()
        let timeSinceLastUpdate = now.timeIntervalSince(lastUpdateTime)
        
        if timeSinceLastUpdate >= minUpdateInterval {
            performUpdate()
        } else {
            pendingUpdate = true
            updateTimer?.invalidate()
            
            let delay = minUpdateInterval - timeSinceLastUpdate
            updateTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                if self?.pendingUpdate == true {
                    self?.performUpdate()
                }
            }
        }
    }
    
    private func performUpdate() {
        lastUpdateTime = Date()
        pendingUpdate = false
        updateTimer?.invalidate()
        
        let oldCategoryStats = categoryStats
        let oldWeeklyStats = weeklyStats
        let oldCurrentStreak = currentStreak
        let oldBestStreak = bestStreak
        let oldTaskStreaks = taskStreaks
        let oldTaskPerformanceAnalytics = taskPerformanceAnalytics
        
        updateCategoryStats()
        updateWeeklyStats()
        updateStreakStats()
        updateTaskStreaks()
        updateRecurringTasks()
        updateTaskPerformanceAnalytics()
        
        let dataChanged = categoryStats != oldCategoryStats ||
                         weeklyStats != oldWeeklyStats ||
                         currentStreak != oldCurrentStreak ||
                         bestStreak != oldBestStreak ||
                         taskStreaks != oldTaskStreaks ||
                         taskPerformanceAnalytics != oldTaskPerformanceAnalytics
        
        if dataChanged {
            print("📊 Data changed, updating UI")
            objectWillChange.send()
        } else {
            print("📊 No data changes detected, skipping UI update")
        }
    }
    
    private func setupObservers() {
        NotificationCenter.default.publisher(for: .tasksDidUpdate)
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("📊 Tasks updated (debounced)")
                self?.scheduleUpdate()
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: .categoriesDidUpdate)
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("📊 Categories updated (debounced)")
                self?.scheduleUpdate()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .timeTrackingUpdated)
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("📊 Time tracking updated (debounced)")
                self?.scheduleUpdate()
            }
            .store(in: &cancellables)
        
        categoryManager.$categories
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("📊 Category manager updated (debounced)")
                self?.scheduleUpdate()
            }
            .store(in: &cancellables)
        
        taskManager.$tasks
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("📊 Task manager updated (debounced)")
                self?.scheduleUpdate()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .cloudKitDataChanged)
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("📊 CloudKit data changed (debounced)")
                self?.scheduleUpdate()
            }
            .store(in: &cancellables)
        
        cloudKitService.$syncStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                if status == .success {
                    print("📊 CloudKit sync completed")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self?.scheduleUpdate()
                    }
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("📊 App became active")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.scheduleUpdate()
                }
            }
            .store(in: &cancellables)
        
        $selectedTimeRange
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("📊 Time range changed - immediate update")
                self?.performUpdate() 
            }
            .store(in: &cancellables)
    }
    
    private func updateCategoryStats() {
        let categories = categoryManager.categories
        let allTasks = taskManager.tasks
        let (startDate, endDate) = selectedTimeRange.dateRange
        
        print("📊 Date range: \(startDate) to \(endDate)")
        print("📊 Available categories: \(categories.map { "\($0.name) (ID: \($0.id.uuidString.prefix(8)))" })")
        
        let timeTrackingData = UserDefaults.standard.dictionary(forKey: "timeTracking") as? [String: [String: Double]] ?? [:]
        let categoryMetadata = UserDefaults.standard.dictionary(forKey: "categoryMetadata") as? [String: [String: String]] ?? [:]
        let taskMetadata = UserDefaults.standard.dictionary(forKey: "taskMetadata") as? [String: [String: String]] ?? [:] // Per retrocompatibilità
        
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
            
            // Calcola ore dalle durate dei task completati
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
                        
                        var taskDuration: TimeInterval = 0
                        var durationSource = "no duration"
                        
                        if let actualDuration = completion.actualDuration, actualDuration > 0 {
                            taskDuration = actualDuration
                            durationSource = "completion actual duration"
                        } else if task.totalTrackedTime > 0 {
                            taskDuration = task.totalTrackedTime
                            durationSource = "tracked time"
                        } else if task.hasDuration && task.duration > 0 {
                            taskDuration = task.duration
                            durationSource = "estimated duration"
                        }
                        
                        if taskDuration > 0 {
                            print("📊   -> Included: Task '\(task.name)' completed on \(date) with \(String(format: "%.2f", taskDuration/3600.0))h (\(durationSource))")
                            return taskDuration / 3600.0
                        } else {
                            print("📊   -> Excluded: Task '\(task.name)' completed on \(date) but has NO duration data")
                            return nil
                        }
                    }
                    .reduce(0.0, +)
                
                return total + completionHours
            }
            
            // Calcola ore dalle sessioni di time tracking (nuovi category metadata)
            let calendar = Calendar.current
            var trackedHours = 0.0
            let categoryKey = "category_\(category.id.uuidString)"
            
            var currentDate = startDate
            while currentDate <= endDate {
                let dateKey = ISO8601DateFormatter().string(from: calendar.startOfDay(for: currentDate))
                if let dayData = timeTrackingData[dateKey],
                   let categoryHours = dayData[categoryKey] {
                    trackedHours += categoryHours
                    print("📊 Category \(category.name) on \(dateKey): \(categoryHours)h from time tracking")
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
                print("📊 Category \(category.name): \(String(format: "%.2f", taskHours))h from task durations + \(String(format: "%.2f", trackedHours))h from time tracking = \(String(format: "%.2f", totalHours))h total")
            } else {
                print("📊 Category \(category.name): 0 hours (no tasks with duration or time tracking sessions)")
            }
        }
        
        // Gestisci anche le vecchie entry "uncategorized" dal time tracking
        let calendar = Calendar.current
        var currentDate = startDate
        var uncategorizedHours = 0.0
        
        while currentDate <= endDate {
            let dateKey = ISO8601DateFormatter().string(from: calendar.startOfDay(for: currentDate))
            if let dayData = timeTrackingData[dateKey],
               let uncategorizedTime = dayData["uncategorized"] {
                uncategorizedHours += uncategorizedTime
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate.addingTimeInterval(86400)
        }
        
        if uncategorizedHours > 0 {
            categoryStatsList.append(CategoryStat(
                name: "Uncategorized",
                color: "#9CA3AF",
                hours: uncategorizedHours
            ))
            print("📊 Uncategorized: \(String(format: "%.2f", uncategorizedHours))h from time tracking")
        }
        
        // Per retrocompatibilità: gestisci i vecchi task metadata (che verranno progressivamente rimossi)
        let calendar2 = Calendar.current
        var currentDate2 = startDate
        var taskTracking: [String: Double] = [:]
        
        while currentDate2 <= endDate {
            let dateKey = ISO8601DateFormatter().string(from: calendar2.startOfDay(for: currentDate2))
            if let dayData = timeTrackingData[dateKey] {
                for (key, hours) in dayData {
                    if key.hasPrefix("task_") {
                        taskTracking[key, default: 0] += hours
                    }
                }
            }
            currentDate2 = calendar2.date(byAdding: .day, value: 1, to: currentDate2) ?? endDate.addingTimeInterval(86400)
        }
        
        // Aggiungi solo i task metadata che non sono stati già migrati alle categorie
        for (taskKey, hours) in taskTracking {
            if hours > 0, let metadata = taskMetadata[taskKey] {
                categoryStatsList.append(CategoryStat(
                    name: metadata["name"] ?? "Unknown Task",
                    color: metadata["color"] ?? "#6366F1",
                    hours: hours
                ))
                print("📊 Legacy task \(metadata["name"] ?? "Unknown"): \(String(format: "%.2f", hours))h from old time tracking format")
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
    
    struct TaskPerformanceAnalytics: Identifiable, Equatable {
        let id = UUID()
        let taskId: UUID
        let taskName: String
        let categoryName: String?
        let categoryColor: String?
        let completions: [TaskCompletionAnalytics]
        let averageDifficulty: Double?
        let averageQuality: Double?
        let averageDuration: TimeInterval?
        let estimationAccuracy: Double? 
        let improvementTrend: ImprovementTrend
        
        static func == (lhs: TaskPerformanceAnalytics, rhs: TaskPerformanceAnalytics) -> Bool {
            return lhs.taskId == rhs.taskId &&
                   lhs.averageDifficulty == rhs.averageDifficulty &&
                   lhs.averageQuality == rhs.averageQuality
        }
    }
    
    struct TaskCompletionAnalytics: Identifiable, Equatable {
        let id = UUID()
        let date: Date
        let actualDuration: TimeInterval?
        let difficultyRating: Int?
        let qualityRating: Int?
        let estimatedDuration: TimeInterval?
        let wasTracked: Bool
        
        static func == (lhs: TaskCompletionAnalytics, rhs: TaskCompletionAnalytics) -> Bool {
            return lhs.date == rhs.date &&
                   lhs.actualDuration == rhs.actualDuration &&
                   lhs.difficultyRating == rhs.difficultyRating &&
                   lhs.qualityRating == rhs.qualityRating
        }
    }
    
    enum ImprovementTrend: String, CaseIterable {
        case improving = "Improving"
        case stable = "Stable"
        case declining = "Declining"
        case insufficient = "Insufficient Data"
        
        var color: Color {
            switch self {
            case .improving: return .green
            case .stable: return .blue
            case .declining: return .orange
            case .insufficient: return .gray
            }
        }
        
        var icon: String {
            switch self {
            case .improving: return "arrow.up.right"
            case .stable: return "arrow.right"
            case .declining: return "arrow.down.right"
            case .insufficient: return "questionmark"
            }
        }
    }
    
    private func updateTaskPerformanceAnalytics() {
        let allTasks = taskManager.tasks
        let (startDate, endDate) = selectedTimeRange.dateRange
        
        var analyticsArray: [TaskPerformanceAnalytics] = []
        
        for task in allTasks {
            let completionAnalytics = getTaskCompletionAnalytics(for: task, startDate: startDate, endDate: endDate)
            
            guard !completionAnalytics.isEmpty else { continue }
            
            let avgDifficulty = completionAnalytics.compactMap { $0.difficultyRating }.isEmpty ? nil :
                Double(completionAnalytics.compactMap { $0.difficultyRating }.reduce(0, +)) / Double(completionAnalytics.compactMap { $0.difficultyRating }.count)
            
            let avgQuality = completionAnalytics.compactMap { $0.qualityRating }.isEmpty ? nil :
                Double(completionAnalytics.compactMap { $0.qualityRating }.reduce(0, +)) / Double(completionAnalytics.compactMap { $0.qualityRating }.count)
            
            let avgDuration = completionAnalytics.compactMap { $0.actualDuration }.isEmpty ? nil :
                completionAnalytics.compactMap { $0.actualDuration }.reduce(0, +) / Double(completionAnalytics.compactMap { $0.actualDuration }.count)
            
            let estimationAccuracy = calculateEstimationAccuracy(for: completionAnalytics)
            let improvementTrend = calculateImprovementTrend(for: completionAnalytics)
            
            let analytics = TaskPerformanceAnalytics(
                taskId: task.id,
                taskName: task.name,
                categoryName: task.category?.name,
                categoryColor: task.category?.color,
                completions: completionAnalytics,
                averageDifficulty: avgDifficulty,
                averageQuality: avgQuality,
                averageDuration: avgDuration,
                estimationAccuracy: estimationAccuracy,
                improvementTrend: improvementTrend
            )
            
            analyticsArray.append(analytics)
        }
        
        taskPerformanceAnalytics = analyticsArray
        topPerformingTasks = analyticsArray
            .filter { $0.averageQuality ?? 0 >= 7.0 }
            .sorted { ($0.averageQuality ?? 0) > ($1.averageQuality ?? 0) }
            .prefix(5)
            .map { $0 }
        
        tasksNeedingImprovement = analyticsArray
            .filter { analytics in
                (analytics.averageQuality ?? 10) < 6.0 || 
                (analytics.averageDifficulty ?? 0) > 7.0 ||
                analytics.improvementTrend == .declining
            }
            .sorted { analytics1, analytics2 in
                let score1 = (analytics1.averageQuality ?? 0) - (analytics1.averageDifficulty ?? 0)
                let score2 = (analytics2.averageQuality ?? 0) - (analytics2.averageDifficulty ?? 0)
                return score1 < score2
            }
            .prefix(5)
            .map { $0 }
    }
    
    func getWeeklyStatsForDay(date: Date) -> (completed: Int, total: Int, rate: Double) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!.addingTimeInterval(-1)
        
        let singleDayTasks = taskManager.tasks.filter { task in
            task.recurrence == nil && calendar.isDate(task.startTime, inSameDayAs: date)
        }
        
        let recurringDayTasks = taskManager.tasks.filter { task in
            guard let recurrence = task.recurrence else { return false }
            
            if task.startTime > endOfDay { return false }
            if let endDate = recurrence.endDate, endDate < startOfDay { return false }
            
            return shouldTaskOccurOnDate(task: task, date: startOfDay)
        }
        
        let allDayTasks = singleDayTasks + recurringDayTasks
        let completedCount = allDayTasks.filter { task in
            task.completions[startOfDay]?.isCompleted == true
        }.count
        
        let totalCount = allDayTasks.count
        let rate = totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0.0
        
        return (completed: completedCount, total: totalCount, rate: rate)
    }
    
    func getWeeklyStatsForWeekOffset(_ weekOffset: Int) -> (completed: Int, total: Int, rate: Double) {
        let calendar = Calendar.current
        let today = Date()
        let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: today)!
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
        
        var totalCompleted = 0
        var totalTasks = 0
        
        var currentDate = weekStart
        while currentDate <= weekEnd {
            let dayStats = getWeeklyStatsForDay(date: currentDate)
            totalCompleted += dayStats.completed
            totalTasks += dayStats.total
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        let rate = totalTasks > 0 ? Double(totalCompleted) / Double(totalTasks) : 0.0
        return (completed: totalCompleted, total: totalTasks, rate: rate)
    }
    
    func getMonthlyStatsForMonth(_ month: Date) -> (completed: Int, total: Int, rate: Double) {
        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)!.addingTimeInterval(-1)
        
        var totalCompleted = 0
        var totalTasks = 0
        
        var currentDate = monthStart
        while currentDate <= monthEnd {
            let dayStats = getWeeklyStatsForDay(date: currentDate)
            totalCompleted += dayStats.completed
            totalTasks += dayStats.total
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        let rate = totalTasks > 0 ? Double(totalCompleted) / Double(totalTasks) : 0.0
        return (completed: totalCompleted, total: totalTasks, rate: rate)
    }
    
    private func getTaskCompletionAnalytics(for task: TodoTask, startDate: Date, endDate: Date) -> [TaskCompletionAnalytics] {
        var analytics: [TaskCompletionAnalytics] = []
        
        for (date, completion) in task.completions {
            guard completion.isCompleted &&
                  date >= Calendar.current.startOfDay(for: startDate) &&
                  date <= Calendar.current.startOfDay(for: endDate) else { continue }
            
            let trackingSessions = taskManager.getTrackingSessions(for: task.id)
            let sessionForDate = trackingSessions.first { session in
                Calendar.current.isDate(session.startTime, inSameDayAs: date)
            }
            
            let completionAnalytic = TaskCompletionAnalytics(
                date: date,
                actualDuration: completion.actualDuration,
                difficultyRating: completion.difficultyRating,
                qualityRating: completion.qualityRating,
                estimatedDuration: task.hasDuration ? task.duration : nil,
                wasTracked: sessionForDate != nil
            )
            
            analytics.append(completionAnalytic)
        }
        
        return analytics.sorted { $0.date < $1.date }
    }
    
    private func calculateEstimationAccuracy(for completions: [TaskCompletionAnalytics]) -> Double? {
        let accuracyData = completions.compactMap { completion -> Double? in
            guard let actual = completion.actualDuration,
                  let estimated = completion.estimatedDuration,
                  estimated > 0 else { return nil }
            
            return abs(actual - estimated) / estimated
        }
        
        guard !accuracyData.isEmpty else { return nil }
        
        let avgAccuracy = accuracyData.reduce(0, +) / Double(accuracyData.count)
        return max(0, 1.0 - avgAccuracy) 
    }
    
    private func calculateImprovementTrend(for completions: [TaskCompletionAnalytics]) -> ImprovementTrend {
        guard completions.count >= 3 else { return .insufficient }
        
        let qualityRatings = completions.compactMap { $0.qualityRating }
        guard qualityRatings.count >= 3 else { return .insufficient }
        
        let recentHalf = qualityRatings.suffix(qualityRatings.count / 2)
        let olderHalf = qualityRatings.prefix(qualityRatings.count / 2)
        
        let recentAvg = Double(recentHalf.reduce(0, +)) / Double(recentHalf.count)
        let olderAvg = Double(olderHalf.reduce(0, +)) / Double(olderHalf.count)
        
        let improvement = recentAvg - olderAvg
        
        if improvement > 0.5 {
            return .improving
        } else if improvement < -0.5 {
            return .declining
        } else {
            return .stable
        }
    }
}

extension Logger {
    static func stats(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        Logger.shared.log(message, level: level, subsystem: "statistics", file: file, function: function, line: line)
    }
}