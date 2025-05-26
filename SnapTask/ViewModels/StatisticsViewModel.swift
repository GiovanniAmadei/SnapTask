import SwiftUI
import Combine
import os.log
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
    
    // Tasks that should be included in consistency tracking
    var trackedRecurringTasks: [TodoTask] {
        recurringTasks.filter { task in
            if let recurrence = task.recurrence {
                return recurrence.trackInStatistics
            }
            return false
        }
    }
    
    // Make sure we use all recurring tasks in consistency view
    var consistency: [TodoTask] {
        // Use all recurring tasks for consistency view regardless of tracking setting
        recurringTasks
    }
    
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
    
    // Method to be called after CloudKit synchronization
    func refreshAfterSync() {
        DispatchQueue.main.async { [weak self] in
            // Invalidate the current statistics
            self?.categoryStats = []
            self?.weeklyStats = []
            self?.currentStreak = 0
            self?.bestStreak = 0
            self?.recurringTasks = []
            
            // Force a refresh after a short delay to ensure all data is loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.updateStats()
            }
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
        
        // Listen for time tracking updates
        NotificationCenter.default.publisher(for: .timeTrackingUpdated)
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
        
        // Get time tracking data from UserDefaults
        let timeTrackingData = UserDefaults.standard.dictionary(forKey: "timeTracking") as? [String: [String: Double]] ?? [:]
        let taskMetadata = UserDefaults.standard.dictionary(forKey: "taskMetadata") as? [String: [String: String]] ?? [:]
        
        var categoryStatsList: [CategoryStat] = []
        
        // Process regular categories
        for category in categories {
            // Calculate hours from completed tasks
            let categoryTasks = allTasks.filter { task in
                task.category?.id == category.id
            }
            let taskHours = categoryTasks.reduce(0.0) { total, task in
                let taskHours = task.completions
                    .filter { $0.key >= startDate && $0.key <= endDate && $0.value.isCompleted }
                    .reduce(0.0) { sum, completion in
                        sum + (task.hasDuration ? task.duration / 3600.0 : 0)
                    }
                return total + taskHours
            }
            
            // Add tracked time from Pomodoro sessions
            let calendar = Calendar.current
            var trackedHours = 0.0
            
            var currentDate = startDate
            while currentDate <= endDate {
                let dateKey = ISO8601DateFormatter().string(from: calendar.startOfDay(for: currentDate))
                if let dayData = timeTrackingData[dateKey],
                   let categoryHours = dayData[category.id.uuidString] {
                    trackedHours += categoryHours
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
            }
        }
        
        // Process individual task tracking
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
        
        // Add individual tasks to statistics
        for (taskKey, hours) in taskTracking {
            if hours > 0, let metadata = taskMetadata[taskKey] {
                categoryStatsList.append(CategoryStat(
                    name: metadata["name"] ?? "Unknown Task",
                    color: metadata["color"] ?? "#6366F1",
                    hours: hours
                ))
            }
        }
        
        categoryStats = categoryStatsList
    }
    
    private func updateWeeklyStats() {
        let calendar = Calendar.current
        let today = Date()
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today)!
        
        weeklyStats = (0...6).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart)!
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!.addingTimeInterval(-1)
            
            // 1. Filtra le task SINGLE (non ricorrenti) create specificamente per questo giorno
            let singleDayTasks = taskManager.tasks.filter { task in
                task.recurrence == nil && calendar.isDate(task.startTime, inSameDayAs: date)
            }
            
            // 2. Filtra le task RICORRENTI che dovrebbero essere attive in questo giorno
            let recurringDayTasks = taskManager.tasks.filter { task in
                guard let recurrence = task.recurrence else { return false }
                
                // Verifica che la task sia stata creata in o prima di questo giorno
                if task.startTime > endOfDay { return false }
                
                // Verifica la data di fine se esiste
                if let endDate = recurrence.endDate, endDate < startOfDay { return false }
                
                // Controlla il pattern di ricorrenza per questo giorno specifico
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
            
            // Combina tutte le task attive per questo giorno
            let allDayTasks = singleDayTasks + recurringDayTasks
            
            // Conta quante task sono state completate per questo giorno
            let completedCount = allDayTasks.filter { task in
                if let completion = task.completions[startOfDay], completion.isCompleted {
                    return true
                }
                return false
            }.count
            
            return WeeklyStat(
                day: date.formatted(.dateTime.weekday(.abbreviated)),
                completedTasks: completedCount,
                totalTasks: allDayTasks.count
            )
        }
    }
    
    private func updateStreakStats() {
        // Improve date calculations using Calendar
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let yearAgo = calendar.date(byAdding: .year, value: -1, to: today) else {
            Logger.stats("Date calculation failed", level: .error)
            return
        }
        
        // Genera array di date dal passato a oggi
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
        
        // Itera dal giorno più recente al più vecchio
        for date in dates.reversed() {
            let startOfDay = calendar.startOfDay(for: date)
            
            // Ottiene le task per il giorno, includendo quelle ricorrenti
            let dayTasks = taskManager.tasks.filter { task in
                // Verifica che la task sia stata creata in o prima di questo giorno
                guard task.startTime <= startOfDay else { return false }
                
                // Includi task specifiche per questo giorno
                if calendar.isDate(task.startTime, inSameDayAs: date) {
                    return true
                }
                
                // Includi task ricorrenti per questo giorno
                if let recurrence = task.recurrence {
                    // Verifica la data di fine se esiste
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
                    }
                }
                return false
            }
            
            // Controlla se ci sono task per il giorno e se sono tutte completate
            let allCompletedForDay = !dayTasks.isEmpty && dayTasks.allSatisfy { task in
                if let completion = task.completions[startOfDay] {
                    return completion.isCompleted
                }
                return false
            }
            
            if allCompletedForDay {
                tempStreak += 1
                // Aggiorna la striscia migliore
                bestStreak = max(bestStreak, tempStreak)
                
                // Se siamo a oggi, questa è la striscia corrente
                if calendar.isDateInToday(date) {
                    currentStreak = tempStreak
                }
            } else {
                // Se c'è un'interruzione nella striscia
                if tempStreak > 0 && calendar.isDateInToday(date) {
                    // Se l'interruzione è proprio oggi, consideriamo la striscia corrente come 0
                    currentStreak = 0
                }
                tempStreak = 0
            }
        }
        
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
    }
    
    private func updateRecurringTasks() {
        // Include all recurring tasks regardless of trackInStatistics setting
        recurringTasks = taskManager.tasks.filter { task in 
            task.recurrence != nil
        }
    }
    
    func consistencyPoints(for task: TodoTask, in timeRange: TaskConsistencyChartView.TimeRange) -> [(x: CGFloat, y: CGFloat)] {
        guard let recurrence = task.recurrence else { 
            return [] 
        }
        
        let calendar = Calendar.current
        let today = Date()
        let taskCreationDay = calendar.startOfDay(for: task.startTime)
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
        var foundFirstValidDay = false
        
        // Calculate points for each day in the period
        for dayOffset in (1-daysToAnalyze)...0 {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: today)!
            let startOfDay = calendar.startOfDay(for: date)
            
            // Normalize x position between 0 and 1
            let normalizedX = CGFloat(dayOffset + daysToAnalyze) / CGFloat(daysToAnalyze)
            
            // Skip days before task was created
            if startOfDay < taskCreationDay {
                continue
            }
            
            // We've found the first valid day for this task
            foundFirstValidDay = true
            
            // Check if task should occur on this date based on recurrence pattern
            if shouldTaskOccurOnDate(task: task, date: startOfDay) {
                // Check if task was completed on this day
                let isCompleted = task.completions[startOfDay]?.isCompleted == true
                
                // Update progress: +1 if completed, -1 if not completed
                if isCompleted {
                    cumulativeProgress += 1
                } else {
                    // Penalize missed tasks by decreasing the score
                    cumulativeProgress = max(0, cumulativeProgress - 1)
                }
                
                points.append((x: normalizedX, y: CGFloat(cumulativeProgress)))
            }
        }
        
        // If we have no points but the task exists in the time range, add a starting point
        if points.isEmpty && foundFirstValidDay {
            // Calculate normalized X for task creation date
            let daysDiff = calendar.dateComponents([.day], from: calendar.startOfDay(for: today.addingTimeInterval(-Double(daysToAnalyze-1) * 86400)), to: taskCreationDay).day ?? 0
            let startX = CGFloat(max(0, min(daysToAnalyze, daysDiff))) / CGFloat(daysToAnalyze)
            
            points.append((x: startX, y: 0))
            
            // Add another point at current date if we only have one point
            if points.count == 1 {
                points.append((x: 1.0, y: 0))
            }
        }
        
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

// Extension to add Statistics-specific logging
extension Logger {
    static func stats(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        Logger.shared.log(message, level: level, subsystem: "statistics", file: file, function: function, line: line)
    }
}
