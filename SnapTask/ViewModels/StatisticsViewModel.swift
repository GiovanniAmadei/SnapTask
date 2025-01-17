import SwiftUI
import Combine

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
    
    @Published private(set) var categoryStats: [CategoryStat] = []
    @Published private(set) var weeklyStats: [WeeklyStat] = []
    @Published private(set) var currentStreak: Int = 0
    @Published private(set) var bestStreak: Int = 0
    
    private var cancellables = Set<AnyCancellable>()
    private let taskManager: TaskManager
    private let settingsViewModel: SettingsViewModel
    
    init(taskManager: TaskManager = .shared, settingsViewModel: SettingsViewModel = .shared) {
        self.taskManager = taskManager
        self.settingsViewModel = settingsViewModel
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
            
        // Listen for task manager updates
        taskManager.$tasks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStats()
            }
            .store(in: &cancellables)
            
        // Listen for settings updates
        settingsViewModel.$categories
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
        let categories = SettingsViewModel.shared.categories
        let allTasks = taskManager.tasks
        let calendar = Calendar.current
        let today = Date().startOfDay
        let startOfMonth = calendar.date(byAdding: .month, value: -1, to: today)!
        
        categoryStats = categories.map { category in
            let categoryTasks = allTasks.filter { task in
                task.category?.id == category.id
            }
            let totalHours = categoryTasks.reduce(0.0) { total, task in
                // Sum up all completed instances of this task
                let taskHours = task.completions
                    .filter { $0.key >= startOfMonth && $0.value.isCompleted }
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
        }
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
        let calendar = Calendar.current
        var currentStreak = 0
        var bestStreak = 0
        var tempStreak = 0
        
        // Get last 365 days of tasks
        let today = calendar.startOfDay(for: Date())
        let yearAgo = calendar.date(byAdding: .year, value: -1, to: today)!
        
        let dates = stride(from: today, through: yearAgo, by: -86400).map { date in
            let startOfDay = date.startOfDay
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
            
            // Check if all tasks for this day were completed
            return !dayTasks.isEmpty && dayTasks.allSatisfy { task in
                if let completion = task.completions[startOfDay] {
                    return completion.isCompleted
                }
                return false
            }
        }
        
        // Calculate streaks
        for completed in dates {
            if completed {
                tempStreak += 1
                currentStreak = tempStreak
                bestStreak = max(bestStreak, tempStreak)
            } else {
                if currentStreak == tempStreak {
                    currentStreak = 0
                }
                tempStreak = 0
            }
        }
        
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
    }
} 