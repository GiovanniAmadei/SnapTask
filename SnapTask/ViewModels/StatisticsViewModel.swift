import SwiftUI
import Combine
import OSLog

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
        updateStreaks()
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
                if let recurrence = task.recurrence {
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
    
    private func updateStreaks() {
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
                if let recurrence = task.recurrence {
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
}

// Add logger extension at the bottom of the file
private extension Logger {
    static let stats = Logger(subsystem: "com.yourapp.SnapTask", category: "Statistics")
} 