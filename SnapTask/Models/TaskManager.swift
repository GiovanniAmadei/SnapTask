import Foundation
import Combine

class TaskManager: ObservableObject {
    static let shared = TaskManager()
    
    @Published private(set) var tasks: [TodoTask] = []
    private let tasksKey = "savedTasks"
    
    init() {
        loadTasks()
    }
    
    func addTask(_ task: TodoTask) {
        tasks.append(task)
        saveTasks()
        notifyTasksUpdated()
        objectWillChange.send()
    }
    
    func updateTask(_ task: TodoTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
            saveTasks()
            notifyTasksUpdated()
            objectWillChange.send()
        }
    }
    
    func removeTask(_ task: TodoTask) {
        tasks.removeAll { $0.id == task.id }
        saveTasks()
        notifyTasksUpdated()
        objectWillChange.send()
    }
    
    func toggleTaskCompletion(_ taskId: UUID, on date: Date = Date()) {
        if let index = tasks.firstIndex(where: { $0.id == taskId }) {
            var task = tasks[index]
            let startOfDay = date.startOfDay
            
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
            
            tasks[index] = task
            saveTasks()
            notifyTasksUpdated()
            objectWillChange.send()
        }
    }
    
    func toggleSubtask(taskId: UUID, subtaskId: UUID, on date: Date = Date()) {
        if let taskIndex = tasks.firstIndex(where: { $0.id == taskId }) {
            var task = tasks[taskIndex]
            let startOfDay = date.startOfDay
            
            var completion = task.completions[startOfDay] ?? TaskCompletion(isCompleted: false, completedSubtasks: [])
            
            // Add a small delay to ensure animations complete
            DispatchQueue.main.async {
                if completion.completedSubtasks.contains(subtaskId) {
                    completion.completedSubtasks.remove(subtaskId)
                } else {
                    completion.completedSubtasks.insert(subtaskId)
                }
                
                task.completions[startOfDay] = completion
                self.tasks[taskIndex] = task
                self.saveTasks()
                self.notifyTasksUpdated()
                self.objectWillChange.send()
            }
        }
    }
    
    private func saveTasks() {
        do {
            let data = try JSONEncoder().encode(tasks)
            UserDefaults.standard.set(data, forKey: tasksKey)
        } catch {
            print("Error saving tasks: \(error)")
        }
    }
    
    private func loadTasks() {
        if let data = UserDefaults.standard.data(forKey: tasksKey) {
            do {
                tasks = try JSONDecoder().decode([TodoTask].self, from: data)
            } catch {
                print("Error loading tasks: \(error)")
                tasks = []
            }
        }
    }
    
    private func notifyTasksUpdated() {
        NotificationCenter.default.post(name: .tasksDidUpdate, object: nil)
    }
}

extension Notification.Name {
    static let tasksDidUpdate = Notification.Name("tasksDidUpdate")
} 