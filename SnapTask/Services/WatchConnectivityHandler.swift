import Foundation
import WatchConnectivity
import Combine

// MARK: - Sync Payload Model
struct WatchSyncPayload: Codable {
    let tasks: [TodoTask]
    let categories: [Category]
    let rewards: [Reward]
    let totalPoints: Int
}

/// Handles communication with Apple Watch via WCSession
/// This runs on the iOS app side to respond to Watch requests
@MainActor
class WatchConnectivityHandler: NSObject, ObservableObject {
    static let shared = WatchConnectivityHandler()
    
    @Published var isWatchReachable: Bool = false
    @Published var isWatchPaired: Bool = false
    @Published var isWatchAppInstalled: Bool = false
    
    private var session: WCSession?
    private var cancellables = Set<AnyCancellable>()
    
    private override init() {
        super.init()
        
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
        
        setupObservers()
    }
    
    private func setupObservers() {
        // Sync to Watch when tasks change
        NotificationCenter.default.publisher(for: Notification.Name("tasksDidUpdate"))
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.sendFullSyncToWatch()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Send Data to Watch
    
    /// Send full sync data to Watch using file transfer for reliability
    func sendFullSyncToWatch() {
        guard let session = session, session.activationState == .activated else {
            print("📱 WCSession not activated")
            return
        }
        
        // Filter tasks to reduce size
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let relevantTasks = TaskManager.shared.tasks.filter { task in
            if task.recurrence != nil {
                return true
            }
            let taskDate = calendar.startOfDay(for: task.startTime)
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: today)!
            let weekAhead = calendar.date(byAdding: .day, value: 7, to: today)!
            return taskDate >= weekAgo && taskDate <= weekAhead
        }
        
        // Create sync data and write to temp file
        let syncData = WatchSyncPayload(
            tasks: relevantTasks,
            categories: CategoryManager.shared.categories,
            rewards: RewardManager.shared.rewards,
            totalPoints: RewardManager.shared.totalPoints()
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(syncData)
            
            // Write to temp file
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("watchSync_\(UUID().uuidString).json")
            try jsonData.write(to: tempURL)
            
            // Transfer file to Watch
            session.transferFile(tempURL, metadata: ["type": "fullSync"])
            print("📱 Transferring sync file to Watch (\(jsonData.count) bytes, \(relevantTasks.count) tasks)")
            
        } catch {
            print("📱 Failed to create sync file: \(error.localizedDescription)")
        }
    }
    
    /// Send updated task to Watch
    func sendTaskUpdate(_ task: TodoTask) {
        guard let session = session, session.isReachable else { return }
        guard let taskData = try? JSONEncoder().encode(task) else { return }
        
        session.sendMessage([
            "action": "taskUpdated",
            "task": taskData
        ], replyHandler: nil, errorHandler: nil)
    }
    
    /// Send updated reward to Watch
    func sendRewardUpdate(_ reward: Reward) {
        guard let session = session, session.isReachable else { return }
        guard let rewardData = try? JSONEncoder().encode(reward) else { return }
        
        session.sendMessage([
            "action": "rewardUpdated",
            "reward": rewardData
        ], replyHandler: nil, errorHandler: nil)
    }
    
    /// Send points update to Watch
    func sendPointsUpdate(_ points: Int) {
        guard let session = session, session.isReachable else { return }
        
        session.sendMessage([
            "action": "pointsUpdated",
            "totalPoints": points
        ], replyHandler: nil, errorHandler: nil)
    }
    
    // MARK: - Message Handlers (called on MainActor)
    
    private func handleFullSyncRequest(replyHandler: (([String: Any]) -> Void)?) {
        // Reply immediately with lightweight ACK
        replyHandler?(["status": "ok"])
        
        // Send data via file transfer
        sendFullSyncToWatch()
    }
    
    private func handleTaskUpdate(_ message: [String: Any]) {
        // Try base64 format first (new), then legacy Data format
        var taskData: Data?
        
        if let base64String = message["taskBase64"] as? String {
            taskData = Data(base64Encoded: base64String)
        } else if let data = message["task"] as? Data {
            taskData = data
        }
        
        guard let data = taskData,
              let task = try? JSONDecoder().decode(TodoTask.self, from: data) else {
            print("📱 Failed to decode task from Watch")
            return
        }
        
        // Apply incoming task from Watch as an upsert (create if missing, replace if exists)
        TaskManager.shared.upsertTaskFromRemote(task)
        print("📱 Task upserted from Watch: \(task.name)")
    }
    
    private func handleTaskDeletion(_ message: [String: Any]) {
        guard let taskIdString = message["taskId"] as? String,
              let taskId = UUID(uuidString: taskIdString) else {
            return
        }
        
        if let task = TaskManager.shared.tasks.first(where: { $0.id == taskId }) {
            Task {
                await TaskManager.shared.removeTask(task)
            }
            print("📱 Task deleted from Watch: \(task.name)")
        }
    }
    
    private func handleRewardUpdate(_ message: [String: Any]) {
        // Try base64 format first (new), then legacy Data format
        var rewardData: Data?
        
        if let base64String = message["rewardBase64"] as? String {
            rewardData = Data(base64Encoded: base64String)
        } else if let data = message["reward"] as? Data {
            rewardData = data
        }
        
        guard let data = rewardData,
              let reward = try? JSONDecoder().decode(Reward.self, from: data) else {
            print("📱 Failed to decode reward from Watch")
            return
        }
        
        // Use RewardManager's update method
        RewardManager.shared.updateReward(reward)
        
        print("📱 Reward updated from Watch: \(reward.name)")
    }
    
    private func handleRewardRedemption(_ message: [String: Any]) {
        // Try base64 format first (new), then legacy Data format
        var rewardData: Data?
        
        if let base64String = message["rewardBase64"] as? String {
            rewardData = Data(base64Encoded: base64String)
        } else if let data = message["reward"] as? Data {
            rewardData = data
        }
        
        guard let data = rewardData,
              let reward = try? JSONDecoder().decode(Reward.self, from: data) else {
            print("📱 Failed to decode reward from Watch")
            return
        }
        
        // Use RewardManager's redeem method
        RewardManager.shared.redeemReward(reward)
        print("📱 Reward redeemed from Watch: \(reward.name)")
    }
    
    private func handleRewardDeletion(_ message: [String: Any]) {
        guard let rewardIdString = message["rewardId"] as? String,
              let rewardId = UUID(uuidString: rewardIdString) else {
            return
        }
        
        if let reward = RewardManager.shared.rewards.first(where: { $0.id == rewardId }) {
            RewardManager.shared.removeReward(reward)
            print("📱 Reward deleted from Watch: \(reward.name)")
        }
    }
    
    private func handleTrackingSession(_ message: [String: Any]) {
        // Try base64 format first (new), then legacy Data format
        var sessionData: Data?
        
        if let base64String = message["sessionBase64"] as? String {
            sessionData = Data(base64Encoded: base64String)
        } else if let data = message["session"] as? Data {
            sessionData = data
        }
        
        guard let data = sessionData,
              let trackingSession = try? JSONDecoder().decode(TrackingSession.self, from: data) else {
            print("📱 Failed to decode tracking session from Watch")
            return
        }
        
        TaskManager.shared.saveTrackingSession(trackingSession)
        print("📱 Tracking session saved from Watch: \(trackingSession.taskName ?? "Unknown")")
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityHandler: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isWatchPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isWatchReachable = session.isReachable
        }
        
        if let error = error {
            print("📱 WCSession activation error: \(error.localizedDescription)")
        } else {
            print("📱 WCSession activated: \(activationState.rawValue)")
        }
    }
    
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        print("📱 WCSession became inactive")
    }
    
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        print("📱 WCSession deactivated")
        // Reactivate for switching watches
        session.activate()
    }
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isWatchReachable = session.isReachable
        }
        print("📱 Watch reachability changed: \(session.isReachable)")
    }
    
    // MARK: - Receive Messages from Watch
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleMessageNonisolated(message, replyHandler: nil)
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handleMessageNonisolated(message, replyHandler: replyHandler)
    }
    
    nonisolated private func handleMessageNonisolated(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)?) {
        guard let action = message["action"] as? String else {
            replyHandler?(["error": "No action specified"])
            return
        }
        
        Task { @MainActor in
            switch action {
            case "requestFullSync":
                self.handleFullSyncRequest(replyHandler: replyHandler)
                
            case "updateTask":
                self.handleTaskUpdate(message)
                replyHandler?(["status": "success"])
                
            case "deleteTask":
                self.handleTaskDeletion(message)
                replyHandler?(["status": "success"])
                
            case "updateReward":
                self.handleRewardUpdate(message)
                replyHandler?(["status": "success"])
                
            case "redeemReward":
                self.handleRewardRedemption(message)
                replyHandler?(["status": "success"])
                
            case "deleteReward":
                self.handleRewardDeletion(message)
                replyHandler?(["status": "success"])
                
            case "saveTrackingSession":
                self.handleTrackingSession(message)
                replyHandler?(["status": "success"])
                
            default:
                print("📱 Unknown action from Watch: \(action)")
                replyHandler?(["error": "Unknown action"])
            }
        }
    }
    
    // MARK: - User Info Transfer
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handleMessageNonisolated(userInfo, replyHandler: nil)
    }
    
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handleMessageNonisolated(applicationContext, replyHandler: nil)
    }
    
    // MARK: - File Transfer
    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        if let error = error {
            print("📱 File transfer failed: \(error.localizedDescription)")
        } else {
            print("📱 File transfer completed successfully")
            // Clean up temp file
            try? FileManager.default.removeItem(at: fileTransfer.file.fileURL)
        }
    }
}
