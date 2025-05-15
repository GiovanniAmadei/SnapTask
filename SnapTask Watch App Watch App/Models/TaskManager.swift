import Foundation
import Combine

class TaskManager: ObservableObject {
    static let shared = TaskManager()
    
    @Published var tasks: [TodoTask] = []
    private let tasksKey = "savedTasks"
    
    init() {
        loadTasks()
    }
    
    func addTask(_ task: TodoTask) {
        print("Adding task: \(task.name)")
        print("Has recurrence: \(task.recurrence != nil)")
        tasks.append(task)
        saveTasks()
        notifyTasksUpdated()
        objectWillChange.send()
        
        // Sincronizar con Apple Watch
        synchronizeWithWatch()
    }
    
    func updateTask(_ updatedTask: TodoTask) {
        if let index = tasks.firstIndex(where: { $0.id == updatedTask.id }) {
            // Preserva i dati di completamento esistenti
            let existingCompletions = tasks[index].completions
            var task = updatedTask
            task.completions = existingCompletions
            tasks[index] = task
            
            saveTasks()
            notifyTasksUpdated()
            
            // Sincronizar con Apple Watch
            synchronizeWithWatch()
        }
    }
    
    func removeTask(_ task: TodoTask) {
        tasks.removeAll { $0.id == task.id }
        saveTasks()
        notifyTasksUpdated()
        objectWillChange.send()
        
        // Sincronizar con Apple Watch
        synchronizeWithWatch()
    }
    
    func toggleTaskCompletion(_ taskId: UUID, on date: Date = Date()) {
        if let index = tasks.firstIndex(where: { $0.id == taskId }) {
            var task = tasks[index]
            let startOfDay = date.startOfDay
            
            // Aggiorna il completion status
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
            
            // Aggiorna completionDates
            if task.completions[startOfDay]?.isCompleted == true {
                if !task.completionDates.contains(startOfDay) {
                    task.completionDates.append(startOfDay)
                }
            } else {
                task.completionDates.removeAll { $0 == startOfDay }
            }
            
            tasks[index] = task
            
            // Forza l'aggiornamento
            DispatchQueue.main.async { [weak self] in
                self?.saveTasks()
                self?.notifyTasksUpdated()
                self?.objectWillChange.send()
                
                // Sincronizar con Apple Watch
                self?.synchronizeWithWatch()
            }
        }
    }
    
    func toggleSubtask(taskId: UUID, subtaskId: UUID, on date: Date = Date()) {
        guard let taskIndex = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        
        var task = tasks[taskIndex]
        let startOfDay = date.startOfDay
        
        var completion = task.completions[startOfDay] ?? TaskCompletion(isCompleted: false, completedSubtasks: [])
        
        if completion.completedSubtasks.contains(subtaskId) {
            completion.completedSubtasks.remove(subtaskId)
        } else {
            completion.completedSubtasks.insert(subtaskId)
        }
        
        task.completions[startOfDay] = completion
        tasks[taskIndex] = task
        
        // Ensure UI updates happen on the main thread
        DispatchQueue.main.async { [weak self] in
            self?.saveTasks()
            self?.notifyTasksUpdated()
            self?.objectWillChange.send()
            
            // Sincronizar con Apple Watch
            self?.synchronizeWithWatch()
        }
    }
    
    func saveTasks() {
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
    
    func notifyTasksUpdated() {
        NotificationCenter.default.post(name: .tasksDidUpdate, object: nil)
    }
    
    // For debugging purposes only
    func resetUserDefaults() {
        UserDefaults.standard.removeObject(forKey: tasksKey)
        loadTasks()
        notifyTasksUpdated()
        objectWillChange.send()
        
        // Sincronizar con Apple Watch
        synchronizeWithWatch()
    }
    
    // Method to send task updates to the iOS app
    func synchronizeWithWatch() {
        WatchConnectivityManager.shared.sendTasksToiOS(tasks: self.tasks)
    }
    
    func isSubtaskCompleted(taskId: UUID, subtaskId: UUID, on date: Date = Date()) -> Bool {
        guard let task = tasks.first(where: { $0.id == taskId }) else { return false }
        let startOfDay = date.startOfDay
        
        if let completion = task.completions[startOfDay] {
            return completion.completedSubtasks.contains(subtaskId)
        }
        return false
    }
}

extension Notification.Name {
    static let tasksDidUpdate = Notification.Name("tasksDidUpdate")
} 