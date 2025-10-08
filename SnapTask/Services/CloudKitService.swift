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
    private let journalEntryRecordType = "JournalEntry"
    
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
        var journalEntries: Set<String> = []
        var journalPhotos: Set<String> = []
        var journalVoiceMemos: Set<String> = []
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
    private enum ItemType: String, Codable {
        case task = "task"
        case category = "category"
        case reward = "reward"
        case pointsHistory = "pointsHistory"
        case trackingSession = "trackingSession"
        case journalEntry = "journalEntry"
        case journalPhoto = "journalPhoto"
        case journalVoiceMemo = "journalVoiceMemo"
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
        case .journalEntry:
            tracker.journalEntries.insert(itemID)
        case .journalPhoto:
            tracker.journalPhotos.insert(itemID)
        case .journalVoiceMemo:
            tracker.journalVoiceMemos.insert(itemID)
        }
        
        deletedItems = tracker
        print(" Marked \(type) as deleted: \(itemID)")
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
        case .journalEntry:
            tracker.journalEntries.remove(itemID)
        case .journalPhoto:
            tracker.journalPhotos.remove(itemID)
        case .journalVoiceMemo:
            tracker.journalVoiceMemos.remove(itemID)
        }
        
        deletedItems = tracker
        print(" Removed from deleted \(type): \(itemID)")
    }
    
    // MARK: - Initialization
    private init() {
        container = CKContainer.default()
        privateDatabase = container.privateCloudDatabase
        zoneID = CKRecordZone.ID(zoneName: "SnapTaskZone", ownerName: CKCurrentUserDefaultName)
        recordZone = CKRecordZone(zoneID: zoneID)
        
        // Load sync preference (default to true if unset)
        if let stored = UserDefaults.standard.object(forKey: "cloudkit_sync_enabled") as? Bool {
            isCloudKitEnabled = stored
        } else {
            isCloudKitEnabled = true
            UserDefaults.standard.set(true, forKey: "cloudkit_sync_enabled")
        }
        
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
            print(" Zone exists")
        } catch let error as CKError where error.code == .zoneNotFound {
            print(" Creating zone...")
            _ = try await privateDatabase.save(recordZone)
            print(" Zone created")
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
                print(" Subscription created")
            } else {
                print(" Subscription already exists")
            }
        } catch {
            print(" Failed to setup subscription: \(error)")
        }
    }
    
    // MARK: - Public API
    func syncNow() {
        guard isCloudKitEnabled else {
            print(" CloudKit sync is disabled")
            return
        }
        
        if isSyncing {
            print(" Sync already in progress, skipping")
            return
        }
        
        let now = Date()
        if now.timeIntervalSince(lastSyncTime) < minSyncInterval {
            print(" Sync throttled - too frequent")
            return
        }
        
        activeSyncTask?.cancel()
        activeSyncTask = Task {
            await performFullSync()
        }
    }
    
    func forceFullSync() {
        guard isCloudKitEnabled else {
            print(" CloudKit sync is disabled")
            return
        }
        
        print(" Force full sync requested - clearing change token")
        
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
    
    func deleteJournalPhoto(on date: Date, photo: JournalPhoto) {
        let day = Calendar.current.startOfDay(for: date)
        let entry = JournalManager.shared.entry(for: day)
        markAsDeleted(itemID: photo.id.uuidString, type: .journalPhoto)
        
        AttachmentService.deleteJournalPhoto(for: entry.id, photo: photo)
        JournalManager.shared.removePhoto(withId: photo.id, for: day)
        
        Task {
            await saveDeletionMarker(type: "JournalPhoto", id: photo.id.uuidString)
        }
    }
    
    func deleteJournalVoiceMemo(on date: Date, memo: JournalVoiceMemo) {
        let day = Calendar.current.startOfDay(for: date)
        let entry = JournalManager.shared.entry(for: day)
        let idString = memo.id.uuidString
        
        markAsDeleted(itemID: idString, type: .journalVoiceMemo)
        
        if FileManager.default.fileExists(atPath: memo.audioPath) {
            try? FileManager.default.removeItem(atPath: memo.audioPath)
        }
        JournalManager.shared.removeVoiceMemo(withId: memo.id, for: day)
        
        Task {
            await saveDeletionMarker(type: "JournalVoiceMemo", id: idString)
        }
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
                
                print(" Task saved to CloudKit: \(task.name)")
                
                DispatchQueue.main.async {
                    self.syncStatus = .success
                    self.lastSyncDate = Date()
                }
            } catch let error as CKError {
                if error.code == .serverRecordChanged && retryCount < 3 {
                    print(" Concurrent write detected for \(task.name), retrying...")
                    
                    // Wait with exponential backoff
                    try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(retryCount)) * 500_000_000))
                    
                    // Fetch and merge
                    await resolveConflictAndRetry(task: task, retryCount: retryCount + 1)
                    return
                }
                
                print(" CloudKit error saving task: \(error.localizedDescription)")
                await handleCloudKitError(error)
            } catch {
                print(" Failed to save task: \(error)")
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
                print(" Task deleted: \(task.name)")
            } catch let error as CKError where error.code == .unknownItem {
                print(" Task already deleted from CloudKit: \(task.name)")
            } catch {
                print(" Failed to delete task: \(error)")
                await handleSyncError(error)
            }
        }
    }
    
    // MARK: - Category Operations
    func saveCategory(_ category: Category) {
        guard isCloudKitEnabled else { return }
        if deletedItems.categories.contains(category.id.uuidString) {
            print(" Skipping CloudKit save for deleted category \(category.name)")
            return
        }
        
        Task {
            do {
                let record = createCategoryRecord(from: category)
                _ = try await privateDatabase.save(record)
                print(" Category saved: \(category.name)")
            } catch let error as CKError {
                print(" CloudKit error saving category: \(error.localizedDescription)")
                await handleCloudKitError(error)
            } catch {
                print(" Failed to save category: \(error)")
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
                await saveDeletionMarker(type: "Category", id: category.id.uuidString)
                print(" Category deleted: \(category.name)")
            } catch let error as CKError {
                if error.code == .unknownItem {
                    print(" Category already deleted from CloudKit: \(category.name)")
                    await saveDeletionMarker(type: "Category", id: category.id.uuidString)
                } else {
                    print(" CloudKit error deleting category: \(error.localizedDescription)")
                    await handleCloudKitError(error)
                }
            } catch {
                print(" Failed to delete category: \(error)")
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
                print(" Reward saved: \(reward.name)")
            } catch {
                print(" Failed to save reward: \(error)")
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
                print(" Reward deleted: \(reward.name)")
            } catch let error as CKError where error.code == .unknownItem {
                print(" Reward already deleted")
            } catch {
                print(" Failed to delete reward: \(error)")
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
                print(" Points entry saved: \(entry.points) points")
            } catch {
                print(" Failed to save points entry: \(error)")
            }
        }
    }
    
    func syncPointsHistory(_ history: [Date: Int]) {
        guard isCloudKitEnabled else { return }
        
        Task {
            do {
                var records: [CKRecord] = []
                
                for (date, points) in history {
                    let startOfDay = Calendar.current.startOfDay(for: date)
                    let recordID = stablePointsHistoryRecordID(for: startOfDay)
                    let record = CKRecord(recordType: pointsHistoryRecordType, recordID: recordID)
                    record["date"] = startOfDay
                    record["points"] = points
                    record["frequency"] = RewardFrequency.daily.rawValue
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
                        self.privateDatabase.add(operation)
                    }
                }
                
                print(" Synced \(records.count) points history entries")
            } catch {
                print(" Failed to sync points history: \(error)")
            }
        }
    }
    
    private func stablePointsHistoryRecordID(for date: Date) -> CKRecord.ID {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        return CKRecord.ID(recordName: "points-\(dateString)", zoneID: zoneID)
    }
    
    // MARK: - Settings Operations
    func saveAppSettings(_ settings: [String: Any]) {
        guard isCloudKitEnabled else { return }
        
        Task {
            do {
                let record = createSettingsRecord(from: settings)
                _ = try await privateDatabase.save(record)
                print(" App settings saved")
            } catch {
                print(" Failed to save app settings: \(error)")
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
                print(" Tracking session saved: \(session.deviceDisplayInfo) - \(formatDuration(session.effectiveWorkTime))")
            } catch {
                print(" Failed to save tracking session: \(error)")
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
                print(" Tracking session deleted: \(session.deviceDisplayInfo)")
            } catch let error as CKError where error.code == .unknownItem {
                print(" Tracking session already deleted")
            } catch {
                print(" Failed to delete tracking session: \(error)")
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
        print(" Starting full sync")
        
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
            
            print(" Full sync completed successfully")
            
        } catch {
            await handleSyncError(error)
        }
    }
    
    struct SyncChanges {
        var tasks: [TodoTask] = []
        var categories: [Category] = []
        var rewards: [Reward] = []
        var pointsHistory: [PointsHistory] = []
        var trackingSessions: [TrackingSession] = []
        var journalEntries: [JournalEntry] = []
        var settings: [String: Any] = [:]
        struct DeletionMarkerEvent {
            let type: String
            let id: String
        }
        var deletionMarkers: [DeletionMarkerEvent] = []
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
            
            self.rememberRecordType(record)
            
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
            case self.journalEntryRecordType:
                if let entry = self.createJournalEntry(from: record) {
                    changes.journalEntries.append(entry)
                }
            case self.deletionMarkerRecordType:
                if let type = record["type"] as? String,
                   let itemId = record["itemId"] as? String {
                    changes.deletionMarkers.append(.init(type: type, id: itemId))
                    print(" Deletion marker received (fresh) for \(type) \(itemId.prefix(8))…")
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
                    if let ckError = error as? CKError, ckError.code == .changeTokenExpired {
                        print(" Change token expired, clearing and retrying full sync")
                        self?.serverChangeToken = nil
                        Task {
                            try? await Task.sleep(nanoseconds: 1_000_000_000) 
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
            
            self.privateDatabase.add(operation)
        }
    }
    
    private func fetchChangesWithoutToken() async throws -> SyncChanges {
        print(" Performing fresh sync without change token")
        
        let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zoneID])
        
        var changes = SyncChanges()
        
        operation.configurationsByRecordZoneID = [
            zoneID: CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        ]
        
        operation.recordChangedBlock = { [weak self] record in
            guard let self = self else { return }
            
            self.rememberRecordType(record)
            
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
            case self.journalEntryRecordType:
                if let entry = self.createJournalEntry(from: record) {
                    changes.journalEntries.append(entry)
                }
            case self.deletionMarkerRecordType:
                if let type = record["type"] as? String,
                   let itemId = record["itemId"] as? String {
                    changes.deletionMarkers.append(.init(type: type, id: itemId))
                    print(" Deletion marker received (fresh) for \(type) \(itemId.prefix(8))…")
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
                print(" Fresh change token saved")
            }
            
            operation.recordZoneFetchCompletionBlock = { [weak self] _, token, _, _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    self?.serverChangeToken = token
                    print(" Fresh full sync completed")
                    continuation.resume(returning: changes)
                }
            }
            
            self.privateDatabase.add(operation)
        }
    }
    
    private func processChanges(_ changes: SyncChanges) async {
        // First apply tombstones so we don't resurrect items in merge steps
        await processDeletionMarkers(changes.deletionMarkers)
        await processDeletions(changes.deletedRecordIDs)
        
        await mergeTasks(changes.tasks)
        await mergeCategories(changes.categories)
        await mergeRewards(changes.rewards)
        await mergePointsHistory(changes.pointsHistory)
        await mergeTrackingSessions(changes.trackingSessions)
        await mergeJournalEntries(changes.journalEntries)
        
        if !changes.settings.isEmpty {
            await applySettings(changes.settings)
        }
        
        NotificationCenter.default.post(name: .cloudKitDataChanged, object: nil)
    }
    
    private var knownRecordTypes: [String: String] {
        get {
            if let data = UserDefaults.standard.data(forKey: "cloudkit_known_record_types"),
               let dict = try? JSONDecoder().decode([String: String].self, from: data) {
                return dict
            }
            return [:]
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "cloudkit_known_record_types")
            }
        }
    }
    
    private func knownType(for recordID: CKRecord.ID) -> String? {
        return knownRecordTypes[recordID.recordName]
    }
    
    private func rememberRecordType(_ record: CKRecord) {
        var map = knownRecordTypes
        map[record.recordID.recordName] = record.recordType
        knownRecordTypes = map
    }
    
    private func processDeletions(_ deletedIDs: [CKRecord.ID]) async {
        for recordID in deletedIDs {
            let idString = recordID.recordName
            
            guard let type = knownType(for: recordID) else {
                print(" Skipping deletion for unknown type recordID: \(idString)")
                continue
            }
            
            guard let uuid = UUID(uuidString: idString) else {
                print(" Skipping deletion for non-UUID recordID: \(idString)")
                continue
            }
            
            switch type {
            case taskRecordType:
                let tasks = TaskManager.shared.tasks
                if let taskIndex = tasks.firstIndex(where: { $0.id == uuid }) {
                    let task = tasks[taskIndex]
                    TaskManager.shared.removeTaskFromRemoteSync(task)
                    markAsDeleted(itemID: task.id.uuidString, type: .task)
                    print(" Deleted task from remote: \(task.name)")
                }
                
            case categoryRecordType:
                let categories = CategoryManager.shared.categories
                if let categoryIndex = categories.firstIndex(where: { $0.id == uuid }) {
                    let category = categories[categoryIndex]
                    await CategoryManager.shared.forceRemoveCategory(category)
                    markAsDeleted(itemID: category.id.uuidString, type: .category)
                    print(" Deleted category from remote: \(category.name)")
                }
                
            case rewardRecordType:
                let rewards = RewardManager.shared.rewards
                if let rewardIndex = rewards.firstIndex(where: { $0.id == uuid }) {
                    let reward = rewards[rewardIndex]
                    RewardManager.shared.removeReward(reward)
                    markAsDeleted(itemID: reward.id.uuidString, type: .reward)
                    print(" Deleted reward from remote: \(reward.name)")
                }
                
            case trackingSessionRecordType:
                let trackingSessions = TaskManager.shared.getTrackingSessions()
                if let sessionIndex = trackingSessions.firstIndex(where: { $0.id == uuid }) {
                    let session = trackingSessions[sessionIndex]
                    TaskManager.shared.deleteTrackingSession(session)
                    markAsDeleted(itemID: session.id.uuidString, type: .trackingSession)
                    print(" Deleted tracking session from remote: \(session.deviceDisplayInfo)")
                }
                
            case journalEntryRecordType:
                let entriesDict = JournalManager.shared.entriesByDay
                if let entryToDelete = entriesDict.values.first(where: { $0.id == uuid }) {
                    JournalManager.shared.deleteEntry(for: entryToDelete.date)
                    markAsDeleted(itemID: entryToDelete.id.uuidString, type: .journalEntry)
                    print(" Deleted journal entry from remote: \(entryToDelete.date)")
                }
                
            default:
                print(" Skipping deletion for unsupported type \(type) id: \(idString)")
            }
        }
    }
    
    private func processDeletionMarkers(_ markers: [SyncChanges.DeletionMarkerEvent]) async {
        guard !markers.isEmpty else { return }
        for marker in markers {
            let idString = marker.id
            guard let uuid = UUID(uuidString: idString) else { continue }
            
            switch marker.type {
            case "Category":
                let categories = CategoryManager.shared.categories
                if let idx = categories.firstIndex(where: { $0.id == uuid }) {
                    let category = categories[idx]
                    await CategoryManager.shared.forceRemoveCategory(category)
                    print(" Applied tombstone for Category \(category.name)")
                } else {
                    print(" Tombstone Category for unknown local id \(idString.prefix(8))…")
                }
                markAsDeleted(itemID: idString, type: .category)
                
            case "Reward":
                let rewards = RewardManager.shared.rewards
                if let idx = rewards.firstIndex(where: { $0.id == uuid }) {
                    let reward = rewards[idx]
                    RewardManager.shared.removeReward(reward)
                    print(" Applied tombstone for Reward \(reward.name)")
                } else {
                    print(" Tombstone Reward for unknown local id \(idString.prefix(8))…")
                }
                markAsDeleted(itemID: idString, type: .reward)
                
            case "TodoTask", "Task":
                let tasks = TaskManager.shared.tasks
                if let idx = tasks.firstIndex(where: { $0.id == uuid }) {
                    let task = tasks[idx]
                    TaskManager.shared.removeTaskFromRemoteSync(task)
                    markAsDeleted(itemID: task.id.uuidString, type: .task)
                    print(" Applied tombstone for Task \(task.name)")
                } else {
                    print(" Tombstone Task for unknown local id \(idString.prefix(8))…")
                }
                markAsDeleted(itemID: idString, type: .task)
                
            case "TrackingSession":
                let sessions = TaskManager.shared.getTrackingSessions()
                if let idx = sessions.firstIndex(where: { $0.id == uuid }) {
                    let session = sessions[idx]
                    TaskManager.shared.deleteTrackingSession(session)
                    print(" Applied tombstone for TrackingSession \(session.deviceDisplayInfo)")
                }
                markAsDeleted(itemID: idString, type: .trackingSession)
                
            case "JournalEntry":
                let entriesDict = JournalManager.shared.entriesByDay
                if let entryToDelete = entriesDict.values.first(where: { $0.id == uuid }) {
                    JournalManager.shared.deleteEntry(for: entryToDelete.date)
                    print(" Applied tombstone for JournalEntry \(entryToDelete.date)")
                }
                markAsDeleted(itemID: idString, type: .journalEntry)
                
            case "JournalPhoto":
                let entriesDict = JournalManager.shared.entriesByDay
                if let (date, entry) = entriesDict.first(where: { $0.value.photos.contains(where: { $0.id == uuid }) }) {
                    if let photo = entry.photos.first(where: { $0.id == uuid }) {
                        AttachmentService.deleteJournalPhoto(for: entry.id, photo: photo)
                        JournalManager.shared.removePhoto(withId: uuid, for: date)
                        print(" Applied tombstone for JournalPhoto \(uuid.uuidString.prefix(8))…")
                    }
                } else {
                    print(" Tombstone JournalPhoto for unknown local id \(idString.prefix(8))…")
                }
                markAsDeleted(itemID: idString, type: .journalPhoto)
                
            case "JournalVoiceMemo":
                let entriesDict = JournalManager.shared.entriesByDay
                if let (date, entry) = entriesDict.first(where: { $0.value.voiceMemos.contains(where: { $0.id == uuid }) }) {
                    if let memo = entry.voiceMemos.first(where: { $0.id == uuid }) {
                        if FileManager.default.fileExists(atPath: memo.audioPath) {
                            try? FileManager.default.removeItem(atPath: memo.audioPath)
                        }
                        JournalManager.shared.removeVoiceMemo(withId: uuid, for: date)
                        print(" Applied tombstone for JournalVoiceMemo \(uuid.uuidString.prefix(8))…")
                    }
                } else {
                    print(" Tombstone JournalVoiceMemo for unknown local id \(idString.prefix(8))…")
                }
                markAsDeleted(itemID: idString, type: .journalVoiceMemo)
                
            case "PointsHistory":
                markAsDeleted(itemID: idString, type: .pointsHistory)
                
            default:
                print(" Unknown tombstone type \(marker.type) for id \(idString)")
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
                continue 
            }
            
            if let localTask = localMap[remoteTask.id] {
                var mergedTask: TodoTask
                
                if remoteTask.lastModifiedDate > localTask.lastModifiedDate {
                    mergedTask = remoteTask
                    print(" Remote task is newer for \(remoteTask.name)")
                } else if localTask.lastModifiedDate > remoteTask.lastModifiedDate {
                    mergedTask = localTask
                    print(" Local task is newer for \(localTask.name)")
                } else {
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
                    print(" Same timestamp, merged completions for \(remoteTask.name)")
                }
                
                syncSubtaskCompletionStates(&mergedTask)
                
                if let index = mergedTasks.firstIndex(where: { $0.id == remoteTask.id }) {
                    mergedTasks[index] = mergedTask
                    hasChanges = true
                }
            } else {
                var newTask = remoteTask
                syncSubtaskCompletionStates(&newTask)
                mergedTasks.append(newTask)
                hasChanges = true
                print(" Added task from remote: \(remoteTask.name)")
            }
        }
        
        if hasChanges {
            TaskManager.shared.updateAllTasks(mergedTasks)
        }
    }
    
    private func mergeCategories(_ remoteCategories: [Category]) async {
        guard !remoteCategories.isEmpty else { return }
        
        let localCategories = CategoryManager.shared.categories
        
        var mergedCategories: [Category] = []
        var processedIds = Set<UUID>()
        var processedNames = Set<String>()
        
        for localCategory in localCategories {
            let normalizedName = localCategory.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if !processedIds.contains(localCategory.id) && !processedNames.contains(normalizedName) {
                mergedCategories.append(localCategory)
                processedIds.insert(localCategory.id)
                processedNames.insert(normalizedName)
            }
        }
        
        var hasChanges = false
        for remoteCategory in remoteCategories {
            if deletedItems.categories.contains(remoteCategory.id.uuidString) {
                continue 
            }
            
            let normalizedName = remoteCategory.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !processedIds.contains(remoteCategory.id) && !processedNames.contains(normalizedName) {
                mergedCategories.append(remoteCategory)
                processedIds.insert(remoteCategory.id)
                processedNames.insert(normalizedName)
                hasChanges = true
                print(" Added category from remote: \(remoteCategory.name)")
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
                print(" Added reward from remote: \(remoteReward.name)")
            }
        }
        
        if hasChanges {
            RewardManager.shared.importRewards(mergedRewards)
        }
    }
    
    private func mergePointsHistory(_ remoteHistory: [PointsHistory]) async {
        guard !remoteHistory.isEmpty else { return }
        
        var dailyPoints: [Date: Int] = [:]
        
        for entry in remoteHistory {
            let startOfDay = Calendar.current.startOfDay(for: entry.date)
            dailyPoints[startOfDay] = max(dailyPoints[startOfDay] ?? 0, entry.points)
        }
        
        let existingPoints = RewardManager.shared.dailyPointsHistory
        for (date, points) in dailyPoints {
            if existingPoints[date] == nil {
                RewardManager.shared.addPoints(points, on: date)
            }
        }
        
        print(" Synced \(remoteHistory.count) points history entries")
    }
    
    private func mergeTrackingSessions(_ remoteSessions: [TrackingSession]) async {
        guard !remoteSessions.isEmpty else { return }
        
        let localSessions = TaskManager.shared.getTrackingSessions()
        let localMap = Dictionary(uniqueKeysWithValues: localSessions.map { ($0.id, $0) })
        
        var mergedSessions = localSessions
        var hasChanges = false
        
        for remoteSession in remoteSessions {
            if deletedItems.trackingSessions.contains(remoteSession.id.uuidString) {
                continue 
            }
            
            if let localSession = localMap[remoteSession.id] {
                if remoteSession.lastModifiedDate > localSession.lastModifiedDate {
                    if let index = mergedSessions.firstIndex(where: { $0.id == remoteSession.id }) {
                        mergedSessions[index] = remoteSession
                        hasChanges = true
                        print(" Updated tracking session from \(remoteSession.deviceDisplayInfo)")
                    }
                }
            } else {
                mergedSessions.append(remoteSession)
                hasChanges = true
                print(" Added tracking session from \(remoteSession.deviceDisplayInfo) - \(formatDuration(remoteSession.effectiveWorkTime))")
            }
        }
        
        if hasChanges {
            TaskManager.shared.updateAllTrackingSessions(mergedSessions)
        }
    }
    
    private func mergeJournalEntries(_ remoteEntries: [JournalEntry]) async {
        guard !remoteEntries.isEmpty else { return }
        
        let localEntries = Array(JournalManager.shared.entriesByDay.values)
        let localMap = Dictionary(uniqueKeysWithValues: localEntries.map { ($0.id, $0) })
        
        var hasChanges = false
        let mergeEpsilon: TimeInterval = 120
        
        for remoteEntryRaw in remoteEntries {
            var remoteEntry = remoteEntryRaw
            
            if !deletedItems.journalPhotos.isEmpty {
                remoteEntry.photos.removeAll { deletedItems.journalPhotos.contains($0.id.uuidString) }
            }
            if !deletedItems.journalVoiceMemos.isEmpty {
                remoteEntry.voiceMemos.removeAll { deletedItems.journalVoiceMemos.contains($0.id.uuidString) }
            }
            
            if deletedItems.journalEntries.contains(remoteEntry.id.uuidString) {
                continue 
            }
            
            if let localEntry = localMap[remoteEntry.id] {
                if localEntry.isEmpty && !remoteEntry.isEmpty {
                    JournalManager.shared.importEntry(remoteEntry)
                    hasChanges = true
                    print(" Imported remote journal entry because local was empty for \(remoteEntry.date)")
                    continue
                }
                
                let timeDiff = abs(localEntry.updatedAt.timeIntervalSince(remoteEntry.updatedAt))
                let nearSimultaneous = timeDiff <= mergeEpsilon

                if nearSimultaneous {
                    JournalManager.shared.importEntry(remoteEntry)
                    hasChanges = true
                    print(" Near-simultaneous journal change, merging for \(remoteEntry.date)")
                } else if remoteEntry.updatedAt > localEntry.updatedAt {
                    JournalManager.shared.importEntry(remoteEntry)
                    hasChanges = true
                    print(" Remote journal entry is newer for \(remoteEntry.date)")
                } else if localEntry.updatedAt > remoteEntry.updatedAt {
                    print(" Local journal entry is newer for \(localEntry.date)")
                } else {
                    print(" Same timestamp for journal entry \(remoteEntry.date)")
                }
            } else {
                JournalManager.shared.importEntry(remoteEntry)
                hasChanges = true
                print(" Added journal entry from remote: \(remoteEntry.date)")
            }
        }
        
        if hasChanges {
            NotificationCenter.default.post(name: .journalEntriesChanged, object: nil)
        }
    }
    
    private func applySettings(_ settings: [String: Any]) async {
        for (key, value) in settings {
            UserDefaults.standard.set(value, forKey: "cloudkit_\(key)")
        }
        
        NotificationCenter.default.post(name: .cloudKitSettingsChanged, object: settings)
        print(" Applied remote settings: \(settings.keys)")
    }
    
    // MARK: - Record Creation
    private func createTaskRecord(from task: TodoTask) -> CKRecord {
        let recordID = CKRecord.ID(recordName: task.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: taskRecordType, recordID: recordID)
        
        record["name"] = task.name.isEmpty ? "untitled_task".localized : task.name
        record["taskDescription"] = task.description
        record["startTime"] = task.startTime
        record["hasSpecificTime"] = task.hasSpecificTime
        record["duration"] = max(0, task.duration) 
        record["hasDuration"] = task.hasDuration
        record["icon"] = task.icon.isEmpty ? "circle" : task.icon
        record["priority"] = task.priority.rawValue
        record["hasRewardPoints"] = task.hasRewardPoints
        record["rewardPoints"] = max(0, task.rewardPoints) 
        record["taskCreationDate"] = task.creationDate
        record["taskLastModifiedDate"] = task.lastModifiedDate
        
        record["timeScope"] = task.timeScope.rawValue
        record["scopeStartDate"] = task.scopeStartDate
        record["scopeEndDate"] = task.scopeEndDate
        
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
            print(" Error encoding complex objects for task: \(error)")
        }
        
        if let photoPath = task.photoPath {
            let url = URL(fileURLWithPath: photoPath)
            if FileManager.default.fileExists(atPath: url.path) {
                record["photo"] = CKAsset(fileURL: url)
            } else {
                record["photo"] = nil
            }
        } else {
            record["photo"] = nil
        }
        
        let photoAssets: [CKAsset] = task.photos.compactMap { p in
            let url = URL(fileURLWithPath: p.photoPath)
            return FileManager.default.fileExists(atPath: url.path) ? CKAsset(fileURL: url) : nil
        }
        if !photoAssets.isEmpty {
            record["photos"] = photoAssets
            if record["photo"] == nil {
                record["photo"] = photoAssets.first
            }
        } else {
            record["photos"] = nil
        }
        
        setVoiceMemos(on: record, for: task)
        
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
        
        let timeScopeRaw = record["timeScope"] as? String
        let decodedTimeScope = TaskTimeScope(rawValue: timeScopeRaw ?? "") ?? .today
        let decodedScopeStart: Date? = record["scopeStartDate"] as? Date
        let decodedScopeEnd: Date? = record["scopeEndDate"] as? Date
        
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
            rewardPoints: rewardPoints,
            hasNotification: false,
            notificationId: nil,
            timeScope: decodedTimeScope,
            scopeStartDate: decodedScopeStart,
            scopeEndDate: decodedScopeEnd
        )
        
        task.completions = completions
        task.completionDates = completionDates
        task.creationDate = creationDate ?? Date()
        task.lastModifiedDate = lastModifiedDate ?? Date()
        
        if let asset = record["photo"] as? CKAsset, let fileURL = asset.fileURL {
            if let data = try? Data(contentsOf: fileURL), let result = AttachmentService.savePhoto(for: uuid, imageData: data) {
                task.photoPath = result.photoPath
                task.photoThumbnailPath = result.thumbnailPath
            }
        }
        
        if let assets = record["photos"] as? [CKAsset], !assets.isEmpty {
            var imported: [TaskPhoto] = []
            for asset in assets {
                if let url = asset.fileURL,
                   let data = try? Data(contentsOf: url),
                   let added = AttachmentService.addPhoto(for: uuid, imageData: data) {
                    imported.append(added)
                }
            }
            if !imported.isEmpty {
                task.photos = imported
                if task.photoPath == nil, let first = imported.first {
                    task.photoPath = first.photoPath
                    task.photoThumbnailPath = first.thumbnailPath
                }
            }
        }
        
        if let metaData = record["voiceMemosMeta"] as? Data,
           let assets = record["voiceMemosAssets"] as? [CKAsset],
           let metas = try? JSONDecoder().decode([CloudVoiceMemoMeta].self, from: metaData),
           !assets.isEmpty, !metas.isEmpty {
            var memos: [TaskVoiceMemo] = []
            let count = min(assets.count, metas.count)
            for i in 0..<count {
                if let fileURL = assets[i].fileURL,
                   let data = try? Data(contentsOf: fileURL) {
                    if let memo = saveVoiceMemoData(taskId: uuid, data: data, id: metas[i].id, duration: metas[i].duration, createdAt: metas[i].createdAt, name: metas[i].name) {
                        memos.append(memo)
                    }
                }
            }
            if !memos.isEmpty {
                task.voiceMemos = memos.sorted { $0.createdAt > $1.createdAt }
            }
        }
        
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
    
    private struct CloudVoiceMemoMeta: Codable {
        let id: UUID
        let duration: TimeInterval
        let createdAt: Date
        let name: String?
    }
    
    private func setVoiceMemos(on record: CKRecord, for task: TodoTask) {
        let assets: [CKAsset] = task.voiceMemos.compactMap { memo in
            let url = URL(fileURLWithPath: memo.audioPath)
            return FileManager.default.fileExists(atPath: url.path) ? CKAsset(fileURL: url) : nil
        }
        if !assets.isEmpty {
            record["voiceMemosAssets"] = assets
            let metas = task.voiceMemos.map { CloudVoiceMemoMeta(id: $0.id, duration: $0.duration, createdAt: $0.createdAt, name: $0.name) }
            if let data = try? JSONEncoder().encode(metas) {
                record["voiceMemosMeta"] = data
            }
        } else {
            record["voiceMemosAssets"] = nil
            record["voiceMemosMeta"] = nil
        }
    }
    
    private func saveVoiceMemoData(taskId: UUID, data: Data, id: UUID, duration: TimeInterval, createdAt: Date, name: String? = nil) -> TaskVoiceMemo? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folder = docs.appendingPathComponent("Attachments", isDirectory: true).appendingPathComponent(taskId.uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let fileURL = folder.appendingPathComponent("memo_\(id.uuidString).m4a")
            try data.write(to: fileURL, options: .atomic)
            return TaskVoiceMemo(id: id, audioPath: fileURL.path, duration: duration, createdAt: createdAt, name: name)
        } catch {
            return nil
        }
    }
    
    private struct CloudJournalPhotoMeta: Codable {
        let id: UUID
        let createdAt: Date
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
              let frequency = RewardFrequency(rawValue: frequencyRaw) else {
            return nil
        }
        
        let id = UUID(uuidString: record.recordID.recordName) ?? UUID()
        
        return PointsHistory(id: id, date: date, points: points, frequency: frequency)
    }
    
    private func createSettingsRecord(from settings: [String: Any]) -> CKRecord {
        let recordID = CKRecord.ID(recordName: "AppSettings", zoneID: zoneID)
        let record = CKRecord(recordType: settingsRecordType, recordID: recordID)
        
        let jsonCompatibleSettings = makeJSONCompatible(settings)
        
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
                print(" Skipping non-JSON-serializable value for key \(key): \(type(of: value))")
            }
        }
        
        return result
    }
    
    private func createSettings(from record: CKRecord) -> [String: Any]? {
        guard let data = record["settings"] as? Data else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
    
    private func createJournalEntryRecord(from entry: JournalEntry) -> CKRecord {
        let recordID = CKRecord.ID(recordName: entry.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: journalEntryRecordType, recordID: recordID)
        
        record["date"] = entry.date
        record["title"] = entry.title
        record["text"] = entry.text
        record["entryCreatedAt"] = entry.createdAt
        record["entryUpdatedAt"] = entry.updatedAt
        
        if let mood = entry.mood {
            record["mood"] = mood.rawValue
        }
        
        if !entry.tags.isEmpty {
            record["tags"] = entry.tags
        }
        
        let photoAssets: [CKAsset] = entry.photos.compactMap { photo in
            let url = URL(fileURLWithPath: photo.photoPath)
            return FileManager.default.fileExists(atPath: url.path) ? CKAsset(fileURL: url) : nil
        }
        record["photos"] = photoAssets.isEmpty ? nil : photoAssets
        
        if !photoAssets.isEmpty {
            let metas = entry.photos.map { CloudJournalPhotoMeta(id: $0.id, createdAt: $0.createdAt) }
            if let data = try? JSONEncoder().encode(metas) {
                record["journalPhotosMeta"] = data
            }
        } else {
            record["journalPhotosMeta"] = nil
        }
        
        setJournalVoiceMemos(on: record, for: entry)
        
        return record
    }
    
    private func createJournalEntry(from record: CKRecord) -> JournalEntry? {
        guard let date = record["date"] as? Date,
              let uuid = UUID(uuidString: record.recordID.recordName) else {
            return nil
        }
        
        let title = record["title"] as? String ?? ""
        let text = record["text"] as? String ?? ""
        let createdAt = record["entryCreatedAt"] as? Date ?? record.creationDate ?? Date()
        let updatedAt = record["entryUpdatedAt"] as? Date ?? record.modificationDate ?? createdAt
        
        var mood: MoodType?
        if let moodRaw = record["mood"] as? String {
            mood = MoodType(rawValue: moodRaw)
        }
        
        let tags = record["tags"] as? [String] ?? []
        
        var photos: [JournalPhoto] = []
        if let assets = record["photos"] as? [CKAsset], !assets.isEmpty {
            if let metaData = record["journalPhotosMeta"] as? Data,
               let metas = try? JSONDecoder().decode([CloudJournalPhotoMeta].self, from: metaData),
               !metas.isEmpty {
                let count = min(assets.count, metas.count)
                for i in 0..<count {
                    if let url = assets[i].fileURL,
                       let data = try? Data(contentsOf: url),
                       let photo = saveJournalPhotoData(entryId: uuid, data: data, id: metas[i].id, createdAt: metas[i].createdAt) {
                        photos.append(photo)
                    }
                }
            } else {
                for asset in assets {
                    if let url = asset.fileURL,
                       let data = try? Data(contentsOf: url),
                       let photo = saveJournalPhotoData(entryId: uuid, data: data) {
                        photos.append(photo)
                    }
                }
            }
        }
        
        var voiceMemos: [JournalVoiceMemo] = []
        if let metaData = record["journalVoiceMemosMeta"] as? Data,
           let assets = record["journalVoiceMemosAssets"] as? [CKAsset],
           let metas = try? JSONDecoder().decode([CloudJournalVoiceMemoMeta].self, from: metaData),
           !assets.isEmpty, !metas.isEmpty {
            let count = min(assets.count, metas.count)
            for i in 0..<count {
                if let fileURL = assets[i].fileURL,
                   let data = try? Data(contentsOf: fileURL) {
                    if let memo = saveJournalVoiceMemoData(entryId: uuid, data: data, id: metas[i].id, duration: metas[i].duration, createdAt: metas[i].createdAt, name: metas[i].name) {
                        voiceMemos.append(memo)
                    }
                }
            }
        }
        
        return JournalEntry(
            id: uuid,
            date: date,
            title: title,
            text: text,
            mood: mood,
            tags: tags,
            voiceMemos: voiceMemos,
            photos: photos,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    private struct CloudJournalVoiceMemoMeta: Codable {
        let id: UUID
        let duration: TimeInterval
        let createdAt: Date
        let name: String?
    }
    
    private func setJournalVoiceMemos(on record: CKRecord, for entry: JournalEntry) {
        let assets: [CKAsset] = entry.voiceMemos.compactMap { memo in
            let url = URL(fileURLWithPath: memo.audioPath)
            return FileManager.default.fileExists(atPath: url.path) ? CKAsset(fileURL: url) : nil
        }
        if !assets.isEmpty {
            record["journalVoiceMemosAssets"] = assets
            let metas = entry.voiceMemos.map { CloudJournalVoiceMemoMeta(id: $0.id, duration: $0.duration, createdAt: $0.createdAt, name: $0.name) }
            if let data = try? JSONEncoder().encode(metas) {
                record["journalVoiceMemosMeta"] = data
            }
        } else {
            record["journalVoiceMemosAssets"] = nil
            record["journalVoiceMemosMeta"] = nil
        }
    }
    
    private func saveJournalPhotoData(entryId: UUID, data: Data) -> JournalPhoto? {
        let generatedId = UUID()
        let createdAt = Date()
        return AttachmentService.addJournalPhoto(for: entryId, imageData: data, id: generatedId, createdAt: createdAt)
    }
    
    private func saveJournalPhotoData(entryId: UUID, data: Data, id: UUID, createdAt: Date) -> JournalPhoto? {
        return AttachmentService.addJournalPhoto(for: entryId, imageData: data, id: id, createdAt: createdAt)
    }
    
    private func saveJournalVoiceMemoData(entryId: UUID, data: Data, id: UUID, duration: TimeInterval, createdAt: Date, name: String? = nil) -> JournalVoiceMemo? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folder = docs.appendingPathComponent("Attachments", isDirectory: true)
            .appendingPathComponent("Journal", isDirectory: true)
            .appendingPathComponent(entryId.uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let fileURL = folder.appendingPathComponent("journal_memo_\(id.uuidString).m4a")
            try data.write(to: fileURL, options: .atomic)
            return JournalVoiceMemo(id: id, audioPath: fileURL.path, duration: duration, createdAt: createdAt, name: name)
        } catch {
            return nil
        }
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
            print(" Saved deletion marker for \(type) \(id)")
        } catch {
            print(" Failed to save deletion marker for \(type) \(id): \(error)")
        }
    }
    
    // MARK: - Tracking Session Record Creation
    private func createTrackingSessionRecord(from session: TrackingSession) -> CKRecord {
        let recordID = CKRecord.ID(recordName: session.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: trackingSessionRecordType, recordID: recordID)
        
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
            print(" Failed to decode tracking session from record")
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
            print(" Failed to encode \(key): \(error)")
        }
    }
    
    private func decodeFromRecord<T: Codable>(_ record: CKRecord, key: String, type: T.Type = T.self) -> T? {
        guard let data = record[key] as? Data else { return nil }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            print(" Failed to decode \(key): \(error)")
            return nil
        }
    }
    
    private func canPerformSync() -> Bool {
        let now = Date()
        guard now.timeIntervalSince(lastSyncTime) >= minSyncInterval else {
            print(" Sync throttled - too frequent")
            return false
        }
        
        guard !isSyncing else {
            print(" Sync already in progress")
            return false
        }
        
        guard isCloudKitEnabled else {
            print(" CloudKit sync is disabled")
            return false
        }
        
        if syncRetryCount >= maxSyncRetries {
            let timeSinceLastError = now.timeIntervalSince(lastErrorTime)
            if timeSinceLastError < 300 { // 5 minutes
                print(" Max sync retries reached, cooling down")
                return false
            } else {
                syncRetryCount = 0 // Reset retry count after cooldown
            }
        }
        
        return true
    }
    
    // Removed duplicate stablePointsHistoryRecordID(for date: Date) function
    
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
        print(" Sync error: \(error)")
        
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
                print(" Change token expired - clearing token and retrying")
                syncStatus = .error("sync_token_expired".localized)
                serverChangeToken = nil
                if syncRetryCount < maxSyncRetries {
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                        await performFullSync()
                    }
                }
            case .serverRecordChanged:
                syncStatus = .error("sync_error".localized)
                if syncRetryCount < maxSyncRetries {
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                        await performFullSync()
                    }
                }
            default:
                if ckError.localizedDescription.contains("client knowledge differs") {
                    print(" Client knowledge differs from server - clearing token and retrying")
                    syncStatus = .error("sync_state_mismatch".localized)
                    serverChangeToken = nil
                    if syncRetryCount < maxSyncRetries {
                        Task {
                            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
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
        print(" CloudKit error: \(error.localizedDescription)")
        
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
            print(" Record conflict detected, will retry sync")
            if syncRetryCount < maxSyncRetries {
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    await performFullSync()
                }
            }
        case .unknownItem:
            print(" Item already deleted")
        case .constraintViolation:
            syncStatus = .error("sync_error".localized)
        case .zoneNotFound:
            syncStatus = .error("zone_missing_recreating".localized)
            try? await ensureZoneExists()
            if syncRetryCount < maxSyncRetries {
                Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
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
            let recordID = CKRecord.ID(recordName: task.id.uuidString, zoneID: zoneID)
            let serverRecord = try await privateDatabase.record(for: recordID)
            
            guard let currentTask = createTask(from: serverRecord) else {
                print(" Could not parse current task from CloudKit")
                return
            }
            
            let mergedTask = mergeTaskConflict(local: task, remote: currentTask)
            
            let updatedRecord = updateTaskRecord(serverRecord, with: mergedTask)
            
            let operation = CKModifyRecordsOperation(recordsToSave: [updatedRecord])
            operation.savePolicy = CKModifyRecordsOperation.RecordSavePolicy.changedKeys
            operation.isAtomic = false
            
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[CKRecord], Error>) in
                operation.modifyRecordsCompletionBlock = { (savedRecords: [CKRecord]?, deletedRecordIDs: [CKRecord.ID]?, error: Error?) in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: savedRecords ?? [])
                    }
                }
                self.privateDatabase.add(operation)
            }
            
            print(" Conflict resolved and task updated: \(mergedTask.name)")
            
        } catch {
            print(" Failed to resolve conflict for \(task.name): \(error)")
            if retryCount < 3 {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                saveTask(task, retryCount: retryCount + 1)
            }
        }
    }
    
    private func updateTaskRecord(_ existingRecord: CKRecord, with task: TodoTask) -> CKRecord {
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
        existingRecord["timeScope"] = task.timeScope.rawValue
        existingRecord["scopeStartDate"] = task.scopeStartDate
        existingRecord["scopeEndDate"] = task.scopeEndDate
        
        encodeToRecord(existingRecord, key: "category", value: task.category)
        encodeToRecord(existingRecord, key: "location", value: task.location)
        encodeToRecord(existingRecord, key: "recurrence", value: task.recurrence)
        encodeToRecord(existingRecord, key: "pomodoroSettings", value: task.pomodoroSettings)
        encodeToRecord(existingRecord, key: "subtasks", value: task.subtasks)
        encodeToRecord(existingRecord, key: "completions", value: task.completions)
        encodeToRecord(existingRecord, key: "completionDates", value: task.completionDates)
        
        if let photoPath = task.photoPath {
            let url = URL(fileURLWithPath: photoPath)
            if FileManager.default.fileExists(atPath: url.path) {
                existingRecord["photo"] = CKAsset(fileURL: url)
            } else {
                existingRecord["photo"] = nil
            }
        } else {
            existingRecord["photo"] = nil
        }
        
        let photoAssets: [CKAsset] = task.photos.compactMap { p in
            let url = URL(fileURLWithPath: p.photoPath)
            return FileManager.default.fileExists(atPath: url.path) ? CKAsset(fileURL: url) : nil
        }
        if !photoAssets.isEmpty {
            existingRecord["photos"] = photoAssets
            if existingRecord["photo"] == nil {
                existingRecord["photo"] = photoAssets.first
            }
        } else {
            existingRecord["photos"] = nil
        }
        
        setVoiceMemos(on: existingRecord, for: task)
        
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
        
        let allCompletionDates = Set(local.completionDates + remote.completionDates)
        merged.completionDates = Array(allCompletionDates).sorted()
        
        merged.lastModifiedDate = max(local.lastModifiedDate, remote.lastModifiedDate)
        
        syncSubtaskCompletionStates(&merged)
        
        print(" Merged conflict for task: \(merged.name) (using \(local.lastModifiedDate > remote.lastModifiedDate ? "local" : "remote") completion state)")
        return merged
    }
    
    // MARK: - Remote Notifications
    func processRemoteNotification(_ userInfo: [AnyHashable: Any]) {
        guard isCloudKitEnabled else { return }
        
        if let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) {
            if notification.subscriptionID == subscriptionID {
                print(" Received CloudKit notification")
                syncNow()
            }
        }
    }
    
    func clearDeletionMarkers() {
        deletedItems = DeletionTracker()
        print(" Cleared all deletion markers")
    }
    
    func resetSyncState() async {
        print(" Resetting CloudKit sync state")
        
        serverChangeToken = nil
        
        clearDeletionMarkers()
        
        syncStatus = .idle
        lastSyncDate = nil
        syncRetryCount = 0
        
        await performFullSync()
    }
    
    func clearSyncTokens() {
        print(" Clearing all sync tokens and state")
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
                "trackingSessions": deletedItems.trackingSessions.count,
                "journalEntries": deletedItems.journalEntries.count,
                "journalPhotos": deletedItems.journalPhotos.count,
                "journalVoiceMemos": deletedItems.journalVoiceMemos.count
            ]
        ]
    }
    
    func saveJournalEntry(_ entry: JournalEntry) {
        guard isCloudKitEnabled else { return }
        
        Task {
            do {
                let recordID = CKRecord.ID(recordName: entry.id.uuidString, zoneID: zoneID)
                
                let record: CKRecord
                do {
                    record = try await privateDatabase.record(for: recordID)
                } catch let error as CKError where error.code == .unknownItem {
                    record = CKRecord(recordType: journalEntryRecordType, recordID: recordID)
                }
                
                applyJournalEntry(entry, to: record)
                
                let op = CKModifyRecordsOperation(recordsToSave: [record])
                op.savePolicy = .changedKeys
                op.isAtomic = false
                
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    op.modifyRecordsCompletionBlock = { _, _, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: ())
                        }
                    }
                    self.privateDatabase.add(op)
                }
                
                DispatchQueue.main.async {
                    self.syncStatus = .success
                    self.lastSyncDate = Date()
                }
            } catch let ckError as CKError {
                if ckError.code == .serverRecordChanged {
                    await self.resolveJournalConflictAndSave(entry)
                } else {
                    await self.handleCloudKitError(ckError)
                }
            } catch {
                await self.handleSyncError(error)
            }
        }
    }
    
    func deleteJournalEntry(_ entry: JournalEntry) {
        guard isCloudKitEnabled else { return }
        
        markAsDeleted(itemID: entry.id.uuidString, type: .journalEntry)
        
        Task {
            do {
                let recordID = CKRecord.ID(recordName: entry.id.uuidString, zoneID: zoneID)
                _ = try await privateDatabase.deleteRecord(withID: recordID)
                await saveDeletionMarker(type: "JournalEntry", id: entry.id.uuidString)
            } catch let error as CKError {
                if error.code == .unknownItem {
                    await saveDeletionMarker(type: "JournalEntry", id: entry.id.uuidString)
                } else {
                    await handleCloudKitError(error)
                }
            } catch {
                await handleSyncError(error)
            }
        }
    }
    
    private func applyJournalEntry(_ entry: JournalEntry, to record: CKRecord) {
        record["date"] = entry.date
        record["title"] = entry.title
        record["text"] = entry.text
        record["entryCreatedAt"] = entry.createdAt
        record["entryUpdatedAt"] = entry.updatedAt
        
        if let mood = entry.mood {
            record["mood"] = mood.rawValue
        } else {
            record["mood"] = nil
        }
        
        record["tags"] = entry.tags.isEmpty ? nil : entry.tags
        
        let photoAssets: [CKAsset] = entry.photos.compactMap { photo in
            let url = URL(fileURLWithPath: photo.photoPath)
            return FileManager.default.fileExists(atPath: url.path) ? CKAsset(fileURL: url) : nil
        }
        record["photos"] = photoAssets.isEmpty ? nil : photoAssets
        
        if !photoAssets.isEmpty {
            let metas = entry.photos.map { CloudJournalPhotoMeta(id: $0.id, createdAt: $0.createdAt) }
            if let data = try? JSONEncoder().encode(metas) {
                record["journalPhotosMeta"] = data
            }
        } else {
            record["journalPhotosMeta"] = nil
        }
        
        setJournalVoiceMemos(on: record, for: entry)
    }
    
    private func resolveJournalConflictAndSave(_ entry: JournalEntry) async {
        do {
            let recordID = CKRecord.ID(recordName: entry.id.uuidString, zoneID: zoneID)
            let serverRecord = try await privateDatabase.record(for: recordID)
            
            if let remote = createJournalEntry(from: serverRecord) {
                var final = entry
                if remote.updatedAt > entry.updatedAt {
                    final = remote
                } else if remote.updatedAt == entry.updatedAt {
                    var merged = remote
                    if !entry.text.isEmpty && remote.text.isEmpty { merged.text = entry.text }
                    if !entry.title.isEmpty && remote.title.isEmpty { merged.title = entry.title }
                    if merged.mood == nil, let m = entry.mood { merged.mood = m }
                    merged.tags = Array(Set(merged.tags + entry.tags)).sorted()
                    
                    let photoMap = Dictionary(uniqueKeysWithValues: (merged.photos + entry.photos).map { ($0.id, $0) })
                    var mergedPhotos = Array(photoMap.values).sorted { $0.createdAt > $1.createdAt }
                    if !deletedItems.journalPhotos.isEmpty {
                        mergedPhotos.removeAll { deletedItems.journalPhotos.contains($0.id.uuidString) }
                    }
                    merged.photos = mergedPhotos
                    
                    let memoMap = Dictionary(uniqueKeysWithValues: (merged.voiceMemos + entry.voiceMemos).map { ($0.id, $0) })
                    merged.voiceMemos = Array(memoMap.values).sorted { $0.createdAt > $1.createdAt }
                    if !deletedItems.journalVoiceMemos.isEmpty {
                        merged.voiceMemos.removeAll { deletedItems.journalVoiceMemos.contains($0.id.uuidString) }
                    }
                    
                    final = merged
                }
                
                applyJournalEntry(final, to: serverRecord)
                
                let op = CKModifyRecordsOperation(recordsToSave: [serverRecord])
                op.savePolicy = .changedKeys
                op.isAtomic = false
                
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    op.modifyRecordsCompletionBlock = { _, _, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: ())
                        }
                    }
                    self.privateDatabase.add(op)
                }
            } else {
                let newRecord = createJournalEntryRecord(from: entry)
                _ = try await privateDatabase.save(newRecord)
            }
        } catch {
            await handleSyncError(error)
        }
    }
    
    func clearAllPointsHistory() async {
        guard isCloudKitEnabled else {
            print(" CloudKit disabled, skipping points history clear")
            return
        }
        
        do {
            var allIDs: [CKRecord.ID] = []
            var cursor: CKQueryOperation.Cursor? = nil
            
            repeat {
                let operation: CKQueryOperation
                if let c = cursor {
                    operation = CKQueryOperation(cursor: c)
                } else {
                    let query = CKQuery(recordType: pointsHistoryRecordType, predicate: NSPredicate(value: true))
                    operation = CKQueryOperation(query: query)
                    operation.zoneID = zoneID
                }
                
                operation.resultsLimit = 500
                operation.recordFetchedBlock = { record in
                    allIDs.append(record.recordID)
                }
                
                cursor = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKQueryOperation.Cursor?, Error>) in
                    operation.queryCompletionBlock = { nextCursor, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: nextCursor)
                        }
                    }
                    self.privateDatabase.add(operation)
                }
            } while cursor != nil
            
            guard !allIDs.isEmpty else {
                print(" No PointsHistory records to clear")
                return
            }
            
            let batchSize = 200
            for i in stride(from: 0, to: allIDs.count, by: batchSize) {
                let chunk = Array(allIDs[i..<min(i + batchSize, allIDs.count)])
                let op = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: chunk)
                _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    op.modifyRecordsCompletionBlock = { _, _, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: ())
                        }
                    }
                    self.privateDatabase.add(op)
                }
            }
            
            print(" Cleared \(allIDs.count) PointsHistory records from CloudKit")
        } catch {
            print(" Failed to clear PointsHistory from CloudKit: \(error)")
        }
    }
}