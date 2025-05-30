import Foundation
import CloudKit
import Combine
import UIKit

@MainActor
class CloudKitService: ObservableObject {
    static let shared = CloudKitService()
    
    // MARK: - Configuration
    private let container: CKContainer
    internal let privateDatabase: CKDatabase
    internal let zoneID: CKRecordZone.ID
    private let recordZone: CKRecordZone
    
    // Record Types
    private let taskRecordType = "TodoTask"
    internal let categoryRecordType = "Category"
    private let rewardRecordType = "Reward"
    private let pointsHistoryRecordType = "PointsHistory"
    private let settingsRecordType = "AppSettings"
    private let deletionMarkerRecordType = "DeletionMarker"
    
    // Subscription IDs
    private let subscriptionID = "SnapTaskZone-changes"
    
    // MARK: - State Management
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    @Published var isSyncing = false
    @Published var isCloudKitEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isCloudKitEnabled, forKey: "cloudkit_sync_enabled")
            if isCloudKitEnabled {
                Task { await initializeCloudKit() }
            }
        }
    }
    
    enum SyncStatus: Equatable {
        case idle
        case syncing
        case success
        case error(String)
        case disabled
        
        var description: String {
            switch self {
            case .idle: return "Ready to sync"
            case .syncing: return "Syncing..."
            case .success: return "Up to date"
            case .error(let message): return message
            case .disabled: return "Sync disabled"
            }
        }
    }
    
    // MARK: - Change Tokens
    private let changeTokenKey = "cloudkit_change_token"
    private var serverChangeToken: CKServerChangeToken? {
        get {
            guard let data = UserDefaults.standard.data(forKey: changeTokenKey) else { return nil }
            return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
        }
        set {
            if let token = newValue {
                let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
                UserDefaults.standard.set(data, forKey: changeTokenKey)
            } else {
                UserDefaults.standard.removeObject(forKey: changeTokenKey)
            }
        }
    }
    
    // MARK: - Sync Control
    private var lastSyncTime: Date = .distantPast
    private let minSyncInterval: TimeInterval = 5.0
    private var activeSyncTask: Task<Void, Never>?
    private var syncRetryCount: Int = 0
    private let maxSyncRetries: Int = 3
    private var lastErrorTime: Date = .distantPast
    
    // MARK: - Deletion Tracking
    struct DeletionTracker: Codable {
        var tasks: Set<String> = []
        var categories: Set<String> = []
        var rewards: Set<String> = []
        var pointsHistory: Set<String> = []
    }
    
    private var deletedItems: DeletionTracker {
        get {
            let data = UserDefaults.standard.data(forKey: "cloudkit_deleted_items")
            guard let data = data else { return DeletionTracker() }
            return (try? JSONDecoder().decode(DeletionTracker.self, from: data)) ?? DeletionTracker()
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            UserDefaults.standard.set(data, forKey: "cloudkit_deleted_items")
        }
    }
    
    // MARK: - Initialization
    private init() {
        container = CKContainer.default()
        privateDatabase = container.privateCloudDatabase
        zoneID = CKRecordZone.ID(zoneName: "SnapTaskZone", ownerName: CKCurrentUserDefaultName)
        recordZone = CKRecordZone(zoneID: zoneID)
        
        // Load sync preference
        isCloudKitEnabled = UserDefaults.standard.bool(forKey: "cloudkit_sync_enabled")
        
        Task {
            if isCloudKitEnabled {
                await initializeCloudKit()
            } else {
                syncStatus = .disabled
            }
        }
    }
    
    // MARK: - CloudKit Setup
    private func initializeCloudKit() async {
        guard isCloudKitEnabled else {
            syncStatus = .disabled
            return
        }
        
        do {
            let accountStatus = try await container.accountStatus()
            
            guard accountStatus == .available else {
                await updateSyncStatus(for: accountStatus)
                return
            }
            
            try await ensureZoneExists()
            await setupSubscription()
            await performFullSync()
            
        } catch {
            await handleSyncError(error)
        }
    }
    
    private func ensureZoneExists() async throws {
        do {
            _ = try await privateDatabase.recordZone(for: zoneID)
            print("✅ Zone exists")
        } catch let error as CKError where error.code == .zoneNotFound {
            print("📦 Creating zone...")
            _ = try await privateDatabase.save(recordZone)
            print("✅ Zone created")
        }
    }
    
    private func setupSubscription() async {
        do {
            // Check if subscription already exists
            let existingSubscriptions = try await privateDatabase.allSubscriptions()
            let hasSubscription = existingSubscriptions.contains { $0.subscriptionID == subscriptionID }
            
            if !hasSubscription {
                let subscription = CKRecordZoneSubscription(zoneID: zoneID, subscriptionID: subscriptionID)
                
                let notificationInfo = CKSubscription.NotificationInfo()
                notificationInfo.shouldSendContentAvailable = true
                subscription.notificationInfo = notificationInfo
                
                _ = try await privateDatabase.save(subscription)
                print("✅ Subscription created")
            } else {
                print("✅ Subscription already exists")
            }
        } catch {
            print("❌ Failed to setup subscription: \(error)")
        }
    }
    
    // MARK: - Public API
    func syncNow() {
        guard isCloudKitEnabled else { return }
        guard canPerformSync() else { return }
        
        activeSyncTask?.cancel()
        activeSyncTask = Task {
            await performFullSync()
        }
    }
    
    func enableCloudKitSync() {
        isCloudKitEnabled = true
    }
    
    func disableCloudKitSync() {
        isCloudKitEnabled = false
        syncStatus = .disabled
        activeSyncTask?.cancel()
    }
    
    // MARK: - Task Operations
    func saveTask(_ task: TodoTask) {
        guard isCloudKitEnabled else { return }
        
        Task {
            do {
                let record = createTaskRecord(from: task)
                _ = try await privateDatabase.save(record)
                print("✅ Task saved: \(task.name)")
            } catch let error as CKError {
                print("❌ CloudKit error saving task: \(error.localizedDescription)")
                await handleCloudKitError(error)
            } catch {
                print("❌ Failed to save task: \(error)")
                await handleSyncError(error)
            }
        }
    }
    
    func deleteTask(_ task: TodoTask) {
        guard isCloudKitEnabled else { return }
        
        markAsDeleted(itemID: task.id.uuidString, type: .task)
        
        Task {
            do {
                let recordID = CKRecord.ID(recordName: task.id.uuidString, zoneID: zoneID)
                _ = try await privateDatabase.deleteRecord(withID: recordID)
                print("✅ Task deleted: \(task.name)")
            } catch let error as CKError {
                if error.code == .unknownItem {
                    print("ℹ️ Task already deleted from CloudKit: \(task.name)")
                } else {
                    print("❌ CloudKit error deleting task: \(error.localizedDescription)")
                    await handleCloudKitError(error)
                }
            } catch {
                print("❌ Failed to delete task: \(error)")
                await handleSyncError(error)
            }
        }
    }
    
    // MARK: - Category Operations
    func saveCategory(_ category: Category) {
        guard isCloudKitEnabled else { return }
        
        Task {
            do {
                let record = createCategoryRecord(from: category)
                _ = try await privateDatabase.save(record)
                print("✅ Category saved: \(category.name)")
            } catch let error as CKError {
                print("❌ CloudKit error saving category: \(error.localizedDescription)")
                await handleCloudKitError(error)
            } catch {
                print("❌ Failed to save category: \(error)")
                await handleSyncError(error)
            }
        }
    }
    
    func deleteCategory(_ category: Category) {
        guard isCloudKitEnabled else { return }
        
        markAsDeleted(itemID: category.id.uuidString, type: .category)
        
        Task {
            do {
                let recordID = CKRecord.ID(recordName: category.id.uuidString, zoneID: zoneID)
                _ = try await privateDatabase.deleteRecord(withID: recordID)
                print("✅ Category deleted: \(category.name)")
            } catch let error as CKError {
                if error.code == .unknownItem {
                    print("ℹ️ Category already deleted from CloudKit: \(category.name)")
                } else {
                    print("❌ CloudKit error deleting category: \(error.localizedDescription)")
                    await handleCloudKitError(error)
                }
            } catch {
                print("❌ Failed to delete category: \(error)")
                await handleSyncError(error)
            }
        }
    }
    
    // MARK: - Reward Operations
    func saveReward(_ reward: Reward) {
        guard isCloudKitEnabled else { return }
        
        Task {
            do {
                let record = createRewardRecord(from: reward)
                _ = try await privateDatabase.save(record)
                print("✅ Reward saved: \(reward.name)")
            } catch {
                print("❌ Failed to save reward: \(error)")
            }
        }
    }
    
    func deleteReward(_ reward: Reward) {
        guard isCloudKitEnabled else { return }
        
        markAsDeleted(itemID: reward.id.uuidString, type: .reward)
        
        Task {
            do {
                let recordID = CKRecord.ID(recordName: reward.id.uuidString, zoneID: zoneID)
                _ = try await privateDatabase.deleteRecord(withID: recordID)
                await saveDeletionMarker(type: "Reward", id: reward.id.uuidString)
                print("✅ Reward deleted: \(reward.name)")
            } catch let error as CKError where error.code == .unknownItem {
                print("ℹ️ Reward already deleted")
            } catch {
                print("❌ Failed to delete reward: \(error)")
            }
        }
    }
    
    // MARK: - Points History Operations
    func savePointsEntry(_ entry: PointsHistory) {
        guard isCloudKitEnabled else { return }
        
        Task {
            do {
                let record = createPointsHistoryRecord(from: entry)
                _ = try await privateDatabase.save(record)
                print("✅ Points entry saved: \(entry.points) points")
            } catch {
                print("❌ Failed to save points entry: \(error)")
            }
        }
    }
    
    func syncPointsHistory(_ history: [Date: Int]) {
        guard isCloudKitEnabled else { return }
        
        Task {
            do {
                var records: [CKRecord] = []
                
                for (date, points) in history {
                    let entry = PointsHistory(date: date, points: points, frequency: .daily)
                    let record = createPointsHistoryRecord(from: entry)
                    records.append(record)
                }
                
                // Batch save for efficiency - reduced size to prevent memory issues
                let batchSize = 50
                for i in stride(from: 0, to: records.count, by: batchSize) {
                    let batch = Array(records[i..<min(i + batchSize, records.count)])
                    let operation = CKModifyRecordsOperation(recordsToSave: batch)
                    _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        operation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
                            if let error = error {
                                continuation.resume(throwing: error)
                            } else {
                                continuation.resume(returning: ())
                            }
                        }
                        privateDatabase.add(operation)
                    }
                }
                
                print("✅ Synced \(records.count) points entries")
            } catch {
                print("❌ Failed to sync points history: \(error)")
            }
        }
    }
    
    // MARK: - Settings Operations
    func saveAppSettings(_ settings: [String: Any]) {
        guard isCloudKitEnabled else { return }
        
        Task {
            do {
                let record = createSettingsRecord(from: settings)
                _ = try await privateDatabase.save(record)
                print("✅ App settings saved")
            } catch {
                print("❌ Failed to save app settings: \(error)")
            }
        }
    }
    
    // MARK: - Sync Implementation
    private func performFullSync() async {
        guard !isSyncing else { return }
        guard isCloudKitEnabled else { return }
        
        isSyncing = true
        syncStatus = .syncing
        lastSyncTime = Date()
        
        defer {
            isSyncing = false
        }
        
        do {
            let changes = try await fetchChanges()
            await processChanges(changes)
            
            syncStatus = .success
            lastSyncDate = Date()
            syncRetryCount = 0 // Reset retry count on success
            print("✅ Full sync completed successfully")
            
        } catch {
            await handleSyncError(error)
        }
    }
    
    private struct SyncChanges {
        var tasks: [TodoTask] = []
        var categories: [Category] = []
        var rewards: [Reward] = []
        var pointsHistory: [PointsHistory] = []
        var settings: [String: Any] = [:]
        var deletedRecordIDs: [CKRecord.ID] = []
    }
    
    private func fetchChanges() async throws -> SyncChanges {
        let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zoneID])
        
        var changes = SyncChanges()
        
        if let token = serverChangeToken {
            operation.configurationsByRecordZoneID = [
                zoneID: CKFetchRecordZoneChangesOperation.ZoneConfiguration(
                    previousServerChangeToken: token
                )
            ]
        }
        
        operation.recordChangedBlock = { [weak self] record in
            guard let self = self else { return }
            
            switch record.recordType {
            case self.taskRecordType:
                if let task = self.createTask(from: record) {
                    changes.tasks.append(task)
                }
            case self.categoryRecordType:
                if let category = self.createCategory(from: record) {
                    changes.categories.append(category)
                }
            case self.rewardRecordType:
                if let reward = self.createReward(from: record) {
                    changes.rewards.append(reward)
                }
            case self.pointsHistoryRecordType:
                if let pointsEntry = self.createPointsHistory(from: record) {
                    changes.pointsHistory.append(pointsEntry)
                }
            case self.settingsRecordType:
                if let settings = self.createSettings(from: record) {
                    changes.settings = settings
                }
            default:
                break
            }
        }
        
        operation.recordWithIDWasDeletedBlock = { recordID, _ in
            changes.deletedRecordIDs.append(recordID)
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            operation.recordZoneChangeTokensUpdatedBlock = { [weak self] _, token, _ in
                self?.serverChangeToken = token
            }
            
            operation.recordZoneFetchCompletionBlock = { [weak self] _, token, _, _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    self?.serverChangeToken = token
                    continuation.resume(returning: changes)
                }
            }
            
            privateDatabase.add(operation)
        }
    }
    
    private func processChanges(_ changes: SyncChanges) async {
        // Process deletions first
        await processDeletions(changes.deletedRecordIDs)
        
        // Merge and apply changes
        await mergeTasks(changes.tasks)
        await mergeCategories(changes.categories)
        await mergeRewards(changes.rewards)
        await mergePointsHistory(changes.pointsHistory)
        
        if !changes.settings.isEmpty {
            await applySettings(changes.settings)
        }
        
        // Notify UI
        NotificationCenter.default.post(name: .cloudKitDataChanged, object: nil)
    }
    
    private func processDeletions(_ deletedIDs: [CKRecord.ID]) async {
        for recordID in deletedIDs {
            let id = recordID.recordName
            
            // Handle task deletions
            if let uuid = UUID(uuidString: id) {
                let tasks = TaskManager.shared.tasks
                if let taskIndex = tasks.firstIndex(where: { $0.id == uuid }) {
                    let task = tasks[taskIndex]
                    TaskManager.shared.removeTask(task)
                    print("🗑️ Deleted task from remote: \(task.name)")
                }
                
                // Handle category deletions
                let categories = CategoryManager.shared.categories
                if let categoryIndex = categories.firstIndex(where: { $0.id == uuid }) {
                    let category = categories[categoryIndex]
                    CategoryManager.shared.removeCategory(category)
                    print("🗑️ Deleted category from remote: \(category.name)")
                }
                
                // Handle reward deletions
                let rewards = RewardManager.shared.rewards
                if let rewardIndex = rewards.firstIndex(where: { $0.id == uuid }) {
                    let reward = rewards[rewardIndex]
                    RewardManager.shared.removeReward(reward)
                    print("🗑️ Deleted reward from remote: \(reward.name)")
                }
            }
        }
    }
    
    private func mergeTasks(_ remoteTasks: [TodoTask]) async {
        guard !remoteTasks.isEmpty else { return }
        
        let localTasks = TaskManager.shared.tasks
        let localMap = Dictionary(uniqueKeysWithValues: localTasks.map { ($0.id, $0) })
        
        var mergedTasks = localTasks
        var hasChanges = false
        
        for remoteTask in remoteTasks {
            if deletedItems.tasks.contains(remoteTask.id.uuidString) {
                continue // Skip deleted items
            }
            
            if let localTask = localMap[remoteTask.id] {
                // Conflict resolution: prefer most recent modification
                if remoteTask.lastModifiedDate > localTask.lastModifiedDate {
                    if let index = mergedTasks.firstIndex(where: { $0.id == remoteTask.id }) {
                        mergedTasks[index] = remoteTask
                        hasChanges = true
                        print("🔄 Updated task from remote: \(remoteTask.name)")
                    }
                }
            } else {
                // New remote task
                mergedTasks.append(remoteTask)
                hasChanges = true
                print("📥 Added task from remote: \(remoteTask.name)")
            }
        }
        
        if hasChanges {
            TaskManager.shared.updateAllTasks(mergedTasks)
        }
    }
    
    private func mergeCategories(_ remoteCategories: [Category]) async {
        guard !remoteCategories.isEmpty else { return }
        
        let localCategories = CategoryManager.shared.categories
        
        // Create a comprehensive merge
        var mergedCategories: [Category] = []
        var processedIds = Set<UUID>()
        var processedNames = Set<String>()
        
        // Add existing local categories first
        for localCategory in localCategories {
            let normalizedName = localCategory.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if !processedIds.contains(localCategory.id) && !processedNames.contains(normalizedName) {
                mergedCategories.append(localCategory)
                processedIds.insert(localCategory.id)
                processedNames.insert(normalizedName)
            }
        }
        
        // Add remote categories that aren't duplicates or deleted
        var hasChanges = false
        for remoteCategory in remoteCategories {
            // Skip deleted categories
            if deletedItems.categories.contains(remoteCategory.id.uuidString) {
                continue
            }
            
            let normalizedName = remoteCategory.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Only add if we haven't seen this ID or name
            if !processedIds.contains(remoteCategory.id) && !processedNames.contains(normalizedName) {
                mergedCategories.append(remoteCategory)
                processedIds.insert(remoteCategory.id)
                processedNames.insert(normalizedName)
                hasChanges = true
                print("📥 Added category from remote: \(remoteCategory.name)")
            }
        }
        
        if hasChanges {
            CategoryManager.shared.importCategories(mergedCategories)
        }
    }
    
    private func mergeRewards(_ remoteRewards: [Reward]) async {
        guard !remoteRewards.isEmpty else { return }
        
        let localRewards = RewardManager.shared.rewards
        let localMap = Dictionary(uniqueKeysWithValues: localRewards.map { ($0.id, $0) })
        
        var mergedRewards = localRewards
        var hasChanges = false
        
        for remoteReward in remoteRewards {
            if deletedItems.rewards.contains(remoteReward.id.uuidString) {
                continue
            }
            
            if let localReward = localMap[remoteReward.id] {
                // Merge redemptions
                let allRedemptions = Set(localReward.redemptions + remoteReward.redemptions)
                var updatedReward = remoteReward
                updatedReward.redemptions = Array(allRedemptions).sorted()
                
                if let index = mergedRewards.firstIndex(where: { $0.id == remoteReward.id }) {
                    mergedRewards[index] = updatedReward
                    hasChanges = true
                }
            } else {
                mergedRewards.append(remoteReward)
                hasChanges = true
                print("📥 Added reward from remote: \(remoteReward.name)")
            }
        }
        
        if hasChanges {
            RewardManager.shared.importRewards(mergedRewards)
        }
    }
    
    private func mergePointsHistory(_ remoteHistory: [PointsHistory]) async {
        guard !remoteHistory.isEmpty else { return }
        
        // Convert to daily points dictionary format
        var dailyPoints: [Date: Int] = [:]
        
        for entry in remoteHistory {
            let startOfDay = Calendar.current.startOfDay(for: entry.date)
            dailyPoints[startOfDay] = (dailyPoints[startOfDay] ?? 0) + entry.points
        }
        
        // Merge with existing points
        let existingPoints = RewardManager.shared.dailyPointsHistory
        for (date, points) in dailyPoints {
            if existingPoints[date] == nil {
                RewardManager.shared.addPoints(points, on: date)
            }
        }
        
        print("📥 Merged \(remoteHistory.count) points history entries")
    }
    
    private func applySettings(_ settings: [String: Any]) async {
        // Apply remote settings to UserDefaults
        for (key, value) in settings {
            UserDefaults.standard.set(value, forKey: "cloudkit_\(key)")
        }
        
        // Notify about settings changes
        NotificationCenter.default.post(name: .cloudKitSettingsChanged, object: settings)
        print("📥 Applied remote settings: \(settings.keys)")
    }
    
    // MARK: - Record Creation
    private func createTaskRecord(from task: TodoTask) -> CKRecord {
        let recordID = CKRecord.ID(recordName: task.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: taskRecordType, recordID: recordID)
        
        // Safely set basic fields
        record["name"] = task.name.isEmpty ? "Untitled Task" : task.name
        record["taskDescription"] = task.description
        record["startTime"] = task.startTime
        record["duration"] = max(0, task.duration) // Ensure non-negative
        record["hasDuration"] = task.hasDuration
        record["icon"] = task.icon.isEmpty ? "circle.fill" : task.icon
        record["priority"] = task.priority.rawValue
        record["hasRewardPoints"] = task.hasRewardPoints
        record["rewardPoints"] = max(0, task.rewardPoints) // Ensure non-negative
        record["taskCreationDate"] = task.creationDate
        record["taskLastModifiedDate"] = task.lastModifiedDate
        
        // Safely encode complex objects
        do {
            encodeToRecord(record, key: "category", value: task.category)
            encodeToRecord(record, key: "location", value: task.location)
            encodeToRecord(record, key: "recurrence", value: task.recurrence)
            encodeToRecord(record, key: "pomodoroSettings", value: task.pomodoroSettings)
            encodeToRecord(record, key: "subtasks", value: task.subtasks)
            encodeToRecord(record, key: "completions", value: task.completions)
            encodeToRecord(record, key: "completionDates", value: task.completionDates)
        } catch {
            print("⚠️ Error encoding complex objects for task: \(error)")
        }
        
        return record
    }
    
    private func createTask(from record: CKRecord) -> TodoTask? {
        guard let name = record["name"] as? String,
              let uuid = UUID(uuidString: record.recordID.recordName) else {
            return nil
        }
        
        let description = record["taskDescription"] as? String
        let startTime = record["startTime"] as? Date ?? Date()
        let duration = record["duration"] as? TimeInterval ?? 0
        let hasDuration = record["hasDuration"] as? Bool ?? false
        let icon = record["icon"] as? String ?? "circle"
        let priority = Priority(rawValue: record["priority"] as? String ?? "") ?? .medium
        let hasRewardPoints = record["hasRewardPoints"] as? Bool ?? false
        let rewardPoints = record["rewardPoints"] as? Int ?? 0
        let creationDate = record["taskCreationDate"] as? Date ?? record.creationDate
        let lastModifiedDate = record["taskLastModifiedDate"] as? Date ?? record.modificationDate ?? creationDate
        
        let category: Category? = decodeFromRecord(record, key: "category")
        let location: TaskLocation? = decodeFromRecord(record, key: "location")
        let recurrence: Recurrence? = decodeFromRecord(record, key: "recurrence")
        let pomodoroSettings: PomodoroSettings? = decodeFromRecord(record, key: "pomodoroSettings")
        let subtasks: [Subtask] = decodeFromRecord(record, key: "subtasks") ?? []
        let completions: [Date: TaskCompletion] = decodeFromRecord(record, key: "completions") ?? [:]
        let completionDates: [Date] = decodeFromRecord(record, key: "completionDates") ?? []
        
        var task = TodoTask(
            id: uuid,
            name: name,
            description: description,
            location: location,
            startTime: startTime,
            duration: duration,
            hasDuration: hasDuration,
            category: category,
            priority: priority,
            icon: icon,
            recurrence: recurrence,
            pomodoroSettings: pomodoroSettings,
            subtasks: subtasks,
            hasRewardPoints: hasRewardPoints,
            rewardPoints: rewardPoints
        )
        
        task.completions = completions
        task.completionDates = completionDates
        task.creationDate = creationDate ?? Date()
        task.lastModifiedDate = lastModifiedDate ?? Date()
        
        syncSubtaskCompletionStates(&task)
        
        return task
    }
    
    private func syncSubtaskCompletionStates(_ task: inout TodoTask) {
        let today = Calendar.current.startOfDay(for: Date())
        
        if let todayCompletion = task.completions[today] {
            // Update subtask completion states based on today's completion data
            for i in 0..<task.subtasks.count {
                let subtaskId = task.subtasks[i].id
                task.subtasks[i].isCompleted = todayCompletion.completedSubtasks.contains(subtaskId)
            }
        }
    }
    
    private func createCategoryRecord(from category: Category) -> CKRecord {
        let recordID = CKRecord.ID(recordName: category.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: categoryRecordType, recordID: recordID)
        
        record["name"] = category.name
        record["color"] = category.color
        
        return record
    }
    
    private func createCategory(from record: CKRecord) -> Category? {
        guard let name = record["name"] as? String,
              let color = record["color"] as? String,
              let uuid = UUID(uuidString: record.recordID.recordName) else {
            return nil
        }
        
        return Category(id: uuid, name: name, color: color)
    }
    
    private func createRewardRecord(from reward: Reward) -> CKRecord {
        let recordID = CKRecord.ID(recordName: reward.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: rewardRecordType, recordID: recordID)
        
        record["name"] = reward.name
        record["rewardDescription"] = reward.description
        record["pointsCost"] = reward.pointsCost
        record["frequency"] = reward.frequency.rawValue
        record["icon"] = reward.icon
        record["rewardCreationDate"] = reward.creationDate
        record["rewardLastModifiedDate"] = reward.lastModifiedDate
        
        encodeToRecord(record, key: "redemptions", value: reward.redemptions)
        
        return record
    }
    
    private func createReward(from record: CKRecord) -> Reward? {
        guard let name = record["name"] as? String,
              let pointsCost = record["pointsCost"] as? Int,
              let frequencyRaw = record["frequency"] as? String,
              let frequency = RewardFrequency(rawValue: frequencyRaw),
              let icon = record["icon"] as? String,
              let uuid = UUID(uuidString: record.recordID.recordName) else {
            return nil
        }
        
        let description = record["rewardDescription"] as? String
        let creationDate = record["rewardCreationDate"] as? Date ?? record.creationDate
        let lastModifiedDate = record["rewardLastModifiedDate"] as? Date ?? record.modificationDate ?? creationDate
        let redemptions: [Date] = decodeFromRecord(record, key: "redemptions") ?? []
        
        var reward = Reward(
            id: uuid,
            name: name,
            description: description,
            pointsCost: pointsCost,
            frequency: frequency,
            icon: icon
        )
        
        reward.redemptions = redemptions
        reward.creationDate = creationDate ?? Date()
        reward.lastModifiedDate = lastModifiedDate ?? Date()
        
        return reward
    }
    
    private func createPointsHistoryRecord(from entry: PointsHistory) -> CKRecord {
        let recordID = CKRecord.ID(recordName: entry.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: pointsHistoryRecordType, recordID: recordID)
        
        record["date"] = entry.date
        record["points"] = entry.points
        record["frequency"] = entry.frequency.rawValue
        
        return record
    }
    
    private func createPointsHistory(from record: CKRecord) -> PointsHistory? {
        guard let date = record["date"] as? Date,
              let points = record["points"] as? Int,
              let frequencyRaw = record["frequency"] as? String,
              let frequency = RewardFrequency(rawValue: frequencyRaw),
              let uuid = UUID(uuidString: record.recordID.recordName) else {
            return nil
        }
        
        return PointsHistory(id: uuid, date: date, points: points, frequency: frequency)
    }
    
    private func createSettingsRecord(from settings: [String: Any]) -> CKRecord {
        let recordID = CKRecord.ID(recordName: "AppSettings", zoneID: zoneID)
        let record = CKRecord(recordType: settingsRecordType, recordID: recordID)
        
        // Ensure settings are JSON-compatible before serialization
        let jsonCompatibleSettings = makeJSONCompatible(settings)
        
        // Convert settings to Data manually since [String: Any] doesn't conform to Codable
        if let data = try? JSONSerialization.data(withJSONObject: jsonCompatibleSettings) {
            record["settings"] = data
        }
        record["lastUpdated"] = Date()
        
        return record
    }
    
    private func makeJSONCompatible(_ dictionary: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        
        for (key, value) in dictionary {
            switch value {
            case let date as Date:
                result[key] = date.timeIntervalSince1970
            case let uuid as UUID:
                result[key] = uuid.uuidString
            case let data as Data:
                result[key] = data.base64EncodedString()
            case let string as String:
                result[key] = string
            case let number as NSNumber:
                result[key] = number
            case let bool as Bool:
                result[key] = bool
            case let int as Int:
                result[key] = int
            case let double as Double:
                result[key] = double
            case let float as Float:
                result[key] = Double(float)
            default:
                // Skip non-JSON-serializable types
                print("⚠️ Skipping non-JSON-serializable value for key \(key): \(type(of: value))")
            }
        }
        
        return result
    }
    
    private func createSettings(from record: CKRecord) -> [String: Any]? {
        guard let data = record["settings"] as? Data else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
    
    // MARK: - Deletion Markers
    private func createDeletionMarker(type: String, id: String) -> CKRecord {
        let recordID = CKRecord.ID(recordName: "\(type)-\(id)", zoneID: zoneID)
        let record = CKRecord(recordType: deletionMarkerRecordType, recordID: recordID)
        
        record["type"] = type
        record["itemId"] = id
        record["deletedAt"] = Date()
        
        return record
    }
    
    private func saveDeletionMarker(type: String, id: String) async {
        let record = createDeletionMarker(type: type, id: id)
        do {
            _ = try await privateDatabase.save(record)
            print("✅ Saved deletion marker for \(type) \(id)")
        } catch {
            print("❌ Failed to save deletion marker for \(type) \(id): \(error)")
        }
    }
    
    // MARK: - Helper Methods
    private func encodeToRecord<T: Codable>(_ record: CKRecord, key: String, value: T?) {
        guard let value = value else { return }
        
        do {
            let data = try JSONEncoder().encode(value)
            record[key] = data
        } catch {
            print("⚠️ Failed to encode \(key): \(error)")
        }
    }
    
    private func decodeFromRecord<T: Codable>(_ record: CKRecord, key: String, type: T.Type = T.self) -> T? {
        guard let data = record[key] as? Data else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    
    private func canPerformSync() -> Bool {
        let now = Date()
        guard now.timeIntervalSince(lastSyncTime) >= minSyncInterval else {
            print("🔄 Sync throttled - too frequent")
            return false
        }
        
        guard !isSyncing else {
            print("🔄 Sync already in progress")
            return false
        }
        
        guard isCloudKitEnabled else {
            print("🔄 CloudKit sync is disabled")
            return false
        }
        
        // Check retry limits
        if syncRetryCount >= maxSyncRetries {
            let timeSinceLastError = now.timeIntervalSince(lastErrorTime)
            if timeSinceLastError < 300 { // 5 minutes cooldown
                print("🔄 Max sync retries reached, cooling down")
                return false
            } else {
                syncRetryCount = 0 // Reset after cooldown
            }
        }
        
        return true
    }
    
    // MARK: - Deletion Tracking
    private enum ItemType {
        case task, category, reward, pointsHistory
    }
    
    private func markAsDeleted(itemID: String, type: ItemType) {
        var tracker = deletedItems
        
        switch type {
        case .task:
            tracker.tasks.insert(itemID)
        case .category:
            tracker.categories.insert(itemID)
        case .reward:
            tracker.rewards.insert(itemID)
        case .pointsHistory:
            tracker.pointsHistory.insert(itemID)
        }
        
        deletedItems = tracker
        print("🗑️ Marked \(type) as deleted: \(itemID)")
    }
    
    private func removeFromDeleted(itemID: String, type: ItemType) {
        var tracker = deletedItems
        
        switch type {
        case .task:
            tracker.tasks.remove(itemID)
        case .category:
            tracker.categories.remove(itemID)
        case .reward:
            tracker.rewards.remove(itemID)
        case .pointsHistory:
            tracker.pointsHistory.remove(itemID)
        }
        
        deletedItems = tracker
        print("✅ Removed from deleted \(type): \(itemID)")
    }
    
    private func updateSyncStatus(for accountStatus: CKAccountStatus) async {
        switch accountStatus {
        case .available:
            syncStatus = .idle
        case .noAccount:
            syncStatus = .error("No iCloud account")
        case .restricted:
            syncStatus = .error("iCloud restricted")
        case .couldNotDetermine:
            syncStatus = .error("Cannot determine iCloud status")
        @unknown default:
            syncStatus = .error("Unknown iCloud status")
        }
    }
    
    private func handleSyncError(_ error: Error) async {
        print("❌ Sync error: \(error)")
        
        syncRetryCount += 1
        lastErrorTime = Date()
        
        if let ckError = error as? CKError {
            switch ckError.code {
            case .networkFailure, .networkUnavailable:
                syncStatus = .error("Network error")
            case .quotaExceeded:
                syncStatus = .error("iCloud storage full")
            case .notAuthenticated:
                syncStatus = .error("Authentication failed")
            case .zoneNotFound:
                syncStatus = .error("Zone missing")
                try? await ensureZoneExists()
            case .serverRecordChanged:
                syncStatus = .error("Sync conflict")
                // Only retry if under limit
                if syncRetryCount < maxSyncRetries {
                    Task { 
                        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
                        await performFullSync() 
                    }
                }
            default:
                syncStatus = .error("Sync failed: \(ckError.localizedDescription)")
            }
        } else {
            syncStatus = .error("Sync failed")
        }
    }
    
    private func handleCloudKitError(_ error: CKError) async {
        print("❌ CloudKit error: \(error.localizedDescription)")
        
        switch error.code {
        case .networkFailure, .networkUnavailable:
            syncStatus = .error("Network unavailable")
        case .quotaExceeded:
            syncStatus = .error("iCloud storage full")
        case .notAuthenticated:
            syncStatus = .error("Not signed into iCloud")
        case .invalidArguments:
            syncStatus = .error("Invalid data format")
        case .serverRecordChanged:
            print("⚠️ Record conflict detected, will retry sync")
            if syncRetryCount < maxSyncRetries {
                Task { 
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
                    await performFullSync() 
                }
            }
        case .unknownItem:
            print("ℹ️ Item already deleted")
        case .constraintViolation:
            syncStatus = .error("Data constraint violation")
        case .zoneNotFound:
            syncStatus = .error("Zone missing, recreating...")
            try? await ensureZoneExists()
            if syncRetryCount < maxSyncRetries {
                Task { 
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                    await performFullSync() 
                }
            }
        case .limitExceeded:
            syncStatus = .error("Rate limit exceeded")
        default:
            syncStatus = .error("CloudKit error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Remote Notifications
    func processRemoteNotification(_ userInfo: [AnyHashable: Any]) {
        guard isCloudKitEnabled else { return }
        
        if let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) {
            if notification.subscriptionID == subscriptionID {
                print("📱 Received CloudKit notification")
                syncNow()
            }
        }
    }
    
    func clearDeletionMarkers() {
        deletedItems = DeletionTracker()
        print("🗑️ Cleared all deletion markers")
    }
    
    func resetSyncState() async {
        print("🔄 Resetting CloudKit sync state")
        
        // Clear change token
        serverChangeToken = nil
        
        // Clear deletion markers
        clearDeletionMarkers()
        
        // Reset sync status
        syncStatus = .idle
        lastSyncDate = nil
        syncRetryCount = 0
        
        // Perform fresh sync
        await performFullSync()
    }
}

// MARK: - Legacy Compatibility
extension CloudKitService {
    func syncTasks() { syncNow() }
    func syncInBackground() { syncNow() }
    func performInitialSync() { syncNow() }
    func setup() {
        print("ℹ️ Legacy setup() called - handled automatically")
    }
    
    func manualSyncCategories(isBackground: Bool = false, completion: @escaping (Bool) -> Void) {
        Task {
            await performFullSync()
            completion(syncStatus == .success)
        }
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let cloudKitDataChanged = Notification.Name("cloudKitDataChanged")
    static let cloudKitSettingsChanged = Notification.Name("cloudKitSettingsChanged")
}
