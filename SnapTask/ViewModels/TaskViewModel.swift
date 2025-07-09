import Foundation
import Combine

@MainActor
class TaskViewModel: ObservableObject {
    @Published private(set) var currentStreak: Int = 0
    private let taskManager = TaskManager.shared
    
    func refreshTask(_ task: TodoTask, for date: Date) {
        currentStreak = task.streakForDate(date)
        objectWillChange.send()
    }
    
    func toggleCompletion(for task: TodoTask, on date: Date) {
        var updatedTask = task
        let startOfDay = date.startOfDay
        
        if let completion = updatedTask.completions[startOfDay]?.isCompleted {
            updatedTask.completions[startOfDay]?.isCompleted = !completion
            
            if !completion {
                if !updatedTask.completionDates.contains(startOfDay) {
                    updatedTask.completionDates.append(startOfDay)
                }
            } else {
                updatedTask.completionDates.removeAll { $0 == startOfDay }
            }
        } else {
            updatedTask.completions[startOfDay] = TaskCompletion(isCompleted: true)
            if !updatedTask.completionDates.contains(startOfDay) {
                updatedTask.completionDates.append(startOfDay)
            }
        }
        
        Task {
            await taskManager.updateTask(updatedTask)
        }
        currentStreak = updatedTask.streakForDate(date)
        objectWillChange.send()
    }
}