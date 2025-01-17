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
    
    init(taskManager: TaskManager = .shared) {
        self.taskManager = taskManager
        updateStats()
        
        // Listen for updates
        NotificationCenter.default.publisher(for: .categoriesDidUpdate)
            .merge(with: NotificationCenter.default.publisher(for: .tasksDidUpdate))
            .sink { [weak self] _ in
                self?.updateStats()
            }
            .store(in: &cancellables)
    }
    
    func updateStats() {
        updateCategoryStats()
        updateWeeklyStats()
        updateStreaks()
    }
    
    private func updateCategoryStats() {
        let categories = SettingsViewModel.shared.categories
        let allTasks = taskManager.tasks
        
        categoryStats = categories.map { category in
            let categoryTasks = allTasks.filter { $0.category.id == category.id }
            let totalHours = categoryTasks.reduce(0.0) { total, task in
                let completedHours = task.completions.reduce(0.0) { subtotal, completion in
                    if completion.value.isCompleted {
                        return subtotal + (task.duration / 3600.0)
                    }
                    return subtotal
                }
                return total + completedHours
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
            let dayTasks = taskManager.tasks.filter { task in
                calendar.isDate(task.startTime, inSameDayAs: date)
            }
            
            let completedCount = dayTasks.filter { task in
                if let completion = task.completions[date.startOfDay] {
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
            let dayTasks = taskManager.tasks.filter { task in
                calendar.isDate(task.startTime, inSameDayAs: date)
            }
            return !dayTasks.isEmpty && dayTasks.allSatisfy { task in
                if let completion = task.completions[date.startOfDay] {
                    return completion.isCompleted
                }
                return false
            }
        }
        
        // Calculate current streak
        for completed in dates {
            if completed {
                tempStreak += 1
            } else {
                break
            }
        }
        currentStreak = tempStreak
        
        // Calculate best streak
        tempStreak = 0
        for completed in dates {
            if completed {
                tempStreak += 1
                bestStreak = max(bestStreak, tempStreak)
            } else {
                tempStreak = 0
            }
        }
        
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
    }
} 