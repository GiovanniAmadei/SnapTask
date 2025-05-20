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