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
        let completionDate = updatedTask.completionKey(for: date)
        
        if let completion = updatedTask.completions[completionDate]?.isCompleted {
            updatedTask.completions[completionDate]?.isCompleted = !completion
            
            if !completion {
                if !updatedTask.completionDates.contains(completionDate) {
                    updatedTask.completionDates.append(completionDate)
                }
            } else {
                updatedTask.completionDates.removeAll { $0 == completionDate }
            }
        } else {
            updatedTask.completions[completionDate] = TaskCompletion(isCompleted: true)
            if !updatedTask.completionDates.contains(completionDate) {
                updatedTask.completionDates.append(completionDate)
            }
        }
        
        Task {
            await taskManager.updateTask(updatedTask)
        }
        currentStreak = updatedTask.streakForDate(date)
        objectWillChange.send()
    }
}