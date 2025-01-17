import Foundation
import WatchConnectivity
import Combine

class WatchTaskManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchTaskManager()
    
    @Published private(set) var tasks: [TodoTask] = []
    private let tasksKey = "watchSavedTasks"
    private var session: WCSession
    
    init(session: WCSession = .default) {
        self.session = session
        super.init()
        setupWatchConnectivity()
        loadLocalTasks()
    }
    
    private func setupWatchConnectivity() {
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }
    
    // MARK: - Task Management
    
    func addTask(_ task: TodoTask) {
        DispatchQueue.main.async {
            self.tasks.append(task)
            self.saveLocalTasks()
        }
    }
    
    func updateTask(_ task: TodoTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
            saveLocalTasks()
        }
    }
    
    func removeTask(_ task: TodoTask) {
        tasks.removeAll { $0.id == task.id }
        saveLocalTasks()
    }
    
    // MARK: - Local Storage
    
    private func loadLocalTasks() {
        if let data = UserDefaults.standard.data(forKey: tasksKey) {
            do {
                tasks = try JSONDecoder().decode([TodoTask].self, from: data)
            } catch {
                print("Error loading watch tasks: \(error)")
                tasks = []
            }
        }
    }
    
    private func saveLocalTasks() {
        do {
            let data = try JSONEncoder().encode(tasks)
            UserDefaults.standard.set(data, forKey: tasksKey)
        } catch {
            print("Error saving watch tasks: \(error)")
        }
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed with error: \(error.localizedDescription)")
        }
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {}
    #endif
}