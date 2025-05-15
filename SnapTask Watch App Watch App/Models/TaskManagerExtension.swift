import Foundation

extension TaskManager {
    // Actualiza todas las tareas reemplazando el array completo
    func updateAllTasks(_ newTasks: [TodoTask]) {
        // Preserve completion data for tasks that already exist
        var updatedTasks: [TodoTask] = []
        
        for newTask in newTasks {
            if let existingIndex = tasks.firstIndex(where: { $0.id == newTask.id }) {
                // Preserve completion data
                var taskWithCompletions = newTask
                taskWithCompletions.completions = tasks[existingIndex].completions
                updatedTasks.append(taskWithCompletions)
            } else {
                // New task, add as is
                updatedTasks.append(newTask)
            }
        }
        
        tasks = updatedTasks
        saveTasks()
        notifyTasksUpdated()
        objectWillChange.send()
    }
} 