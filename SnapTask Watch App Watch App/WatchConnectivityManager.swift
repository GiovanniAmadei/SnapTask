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
            print("⌚ WCSession not activated")
            return
        }
        
        do {
            let data = try JSONEncoder().encode(tasks)
            
            if session.isReachable {
                session.sendMessageData(data, replyHandler: { reply in
                    print("✅ Tasks sent to iOS successfully")
                }) { error in
                    print("❌ Error sending tasks to iOS: \(error.localizedDescription)")
                }
            } else {
                print("⚠️ iOS not reachable from Watch")
            }
        } catch {
            print("❌ Error encoding tasks: \(error.localizedDescription)")
        }
    }
    
    func sendCompletionUpdate(taskId: UUID, isCompleted: Bool, date: Date) {
        guard session.activationState == .activated else {
            print("⌚ WCSession not activated")
            return
        }
        
        let message: [String: Any] = [
            "type": "taskCompletion",
            "taskId": taskId.uuidString,
            "isCompleted": isCompleted,
            "date": date.timeIntervalSince1970
        ]
        
        if session.isReachable {
            session.sendMessage(message, replyHandler: { reply in
                print("✅ Completion update sent to iOS successfully")
            }) { error in
                print("❌ Error sending completion update: \(error.localizedDescription)")
            }
        } else {
            print("⚠️ iOS not reachable, completion update queued")
        }
    }
    
    func requestTasksFromiOS() {
        guard session.activationState == .activated else {
            print("⌚ WCSession not activated, cannot request tasks")
            return
        }
        
        let message = ["type": "requestTasks"]
        
        if session.isReachable {
            session.sendMessage(message, replyHandler: { [weak self] reply in
                print("⌚ Received response from iOS for task request")
                
                if let error = reply["error"] as? String {
                    print("❌ Error from iOS: \(error)")
                    return
                }
                
                if let tasksData = reply["tasks"] as? Data {
                    do {
                        let tasks = try JSONDecoder().decode([TodoTask].self, from: tasksData)
                        print("✅ Received \(tasks.count) tasks from iOS")
                        
                        DispatchQueue.main.async {
                            self?.receivedTasks = tasks
                            TaskManager.shared.updateAllTasks(tasks)
                        }
                    } catch {
                        print("❌ Error decoding received tasks: \(error.localizedDescription)")
                    }
                } else {
                    print("⚠️ No tasks data in response from iOS")
                }
            }) { error in
                print("❌ Error requesting tasks from iOS: \(error.localizedDescription)")
            }
        } else {
            print("⚠️ iOS not reachable, cannot request tasks")
        }
    }
    
    func forceSync() {
        print("⌚ Forcing sync with iOS...")
        requestTasksFromiOS()
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            print("⌚ WCSession activated with state: \(activationState.rawValue)")
        }
        
        if let error = error {
            print("❌ WCSession activation error: \(error.localizedDescription)")
        }
        
        if activationState == .activated {
            // Request tasks as soon as session is activated
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.requestTasksFromiOS()
            }
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            print("⌚ iOS reachability changed: \(session.isReachable)")
            
            // Request tasks when iOS becomes reachable
            if session.isReachable {
                self.requestTasksFromiOS()
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        print("⌚ Received message data from iOS")
        
        do {
            let receivedTasks = try JSONDecoder().decode([TodoTask].self, from: messageData)
            print("✅ Decoded \(receivedTasks.count) tasks from iOS")
            
            DispatchQueue.main.async {
                TaskManager.shared.updateAllTasks(receivedTasks)
                self.receivedTasks = receivedTasks
                
                print("⌚ Updated TaskManager with \(receivedTasks.count) tasks")
            }
        } catch {
            print("❌ Error decoding received tasks from iOS: \(error.localizedDescription)")
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("⌚ Received message from iOS: \(message)")
        
        if let type = message["type"] as? String {
            switch type {
            case "taskUpdate":
                if let taskData = message["task"] as? Data {
                    do {
                        let task = try JSONDecoder().decode(TodoTask.self, from: taskData)
                        DispatchQueue.main.async {
                            TaskManager.shared.updateTask(task)
                            print("✅ Updated single task from iOS: \(task.name)")
                        }
                    } catch {
                        print("❌ Error decoding task from iOS: \(error.localizedDescription)")
                    }
                }
            default:
                print("⚠️ Unknown message type from iOS: \(type)")
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("⌚ Received application context from iOS: \(applicationContext)")
        
        if let tasksUpdated = applicationContext["tasksUpdated"] as? TimeInterval,
           let tasksCount = applicationContext["tasksCount"] as? Int {
            print("⌚ iOS has \(tasksCount) tasks, updated at \(Date(timeIntervalSince1970: tasksUpdated))")
            
            // Request fresh tasks if the context indicates changes
            DispatchQueue.main.async {
                self.requestTasksFromiOS()
            }
        }
    }
    
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        print("⌚ Received file from iOS: \(file.fileURL)")
        
        if let metadata = file.metadata,
           let type = metadata["type"] as? String,
           type == "tasks" {
            
            do {
                let data = try Data(contentsOf: file.fileURL)
                let tasks = try JSONDecoder().decode([TodoTask].self, from: data)
                
                DispatchQueue.main.async {
                    TaskManager.shared.updateAllTasks(tasks)
                    self.receivedTasks = tasks
                    print("✅ Updated tasks from file transfer: \(tasks.count) tasks")
                }
            } catch {
                print("❌ Error processing file transfer: \(error.localizedDescription)")
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