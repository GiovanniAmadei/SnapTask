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
    private let trackingSessionRecordType = "TrackingSession"
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
            case .idle: return "sync_idle".localized
            case .syncing: return "syncing".localized
            case .success: return "sync_success".localized
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
        var trackingSessions: Set<String> = []
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
    
    // MARK: - Deletion Tracking
    private enum ItemType {
        case task, category, reward, pointsHistory, trackingSession
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
        case .trackingSession:
            tracker.trackingSessions.insert(itemID)
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
        case .trackingSession:
            tracker.trackingSessions.remove(itemID)
        }
        
        deletedItems = tracker
        print("✅ Removed from deleted \(type): \(itemID)")
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
        guard isCloudKitEnabled else {
            print("🔄 CloudKit sync is disabled")
            return
        }
        
        if isSyncing {
            print("🔄 Sync already in progress, skipping")
            return
        }
        
        let now = Date()
        if now.timeIntervalSince(lastSyncTime) < minSyncInterval {
            print("🔄 Sync throttled - too frequent")
            return
        }
        
        activeSyncTask?.cancel()
        activeSyncTask = Task {
            await performFullSync()
        }
    }
    
    func forceFullSync() {
        guard isCloudKitEnabled else {
            print("🔄 CloudKit sync is disabled")
            return
        }
        
        print("🔄 Force full sync requested - clearing change token")
        
        // Clear change token to force full sync
        serverChangeToken = nil
        
        // Reset sync state
        syncRetryCount = 0
        lastErrorTime = .distantPast
        
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
    func saveTask(_ task: TodoTask, retryCount: Int = 0) {
        guard isCloudKitEnabled else { return }
        
        Task {
            do {
                let record = createTaskRecord(from: task)
                
                let operation = CKModifyRecordsOperation(recordsToSave: [record])
                operation.savePolicy = .changedKeys // Only update changed fields
                operation.isAtomic = false // Allow partial success
                
                let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[CKRecord], Error>) in
                    operation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: savedRecords ?? [])
                        }
                    }
                    privateDatabase.add(operation)
                }
                
                print("✅ Task saved to CloudKit: \(task.name)")
                
                DispatchQueue.main.async {
                    self.syncStatus = .success
                    self.lastSyncDate = Date()
                }
            } catch let error as CKError {
                if error.code == .serverRecordChanged && retryCount < 3 {
                    print("⚠️ Concurrent write detected for \(task.name), retrying...")
                    
                    // Wait with exponential backoff
                    try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(retryCount)) * 500_000_000))
                    
                    // Fetch and merge
                    await resolveConflictAndRetry(task: task, retryCount: retryCount + 1)
                    return
                }
                
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
    
    // MARK: - Tracking Session Operations
    func saveTrackingSession(_ session: TrackingSession) {
        guard isCloudKitEnabled else { return }
        
        Task {
            do {
                let record = createTrackingSessionRecord(from: session)
                _ = try await privateDatabase.save(record)
                print("✅ Tracking session saved: \(session.deviceDisplayInfo) - \(formatDuration(session.effectiveWorkTime))")
            } catch {
                print("❌ Failed to save tracking session: \(error)")
            }
        }
    }
    
    func deleteTrackingSession(_ session: TrackingSession) {
        guard isCloudKitEnabled else { return }
        
        markAsDeleted(itemID: session.id.uuidString, type: .trackingSession)
        
        Task {
            do {
                let recordID = CKRecord.ID(recordName: session.id.uuidString, zoneID: zoneID)
                _ = try await privateDatabase.deleteRecord(withID: recordID)
                print("✅ Tracking session deleted: \(session.deviceDisplayInfo)")
            } catch let error as CKError where error.code == .unknownItem {
                print("ℹ️ Tracking session already deleted")
            } catch {
                print("❌ Failed to delete tracking session: \(error)")
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    // MARK: - Sync Implementation
    private func performFullSync() async {
        print("🔄 Starting full sync")
        
        DispatchQueue.main.async {
            self.isSyncing = true
            self.syncStatus = .syncing
        }
        
        lastSyncTime = Date()
        
        defer {
            DispatchQueue.main.async {
                self.isSyncing = false
            }
        }
        
        do {
            let changes = try await fetchChanges()
            await processChanges(changes)
            
            DispatchQueue.main.async {
                self.syncStatus = .success
                self.lastSyncDate = Date()
                self.syncRetryCount = 0
            }
            
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
        var trackingSessions: [TrackingSession] = []
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
            case self.trackingSessionRecordType:
                if let session = self.createTrackingSession(from: record) {
                    changes.trackingSessions.append(session)
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
                    // Handle specific "client knowledge differs" error
                    if let ckError = error as? CKError, 
                       ckError.code == .changeTokenExpired {
                        print("⚠️ Change token expired, clearing and retrying full sync")
                        self?.serverChangeToken = nil
                        // Retry without token for full sync
                        Task {
                            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                            do {
                                let freshChanges = try await self?.fetchChangesWithoutToken()
                                continuation.resume(returning: freshChanges ?? changes)
                            } catch {
                                continuation.resume(throwing: error)
                            }
                        }
                        return
                    }
                    continuation.resume(throwing: error)
                } else {
                    self?.serverChangeToken = token
                    continuation.resume(returning: changes)
                }
            }
            
            privateDatabase.add(operation)
        }
    }
    
    // MARK: - Fresh Sync Without Token
    private func fetchChangesWithoutToken() async throws -> SyncChanges {
        print("🔄 Performing fresh sync without change token")
        
        let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zoneID])
        
        var changes = SyncChanges()
        
        // No token configuration - fetch all records
        operation.configurationsByRecordZoneID = [
            zoneID: CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        ]
        
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
            case self.trackingSessionRecordType:
                if let session = self.createTrackingSession(from: record) {
                    changes.trackingSessions.append(session)
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
                print("✅ Fresh change token saved")
            }
            
            operation.recordZoneFetchCompletionBlock = { [weak self] _, token, _, _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    self?.serverChangeToken = token
                    print("✅ Fresh full sync completed")
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
        await mergeTrackingSessions(changes.trackingSessions)
        
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
                    TaskManager.shared.removeTaskFromRemoteSync(task)
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
                
                // Handle tracking session deletions
                let trackingSessions = TaskManager.shared.getTrackingSessions()
                if let sessionIndex = trackingSessions.firstIndex(where: { $0.id == uuid }) {
                    let session = trackingSessions[sessionIndex]
                    TaskManager.shared.deleteTrackingSession(session)
                    print("🗑️ Deleted tracking session from remote: \(session.deviceDisplayInfo)")
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
                var mergedTask: TodoTask
                
                if remoteTask.lastModifiedDate > localTask.lastModifiedDate {
                    // Remote is newer, use remote as base but preserve any local completions that are newer
                    mergedTask = remoteTask
                    print("🔄 Remote task is newer for \(remoteTask.name)")
                } else if localTask.lastModifiedDate > remoteTask.lastModifiedDate {
                    // Local is newer, keep local
                    mergedTask = localTask
                    print("🔄 Local task is newer for \(localTask.name)")
                } else {
                    // Same timestamp, merge completions intelligently
                    mergedTask = remoteTask
                    var mergedCompletions = remoteTask.completions
                    
                    for (date, localCompletion) in localTask.completions {
                        if mergedCompletions[date] == nil {
                            mergedCompletions[date] = localCompletion
                        }
                    }
                    
                    mergedTask.completions = mergedCompletions
                    let allCompletionDates = Set(localTask.completionDates + remoteTask.completionDates)
                    mergedTask.completionDates = Array(allCompletionDates).sorted()
                    print("🔄 Same timestamp, merged completions for \(remoteTask.name)")
                }
                
                // Sync subtask states
                syncSubtaskCompletionStates(&mergedTask)
                
                if let index = mergedTasks.firstIndex(where: { $0.id == remoteTask.id }) {
                    mergedTasks[index] = mergedTask
                    hasChanges = true
                }
            } else {
                // New remote task
                var newTask = remoteTask
                syncSubtaskCompletionStates(&newTask)
                mergedTasks.append(newTask)
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
    
    private func mergeTrackingSessions(_ remoteSessions: [TrackingSession]) async {
        guard !remoteSessions.isEmpty else { return }
        
        let localSessions = TaskManager.shared.getTrackingSessions()
        let localMap = Dictionary(uniqueKeysWithValues: localSessions.map { ($0.id, $0) })
        
        var mergedSessions = localSessions
        var hasChanges = false
        
        for remoteSession in remoteSessions {
            if deletedItems.trackingSessions.contains(remoteSession.id.uuidString) {
                continue // Skip deleted items
            }
            
            if let localSession = localMap[remoteSession.id] {
                // Merge sessions - prefer the one with the latest modification date
                if remoteSession.lastModifiedDate > localSession.lastModifiedDate {
                    if let index = mergedSessions.firstIndex(where: { $0.id == remoteSession.id }) {
                        mergedSessions[index] = remoteSession
                        hasChanges = true
                        print("🔄 Updated tracking session from \(remoteSession.deviceDisplayInfo)")
                    }
                }
            } else {
                // New remote session
                mergedSessions.append(remoteSession)
                hasChanges = true
                print("📥 Added tracking session from \(remoteSession.deviceDisplayInfo) - \(formatDuration(remoteSession.effectiveWorkTime))")
            }
        }
        
        if hasChanges {
            // We'll need to add this method to TaskManager
            TaskManager.shared.updateAllTrackingSessions(mergedSessions)
        }
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
        record["name"] = task.name.isEmpty ? "untitled_task".localized : task.name
        record["taskDescription"] = task.description
        record["startTime"] = task.startTime
        record["hasSpecificTime"] = task.hasSpecificTime
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
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
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
        let hasSpecificTime = record["hasSpecificTime"] as? Bool ?? true
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
            hasSpecificTime: hasSpecificTime,
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
        for i in 0..<task.subtasks.count {
            let subtaskId = task.subtasks[i].id
            var isCompleted = false
            for completion in task.completions.values {
                if completion.completedSubtasks.contains(subtaskId) {
                    isCompleted = true
                    break
                }
            }
            task.subtasks[i].isCompleted = isCompleted
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
    
    // MARK: - Tracking Session Record Creation
    private func createTrackingSessionRecord(from session: TrackingSession) -> CKRecord {
        let recordID = CKRecord.ID(recordName: session.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: trackingSessionRecordType, recordID: recordID)
        
        // Basic session info
        record["sessionId"] = session.id.uuidString
        record["taskId"] = session.taskId?.uuidString
        record["taskName"] = session.taskName
        record["mode"] = session.mode.rawValue
        record["categoryId"] = session.categoryId?.uuidString
        record["categoryName"] = session.categoryName
        record["startTime"] = session.startTime
        record["deviceType"] = session.deviceType.rawValue
        record["deviceName"] = session.deviceName
        record["sessionCreatedAt"] = session.creationDate
        record["sessionModifiedAt"] = session.lastModifiedDate
        
        // Tracking state
        record["isRunning"] = session.isRunning
        record["isPaused"] = session.isPaused
        record["elapsedTime"] = session.elapsedTime
        record["totalDuration"] = session.totalDuration
        record["pausedDuration"] = session.pausedDuration
        record["isCompleted"] = session.isCompleted
        record["endTime"] = session.endTime
        record["notes"] = session.notes
        
        return record
    }
    
    private func createTrackingSession(from record: CKRecord) -> TrackingSession? {
        guard let sessionIdString = record["sessionId"] as? String,
              let sessionId = UUID(uuidString: sessionIdString),
              let modeString = record["mode"] as? String,
              let mode = TrackingMode(rawValue: modeString),
              let startTime = record["startTime"] as? Date,
              let deviceTypeString = record["deviceType"] as? String,
              let deviceType = DeviceType(rawValue: deviceTypeString),
              let deviceName = record["deviceName"] as? String else {
            print("❌ Failed to decode tracking session from record")
            return nil
        }
        
        let creationDate = record["sessionCreatedAt"] as? Date ?? record.creationDate
        let lastModifiedDate = record["sessionModifiedAt"] as? Date ?? record.modificationDate ?? creationDate
        
        let taskId = (record["taskId"] as? String).flatMap { UUID(uuidString: $0) }
        let taskName = record["taskName"] as? String
        let categoryId = (record["categoryId"] as? String).flatMap { UUID(uuidString: $0) }
        let categoryName = record["categoryName"] as? String
        
        let isRunning = record["isRunning"] as? Bool ?? false
        let isPaused = record["isPaused"] as? Bool ?? false
        let elapsedTime = record["elapsedTime"] as? TimeInterval ?? 0
        let totalDuration = record["totalDuration"] as? TimeInterval ?? 0
        let pausedDuration = record["pausedDuration"] as? TimeInterval ?? 0
        let isCompleted = record["isCompleted"] as? Bool ?? false
        let endTime = record["endTime"] as? Date
        let notes = record["notes"] as? String
        
        var session = TrackingSession(
            id: sessionId,
            taskId: taskId,
            taskName: taskName,
            mode: mode,
            categoryId: categoryId,
            categoryName: categoryName,
            startTime: startTime,
            elapsedTime: elapsedTime,
            isRunning: isRunning,
            isPaused: isPaused
        )
        
        // Set additional properties
        session.totalDuration = totalDuration
        session.pausedDuration = pausedDuration
        session.isCompleted = isCompleted
        session.endTime = endTime
        session.notes = notes
        
        return session
    }
    
    // MARK: - Helper Methods
    private func encodeToRecord<T: Codable>(_ record: CKRecord, key: String, value: T?) {
        guard let value = value else { return }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(value)
            record[key] = data
        } catch {
            print("⚠️ Failed to encode \(key): \(error)")
        }
    }
    
    private func decodeFromRecord<T: Codable>(_ record: CKRecord, key: String, type: T.Type = T.self) -> T? {
        guard let data = record[key] as? Data else { return nil }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            print("⚠️ Failed to decode \(key): \(error)")
            return nil
        }
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
    private func updateSyncStatus(for accountStatus: CKAccountStatus) async {
        switch accountStatus {
        case .available:
            syncStatus = .idle
        case .noAccount:
            syncStatus = .error("sync_error".localized)
        case .restricted:
            syncStatus = .error("sync_error".localized)
        case .couldNotDetermine:
            syncStatus = .error("sync_error".localized)
        @unknown default:
            syncStatus = .error("sync_error".localized)
        }
    }
    
    private func handleSyncError(_ error: Error) async {
        print("❌ Sync error: \(error)")
        
        syncRetryCount += 1
        lastErrorTime = Date()
        
        if let ckError = error as? CKError {
            switch ckError.code {
            case .networkFailure, .networkUnavailable:
                syncStatus = .error("sync_error".localized)
            case .quotaExceeded:
                syncStatus = .error("sync_error".localized)
            case .notAuthenticated:
                syncStatus = .error("sync_error".localized)
            case .zoneNotFound:
                syncStatus = .error("zone_missing_recreating".localized)
                try? await ensureZoneExists()
            case .changeTokenExpired:
                print("⚠️ Change token expired - clearing token and retrying")
                syncStatus = .error("sync_token_expired".localized)
                serverChangeToken = nil
                if syncRetryCount < maxSyncRetries {
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
                        await performFullSync()
                    }
                }
            case .serverRecordChanged:
                syncStatus = .error("sync_error".localized)
                // Only retry if under limit
                if syncRetryCount < maxSyncRetries {
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
                        await performFullSync()
                    }
                }
            default:
                // Handle the "client knowledge differs" error specifically
                if ckError.localizedDescription.contains("client knowledge differs") {
                    print("⚠️ Client knowledge differs from server - clearing token and retrying")
                    syncStatus = .error("sync_state_mismatch".localized)
                    serverChangeToken = nil
                    if syncRetryCount < maxSyncRetries {
                        Task {
                            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 second delay
                            await performFullSync()
                        }
                    }
                } else {
                    syncStatus = .error("sync_error".localized)
                }
            }
        } else {
            syncStatus = .error("sync_error".localized)
        }
    }
    
    private func handleCloudKitError(_ error: CKError) async {
        print("❌ CloudKit error: \(error.localizedDescription)")
        
        switch error.code {
        case .networkFailure, .networkUnavailable:
            syncStatus = .error("sync_error".localized)
        case .quotaExceeded:
            syncStatus = .error("sync_error".localized)
        case .notAuthenticated:
            syncStatus = .error("sync_error".localized)
        case .invalidArguments:
            syncStatus = .error("sync_error".localized)
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
            syncStatus = .error("sync_error".localized)
        case .zoneNotFound:
            syncStatus = .error("zone_missing_recreating".localized)
            try? await ensureZoneExists()
            if syncRetryCount < maxSyncRetries {
                Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                    await performFullSync()
                }
            }
        case .limitExceeded:
            syncStatus = .error("sync_error".localized)
        default:
            syncStatus = .error("sync_error".localized)
        }
    }
    
    private func resolveConflictAndRetry(task: TodoTask, retryCount: Int) async {
        do {
            // Fetch the current version from CloudKit
            let recordID = CKRecord.ID(recordName: task.id.uuidString, zoneID: zoneID)
            let currentRecord = try await privateDatabase.record(for: recordID)
            
            // Create current task from record
            guard let currentTask = createTask(from: currentRecord) else {
                print("❌ Could not parse current task from CloudKit")
                return
            }
            
            // Merge our changes into the current version
            let mergedTask = mergeTaskConflict(local: task, remote: currentTask)
            
            // Update the existing record instead of creating new one
            let updatedRecord = updateTaskRecord(currentRecord, with: mergedTask)
            
            // Save the updated record
            let operation = CKModifyRecordsOperation(recordsToSave: [updatedRecord])
            operation.savePolicy = .changedKeys
            operation.isAtomic = false
            
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[CKRecord], Error>) in
                operation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: savedRecords ?? [])
                    }
                }
                privateDatabase.add(operation)
            }
            
            print("✅ Conflict resolved and task updated: \(mergedTask.name)")
            
        } catch {
            print("❌ Failed to resolve conflict for \(task.name): \(error)")
            if retryCount < 3 {
                // Try one more time with simple save
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                saveTask(task, retryCount: retryCount + 1)
            }
        }
    }
    
    private func updateTaskRecord(_ existingRecord: CKRecord, with task: TodoTask) -> CKRecord {
        // Update fields in existing record
        existingRecord["name"] = task.name.isEmpty ? "untitled_task".localized : task.name
        existingRecord["taskDescription"] = task.description
        existingRecord["startTime"] = task.startTime
        existingRecord["hasSpecificTime"] = task.hasSpecificTime
        existingRecord["duration"] = max(0, task.duration)
        existingRecord["hasDuration"] = task.hasDuration
        existingRecord["icon"] = task.icon.isEmpty ? "circle.fill" : task.icon
        existingRecord["priority"] = task.priority.rawValue
        existingRecord["hasRewardPoints"] = task.hasRewardPoints
        existingRecord["rewardPoints"] = max(0, task.rewardPoints)
        existingRecord["taskCreationDate"] = task.creationDate
        existingRecord["taskLastModifiedDate"] = task.lastModifiedDate
        
        // Update complex objects
        encodeToRecord(existingRecord, key: "category", value: task.category)
        encodeToRecord(existingRecord, key: "location", value: task.location)
        encodeToRecord(existingRecord, key: "recurrence", value: task.recurrence)
        encodeToRecord(existingRecord, key: "pomodoroSettings", value: task.pomodoroSettings)
        encodeToRecord(existingRecord, key: "subtasks", value: task.subtasks)
        encodeToRecord(existingRecord, key: "completions", value: task.completions)
        encodeToRecord(existingRecord, key: "completionDates", value: task.completionDates)
        
        return existingRecord
    }
    
    private func mergeTaskConflict(local: TodoTask, remote: TodoTask) -> TodoTask {
        var merged = remote
        
        var mergedCompletions = remote.completions
        
        for (date, localCompletion) in local.completions {
            if mergedCompletions[date] == nil {
                mergedCompletions[date] = localCompletion
            }
        }
        merged.completions = mergedCompletions
        
        // Merge completion dates
        let allCompletionDates = Set(local.completionDates + remote.completionDates)
        merged.completionDates = Array(allCompletionDates).sorted()
        
        // Use latest modification date
        merged.lastModifiedDate = max(local.lastModifiedDate, remote.lastModifiedDate)
        
        // Sync subtask states
        syncSubtaskCompletionStates(&merged)
        
        print("🔄 Merged conflict for task: \(merged.name) (using \(local.lastModifiedDate > remote.lastModifiedDate ? "local" : "remote") completion state)")
        return merged
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
    
    func clearSyncTokens() {
        print("🗑️ Clearing all sync tokens and state")
        serverChangeToken = nil
        UserDefaults.standard.removeObject(forKey: changeTokenKey)
        syncRetryCount = 0
        lastErrorTime = .distantPast
        syncStatus = .idle
    }
    
    func getSyncDiagnostics() -> [String: Any] {
        return [
            "isCloudKitEnabled": isCloudKitEnabled,
            "syncStatus": syncStatus.description,
            "lastSyncDate": lastSyncDate?.description ?? "Never",
            "syncRetryCount": syncRetryCount,
            "hasChangeToken": serverChangeToken != nil,
            "deletedItemsCount": [
                "tasks": deletedItems.tasks.count,
                "categories": deletedItems.categories.count,
                "rewards": deletedItems.rewards.count,
                "pointsHistory": deletedItems.pointsHistory.count,
                "trackingSessions": deletedItems.trackingSessions.count
            ]
        ]
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