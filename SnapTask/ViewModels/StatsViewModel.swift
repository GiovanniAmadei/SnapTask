import SwiftUI
import Combine
import OSLog
import Foundation
import CoreGraphics

@MainActor
class StatsViewModel: ObservableObject {
    struct ConsistencyPoint {
        let date: Date
        let isCompleted: Bool
        let x: CGFloat
        let y: CGFloat
    }
    
    enum TimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
    }
    
    @Published var selectedTimeRange: TimeRange = .week
    @Published private(set) var recurringTasks: [TodoTask] = []
    
    private let taskManager: TaskManager
    
    init(taskManager: TaskManager = .shared) {
        self.taskManager = taskManager
        updateRecurringTasks()
    }
    
    func refreshStats() {
        updateRecurringTasks()
    }
    
    private func updateRecurringTasks() {
        // Make sure we're getting all recurring tasks
        recurringTasks = taskManager.tasks.filter { $0.recurrence != nil }
        
        // Log for debugging
        print("Found \(recurringTasks.count) recurring tasks:")
        for task in recurringTasks {
            print("- \(task.name) (ID: \(task.id))")
        }
        
        // Force a UI update
        objectWillChange.send()
    }
    
    func consistencyPoints(for task: TodoTask, in timeRange: TimeRange) -> [(x: CGFloat, y: CGFloat)] {
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
        
        // Calculate points for each day in the period
        for dayOffset in (1-daysToAnalyze)...0 {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: today)!.startOfDay
            
            // Check if task should occur on this date based on recurrence pattern
            if shouldTaskOccurOnDate(task: task, date: date) {
                // Calculate completion percentage
                let isCompleted = task.completions[date]?.isCompleted == true
                let completionValue: CGFloat = isCompleted ? 1.0 : 0.0
                
                // Normalize x position between 0 and 1
                let normalizedX = CGFloat(dayOffset + daysToAnalyze) / CGFloat(daysToAnalyze)
                
                points.append((x: normalizedX, y: completionValue))
            }
        }
        
        print("Generated \(points.count) points for task \(task.name)")
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
        case .monthlyOrdinal(let patterns):
            return recurrence.shouldOccurOn(date: date)
        case .yearly:
            return recurrence.shouldOccurOn(date: date)
        }
    }
}
