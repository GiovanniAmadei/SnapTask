import Foundation
import SwiftUI

// Protocol that defines the Task Repository interface
protocol TaskRepository {
    // CRUD operations
    func getTasks() -> [TodoTask]
    func getTask(id: UUID) -> TodoTask?
    func saveTasks(_ tasks: [TodoTask])
    func saveTask(_ task: TodoTask)
    func deleteTask(_ task: TodoTask)
    func deleteTaskWithId(_ id: UUID)
    
    // Task completions
    func toggleTaskCompletion(taskId: UUID, on date: Date) -> TodoTask?
    func toggleSubtaskCompletion(taskId: UUID, subtaskId: UUID, on date: Date) -> TodoTask?
    
    // Observers
    var onTasksUpdated: (() -> Void)? { get set }
}

// UserDefaults implementation
class UserDefaultsTaskRepository: TaskRepository {
    private let tasksKey = "savedTasks"
    private var tasks: [TodoTask] = []
    var onTasksUpdated: (() -> Void)?
    
    init() {
        loadTasks()
    }
    
    func getTasks() -> [TodoTask] {
        return tasks
    }
    
    func getTask(id: UUID) -> TodoTask? {
        return tasks.first { $0.id == id }
    }
    
    func saveTasks(_ tasks: [TodoTask]) {
        self.tasks = tasks
        persistTasks()
        onTasksUpdated?()
    }
    
    func saveTask(_ task: TodoTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            // Update existing task, preserving completions
            var updatedTask = task
            updatedTask.completions = tasks[index].completions
            tasks[index] = updatedTask
        } else {
            // Add new task
            tasks.append(task)
        }
        
        persistTasks()
        onTasksUpdated?()
    }
    
    func deleteTask(_ task: TodoTask) {
        deleteTaskWithId(task.id)
    }
    
    func deleteTaskWithId(_ id: UUID) {
        tasks.removeAll { $0.id == id }
        persistTasks()
        onTasksUpdated?()
    }
    
    func toggleTaskCompletion(taskId: UUID, on date: Date = Date()) -> TodoTask? {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return nil }
        
        var task = tasks[index]
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        // Update completion status
        if let completion = task.completions[startOfDay] {
            task.completions[startOfDay] = TaskCompletion(
                isCompleted: !completion.isCompleted,
                completedSubtasks: completion.completedSubtasks
            )
        } else {
            task.completions[startOfDay] = TaskCompletion(
                isCompleted: true,
                completedSubtasks: []
            )
        }
        
        // Update completionDates
        if task.completions[startOfDay]?.isCompleted == true {
            if !task.completionDates.contains(startOfDay) {
                task.completionDates.append(startOfDay)
            }
        } else {
            task.completionDates.removeAll { $0 == startOfDay }
        }
        
        tasks[index] = task
        persistTasks()
        onTasksUpdated?()
        
        return task
    }
    
    func toggleSubtaskCompletion(taskId: UUID, subtaskId: UUID, on date: Date = Date()) -> TodoTask? {
        guard let taskIndex = tasks.firstIndex(where: { $0.id == taskId }) else { return nil }
        
        var task = tasks[taskIndex]
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        var completion = task.completions[startOfDay] ?? TaskCompletion(isCompleted: false, completedSubtasks: [])
        
        if completion.completedSubtasks.contains(subtaskId) {
            completion.completedSubtasks.remove(subtaskId)
        } else {
            completion.completedSubtasks.insert(subtaskId)
        }
        
        task.completions[startOfDay] = completion
        tasks[taskIndex] = task
        
        persistTasks()
        onTasksUpdated?()
        
        return task
    }
    
    // Private helper methods
    private func persistTasks() {
        do {
            let data = try JSONEncoder().encode(tasks)
            UserDefaults.standard.set(data, forKey: tasksKey)
        } catch {
            Log("Error saving tasks: \(error)", level: .error, subsystem: "data")
        }
    }
    
    private func loadTasks() {
        if let data = UserDefaults.standard.data(forKey: tasksKey) {
            do {
                tasks = try JSONDecoder().decode([TodoTask].self, from: data)
            } catch {
                Log("Error loading tasks: \(error)", level: .error, subsystem: "data")
                tasks = []
            }
        }
    }
}

// Repository types enum
enum RepositoryType {
    case userDefaults
    case cloudKit
}

// Repository factory
class TaskRepositoryFactory {
    static let shared = TaskRepositoryFactory()
    
    private var repositories: [RepositoryType: TaskRepository] = [:]
    
    // Current active repository type
    @AppStorage("activeRepositoryType") private var activeRepositoryType = 0 // Default to UserDefaults
    
    private init() {}
    
    func getRepository(type: RepositoryType? = nil) -> TaskRepository {
        // Use specified type or the active type from settings
        let repoType = type ?? (activeRepositoryType == 0 ? .userDefaults : .cloudKit)
        
        // Return cached repository if available
        if let repo = repositories[repoType] {
            return repo
        }
        
        // Create new repository if needed
        let repo: TaskRepository
        switch repoType {
        case .userDefaults:
            repo = UserDefaultsTaskRepository()
        case .cloudKit:
            repo = CloudKitRepository()
        }
        
        // Cache and return
        repositories[repoType] = repo
        return repo
    }
    
    // Change active repository type and save in settings
    func setActiveRepositoryType(_ type: RepositoryType) {
        activeRepositoryType = type == .userDefaults ? 0 : 1
    }
} 