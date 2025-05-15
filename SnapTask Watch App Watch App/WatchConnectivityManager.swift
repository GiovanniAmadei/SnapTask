import Foundation
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    private let session = WCSession.default
    @Published var isReachable = false
    @Published var receivedTasks: [TodoTask] = []
    
    private override init() {
        super.init()
        
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }
    
    func sendTasksToiOS(tasks: [TodoTask]) {
        guard session.activationState == .activated else {
            print("WCSession not activated")
            return
        }
        
        do {
            let data = try JSONEncoder().encode(tasks)
            session.sendMessageData(data, replyHandler: nil) { error in
                print("Error sending tasks to iOS: \(error.localizedDescription)")
            }
        } catch {
            print("Error encoding tasks: \(error.localizedDescription)")
        }
    }
    
    func sendCompletionUpdate(taskId: UUID, isCompleted: Bool, date: Date) {
        guard session.activationState == .activated else {
            print("WCSession not activated")
            return
        }
        
        let message: [String: Any] = [
            "type": "taskCompletion",
            "taskId": taskId.uuidString,
            "isCompleted": isCompleted,
            "date": date.timeIntervalSince1970
        ]
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("Error sending completion update: \(error.localizedDescription)")
        }
    }
    
    func requestTasksFromiOS() {
        guard session.activationState == .activated else {
            print("WCSession not activated")
            return
        }
        
        let message = ["type": "requestTasks"]
        session.sendMessage(message, replyHandler: { [weak self] reply in
            if let tasksData = reply["tasks"] as? Data {
                do {
                    let tasks = try JSONDecoder().decode([TodoTask].self, from: tasksData)
                    DispatchQueue.main.async {
                        self?.receivedTasks = tasks
                        // Update the TaskManager with the new tasks
                        TaskManager.shared.updateAllTasks(tasks)
                    }
                } catch {
                    print("Error decoding received tasks: \(error.localizedDescription)")
                }
            }
        }) { error in
            print("Error requesting tasks: \(error.localizedDescription)")
        }
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
        
        if activationState == .activated {
            // Request tasks as soon as the session is activated
            DispatchQueue.main.async {
                self.requestTasksFromiOS()
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        do {
            let receivedTasks = try JSONDecoder().decode([TodoTask].self, from: messageData)
            DispatchQueue.main.async {
                TaskManager.shared.updateAllTasks(receivedTasks)
            }
        } catch {
            print("Error decoding received tasks: \(error.localizedDescription)")
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let type = message["type"] as? String {
            switch type {
            case "taskUpdate":
                if let taskData = message["task"] as? Data {
                    do {
                        let task = try JSONDecoder().decode(TodoTask.self, from: taskData)
                        DispatchQueue.main.async {
                            TaskManager.shared.updateTask(task)
                        }
                    } catch {
                        print("Error decoding task: \(error.localizedDescription)")
                    }
                }
            default:
                break
            }
        }
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
} 