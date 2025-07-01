import Foundation
import WatchConnectivity

@MainActor
class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    private let session = WCSession.default
    @Published var isReachable = false
    
    private override init() {
        super.init()
        
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
        
        // Listen for task updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(tasksDidUpdate),
            name: Notification.Name("tasksDidUpdate"),
            object: nil
        )
    }
    
    @objc private func tasksDidUpdate() {
        // Automatically send updated tasks to watch when tasks change
        updateWatchContext()
    }
    
    func sendTasksToWatch(tasks: [TodoTask]) {
        guard session.activationState == .activated else {
            print("WCSession not activated, queueing tasks for later")
            // Queue tasks to send when session becomes active
            return
        }
        
        // Try both reachable and background transfer methods
        do {
            let data = try JSONEncoder().encode(tasks)
            
            if session.isReachable {
                // Send immediately if watch is reachable
                session.sendMessageData(data, replyHandler: { reply in
                    print("✅ Tasks sent to Watch successfully via message")
                }) { error in
                    print("❌ Error sending tasks to Watch via message: \(error.localizedDescription)")
                    // Fallback to background transfer
                    self.sendTasksViaBackground(data: data)
                }
            } else {
                // Use background transfer if watch is not reachable
                sendTasksViaBackground(data: data)
            }
        } catch {
            print("❌ Error encoding tasks: \(error.localizedDescription)")
        }
    }
    
    private func sendTasksViaBackground(data: Data) {
        // Use background transfer as fallback
        let file = session.transferFile(
            URL(fileURLWithPath: NSTemporaryDirectory().appending("tasks.json")),
            metadata: ["type": "tasks", "timestamp": Date().timeIntervalSince1970]
        )
        
        do {
            try data.write(to: URL(fileURLWithPath: NSTemporaryDirectory().appending("tasks.json")))
            print("📤 Tasks queued for background transfer to Watch")
        } catch {
            print("❌ Error writing tasks file: \(error.localizedDescription)")
        }
    }
    
    func sendTaskToWatch(task: TodoTask) {
        guard session.activationState == .activated else {
            print("WCSession not activated")
            return
        }
        
        do {
            let taskData = try JSONEncoder().encode(task)
            let message: [String: Any] = [
                "type": "taskUpdate",
                "task": taskData
            ]
            
            if session.isReachable {
                session.sendMessage(message, replyHandler: { reply in
                    print("✅ Task sent to Watch successfully")
                }) { error in
                    print("❌ Error sending task to Watch: \(error.localizedDescription)")
                }
            } else {
                print("⚠️ Watch not reachable, task will be sent via background sync")
            }
        } catch {
            print("❌ Error encoding task: \(error.localizedDescription)")
        }
    }
    
    func updateWatchContext() {
        guard session.activationState == .activated else {
            print("WCSession not activated, cannot update watch context")
            return
        }
        
        let tasks = TaskManager.shared.tasks
        print("📱 Updating watch context with \(tasks.count) tasks")
        
        // Send tasks immediately
        sendTasksToWatch(tasks: tasks)
        
        // Also update application context for background updates
        do {
            let contextInfo: [String: Any] = [
                "tasksUpdated": Date().timeIntervalSince1970,
                "tasksCount": tasks.count
            ]
            
            try session.updateApplicationContext(contextInfo)
            print("📤 Application context updated for Watch")
        } catch {
            print("❌ Error updating watch context: \(error.localizedDescription)")
        }
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            print("📱 WCSession activated with state: \(activationState.rawValue)")
        }
        
        if activationState == .activated {
            // Send current tasks as soon as session is activated
            DispatchQueue.main.async {
                self.updateWatchContext()
            }
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("📱 WCSession became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("📱 WCSession deactivated, reactivating...")
        session.activate()
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            print("📱 Watch reachability changed: \(session.isReachable)")
            
            // Send tasks when watch becomes reachable
            if session.isReachable {
                self.updateWatchContext()
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("📱 Received message from Watch: \(message)")
        
        if let type = message["type"] as? String {
            switch type {
            case "requestTasks":
                // Watch requested tasks, send them
                do {
                    let tasks = TaskManager.shared.tasks
                    let tasksData = try JSONEncoder().encode(tasks)
                    replyHandler(["tasks": tasksData])
                    print("✅ Sent \(tasks.count) tasks to Watch in response to request")
                } catch {
                    print("❌ Error encoding tasks for watch: \(error.localizedDescription)")
                    replyHandler(["error": error.localizedDescription])
                }
                
            case "taskCompletion":
                // Watch reported task completion update
                if let taskIdString = message["taskId"] as? String,
                   let taskId = UUID(uuidString: taskIdString),
                   let isCompleted = message["isCompleted"] as? Bool,
                   let dateValue = message["date"] as? TimeInterval {
                    
                    let date = Date(timeIntervalSince1970: dateValue)
                    
                    DispatchQueue.main.async {
                        TaskManager.shared.toggleTaskCompletion(taskId, on: date)
                        print("✅ Updated task completion from Watch")
                    }
                    
                    replyHandler(["success": true])
                } else {
                    print("❌ Invalid task completion data from Watch")
                    replyHandler(["success": false, "error": "Invalid data"])
                }
                
            default:
                print("⚠️ Unknown message type from Watch: \(type)")
                replyHandler(["error": "Unknown message type"])
            }
        } else {
            print("❌ Invalid message format from Watch")
            replyHandler(["error": "Invalid message format"])
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("📱 Received application context from Watch: \(applicationContext)")
    }
    
    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        if let error = error {
            print("❌ File transfer to Watch failed: \(error.localizedDescription)")
        } else {
            print("✅ File transfer to Watch completed successfully")
        }
    }
}