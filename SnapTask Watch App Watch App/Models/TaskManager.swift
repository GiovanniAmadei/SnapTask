import Foundation
import Combine
import CloudKit

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
        
        // Assicurati che la task abbia una data di modifica aggiornata
        var updatedTask = task
        updatedTask.lastModifiedDate = Date()
        
        tasks.append(updatedTask)
        saveTasks()
        notifyTasksUpdated()
        objectWillChange.send()
        
        // Sincronizza con CloudKit
        CloudKitService.shared.saveTask(updatedTask)
        
        // Sincronizza con iOS
        synchronizeWithWatch()
    }
    
    func updateTask(_ updatedTask: TodoTask) {
        if let index = tasks.firstIndex(where: { $0.id == updatedTask.id }) {
            // Preserva i dati di completamento esistenti
            let existingCompletions = tasks[index].completions
            var task = updatedTask
            task.completions = existingCompletions
            
            // Aggiorna la data di modifica
            task.lastModifiedDate = Date()
            
            tasks[index] = task
            
            saveTasks()
            notifyTasksUpdated()
            
            // Sincronizza con CloudKit
            CloudKitService.shared.saveTask(task)
            
            // Sincronizza con iOS
            synchronizeWithWatch()
        }
    }
    
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
    
    func removeTask(_ task: TodoTask) {
        print("TaskManager Watch: Removing task with ID: \(task.id.uuidString)")
        
        // Rimuovi la task dall'array locale
        tasks.removeAll { $0.id == task.id }
        
        // Salva i cambiamenti nel database locale
        saveTasks()
        notifyTasksUpdated()
        objectWillChange.send()
        
        // Elimina la task su CloudKit
        CloudKitService.shared.deleteTask(task)
        
        // Sincronizza con iOS
        synchronizeWithWatch()
        
        // Forza una sincronizzazione per assicurarti che tutti i dispositivi vedano l'eliminazione
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            CloudKitService.shared.syncTasks()
        }
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
            
            // Aggiorna la data di modifica
            task.lastModifiedDate = Date()
            
            tasks[index] = task
            
            // Forza l'aggiornamento
            DispatchQueue.main.async { [weak self] in
                self?.saveTasks()
                self?.notifyTasksUpdated()
                self?.objectWillChange.send()
                
                // Sincronizza con CloudKit
                CloudKitService.shared.saveTask(task)
                
                // Forza una sincronizzazione completa per assicurarsi che tutti i dispositivi vedano l'aggiornamento
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    CloudKitService.shared.syncTasks()
                }
                
                // Sincronizza con iOS
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
        
        // Aggiorna la data di modifica
        task.lastModifiedDate = Date()
        
        tasks[taskIndex] = task
        
        // Ensure UI updates happen on the main thread
        DispatchQueue.main.async { [weak self] in
            self?.saveTasks()
            self?.notifyTasksUpdated()
            self?.objectWillChange.send()
            
            // Sincronizza con CloudKit
            CloudKitService.shared.saveTask(task)
            
            // Forza una sincronizzazione completa per assicurarsi che tutti i dispositivi vedano l'aggiornamento
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                CloudKitService.shared.syncTasks()
            }
            
            // Sincronizza con iOS
            self?.synchronizeWithWatch()
        }
    }
    
    func addTrackedTime(_ duration: TimeInterval, to taskId: UUID, on date: Date = Date()) {
        guard let taskIndex = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        
        var task = tasks[taskIndex]
        let startOfDay = date.startOfDay
        
        // Get or create completion for this date
        var completion = task.completions[startOfDay] ?? TaskCompletion(isCompleted: false, completedSubtasks: [])
        
        // Add tracked time
        completion.trackedTime += duration
        task.completions[startOfDay] = completion
        
        // Update last modified date
        task.lastModifiedDate = Date()
        tasks[taskIndex] = task
        
        // Save changes
        DispatchQueue.main.async { [weak self] in
            self?.saveTasks()
            self?.notifyTasksUpdated()
            self?.objectWillChange.send()
            
            // Sync with CloudKit
            CloudKitService.shared.saveTask(task)
            
            // Sync with iOS
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
        
        // Sincronizza con iOS
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
    
    // Aggiungo un metodo per sincronizzare regolarmente con CloudKit
    func startRegularSync() {
        // Sincronizza all'avvio
        CloudKitService.shared.syncTasks()
        
        // Configura un timer per sincronizzare ogni 30 secondi
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            CloudKitService.shared.syncTasks()
        }
    }
}

extension Notification.Name {
    static let tasksDidUpdate = Notification.Name("tasksDidUpdate")
}
