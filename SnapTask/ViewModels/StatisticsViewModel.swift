import SwiftUI
import Combine
import os.log
import Foundation
import WidgetKit

// MARK: - Widget Data Models (Codable for sharing with widget)

struct WidgetCategoryStatData: Codable {
    let name: String
    let color: String
    let hours: Double
}

struct WidgetWeeklyStatData: Codable {
    let day: String
    let completedTasks: Int
    let totalTasks: Int
    let completionRate: Double
}

@MainActor
class StatisticsViewModel: ObservableObject {
    struct CategoryStat: Identifiable, Equatable {
        let id = UUID()
        let name: String
        let color: String
        let hours: Double
        /// Set for real categories (nil for "Uncategorized" and per-task tracking entries).
        var categoryId: UUID? = nil
        var icon: String? = nil
        
        static func == (lhs: CategoryStat, rhs: CategoryStat) -> Bool {
            return lhs.name == rhs.name &&
                   lhs.color == rhs.color &&
                   lhs.hours == rhs.hours
        }

    }

    private static let isoFormatter = ISO8601DateFormatter()

    /// Tasks that count in the statistics. Inbox items are undated quick notes: they don't
    /// belong to the day they were written, so they never enter completion rates, streaks or
    /// active days.
    private var statTasks: [TodoTask] {
        taskManager.tasks.filter { $0.timeScope != .inbox }
    }

    private func calculateCategoryStats(for range: TimeRange) -> [CategoryStat] {
        let (startDate, endDate) = range.dateRange
        return calculateCategoryStats(from: startDate, to: endDate)
    }

    private func calculateCategoryStats(from startDate: Date, to endDate: Date) -> [CategoryStat] {
        let categories = categoryManager.categories
        let allTasks = statTasks
        let calendar = Calendar.current
        let startOfStartDate = calendar.startOfDay(for: startDate)
        let endOfEndDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate))!

        let timeTrackingData = UserDefaults.standard.dictionary(forKey: "timeTracking") as? [String: [String: Double]] ?? [:]
        let taskMetadata = UserDefaults.standard.dictionary(forKey: "taskMetadata") as? [String: [String: String]] ?? [:]

        // Pre-aggregate time tracking within date range in ONE fast dictionary pass
        var trackedHoursByCategory: [String: Double] = [:]
        var uncategorizedHours = 0.0
        var taskTracking: [String: Double] = [:]

        for (dateKey, dayData) in timeTrackingData {
            guard let date = Self.isoFormatter.date(from: dateKey),
                  date >= startOfStartDate && date < endOfEndDate else {
                continue
            }
            for (key, hours) in dayData {
                if key == "uncategorized" {
                    uncategorizedHours += hours
                } else if key.hasPrefix("category_") {
                    trackedHoursByCategory[key, default: 0] += hours
                } else if key.hasPrefix("task_") {
                    taskTracking[key, default: 0] += hours
                }
            }
        }

        // Pre-group tasks by category ID and lowercased name for fast matching
        var tasksByCategoryId: [UUID: [TodoTask]] = [:]
        var tasksByCategoryName: [String: [TodoTask]] = [:]
        for task in allTasks {
            if let cat = task.category {
                tasksByCategoryId[cat.id, default: []].append(task)
                tasksByCategoryName[cat.name.lowercased(), default: []].append(task)
            }
        }

        var categoryStatsList: [CategoryStat] = []

        for category in categories {
            var categoryTasks = tasksByCategoryId[category.id] ?? []
            if categoryTasks.isEmpty {
                categoryTasks = tasksByCategoryName[category.name.lowercased()] ?? []
            }

            let taskHours = categoryTasks.reduce(0.0) { total, task in
                let completionHours = task.completions.reduce(0.0) { subtotal, entry in
                    let (date, completion) = entry
                    guard date >= startOfStartDate && date < endOfEndDate && completion.isCompleted else {
                        return subtotal
                    }

                    var taskDuration: TimeInterval = 0
                    if let actualDuration = completion.actualDuration, actualDuration > 0 {
                        taskDuration = actualDuration
                    } else if task.totalTrackedTime > 0 {
                        taskDuration = task.totalTrackedTime
                    } else if task.hasDuration && task.duration > 0 {
                        taskDuration = task.duration
                    }

                    return taskDuration > 0 ? subtotal + (taskDuration / 3600.0) : subtotal
                }
                return total + completionHours
            }

            let categoryKey = "category_\(category.id.uuidString)"
            let trackedHours = trackedHoursByCategory[categoryKey] ?? 0.0
            let totalHours = taskHours + trackedHours

            if totalHours > 0 {
                categoryStatsList.append(CategoryStat(
                    name: category.name,
                    color: category.color,
                    hours: totalHours,
                    categoryId: category.id,
                    icon: category.icon
                ))
            }
        }

        if uncategorizedHours > 0 {
            categoryStatsList.append(CategoryStat(
                name: "Uncategorized",
                color: "#9CA3AF",
                hours: uncategorizedHours
            ))
        }

        for (taskKey, hours) in taskTracking {
            if hours > 0, let metadata = taskMetadata[taskKey] {
                categoryStatsList.append(CategoryStat(
                    name: metadata["name"] ?? "Unknown Task",
                    color: metadata["color"] ?? "#6366F1",
                    hours: hours
                ))
            }
        }

        categoryStatsList.sort { $0.hours > $1.hours }
        return categoryStatsList
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
    
    enum TimeRange: String, CaseIterable {
        case today = "Today"
        case week = "Week"
        case month = "Month"
        case year = "Year"
        case allTime = "AllTime"
        
        var localizedName: String {
            switch self {
            case .today: return "today".localized
            case .week: return "week".localized
            case .month: return "month".localized
            case .year: return "year".localized
            case .allTime: return "all_time".localized
            }
        }
        
        var dateRange: (start: Date, end: Date) {
            let calendar = Calendar.current
            let now = Date()
            switch self {
            case .today:
                return (calendar.startOfDay(for: now), now)
            case .week:
                let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))!
                return (weekStart, now)
            case .month:
                let monthStart = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now))!
                return (monthStart, now)
            case .year:
                let thisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
                let yearStart = calendar.date(byAdding: .month, value: -11, to: thisMonth)!
                return (yearStart, now)
            case .allTime:
                // Ritorna una data molto lontana nel passato
                let distantPast = calendar.date(byAdding: .year, value: -10, to: now)!
                return (distantPast, now)
            }
        }
    }
    
    @Published private(set) var categoryStats: [CategoryStat] = []
    @Published private(set) var weeklyStats: [WeeklyStat] = []
    @Published private(set) var currentStreak: Int = 0
    @Published private(set) var bestStreak: Int = 0
    /// Recomputed synchronously: views must never render the new period with the old period's data
    /// (Swift Charts can crash interpolating between incompatible data sets).
    @Published var selectedTimeRange: TimeRange = .week {
        didSet {
            guard oldValue != selectedTimeRange, !isGeneratingWidgetStats else { return }
            forceUIRefreshOnNextUpdate = true
            performImmediateUpdate(skipWidgetSave: true)
        }
    }
    @Published private(set) var habitSummaries: [HabitSummary] = []
    @Published private(set) var overview = PeriodOverview()
    @Published private(set) var completionBuckets: [CompletionBucket] = []
    @Published private(set) var trendBuckets: [CompletionBucket] = []
    @Published private(set) var weekdayRates: [WeekdayRate] = []
    /// Hours per category name in the previous period of the same length (empty for "all time").
    @Published private(set) var previousCategoryHours: [String: Double] = [:]
    /// False when the previous period starts before any data exists (a comparison would be meaningless).
    @Published private(set) var hasPreviousPeriod = false
    /// Completed/resolved tasks per finished day of the selected period (used to relate mood and productivity).
    @Published private(set) var dailyCompletion: [Date: DayCount] = [:]
    @Published private(set) var recurringTasks: [TodoTask] = []
    @Published private(set) var taskPerformanceAnalytics: [TaskPerformanceAnalytics] = []
    @Published private(set) var topPerformingTasks: [TaskPerformanceAnalytics] = []
    @Published private(set) var tasksNeedingImprovement: [TaskPerformanceAnalytics] = []
    
    private var updateTimer: Timer?
    private var lastUpdateTime: Date = .distantPast
    private let minUpdateInterval: TimeInterval = 1.0 
    private var pendingUpdate = false

    private var isGeneratingWidgetStats = false
    private var shouldSaveWidgetStatsOnNextUpdate = true
    private var forceUIRefreshOnNextUpdate = false
    private static let verboseStatsLogging = false

    private var isUpdating = false
    private var isObserving = false
    
    private var nonRecurringTasksByDay: [Date: [TodoTask]] = [:]
    private var recurringTasksList: [TodoTask] = []
    
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
    private let appGroupUserDefaults = UserDefaults(suiteName: "group.com.snapTask.shared")
    
    init(taskManager: TaskManager? = nil) {
        self.taskManager = taskManager ?? .shared
    }

    private func refreshTaskPartitions() {
        let calendar = Calendar.current
        var nonRec: [Date: [TodoTask]] = [:]
        var rec: [TodoTask] = []
        for task in statTasks {
            if task.recurrence != nil {
                rec.append(task)
            } else {
                let day = calendar.startOfDay(for: task.startTime)
                nonRec[day, default: []].append(task)
            }
        }
        self.nonRecurringTasksByDay = nonRec
        self.recurringTasksList = rec
    }

    func startObserving() {
        guard !isObserving else { return }
        isObserving = true
        setupObservers()
    }

    func stopObserving() {
        guard isObserving else { return }
        isObserving = false

        pendingUpdate = false
        updateTimer?.invalidate()
        updateTimer = nil

        cancellables.removeAll()
    }
    
    func refreshStats() {
        scheduleUpdate()
    }
    
    func refreshAfterSync() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.scheduleUpdate()
        }
    }

    private func performImmediateUpdate(skipWidgetSave: Bool) {
        if skipWidgetSave {
            shouldSaveWidgetStatsOnNextUpdate = false
        }
        performUpdate()
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
        guard !isUpdating else { return }
        isUpdating = true
        defer {
            isUpdating = false
            shouldSaveWidgetStatsOnNextUpdate = true
            forceUIRefreshOnNextUpdate = false
        }

        lastUpdateTime = Date()
        pendingUpdate = false
        updateTimer?.invalidate()
        
        let oldCategoryStats = categoryStats
        let oldWeeklyStats = weeklyStats
        let oldCurrentStreak = currentStreak
        let oldBestStreak = bestStreak
        let oldHabits = habitSummaries
        let oldOverview = overview
        let oldBuckets = completionBuckets
        let oldTaskPerformanceAnalytics = taskPerformanceAnalytics
        
        refreshTaskPartitions()
        updateCategoryStats()
        updateWeeklyStats()
        updateStreakStats()
        updateRecurringTasks()
        updateTaskPerformanceAnalytics()
        updatePeriodStats()
        
        let dataChanged = categoryStats != oldCategoryStats ||
                         weeklyStats != oldWeeklyStats ||
                         currentStreak != oldCurrentStreak ||
                         bestStreak != oldBestStreak ||
                         habitSummaries != oldHabits ||
                         overview != oldOverview ||
                         completionBuckets != oldBuckets ||
                         taskPerformanceAnalytics != oldTaskPerformanceAnalytics

        if dataChanged || forceUIRefreshOnNextUpdate {
            print("📊 Data changed, updating UI")
            objectWillChange.send()
            if shouldSaveWidgetStatsOnNextUpdate {
                Task(priority: .utility) { [weak self] in
                    self?.saveStatsForWidget()
                }
            }
        } else {
            print("📊 No data changes detected, skipping UI update")
        }
    }
    
    // MARK: - Widget Data Sharing
    
    private func saveStatsForWidget() {
        guard !isGeneratingWidgetStats else { return }
        isGeneratingWidgetStats = true
        defer { isGeneratingWidgetStats = false }

        let widgetTimeRanges: [TimeRange] = [.today, .week, .month, .year, .allTime]
        let encoder = JSONEncoder()

        for widgetRange in widgetTimeRanges {
            let categoryStatsForWidget = calculateCategoryStats(for: widgetRange)
            let weeklyStatsForWidget = calculateWeeklyStats(for: widgetRange)

            let widgetKeySuffix: String = {
                switch widgetRange {
                case .allTime:
                    return "allTime"
                default:
                    return widgetRange.rawValue.lowercased()
                }
            }()

            let categoryData = categoryStatsForWidget.map { stat in
                WidgetCategoryStatData(name: stat.name, color: stat.color, hours: stat.hours)
            }

            if let encoded = try? encoder.encode(categoryData) {
                appGroupUserDefaults?.set(encoded, forKey: "widgetCategoryStats_\(widgetKeySuffix)")
            }

            let weeklyData = weeklyStatsForWidget.map { stat in
                WidgetWeeklyStatData(
                    day: stat.day,
                    completedTasks: stat.completedTasks,
                    totalTasks: stat.totalTasks,
                    completionRate: stat.completionRate
                )
            }

            if let encoded = try? encoder.encode(weeklyData) {
                appGroupUserDefaults?.set(encoded, forKey: "widgetWeeklyStats_\(widgetKeySuffix)")
            }
        }

        appGroupUserDefaults?.synchronize()

        DispatchQueue.global(qos: .utility).async {
            WidgetCenter.shared.reloadTimelines(ofKind: "PerformanceWidget")
            WidgetCenter.shared.reloadTimelines(ofKind: "PerformanceWidgetLarge")
        }
        print("📊 Saved stats for widget time ranges and requested timeline reload")
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
        
        NotificationCenter.default.publisher(for: .cloudKitDataChanged)
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("📊 CloudKit data changed (debounced)")
                self?.scheduleUpdate()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .moodDidUpdate)
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("📊 Mood updated (debounced)")
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
        
    }
    
    private func updateCategoryStats() {
        let list = calculateCategoryStats(for: selectedTimeRange)
        withAnimation(.smooth(duration: 0.35)) {
            categoryStats = list
        }
    }

    private func updateWeeklyStats() {
        let next = calculateWeeklyStats(for: selectedTimeRange)
        withAnimation(.smooth(duration: 0.35)) {
            weeklyStats = next
        }
    }

    private func calculateWeeklyStats(for range: TimeRange) -> [WeeklyStat] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        switch range {
        case .today:
            let stats = getWeeklyStatsForDay(date: today)
            return [WeeklyStat(
                day: today.formatted(.dateTime.weekday(.abbreviated)),
                completedTasks: stats.completed,
                totalTasks: stats.total,
                completionRate: stats.rate
            )]
        case .week:
            let start = calendar.date(byAdding: .day, value: -6, to: today)!
            return (0...6).map { dayOffset in
                let date = calendar.date(byAdding: .day, value: dayOffset, to: start)!
                let stats = getWeeklyStatsForDay(date: date)
                return WeeklyStat(
                    day: date.formatted(.dateTime.weekday(.abbreviated)),
                    completedTasks: stats.completed,
                    totalTasks: stats.total,
                    completionRate: stats.rate
                )
            }
        case .month:
            return (0..<5).reversed().map { weeksAgo in
                let weekEnd = calendar.date(byAdding: .day, value: -7 * weeksAgo, to: today)!
                let weekStart = calendar.date(byAdding: .day, value: -6, to: weekEnd)!
                var completed = 0, total = 0
                for offset in 0...6 {
                    let d = getWeeklyStatsForDay(date: calendar.date(byAdding: .day, value: offset, to: weekStart)!)
                    completed += d.completed; total += d.total
                }
                return WeeklyStat(
                    day: weekStart.formatted(.dateTime.day().month(.defaultDigits)),
                    completedTasks: completed,
                    totalTasks: total,
                    completionRate: total > 0 ? Double(completed) / Double(total) : 0
                )
            }
        case .year, .allTime:
            let thisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
            let startDate = calendar.date(byAdding: .month, value: -11, to: thisMonth)!
            return (0..<12).map { monthOffset in
                let monthStart = calendar.date(byAdding: .month, value: monthOffset, to: startDate)!
                let stats = getMonthlyStatsForMonth(monthStart)
                return WeeklyStat(
                    day: monthStart.formatted(.dateTime.month(.abbreviated)),
                    completedTasks: stats.completed,
                    totalTasks: stats.total,
                    completionRate: stats.rate
                )
            }
        }
    }
    
    /// Days with at least one completed task ("giorni attivi").
    private var activeDays: Set<Date> = []

    private func updateStreakStats() {
        let calendar = Calendar.current
        var days = Set<Date>()
        for task in statTasks {
            for (date, completion) in task.completions where completion.isCompleted {
                days.insert(calendar.startOfDay(for: date))
            }
        }
        activeDays = days

        let today = calendar.startOfDay(for: Date())
        var current = 0
        var check = days.contains(today) ? today : calendar.date(byAdding: .day, value: -1, to: today)!
        while days.contains(check) {
            current += 1
            check = calendar.date(byAdding: .day, value: -1, to: check)!
        }

        var best = 0
        var run = 0
        var previous: Date?
        for day in days.sorted() {
            if let previous, calendar.dateComponents([.day], from: previous, to: day).day == 1 {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = day
        }

        currentStreak = current
        bestStreak = max(best, current)
    }
    
    private func updateRecurringTasks() {
        recurringTasks = statTasks.filter { task in
            task.recurrence != nil
        }
    }
    
    // MARK: - Period statistics (one period drives the whole statistics screen)

    struct PeriodOverview: Equatable {
        var completed = 0
        /// Scheduled occurrences already resolved (today's unfinished tasks are excluded).
        var total = 0
        /// Tasks still to do today.
        var pending = 0
        /// Rates only use finished days: a day in progress would otherwise count as 100% (or 0%).
        var rateCompleted = 0
        var rateTotal = 0
        var trackedHours = 0.0
        var activeDays = 0
        var daysInPeriod = 0
        var rate: Double { rateTotal > 0 ? Double(rateCompleted) / Double(rateTotal) : 0 }
    }

    struct CompletionBucket: Identifiable, Equatable {
        var id: Date { start }
        let start: Date
        /// Start of the last day included in the bucket.
        let end: Date
        let completed: Int
        /// Resolved occurrences: today's unfinished tasks are counted in `pending`, not here.
        let total: Int
        var pending: Int = 0
        var missed: Int { max(0, total - completed) }
        var rate: Double { total > 0 ? Double(completed) / Double(total) : 0 }
    }

    struct DayCount: Equatable {
        let completed: Int
        let total: Int
        var rate: Double { total > 0 ? Double(completed) / Double(total) : 0 }
    }

    struct WeekdayRate: Identifiable, Equatable {
        var id: Int { weekday }
        /// Calendar weekday (1 = Sunday).
        let weekday: Int
        let completed: Int
        let total: Int
        var rate: Double { total > 0 ? Double(completed) / Double(total) : 0 }
    }

    enum HabitDayState: Equatable {
        case done, missed, pending, off
    }

    struct HabitDay: Equatable {
        let date: Date
        let state: HabitDayState
    }

    struct HabitSummary: Identifiable, Equatable {
        var id: UUID { taskId }
        let taskId: UUID
        let name: String
        let icon: String
        let color: String
        let categoryName: String?
        let currentStreak: Int
        let bestStreak: Int
        let periodCompleted: Int
        let periodTotal: Int
        /// Every calendar day from the start of the history window to today (oldest first). Only for daily cadence.
        let days: [HabitDay]
        var cadence: HabitCadence = .day
        /// One entry per week/month/year for non-daily habits (oldest first); `date` is the period start.
        var periods: [HabitDay] = []
        var periodRate: Double { periodTotal > 0 ? Double(periodCompleted) / Double(periodTotal) : 0 }
    }

    /// Granularity of one occurrence: daily habits get a day heatmap, the others a grid of their own periods.
    enum HabitCadence: Equatable {
        case day, week, month, year

        var component: Calendar.Component {
            switch self {
            case .day: return .day
            case .week: return .weekOfYear
            case .month: return .month
            case .year: return .year
            }
        }

        var localizedName: String {
            switch self {
            case .day: return "stats_cadence_day".localized
            case .week: return "stats_cadence_week".localized
            case .month: return "stats_cadence_month".localized
            case .year: return "stats_cadence_year".localized
            }
        }
    }

    static func cadence(for task: TodoTask) -> HabitCadence {
        switch task.timeScope {
        case .week: return .week
        case .month: return .month
        case .year, .longTerm: return .year
        default: break
        }
        switch task.recurrence?.type {
        case .monthly, .monthlyOrdinal: return .month
        case .yearly: return .year
        default: return .day
        }
    }

    enum BucketUnit {
        case day, week, month
    }

    private var firstDataDay: Date?

    /// Inclusive day range of the selected period: start of the first day ... start of today.
    var periodDays: (start: Date, end: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if selectedTimeRange == .allTime {
            return (firstDataDay ?? today, today)
        }
        return (calendar.startOfDay(for: selectedTimeRange.dateRange.start), today)
    }

    /// Bars use calendar months for long periods; trend lines use weeks for a year so the shape stays readable.
    func bucketUnit(forTrend: Bool) -> BucketUnit {
        switch selectedTimeRange {
        case .today, .week, .month: return .day
        case .year: return forTrend ? .week : .month
        case .allTime: return .month
        }
    }

    private func updatePeriodStats() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let threeYearsAgo = calendar.date(byAdding: .year, value: -3, to: today)!
        firstDataDay = statTasks
            .map { calendar.startOfDay(for: $0.startTime) }
            .min()
            .map { min(today, max($0, threeYearsAgo)) }
        let (start, end) = periodDays

        // Today is still in progress: its unfinished tasks are "pending", not missed.
        var daily: [Date: (completed: Int, total: Int)] = [:]
        var pendingToday = 0
        var day = start
        while day <= end {
            let stats = getWeeklyStatsForDay(date: day)
            if day == today {
                pendingToday = stats.total - stats.completed
                daily[day] = (stats.completed, stats.completed)
            } else {
                daily[day] = (stats.completed, stats.total)
            }
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }

        var summary = PeriodOverview()
        for value in daily.values {
            summary.completed += value.completed
            summary.total += value.total
        }
        summary.pending = pendingToday
        var finishedDays = daily
        finishedDays[today] = nil
        for value in finishedDays.values {
            summary.rateCompleted += value.completed
            summary.rateTotal += value.total
        }
        summary.daysInPeriod = daily.count
        summary.activeDays = activeDays.filter { $0 >= start && $0 <= end }.count
        summary.trackedHours = categoryStats.reduce(0) { $0 + $1.hours }
        overview = summary

        var bars = makeBuckets(daily, from: start, to: end, unit: bucketUnit(forTrend: false))
        if let last = bars.indices.last, pendingToday > 0 {
            bars[last].pending = pendingToday
        }
        completionBuckets = bars
        trendBuckets = makeBuckets(finishedDays, from: start, to: end, unit: bucketUnit(forTrend: true))

        var byWeekday: [Int: (completed: Int, total: Int)] = [:]
        for (date, value) in finishedDays {
            let weekday = calendar.component(.weekday, from: date)
            byWeekday[weekday, default: (0, 0)].completed += value.completed
            byWeekday[weekday, default: (0, 0)].total += value.total
        }
        weekdayRates = (0..<7).map { offset in
            let weekday = (calendar.firstWeekday - 1 + offset) % 7 + 1
            return WeekdayRate(weekday: weekday,
                               completed: byWeekday[weekday]?.completed ?? 0,
                               total: byWeekday[weekday]?.total ?? 0)
        }

        dailyCompletion = finishedDays.mapValues { DayCount(completed: $0.completed, total: $0.total) }

        let length = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        let previousEnd = calendar.date(byAdding: .day, value: -1, to: start)!
        let previousStart = calendar.date(byAdding: .day, value: -length, to: previousEnd)!
        if selectedTimeRange == .allTime || previousStart < (firstDataDay ?? today) {
            previousCategoryHours = [:]
            hasPreviousPeriod = false
        } else {
            let previous = calculateCategoryStats(from: previousStart, to: previousEnd)
            previousCategoryHours = Dictionary(previous.map { ($0.name, $0.hours) }, uniquingKeysWith: +)
            hasPreviousPeriod = true
        }

        habitSummaries = trackedRecurringTasks
            .map { habitSummary(for: $0, periodStart: start, periodEnd: end, today: today) }
            .sorted { ($0.currentStreak, $0.bestStreak) > ($1.currentStreak, $1.bestStreak) }
    }

    // MARK: - Category detail

    struct CategoryTaskShare: Identifiable, Equatable {
        let id: UUID
        let name: String
        let icon: String
        let hours: Double
        let completions: Int
    }

    struct CategoryDetail: Equatable {
        let hours: Double
        let previousHours: Double?
        let completions: Int
        let trackedSessionHours: Double
        /// Hours per bucket of the selected period.
        let buckets: [(start: Date, hours: Double)]
        let tasks: [CategoryTaskShare]
        let weekdayHours: [(weekday: Int, hours: Double)]

        static func == (lhs: CategoryDetail, rhs: CategoryDetail) -> Bool {
            lhs.hours == rhs.hours && lhs.completions == rhs.completions && lhs.tasks == rhs.tasks
        }
    }

    /// Same sources as the donut (completed tasks' duration + tracked sessions), split by day and by task.
    func categoryDetail(for categoryId: UUID) -> CategoryDetail {
        let calendar = Calendar.current
        let (start, end) = periodDays
        let endExclusive = calendar.date(byAdding: .day, value: 1, to: end)!
        var perDay: [Date: Double] = [:]
        var perTask: [UUID: (name: String, icon: String, hours: Double, completions: Int)] = [:]
        var completions = 0

        for task in statTasks where task.category?.id == categoryId {
            for (date, completion) in task.completions where completion.isCompleted && date >= start && date < endExclusive {
                var duration: TimeInterval = 0
                if let actual = completion.actualDuration, actual > 0 {
                    duration = actual
                } else if task.totalTrackedTime > 0 {
                    duration = task.totalTrackedTime
                } else if task.hasDuration && task.duration > 0 {
                    duration = task.duration
                }
                let hours = duration / 3600
                let day = calendar.startOfDay(for: date)
                perDay[day, default: 0] += hours
                let icon = (task.icon.isEmpty || task.icon == "circle") ? (task.category?.icon ?? "checkmark.circle") : task.icon
                var entry = perTask[task.id] ?? (task.name, icon, 0, 0)
                entry.hours += hours
                entry.completions += 1
                perTask[task.id] = entry
                completions += 1
            }
        }

        var sessionHours = 0.0
        let timeTrackingData = UserDefaults.standard.dictionary(forKey: "timeTracking") as? [String: [String: Double]] ?? [:]
        let key = "category_\(categoryId.uuidString)"
        for (dateKey, dayData) in timeTrackingData {
            guard let date = Self.isoFormatter.date(from: dateKey), date >= start, date < endExclusive,
                  let hours = dayData[key], hours > 0 else { continue }
            perDay[calendar.startOfDay(for: date), default: 0] += hours
            sessionHours += hours
        }

        let unit = bucketUnit(forTrend: false)
        let component: Calendar.Component = unit == .day ? .day : (unit == .week ? .weekOfYear : .month)
        var cursor = unit == .day ? start : (calendar.dateInterval(of: component, for: start)?.start ?? start)
        var buckets: [(start: Date, hours: Double)] = []
        while cursor <= end {
            let next = calendar.date(byAdding: component, value: 1, to: cursor)!
            let hours = perDay.filter { $0.key >= cursor && $0.key < next }.reduce(0) { $0 + $1.value }
            buckets.append((cursor, hours))
            cursor = next
        }

        var byWeekday: [Int: Double] = [:]
        for (day, hours) in perDay {
            byWeekday[calendar.component(.weekday, from: day), default: 0] += hours
        }
        let weekdayHours = (0..<7).map { offset -> (weekday: Int, hours: Double) in
            let weekday = (calendar.firstWeekday - 1 + offset) % 7 + 1
            return (weekday, byWeekday[weekday] ?? 0)
        }

        let total = perDay.values.reduce(0, +)
        let name = categoryManager.categories.first { $0.id == categoryId }?.name
        return CategoryDetail(
            hours: total,
            previousHours: hasPreviousPeriod ? (name.flatMap { previousCategoryHours[$0] } ?? 0) : nil,
            completions: completions,
            trackedSessionHours: sessionHours,
            buckets: buckets,
            tasks: perTask.map { CategoryTaskShare(id: $0.key, name: $0.value.name, icon: $0.value.icon,
                                                   hours: $0.value.hours, completions: $0.value.completions) }
                .sorted { $0.hours > $1.hours },
            weekdayHours: weekdayHours
        )
    }

    private func makeBuckets(_ daily: [Date: (completed: Int, total: Int)], from start: Date, to end: Date, unit: BucketUnit) -> [CompletionBucket] {
        let calendar = Calendar.current
        let component: Calendar.Component
        var cursor: Date
        switch unit {
        case .day:
            component = .day
            cursor = start
        case .week:
            component = .weekOfYear
            cursor = calendar.dateInterval(of: .weekOfYear, for: start)?.start ?? start
        case .month:
            component = .month
            cursor = calendar.dateInterval(of: .month, for: start)?.start ?? start
        }

        var result: [CompletionBucket] = []
        while cursor <= end {
            let next = calendar.date(byAdding: component, value: 1, to: cursor)!
            let last = min(calendar.date(byAdding: .day, value: -1, to: next)!, end)
            var completed = 0
            var total = 0
            var day = max(cursor, start)
            while day <= last {
                if let value = daily[day] {
                    completed += value.completed
                    total += value.total
                }
                day = calendar.date(byAdding: .day, value: 1, to: day)!
            }
            result.append(CompletionBucket(start: cursor, end: last, completed: completed, total: total))
            cursor = next
        }
        return result
    }

    /// Streaks are computed on the whole history (up to 2 years), period numbers only on the selected period.
    /// Non-daily habits: a period counts as done when the task was completed at least once inside it.
    private func periodicHabitSummary(for task: TodoTask, cadence: HabitCadence, periodStart: Date, periodEnd: Date, today: Date) -> HabitSummary {
        let calendar = Calendar.current
        let unit = cadence.component
        let lookback = cadence == .year ? -6 : -2
        let earliest = calendar.date(byAdding: .year, value: lookback, to: today)!
        let completedDays = task.completions.filter { $0.value.isCompleted }.map { calendar.startOfDay(for: $0.key) }
        // Scoped tasks move their start date forward each period: history begins at the first completion if earlier.
        let firstDay = min(calendar.startOfDay(for: task.startTime), completedDays.min() ?? today)
        var cursor = calendar.dateInterval(of: unit, for: max(firstDay, earliest))?.start ?? today

        var periods: [HabitDay] = []
        var run = 0, best = 0, completed = 0, total = 0
        while cursor <= today {
            let next = calendar.date(byAdding: unit, value: 1, to: cursor)!
            let done = completedDays.contains { $0 >= cursor && $0 < next }
            let isCurrent = today < next
            let state: HabitDayState = done ? .done : (isCurrent ? .pending : .missed)
            if done { run += 1; best = max(best, run) } else if !isCurrent { run = 0 }
            // Periods overlapping the selected range; the current one only once it's done.
            if next > periodStart && cursor <= periodEnd && state != .pending {
                total += 1
                if done { completed += 1 }
            }
            periods.append(HabitDay(date: cursor, state: state))
            cursor = next
        }

        let icon = (task.icon.isEmpty || task.icon == "circle") ? (task.category?.icon ?? "repeat") : task.icon
        return HabitSummary(taskId: task.id, name: task.name, icon: icon,
                            color: task.category?.color ?? "#6366F1", categoryName: task.category?.name,
                            currentStreak: run, bestStreak: best,
                            periodCompleted: completed, periodTotal: total,
                            days: [], cadence: cadence, periods: periods)
    }

    private func habitSummary(for task: TodoTask, periodStart: Date, periodEnd: Date, today: Date) -> HabitSummary {
        let cadence = Self.cadence(for: task)
        if cadence != .day {
            return periodicHabitSummary(for: task, cadence: cadence, periodStart: periodStart, periodEnd: periodEnd, today: today)
        }
        let calendar = Calendar.current
        let twoYearsAgo = calendar.date(byAdding: .day, value: -730, to: today)!
        var day = max(calendar.startOfDay(for: task.startTime), twoYearsAgo)

        var days: [HabitDay] = []
        var run = 0
        var best = 0
        var periodCompleted = 0
        var periodTotal = 0

        while day <= today {
            let state: HabitDayState
            if shouldTaskOccurOnDate(task: task, date: day) {
                let done = task.completions[day]?.isCompleted == true
                if done {
                    state = .done
                    run += 1
                    best = max(best, run)
                } else if day == today {
                    state = .pending
                } else {
                    state = .missed
                    run = 0
                }
                if day >= periodStart && day <= periodEnd && state != .pending {
                    periodTotal += 1
                    if done { periodCompleted += 1 }
                }
            } else {
                state = .off
            }
            days.append(HabitDay(date: day, state: state))
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }

        let icon = (task.icon.isEmpty || task.icon == "circle") ? (task.category?.icon ?? "repeat") : task.icon
        return HabitSummary(
            taskId: task.id,
            name: task.name,
            icon: icon,
            color: task.category?.color ?? "#6366F1",
            categoryName: task.category?.name,
            currentStreak: run,
            bestStreak: best,
            periodCompleted: periodCompleted,
            periodTotal: periodTotal,
            days: days
        )
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
        let allTasks = statTasks
        let (startDate, endDate) = selectedTimeRange.dateRange
        let allSessions = taskManager.trackingSessions
        let sessionsByTaskId = Dictionary(grouping: allSessions, by: { $0.taskId })
        
        var analyticsArray: [TaskPerformanceAnalytics] = []
        
        for task in allTasks {
            let taskSessions = sessionsByTaskId[task.id] ?? []
            let completionAnalytics = getTaskCompletionAnalytics(for: task, startDate: startDate, endDate: endDate, sessions: taskSessions)
            
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
        
        if nonRecurringTasksByDay.isEmpty && recurringTasksList.isEmpty && !statTasks.isEmpty {
            refreshTaskPartitions()
        }
        
        let singleDayTasks = nonRecurringTasksByDay[startOfDay] ?? []
        let recurringDayTasks = recurringTasksList.filter { task in
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
    
    private func getTaskCompletionAnalytics(for task: TodoTask, startDate: Date, endDate: Date, sessions: [TrackingSession]) -> [TaskCompletionAnalytics] {
        var analytics: [TaskCompletionAnalytics] = []
        let calendar = Calendar.current
        let startOfStart = calendar.startOfDay(for: startDate)
        let endOfEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate))!
        let sessionDates = Set(sessions.map { calendar.startOfDay(for: $0.startTime) })
        
        for (date, completion) in task.completions {
            guard completion.isCompleted &&
                  date >= startOfStart &&
                  date < endOfEnd else { continue }
            
            let wasTracked = sessionDates.contains(calendar.startOfDay(for: date))
            
            let completionAnalytic = TaskCompletionAnalytics(
                date: date,
                actualDuration: completion.actualDuration,
                difficultyRating: completion.difficultyRating,
                qualityRating: completion.qualityRating,
                estimatedDuration: task.hasDuration ? task.duration : nil,
                wasTracked: wasTracked
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