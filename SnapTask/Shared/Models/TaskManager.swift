import Foundation
import Combine
import WatchConnectivity

class TaskManager: ObservableObject, WCSessionDelegate {
    static let shared = TaskManager()
    
    @Published private(set) var tasks: [TodoTask] = []
    private let tasksKey = "savedTasks"
    private var session: WCSession?
    
    init() {
        loadTasks()
        setupWatchConnectivity()
    }
    
    private func setupWatchConnectivity() {
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }
    
    func addTask(_ task: TodoTask) {
        tasks.append(task)
        saveTasks()
        objectWillChange.send()
    }
    
    func updateTask(_ task: TodoTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
            saveTasks()
            objectWillChange.send()
        }
    }
    
    func removeTask(_ task: TodoTask) {
        tasks.removeAll { $0.id == task.id }
        saveTasks()
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
            objectWillChange.send()
        }
    }
    
    func toggleSubtask(taskId: UUID, subtaskId: UUID, on date: Date = Date()) {
        if let taskIndex = tasks.firstIndex(where: { $0.id == taskId }) {
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
            saveTasks()
            objectWillChange.send()
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
    
    // WCSessionDelegate methods
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed with error: \(error.localizedDescription)")
            return
        }
        print("WCSession activated successfully")
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
    
    // Handle received messages
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // Handle messages from counterpart app
    }
}

extension Notification.Name {
    static let tasksDidUpdate = Notification.Name("tasksDidUpdate")
} 