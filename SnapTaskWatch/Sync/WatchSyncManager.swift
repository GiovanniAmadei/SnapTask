import Foundation
import WatchConnectivity
import Combine

/// Manages dual-mode synchronization: Bluetooth (WCSession) when iPhone is connected,
/// CloudKit when iPhone is not reachable
@MainActor
class WatchSyncManager: NSObject, ObservableObject {
    static let shared = WatchSyncManager()
    
    // MARK: - Published State
    @Published var tasks: [TodoTask] = []
    @Published var categories: [Category] = []
    @Published var rewards: [Reward] = []
    @Published var totalPoints: Int = 0
    @Published var syncStatus: SyncStatus = .idle
    @Published var isPhoneReachable: Bool = false
    @Published var lastSyncDate: Date?
    
    enum SyncStatus: Equatable {
        case idle
        case syncing
        case success
        case error(String)
        
        var description: String {
            switch self {
            case .idle: return "Idle"
            case .syncing: return "Syncing..."
            case .success: return "Synced"
            case .error(let msg): return msg
            }
        }
        
        var icon: String {
            switch self {
            case .idle: return "arrow.triangle.2.circlepath"
            case .syncing: return "arrow.triangle.2.circlepath"
            case .success: return "checkmark.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            }
        }
    }
    
    // MARK: - Managers
    private let connectivityManager = WatchConnectivityManager()
    private let cloudKitManager = WatchCloudKitManager()
    
    // MARK: - Local Storage Keys
    private let tasksKey = "watch_tasks"
    private let categoriesKey = "watch_categories"
    private let rewardsKey = "watch_rewards"
    private let pointsKey = "watch_total_points"
    private let lastSyncKey = "watch_last_sync"
    
    // MARK: - Initialization
    private override init() {
        super.init()
        loadLocalData()
        setupConnectivity()
        
        // Initial sync
        Task {
            await syncNow()
        }
    }
    
    // MARK: - Setup
    private func setupConnectivity() {
        connectivityManager.onDataReceived = { [weak self] data in
            Task { @MainActor in
                self?.handleReceivedData(data)
            }
        }
        
        connectivityManager.onFileReceived = { [weak self] payload in
            Task { @MainActor in
                self?.handleSyncPayload(payload)
            }
        }
        
        connectivityManager.onReachabilityChanged = { [weak self] reachable in
            Task { @MainActor in
                self?.isPhoneReachable = reachable
                if reachable {
                    // Phone just became reachable, sync immediately
                    await self?.syncNow()
                }
            }
        }
        
        cloudKitManager.onDataUpdated = { [weak self] tasks, categories, rewards, points in
            Task { @MainActor in
                self?.updateData(tasks: tasks, categories: categories, rewards: rewards, points: points)
            }
        }
    }
    
    private func handleSyncPayload(_ payload: WatchSyncPayload) {
        print("⌚ Processing sync payload: \(payload.tasks.count) tasks")
        // Merge tasks by lastModifiedDate to preserve newer local/offline edits
        mergeIncomingTasks(payload.tasks)
        self.categories = payload.categories
        self.rewards = payload.rewards
        self.totalPoints = payload.totalPoints
        saveLocalData()
        syncStatus = .success
        lastSyncDate = Date()
        print("⌚ Sync payload processed successfully")
    }
    
    // MARK: - Public API
    func syncNow() async {
        guard syncStatus != .syncing else { return }
        
        syncStatus = .syncing
        
        do {
            if connectivityManager.isReachable {
                // Use Bluetooth sync via WCSession
                try await connectivityManager.requestFullSync()
            } else {
                // Fallback to CloudKit
                try await cloudKitManager.performSync()
            }
            
            syncStatus = .success
            lastSyncDate = Date()
            saveLastSyncDate()
        } catch {
            syncStatus = .error(error.localizedDescription)
        }
    }
    
    func forceSync() async {
        syncStatus = .idle
        await syncNow()
    }
    
    // MARK: - Task Operations
    func toggleTaskCompletion(_ task: TodoTask, on date: Date = Date()) {
        guard var updatedTask = tasks.first(where: { $0.id == task.id }) else { return }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        var completion = updatedTask.completions[startOfDay] ?? TaskCompletion()
        completion.isCompleted.toggle()
        completion.completionDate = completion.isCompleted ? Date() : nil
        updatedTask.completions[startOfDay] = completion
        updatedTask.lastModifiedDate = Date()
        
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = updatedTask
        }
        
        saveLocalData()
        sendTaskUpdate(updatedTask)
    }
    
    func toggleSubtaskCompletion(_ task: TodoTask, subtaskId: UUID, on date: Date = Date()) {
        guard var updatedTask = tasks.first(where: { $0.id == task.id }) else { return }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        var completion = updatedTask.completions[startOfDay] ?? TaskCompletion()
        
        if completion.completedSubtasks.contains(subtaskId) {
            completion.completedSubtasks.remove(subtaskId)
        } else {
            completion.completedSubtasks.insert(subtaskId)
        }
        
        updatedTask.completions[startOfDay] = completion
        updatedTask.lastModifiedDate = Date()
        
        // Update subtask state
        if let subtaskIndex = updatedTask.subtasks.firstIndex(where: { $0.id == subtaskId }) {
            updatedTask.subtasks[subtaskIndex].isCompleted = completion.completedSubtasks.contains(subtaskId)
        }
        
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = updatedTask
        }
        
        saveLocalData()
        sendTaskUpdate(updatedTask)
    }
    
    func createTask(_ task: TodoTask) {
        var newTask = task
        newTask.lastModifiedDate = Date()
        newTask.creationDate = Date()
        tasks.append(newTask)
        saveLocalData()
        sendTaskUpdate(newTask)
        print("⌚ Created task: \(newTask.name), category: \(newTask.category?.name ?? "none"), lastModified: \(newTask.lastModifiedDate)")
    }
    
    func updateTask(_ task: TodoTask) {
        var updatedTask = task
        updatedTask.lastModifiedDate = Date()
        
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = updatedTask
        }
        
        saveLocalData()
        sendTaskUpdate(updatedTask)
    }
    
    func deleteTask(_ task: TodoTask) {
        tasks.removeAll { $0.id == task.id }
        saveLocalData()
        sendTaskDeletion(task.id)
    }
    
    // MARK: - Reward Operations
    func redeemReward(_ reward: Reward) {
        guard var updatedReward = rewards.first(where: { $0.id == reward.id }) else { return }
        guard totalPoints >= reward.pointsCost else { return }
        
        updatedReward.redemptions.append(Date())
        updatedReward.lastModifiedDate = Date()
        
        if let index = rewards.firstIndex(where: { $0.id == reward.id }) {
            rewards[index] = updatedReward
        }
        
        totalPoints -= reward.pointsCost
        
        saveLocalData()
        sendRewardRedemption(updatedReward)
    }
    
    func createReward(_ reward: Reward) {
        rewards.append(reward)
        saveLocalData()
        sendRewardUpdate(reward)
    }
    
    func updateReward(_ reward: Reward) {
        var updatedReward = reward
        updatedReward.lastModifiedDate = Date()
        
        if let index = rewards.firstIndex(where: { $0.id == reward.id }) {
            rewards[index] = updatedReward
        }
        
        saveLocalData()
        sendRewardUpdate(updatedReward)
    }
    
    func deleteReward(_ reward: Reward) {
        rewards.removeAll { $0.id == reward.id }
        saveLocalData()
        sendRewardDeletion(reward.id)
    }
    
    // MARK: - Tracking Session
    func saveTrackingSession(_ session: TrackingSession) {
        sendTrackingSession(session)
    }
    
    // MARK: - Private Methods
    private func handleReceivedData(_ data: [String: Any]) {
        print("⌚ handleReceivedData called with keys: \(data.keys)")
        
        // Try base64 encoded format first (new format), then fall back to Data format (legacy)
        if let tasksBase64 = data["tasksBase64"] as? String,
           let tasksData = Data(base64Encoded: tasksBase64) {
            print("⌚ Found tasks base64 data: \(tasksData.count) bytes")
            do {
                let decodedTasks = try JSONDecoder().decode([TodoTask].self, from: tasksData)
                mergeIncomingTasks(decodedTasks)
                print("⌚ Decoded & merged \(decodedTasks.count) tasks")
            } catch {
                print("⌚ Failed to decode tasks: \(error)")
            }
        } else if let tasksData = data["tasks"] as? Data {
            // Legacy format
            print("⌚ Found tasks data (legacy): \(tasksData.count) bytes")
            do {
                let decodedTasks = try JSONDecoder().decode([TodoTask].self, from: tasksData)
                mergeIncomingTasks(decodedTasks)
                print("⌚ Decoded & merged \(decodedTasks.count) tasks")
            } catch {
                print("⌚ Failed to decode tasks: \(error)")
            }
        } else {
            print("⌚ No tasks data in payload")
        }
        
        // Categories
        if let categoriesBase64 = data["categoriesBase64"] as? String,
           let categoriesData = Data(base64Encoded: categoriesBase64) {
            do {
                let decodedCategories = try JSONDecoder().decode([Category].self, from: categoriesData)
                self.categories = decodedCategories
                print("⌚ Decoded \(decodedCategories.count) categories")
            } catch {
                print("⌚ Failed to decode categories: \(error)")
            }
        } else if let categoriesData = data["categories"] as? Data {
            do {
                let decodedCategories = try JSONDecoder().decode([Category].self, from: categoriesData)
                self.categories = decodedCategories
                print("⌚ Decoded \(decodedCategories.count) categories")
            } catch {
                print("⌚ Failed to decode categories: \(error)")
            }
        }
        
        // Rewards
        if let rewardsBase64 = data["rewardsBase64"] as? String,
           let rewardsData = Data(base64Encoded: rewardsBase64) {
            do {
                let decodedRewards = try JSONDecoder().decode([Reward].self, from: rewardsData)
                self.rewards = decodedRewards
                print("⌚ Decoded \(decodedRewards.count) rewards")
            } catch {
                print("⌚ Failed to decode rewards: \(error)")
            }
        } else if let rewardsData = data["rewards"] as? Data {
            do {
                let decodedRewards = try JSONDecoder().decode([Reward].self, from: rewardsData)
                self.rewards = decodedRewards
                print("⌚ Decoded \(decodedRewards.count) rewards")
            } catch {
                print("⌚ Failed to decode rewards: \(error)")
            }
        }
        
        if let points = data["totalPoints"] as? Int {
            self.totalPoints = points
            print("⌚ Set totalPoints: \(points)")
        }
        
        saveLocalData()
        syncStatus = .success
        lastSyncDate = Date()
        print("⌚ Sync completed successfully")
    }

    /// Merge incoming tasks with local ones preferring the most recent by lastModifiedDate
    private func mergeIncomingTasks(_ incoming: [TodoTask]) {
        var map = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        for t in incoming {
            if let local = map[t.id] {
                let localDate = local.lastModifiedDate ?? .distantPast
                let incomingDate = t.lastModifiedDate ?? .distantPast
                if incomingDate > localDate {
                    map[t.id] = t
                }
            } else {
                map[t.id] = t
            }
        }
        self.tasks = Array(map.values)
            .sorted { ($0.lastModifiedDate ?? .distantPast) > ($1.lastModifiedDate ?? .distantPast) }
    }
    
    private func updateData(tasks: [TodoTask], categories: [Category], rewards: [Reward], points: Int) {
        self.tasks = tasks
        self.categories = categories
        self.rewards = rewards
        self.totalPoints = points
        saveLocalData()
    }
    
    private func sendTaskUpdate(_ task: TodoTask) {
        guard let data = try? JSONEncoder().encode(task) else {
            print("⌚ ERROR: Failed to encode task: \(task.name)")
            return
        }
        
        // Convert to base64 for WCSession compatibility
        let base64String = data.base64EncodedString()
        
        print("⌚ Sending task: \(task.name), category: \(task.category?.name ?? "none"), categoryId: \(task.category?.id.uuidString ?? "nil"), bytes: \(data.count)")
        
        if connectivityManager.isReachable {
            connectivityManager.sendMessage(["action": "updateTask", "taskBase64": base64String])
            print("⌚ Sent task update to iPhone: \(task.name)")
        } else {
            connectivityManager.transferUserInfo(["action": "updateTask", "taskBase64": base64String])
            print("⌚ Queued task update via transferUserInfo: \(task.name)")
        }
    }
    
    private func sendTaskDeletion(_ taskId: UUID) {
        if connectivityManager.isReachable {
            connectivityManager.sendMessage(["action": "deleteTask", "taskId": taskId.uuidString])
        } else {
            connectivityManager.transferUserInfo(["action": "deleteTask", "taskId": taskId.uuidString])
            print("⌚ Queued task deletion via transferUserInfo: \(taskId)")
        }
    }
    
    private func sendRewardUpdate(_ reward: Reward) {
        guard let data = try? JSONEncoder().encode(reward) else { return }
        let base64String = data.base64EncodedString()
        
        if connectivityManager.isReachable {
            connectivityManager.sendMessage(["action": "updateReward", "rewardBase64": base64String])
            print("⌚ Sent reward update to iPhone: \(reward.name)")
        } else {
            connectivityManager.transferUserInfo(["action": "updateReward", "rewardBase64": base64String])
            print("⌚ Queued reward update via transferUserInfo: \(reward.name)")
        }
    }
    
    private func sendRewardRedemption(_ reward: Reward) {
        guard let data = try? JSONEncoder().encode(reward) else { return }
        let base64String = data.base64EncodedString()
        
        if connectivityManager.isReachable {
            connectivityManager.sendMessage(["action": "redeemReward", "rewardBase64": base64String])
            print("⌚ Sent reward redemption to iPhone: \(reward.name)")
        } else {
            connectivityManager.transferUserInfo(["action": "redeemReward", "rewardBase64": base64String])
            print("⌚ Queued reward redemption via transferUserInfo: \(reward.name)")
        }
    }
    
    private func sendRewardDeletion(_ rewardId: UUID) {
        if connectivityManager.isReachable {
            connectivityManager.sendMessage(["action": "deleteReward", "rewardId": rewardId.uuidString])
            print("⌚ Sent reward deletion to iPhone")
        } else {
            Task {
                try? await cloudKitManager.deleteReward(rewardId)
            }
        }
    }
    
    private func sendTrackingSession(_ session: TrackingSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        let base64String = data.base64EncodedString()
        
        if connectivityManager.isReachable {
            connectivityManager.sendMessage(["action": "saveTrackingSession", "sessionBase64": base64String])
            print("⌚ Sent tracking session to iPhone")
        } else {
            connectivityManager.transferUserInfo(["action": "saveTrackingSession", "sessionBase64": base64String])
            print("⌚ Queued tracking session via transferUserInfo")
        }
    }
    
    // MARK: - Local Storage
    private func loadLocalData() {
        let defaults = UserDefaults.standard
        
        if let tasksData = defaults.data(forKey: tasksKey),
           let decodedTasks = try? JSONDecoder().decode([TodoTask].self, from: tasksData) {
            self.tasks = decodedTasks
        }
        
        if let categoriesData = defaults.data(forKey: categoriesKey),
           let decodedCategories = try? JSONDecoder().decode([Category].self, from: categoriesData) {
            self.categories = decodedCategories
        }
        
        if let rewardsData = defaults.data(forKey: rewardsKey),
           let decodedRewards = try? JSONDecoder().decode([Reward].self, from: rewardsData) {
            self.rewards = decodedRewards
        }
        
        self.totalPoints = defaults.integer(forKey: pointsKey)
        
        if let lastSync = defaults.object(forKey: lastSyncKey) as? Date {
            self.lastSyncDate = lastSync
        }
    }
    
    private func saveLocalData() {
        let defaults = UserDefaults.standard
        
        if let tasksData = try? JSONEncoder().encode(tasks) {
            defaults.set(tasksData, forKey: tasksKey)
        }
        
        if let categoriesData = try? JSONEncoder().encode(categories) {
            defaults.set(categoriesData, forKey: categoriesKey)
        }
        
        if let rewardsData = try? JSONEncoder().encode(rewards) {
            defaults.set(rewardsData, forKey: rewardsKey)
        }
        
        defaults.set(totalPoints, forKey: pointsKey)
    }
    
    private func saveLastSyncDate() {
        UserDefaults.standard.set(lastSyncDate, forKey: lastSyncKey)
    }
    
    // MARK: - Nonisolated Access for Complications
    /// Returns tasks from UserDefaults for use in complications (nonisolated context)
    nonisolated static func getTasksForComplications() -> [TodoTask] {
        let defaults = UserDefaults.standard
        guard let tasksData = defaults.data(forKey: "watch_tasks"),
              let decodedTasks = try? JSONDecoder().decode([TodoTask].self, from: tasksData) else {
            return []
        }
        return decodedTasks
    }
}
