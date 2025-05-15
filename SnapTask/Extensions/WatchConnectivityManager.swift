import Foundation
import WatchConnectivity

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
    }
    
    func sendTasksToWatch(tasks: [TodoTask]) {
        guard session.activationState == .activated, session.isReachable else {
            print("Watch is not reachable")
            return
        }
        
        do {
            let data = try JSONEncoder().encode(tasks)
            session.sendMessageData(data, replyHandler: nil) { error in
                print("Error sending tasks to Watch: \(error.localizedDescription)")
            }
        } catch {
            print("Error encoding tasks: \(error.localizedDescription)")
        }
    }
    
    func sendTaskToWatch(task: TodoTask) {
        guard session.activationState == .activated, session.isReachable else {
            print("Watch is not reachable")
            return
        }
        
        do {
            let taskData = try JSONEncoder().encode(task)
            let message: [String: Any] = [
                "type": "taskUpdate",
                "task": taskData
            ]
            
            session.sendMessage(message, replyHandler: nil) { error in
                print("Error sending task to Watch: \(error.localizedDescription)")
            }
        } catch {
            print("Error encoding task: \(error.localizedDescription)")
        }
    }
    
    func updateWatchContext() {
        guard session.activationState == .activated else {
            return
        }
        
        do {
            let tasks = TaskManager.shared.tasks
            let tasksData = try JSONEncoder().encode(tasks)
            
            let contextInfo: [String: Any] = [
                "tasksUpdated": Date().timeIntervalSince1970,
                "tasksCount": tasks.count
            ]
            
            session.transferUserInfo(contextInfo)
            
            // Si el reloj está alcanzable, envía las tareas directamente
            if session.isReachable {
                sendTasksToWatch(tasks: tasks)
            }
        } catch {
            print("Error updating watch context: \(error.localizedDescription)")
        }
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        // Necesario para iOS
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        // Necesario para iOS, reactivar la sesión
        session.activate()
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            
            // Si el reloj acaba de volverse alcanzable, actualiza su contexto
            if session.isReachable {
                self.updateWatchContext()
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        if let type = message["type"] as? String {
            switch type {
            case "requestTasks":
                // El reloj solicitó tareas, envíalas
                do {
                    let tasks = TaskManager.shared.tasks
                    let tasksData = try JSONEncoder().encode(tasks)
                    replyHandler(["tasks": tasksData])
                } catch {
                    print("Error encoding tasks for watch: \(error.localizedDescription)")
                    replyHandler([:])
                }
                
            case "taskCompletion":
                // El reloj informó una actualización de finalización de tarea
                if let taskIdString = message["taskId"] as? String,
                   let taskId = UUID(uuidString: taskIdString),
                   let isCompleted = message["isCompleted"] as? Bool,
                   let dateValue = message["date"] as? TimeInterval {
                    
                    let date = Date(timeIntervalSince1970: dateValue)
                    
                    DispatchQueue.main.async {
                        TaskManager.shared.toggleTaskCompletion(taskId, on: date)
                    }
                    
                    replyHandler(["success": true])
                } else {
                    replyHandler(["success": false])
                }
                
            default:
                replyHandler([:])
            }
        } else {
            replyHandler([:])
        }
    }
} 