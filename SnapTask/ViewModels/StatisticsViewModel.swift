import SwiftUI
import Combine
import OSLog
import Foundation

class StatisticsViewModel: ObservableObject {
    struct CategoryStat: Identifiable {
        let id = UUID()
        let name: String
        let color: String
        let hours: Double
    }
    
    struct WeeklyStat: Identifiable {
        let id = UUID()
        let day: String
        let completedTasks: Int
        let totalTasks: Int
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
    @Published var selectedTimeRange: TimeRange = .today
    @Published private(set) var recurringTasks: [TodoTask] = []
    
    private var cancellables = Set<AnyCancellable>()
    private let taskManager: TaskManager
    private let categoryManager = CategoryManager.shared
    
    init(taskManager: TaskManager = .shared) {
        self.taskManager = taskManager
        setupObservers()
    }
    
    func refreshStats() {
        DispatchQueue.main.async { [weak self] in
            self?.updateStats()
        }
    }
    
    private func setupObservers() {
        // Listen for task updates
        NotificationCenter.default.publisher(for: .tasksDidUpdate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStats()
            }
            .store(in: &cancellables)
            
        // Listen for category updates
        NotificationCenter.default.publisher(for: .categoriesDidUpdate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStats()
            }
            .store(in: &cancellables)
        
        // Listen for category manager updates
        categoryManager.$categories
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStats()
            }
            .store(in: &cancellables)
        
        // Listen for task manager updates
        taskManager.$tasks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStats()
            }
            .store(in: &cancellables)
        
        // Add time range observer
        $selectedTimeRange
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStats()
            }
            .store(in: &cancellables)
    }
    
    private func updateStats() {
        updateCategoryStats()
        updateWeeklyStats()
        updateStreakStats()
        updateRecurringTasks()
        objectWillChange.send()
    }
    
    private func updateCategoryStats() {
        let categories = categoryManager.categories
        let allTasks = taskManager.tasks
        let (startDate, endDate) = selectedTimeRange.dateRange
        
        categoryStats = categories.map { category in
            let categoryTasks = allTasks.filter { task in
                task.category?.id == category.id
            }
            let totalHours = categoryTasks.reduce(0.0) { total, task in
                let taskHours = task.completions
                    .filter { $0.key >= startDate && $0.key <= endDate && $0.value.isCompleted }
                    .reduce(0.0) { sum, completion in
                        sum + (task.hasDuration ? task.duration / 3600.0 : 0)
                    }
                return total + taskHours
            }
            
            return CategoryStat(
                name: category.name,
                color: category.color,
                hours: totalHours
            )
        }.filter { $0.hours > 0 }
    }
    
    private func updateWeeklyStats() {
        let calendar = Calendar.current
        let today = Date()
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today)!
        
        weeklyStats = (0...6).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart)!
            let startOfDay = date.startOfDay
            
            // Get all tasks that were either created for this day or are recurring
            let dayTasks = taskManager.tasks.filter { task in
                if calendar.isDate(task.startTime, inSameDayAs: date) {
                    return true
                }
                // Check if it's a recurring task that should appear on this day
                if task.recurrence != nil {
                    switch task.recurrence!.type {
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
                return false
            }
            
            let completedCount = dayTasks.filter { task in
                if let completion = task.completions[startOfDay] {
                    return completion.isCompleted
                }
                return false
            }.count
            
            return WeeklyStat(
                day: date.formatted(.dateTime.weekday(.abbreviated)),
                completedTasks: completedCount,
                totalTasks: dayTasks.count
            )
        }
    }
    
    private func updateStreakStats() {
        // Improve date calculations using Calendar
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let yearAgo = calendar.date(byAdding: .year, value: -1, to: today) else {
            Logger.stats.error("Date calculation failed")
            return
        }
        
        // Replace manual date stride with Calendar enumeration
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
        
        // Calculate streaks
        for date in dates {
            let dayTasks = taskManager.tasks.filter { task in
                // Include tasks specifically for this day
                if calendar.isDate(task.startTime, inSameDayAs: date) {
                    return true
                }
                // Include recurring tasks
                if task.recurrence != nil {
                    switch task.recurrence!.type {
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
                return false
            }
            
            // Fix allSatisfy closure syntax
            let allCompleted = !dayTasks.isEmpty && dayTasks.allSatisfy { task in
                if let completion = task.completions[date.startOfDay] {
                    return completion.isCompleted
                }
                return false
            }
            
            if allCompleted {
                tempStreak += 1
                bestStreak = max(bestStreak, tempStreak)
                if calendar.isDateInToday(date) {
                    currentStreak = tempStreak
                }
            } else {
                tempStreak = 0
            }
        }
        
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
    }
    
    private func updateRecurringTasks() {
        recurringTasks = taskManager.tasks.filter { $0.recurrence != nil }
    }
    
    func consistencyPoints(for task: TodoTask, in timeRange: TaskConsistencyChartView.TimeRange) -> [(x: CGFloat, y: CGFloat)] {
        guard task.recurrence != nil else { 
            print("Task \(task.name) has no recurrence")
            return [] 
        }
        
        let calendar = Calendar.current
        let today = Date()
        var points: [(x: CGFloat, y: CGFloat)] = []
        
        // Determine time range to analyze
        let daysToAnalyze: Int
        switch timeRange {
        case .week:
            daysToAnalyze = 7
        case .month:
            daysToAnalyze = 30
        case .year:
            daysToAnalyze = 365
        }
        
        // Start with zero progress
        var cumulativeProgress: Int = 0
        
        // Calculate points for each day in the period
        for dayOffset in (1-daysToAnalyze)...0 {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: today)!.startOfDay
            
            // Check if task should occur on this date based on recurrence pattern
            if shouldTaskOccurOnDate(task: task, date: date) {
                // Update the cumulative progress: +1 if completed, -0 if not completed
                let isCompleted = task.completions[date]?.isCompleted == true
                cumulativeProgress = max(0, cumulativeProgress + (isCompleted ? 1 : -1))
                
                // Normalize x position between 0 and 1
                let normalizedX = CGFloat(dayOffset + daysToAnalyze) / CGFloat(daysToAnalyze)
                
                points.append((x: normalizedX, y: CGFloat(cumulativeProgress)))
            }
        }
        
        print("Task: \(task.name) - Generated \(points.count) points, final progress: \(cumulativeProgress)")
        return points
    }
    
    // Helper function to check if a task should occur on a specific date
    private func shouldTaskOccurOnDate(task: TodoTask, date: Date) -> Bool {
        guard let recurrence = task.recurrence else { return false }
        
        let calendar = Calendar.current
        
        // Check if task has started
        if date < calendar.startOfDay(for: task.startTime) {
            return false
        }
        
        // Check end date if it exists
        if let endDate = recurrence.endDate, date > endDate {
            return false
        }
        
        // Check recurrence pattern
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
}

// Add logger extension at the bottom of the file
private extension Logger {
    static let stats = Logger(subsystem: "com.yourapp.SnapTask", category: "Statistics")
} 