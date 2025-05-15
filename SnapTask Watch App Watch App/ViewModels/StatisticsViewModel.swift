import Foundation
import SwiftUI

class StatisticsViewModel: ObservableObject {
    enum TimeRange: String, CaseIterable {
        case today = "Today"
        case week = "This Week"
        case month = "This Month"
        case year = "This Year"
    }
    
    struct CategoryStat: Identifiable {
        let id = UUID()
        let name: String
        let color: String
        let hours: Double
        let percentage: Double
    }
    
    struct DailyStat: Identifiable {
        let id = UUID()
        let day: String
        let completedTasks: Int
        let totalTasks: Int
    }
    
    @Published var selectedTimeRange: TimeRange = .week
    @Published var categoryStats: [CategoryStat] = []
    @Published var weeklyStats: [DailyStat] = []
    @Published var currentStreak: Int = 0
    @Published var bestStreak: Int = 0
    
    private let taskManager = TaskManager.shared
    
    func refreshStats() {
        calculateCategoryStats()
        calculateWeeklyStats()
        calculateStreaks()
    }
    
    private func calculateCategoryStats() {
        let startDate: Date
        let endDate = Date()
        
        switch selectedTimeRange {
        case .today:
            startDate = Calendar.current.startOfDay(for: endDate)
        case .week:
            startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate)!
        case .month:
            startDate = Calendar.current.date(byAdding: .month, value: -1, to: endDate)!
        case .year:
            startDate = Calendar.current.date(byAdding: .year, value: -1, to: endDate)!
        }
        
        var categoryToTime: [String: TimeInterval] = [:]
        var totalTime: TimeInterval = 0
        
        for task in taskManager.tasks {
            guard task.hasDuration else { continue }
            
            // Ottieni le date di completamento nel range specificato
            let completions = task.completions.filter { dateCompletion in
                let date = dateCompletion.key
                return date >= startDate && date <= endDate && dateCompletion.value.isCompleted
            }
            
            if completions.isEmpty { continue }
            
            // Calcola il tempo totale per categoria
            let categoryName = task.category?.name ?? "Uncategorized"
            let categoryColor = task.category?.color ?? "AAAAAA"
            let taskDuration = Double(task.duration) * 60 // Converti in secondi
            
            let totalTaskTime = taskDuration * Double(completions.count)
            categoryToTime[categoryName, default: 0] += totalTaskTime
            totalTime += totalTaskTime
        }
        
        // Converti in ore e crea gli oggetti CategoryStat
        var stats: [CategoryStat] = []
        for (name, time) in categoryToTime {
            let hours = time / 3600 // Converti secondi in ore
            let percentage = totalTime > 0 ? (time / totalTime) * 100 : 0
            
            let color = taskManager.tasks
                .first(where: { $0.category?.name == name })?
                .category?.color ?? "AAAAAA"
            
            stats.append(CategoryStat(name: name, color: color, hours: hours, percentage: percentage))
        }
        
        categoryStats = stats.sorted { $0.hours > $1.hours }
    }
    
    private func calculateWeeklyStats() {
        let calendar = Calendar.current
        let today = Date()
        var stats: [DailyStat] = []
        
        for dayOffset in -6...0 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "E"
            let dayString = dayFormatter.string(from: date)
            
            let dayStart = calendar.startOfDay(for: date)
            let completedTasks = countCompletedTasks(for: dayStart)
            let totalTasks = countTotalTasks(for: dayStart)
            
            stats.append(DailyStat(
                day: dayString,
                completedTasks: completedTasks,
                totalTasks: totalTasks
            ))
        }
        
        weeklyStats = stats
    }
    
    private func calculateStreaks() {
        let calendar = Calendar.current
        let today = Date()
        
        var currentStreak = 0
        var bestStreak = 0
        var tempStreak = 0
        
        // Calcola gli ultimi 365 giorni
        for dayOffset in (0...365).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            
            let dayStart = calendar.startOfDay(for: date)
            let completedTasks = countCompletedTasks(for: dayStart)
            let totalTasks = countTotalTasks(for: dayStart)
            
            if completedTasks > 0 && totalTasks > 0 && completedTasks >= totalTasks / 2 {
                // Giorno produttivo (almeno metà dei task completati)
                tempStreak += 1
                
                if tempStreak > bestStreak {
                    bestStreak = tempStreak
                }
                
                // Se siamo nel giorno corrente, aggiorna lo streak attuale
                if dayOffset == 0 {
                    currentStreak = tempStreak
                }
            } else {
                // Streak interrotto
                tempStreak = 0
                
                // Se è il giorno corrente senza attività, lo streak attuale è 0
                if dayOffset == 0 {
                    currentStreak = 0
                }
            }
        }
        
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
    }
    
    private func countCompletedTasks(for date: Date) -> Int {
        let tasks = taskManager.tasks.filter { task in
            if let completion = task.completions[date], completion.isCompleted {
                return true
            }
            return false
        }
        return tasks.count
    }
    
    private func countTotalTasks(for date: Date) -> Int {
        let dateStart = Calendar.current.startOfDay(for: date)
        
        return taskManager.tasks.filter { task in
            let taskDate = Calendar.current.startOfDay(for: task.startTime)
            
            // Task creati per quella data
            if taskDate == dateStart {
                return true
            }
            
            // Task ricorrenti attivi in quella data
            if let recurrence = task.recurrence, recurrence.isActiveOn(date: date) {
                return true
            }
            
            return false
        }.count
    }
} 