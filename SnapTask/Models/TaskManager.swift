import Foundation
import Combine
import WatchConnectivity

class TaskManager: ObservableObject {
    static let shared = TaskManager()
    
    @Published private(set) var tasks: [TodoTask] = []
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
        
        // Assicurati che la task venga salvata su CloudKit
        CloudKitService.shared.saveTask(updatedTask)
        
        // Sincronizza con Apple Watch
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
            
            // Sincronizza con Apple Watch
            synchronizeWithWatch()
        }
    }
    
    func updateAllTasks(_ newTasks: [TodoTask]) {
        tasks = newTasks
        saveTasks()
        notifyTasksUpdated()
        objectWillChange.send()
        
        // Sincronizza con Apple Watch
        synchronizeWithWatch()
    }
    
    func removeTask(_ task: TodoTask) {
        print("TaskManager iOS: Removing task with ID: \(task.id.uuidString)")
        
        // Rimuovi la task dall'array locale
        tasks.removeAll { $0.id == task.id }
        
        // Salva i cambiamenti nel database locale
        saveTasks()
        notifyTasksUpdated()
        objectWillChange.send()
        
        // Assicurati che la task venga eliminata su CloudKit
        CloudKitService.shared.deleteTask(task)
        
        // Sincronizza con Apple Watch
        synchronizeWithWatch()
        
        // Forza una sincronizzazione per assicurarti che tutti i dispositivi vedano l'eliminazione
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            CloudKitService.shared.syncTasksSafely()
        }
    }
    
    func toggleTaskCompletion(_ taskId: UUID, on date: Date = Date()) {
        if let index = tasks.firstIndex(where: { $0.id == taskId }) {
            var task = tasks[index]
            let startOfDay = Calendar.current.startOfDay(for: date)
            
            // Get current completion status to determine if we're completing or uncompleting
            let isCompleting: Bool
            if let completion = task.completions[startOfDay] {
                isCompleting = !completion.isCompleted
                task.completions[startOfDay] = TaskCompletion(
                    isCompleted: isCompleting,
                    completedSubtasks: completion.completedSubtasks
                )
            } else {
                isCompleting = true
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
            
            // Handle reward points if applicable
            if task.hasRewardPoints {
                if isCompleting {
                    // Add points when completing task
                    RewardManager.shared.addPoints(task.rewardPoints, on: date)
                } else {
                    // Remove points if uncompleting a previously completed task
                    // Only if it was already completed today
                    if task.completionDates.contains(startOfDay) {
                        RewardManager.shared.addPoints(-task.rewardPoints, on: date)
                    }
                }
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
                    CloudKitService.shared.syncTasksSafely()
                }
                
                // Sincronizza con Apple Watch
                self?.synchronizeWithWatch()
            }
        }
    }
    
    func toggleSubtask(taskId: UUID, subtaskId: UUID, on date: Date = Date()) {
        guard let taskIndex = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        
        var task = tasks[taskIndex]
        let startOfDay = Calendar.current.startOfDay(for: date)
        
        var completion = task.completions[startOfDay] ?? TaskCompletion(isCompleted: false, completedSubtasks: [])
        
        // Determine if we're completing or uncompleting the subtask
        let wasCompleted = completion.completedSubtasks.contains(subtaskId)
        
        if wasCompleted {
            completion.completedSubtasks.remove(subtaskId)
        } else {
            completion.completedSubtasks.insert(subtaskId)
        }
        
        task.completions[startOfDay] = completion
        
        // Handle reward points for subtasks, but only if all subtasks are completed/uncompleted
        // and the task has reward points enabled
        if task.hasRewardPoints && !task.subtasks.isEmpty {
            // Check if all subtasks are now completed
            let allSubtasksCompleted = task.subtasks.allSatisfy { subtask in
                completion.completedSubtasks.contains(subtask.id)
            }
            
            // Check previous completion state
            let wasAllCompleted = task.subtasks.allSatisfy { subtask in
                wasCompleted || completion.completedSubtasks.contains(subtask.id)
            }
            
            // Only award points if this is the transition from incomplete to complete
            if allSubtasksCompleted && !wasAllCompleted {
                RewardManager.shared.addPoints(task.rewardPoints, on: date)
            }
            // Only remove points if this is the transition from complete to incomplete
            else if !allSubtasksCompleted && wasAllCompleted {
                RewardManager.shared.addPoints(-task.rewardPoints, on: date)
            }
        }
        
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
                CloudKitService.shared.syncTasksSafely()
            }
            
            // Sincronizza con Apple Watch
            self?.synchronizeWithWatch()
        }
    }
    
    func syncWithCloudKit() {
        // Sincronizza in modo sicuro tramite proxy
        // CloudKitSyncProxy.shared.syncTasks()
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
    
    // Function to synchronize tasks with Apple Watch
    private func synchronizeWithWatch() {
        let connectivityManager = WatchConnectivityManager.shared
        connectivityManager.updateWatchContext()
    }
    
    // For debugging purposes only
    func resetUserDefaults() {
        UserDefaults.standard.removeObject(forKey: tasksKey)
        loadTasks()
        notifyTasksUpdated()
        objectWillChange.send()
        
        // Sincronizza con CloudKit in modo sicuro
        // CloudKitSyncProxy.shared.syncTasks()
        
        // Sincronizza con Apple Watch
        synchronizeWithWatch()
    }
    
    // Aggiungo un metodo per sincronizzare regolarmente con CloudKit
    func startRegularSync() {
        // Sincronizza all'avvio
        CloudKitService.shared.syncTasksSafely()
        
        // Configura un timer per sincronizzare ogni 30 secondi
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            CloudKitService.shared.syncTasksSafely()
        }
    }
}

extension Notification.Name {
    static let tasksDidUpdate = Notification.Name("tasksDidUpdate")
} 