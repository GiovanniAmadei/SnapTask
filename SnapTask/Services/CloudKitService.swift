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
    private let financeEntryRecordType = "FinanceEntry"
    private let financeBudgetRecordType = "FinanceBudget"
    private let financialGoalRecordType = "FinancialGoal"
    private let customFinanceCategoryRecordType = "CustomFinanceCategory"
    private let taskListOrderRecordType = "TaskListOrder"
    /// Each device's tracked-time statistics (see `TimeTrackingStats`), added in 1.8.
    private let deviceTimeTrackingRecordType = "DeviceTimeTracking"
    
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
        var financeEntries: Set<String> = []
        var financeBudgets: Set<String> = []
        var financialGoals: Set<String> = []
        var customFinanceCategories: Set<String> = []
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
        case financeEntry = "financeEntry"
        case financeBudget = "financeBudget"
        case financialGoal = "financialGoal"
        case customFinanceCategory = "customFinanceCategory"
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
        case .financeEntry:
            tracker.financeEntries.insert(itemID)
        case .financeBudget:
            tracker.financeBudgets.insert(itemID)
        case .financialGoal:
            tracker.financialGoals.insert(itemID)
        case .customFinanceCategory:
            tracker.customFinanceCategories.insert(itemID)
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
        case .financeEntry:
            tracker.financeEntries.remove(itemID)
        case .financeBudget:
            tracker.financeBudgets.remove(itemID)
        case .financialGoal:
            tracker.financialGoals.remove(itemID)
        case .customFinanceCategory:
            tracker.customFinanceCategories.remove(itemID)
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
            await uploadLocalDataIfNeeded()
            
        } catch {
            await handleSyncError(error)
        }
    }
    
    private func ensureZoneExists() async throws {
        do {
            _ = try await privateDatabase.recordZone(for: zoneID)
            print(" Zone exists")
        } catch let error as CKError where error.code == .zoneNotFound || error.code == .userDeletedZone {
            print(" Zone missing or purged by user (code \(error.code.rawValue)). Recreating zone...")
            serverChangeToken = nil
            _ = try await privateDatabase.save(recordZone)
            print(" Zone created successfully")
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
        // Requests made while a sync runs are merged into one more pass (see `syncAndWait`).
        Task { await syncAndWait() }
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
        
        Task { await syncAndWait() }
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
            let record = createTaskRecord(from: task)
            do {
                try await saveOverwriting(record)
                markUploaded([record])
                print(" Task saved to CloudKit: \(task.name)")
                syncStatus = .success
                lastSyncDate = Date()
            } catch let error as CKError where error.code == .invalidArguments || error.code == .serverRejectedRequest {
                // Production schema without the 1.8 task fields: sync everything else.
                let fallback = createTaskRecord(from: task, includeFields18: false)
                do {
                    try await saveOverwriting(fallback)
                    markUploaded([fallback])
                    print(" Task saved without 1.8 fields: \(task.name)")
                } catch let retryError as CKError {
                    await handleCloudKitError(retryError)
                } catch {
                    await handleSyncError(error)
                }
            } catch let error as CKError {
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
                try await deleteRecordQueued(recordID)
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
    /// Categories saved here that iCloud has not confirmed yet.
    private var pendingCategoryUploads: Set<UUID> = []
    /// Other records (by name) saved here that iCloud has not confirmed yet.
    var pendingUploads: Set<String> = []
    /// Attachment signatures sent with saves still in flight, and the ones iCloud holds (see the
    /// Attachments extension).
    var mediaAwaitingUpload: [String: String?] = [:]
    var knownMediaCache: [String: String]?
    
    func saveCategory(_ category: Category) {
        guard isCloudKitEnabled else { return }
        if deletedItems.categories.contains(category.id.uuidString) {
            print(" Skipping CloudKit save for deleted category \(category.name)")
            return
        }
        pendingCategoryUploads.insert(category.id)
        
        Task {
            defer { pendingCategoryUploads.remove(category.id) }
            do {
                let record = createCategoryRecord(from: category)
                _ = try await saveOverwriting(record)
                print(" Category saved: \(category.name)")
            } catch let error as CKError where category.icon != nil
                        && (error.code == .invalidArguments || error.code == .serverRejectedRequest) {
                // The production schema may not have the "icon" field yet (added in 1.8):
                // sync name and color anyway, the icon stays local until the schema is deployed.
                print(" Category save rejected, retrying without icon: \(error.localizedDescription)")
                var withoutIcon = category
                withoutIcon.icon = nil
                do {
                    _ = try await saveOverwriting(createCategoryRecord(from: withoutIcon))
                    print(" Category saved without icon: \(category.name)")
                } catch let retryError as CKError {
                    await handleCloudKitError(retryError)
                } catch {
                    await handleSyncError(error)
                }
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
                try await deleteRecordQueued(recordID)
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
    
    /// Saves a record built locally from the app's current state, creating it or replacing the
    /// copy already on the server. A plain `save` of a new CKRecord fails with "record already
    /// exists" for anything synced before, so edits (archived rewards, renamed categories,
    /// updated sessions...) never reached iCloud.
    @discardableResult
    private func saveOverwriting(_ record: CKRecord) async throws -> CKRecord {
        do {
            let (results, _) = try await privateDatabase.modifyRecords(
                saving: [record], deleting: [], savePolicy: .allKeys, atomically: false
            )
            let saved = try results[record.recordID]?.get() ?? record
            outboxDidSave(record.recordID.recordName)
            return saved
        } catch {
            // Offline or iCloud busy: keep it and send it on the next sync.
            if Self.isRetryable(error) { outboxQueueSave(record) }
            throw error
        }
    }
    
    /// Deletes a record, keeping the deletion for the next sync if iCloud can't be reached.
    private func deleteRecordQueued(_ recordID: CKRecord.ID) async throws {
        do {
            try await deleteRecordQueued(recordID)
            outboxDidDelete(recordID.recordName)
        } catch {
            if let ckError = error as? CKError, ckError.code == .unknownItem {
                outboxDidDelete(recordID.recordName)
            } else if Self.isRetryable(error) {
                outboxQueueDelete(recordID.recordName)
            }
            throw error
        }
    }
    
    // MARK: - Reward Operations
    func saveReward(_ reward: Reward) {
        guard isCloudKitEnabled else { return }
        
        Task {
            do {
                let record = createRewardRecord(from: reward)
                _ = try await saveOverwriting(record)
                print(" Reward saved: \(reward.name)")
            } catch let error as CKError where error.code == .invalidArguments || error.code == .serverRejectedRequest {
                // Production schema without the 1.8 fields: save the old fields so the rest still syncs.
                let record = createRewardRecord(from: reward)
                for key in ["categoryId", "categoryName", "archivedDate"] { record[key] = nil }
                do {
                    _ = try await saveOverwriting(record)
                    print(" Reward saved without 1.8 fields: \(reward.name)")
                } catch {
                    print(" Failed to save reward: \(error)")
                }
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
                try await deleteRecordQueued(recordID)
                await saveDeletionMarker(type: "Reward", id: reward.id.uuidString)
                print(" Reward deleted: \(reward.name)")
            } catch let error as CKError where error.code == .unknownItem {
                print(" Reward already deleted")
            } catch {
                print(" Failed to delete reward: \(error)")
            }
        }
    }
    
    // MARK: - Task List Order Operations
    func saveTaskListOrder(_ order: TaskListOrder) {
        guard isCloudKitEnabled else { return }
        
        Task {
            do {
                // Record con nome fisso per lista: .allKeys lo sovrascrive senza conflitti
                try await saveOverwriting(createTaskListOrderRecord(from: order))
                print(" Task list order saved: \(order.listKey)")
            } catch {
                // Senza il tipo TaskListOrder nello schema di produzione l'ordine resta solo locale
                print(" Failed to save task list order: \(error)")
            }
        }
    }
    
    // MARK: - Points History Operations
    func savePointsEntry(_ entry: PointsHistory) {
        guard isCloudKitEnabled else { return }
        
        Task {
            do {
                let record = createPointsHistoryRecord(from: entry)
                _ = try await saveOverwriting(record)
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
                    operation.savePolicy = .allKeys // overwrite days already on the server
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
                let recordID = CKRecord.ID(recordName: "AppSettings", zoneID: zoneID)
                
                // Fetch existing record so we can mutate it (preserves changeTag, avoids conflict errors)
                let record: CKRecord
                do {
                    record = try await privateDatabase.record(for: recordID)
                } catch let ckError as CKError where ckError.code == .unknownItem || ckError.code == .zoneNotFound || ckError.code == .userDeletedZone {
                    record = CKRecord(recordType: settingsRecordType, recordID: recordID)
                }
                
                // Merge: start from what's already stored in the record, overlay new keys
                var mergedSettings: [String: Any] = [:]
                if let existing = createSettings(from: record) {
                    mergedSettings = existing
                }
                for (key, value) in settings {
                    mergedSettings[key] = value
                }
                
                let jsonCompatible = makeJSONCompatible(mergedSettings)
                if let data = try? JSONSerialization.data(withJSONObject: jsonCompatible) {
                    record["settings"] = data
                }
                record["lastUpdated"] = Date()
                
                _ = try await saveOverwriting(record)
                print("✅ App settings saved (merged \(mergedSettings.count) keys)")
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
                _ = try await saveOverwriting(record)
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
                try await deleteRecordQueued(recordID)
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
    // One sync at a time. A request that arrives while one runs (a push from another device, the
    // app coming to the foreground, a local save) is not dropped: one more pass runs right after.
    private var syncInFlight = false
    private var syncRequestedAgain = false
    
    /// Runs a sync and returns when it (and any pass requested meanwhile) has finished.
    func syncAndWait() async {
        guard isCloudKitEnabled else { return }
        if syncInFlight {
            syncRequestedAgain = true
            while syncInFlight { try? await Task.sleep(nanoseconds: 100_000_000) }
            return
        }
        syncInFlight = true
        isSyncing = true
        syncStatus = .syncing
        repeat {
            syncRequestedAgain = false
            await performSyncPass()
        } while syncRequestedAgain && isCloudKitEnabled
        syncInFlight = false
        isSyncing = false
    }
    
    private func performFullSync() async {
        await syncAndWait()
    }
    
    private func performSyncPass() async {
        lastSyncTime = Date()
        await flushOutbox()
        do {
            let (changes, newToken) = try await fetchChanges()
            await processChanges(changes)
            // Saved only once the changes are applied: if the app is closed halfway through,
            // the next sync fetches them again instead of skipping them.
            serverChangeToken = newToken
            persistKnownMedia()
            await uploadTimeTrackingStatsIfNeeded()
            
            syncStatus = .success
            lastSyncDate = Date()
            syncRetryCount = 0
        } catch {
            await handleSyncError(error)
        }
    }
    

    // MARK: - Tracked Time Statistics
    private static let uploadedTimeTrackingKey = "cloudkit_uploaded_time_tracking"
    
    /// Sends this device's tracked-time statistics when they changed since the last upload.
    private func uploadTimeTrackingStatsIfNeeded() async {
        guard let hours = try? JSONSerialization.data(withJSONObject: TimeTrackingStats.local, options: [.sortedKeys]),
              let metadata = try? JSONSerialization.data(withJSONObject: TimeTrackingStats.localMetadata, options: [.sortedKeys]) else { return }
        let fingerprint = hours + metadata
        guard UserDefaults.standard.data(forKey: Self.uploadedTimeTrackingKey) != fingerprint else { return }
        
        let deviceId = TimeTrackingStats.deviceId
        let recordID = CKRecord.ID(recordName: "timetracking-\(deviceId)", zoneID: zoneID)
        let record = CKRecord(recordType: deviceTimeTrackingRecordType, recordID: recordID)
        record["deviceId"] = deviceId
        record["hours"] = hours
        record["metadata"] = metadata
        do {
            try await saveOverwriting(record)
            UserDefaults.standard.set(fingerprint, forKey: Self.uploadedTimeTrackingKey)
        } catch {
            // Until the record type is in the production schema the statistics stay per device.
            print(" Tracked time statistics not uploaded: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Initial Local Upload
    // Uploads all local tasks and rewards to CloudKit once, so existing data
    // on iPhone becomes visible on new devices (iPad, etc.).
    private func uploadLocalDataIfNeeded() async {
        let uploadDoneKey = "cloudkit_initial_upload_v4_done" // v4: includes finance settings
        guard !UserDefaults.standard.bool(forKey: uploadDoneKey) else {
            print(" Initial upload already done, skipping")
            return
        }
        guard isCloudKitEnabled else { return }
        
        print(" Starting initial upload of local data to CloudKit...")
        
        // Upload tasks
        let tasks = await MainActor.run { TaskManager.shared.tasks }
        if !tasks.isEmpty {
            let taskRecords = tasks.map { createTaskRecord(from: $0) }
            do {
                try await batchSaveRecords(taskRecords)
                print(" Initial upload: \(tasks.count) tasks uploaded")
            } catch {
                print(" Initial task upload failed: \(error) — will retry next launch")
                return
            }
        }
        
        // Upload rewards
        let rewards = await MainActor.run { RewardManager.shared.rewards }
        if !rewards.isEmpty {
            let rewardRecords = rewards.map { createRewardRecord(from: $0) }
            do {
                try await batchSaveRecords(rewardRecords)
                print(" Initial upload: \(rewards.count) rewards uploaded")
            } catch {
                print(" Initial reward upload failed: \(error) — will retry next launch")
                return
            }
        }

        // Upload finance
        let financeEntries = await MainActor.run { FinanceManager.shared.entries }
        if !financeEntries.isEmpty {
            let records = financeEntries.map { createFinanceEntryRecord(from: $0) }
            do {
                try await batchSaveRecords(records)
                print(" Initial upload: \(financeEntries.count) finance entries uploaded")
            } catch {
                print(" Initial finance entries upload failed: \(error) — will retry next launch")
                return
            }
        }

        let financeBudgets = await MainActor.run { FinanceManager.shared.budgets }
        if !financeBudgets.isEmpty {
            let records = financeBudgets.map { createFinanceBudgetRecord(from: $0) }
            do {
                try await batchSaveRecords(records)
                print(" Initial upload: \(financeBudgets.count) finance budgets uploaded")
            } catch {
                print(" Initial finance budgets upload failed: \(error) — will retry next launch")
                return
            }
        }

        let financeGoals = await MainActor.run { FinanceManager.shared.financialGoals }
        if !financeGoals.isEmpty {
            let records = financeGoals.map { createFinancialGoalRecord(from: $0) }
            do {
                try await batchSaveRecords(records)
                print(" Initial upload: \(financeGoals.count) finance goals uploaded")
            } catch {
                print(" Initial finance goals upload failed: \(error) — will retry next launch")
                return
            }
        }

        let customFinanceCategories = await MainActor.run { FinanceManager.shared.customCategories }
        if !customFinanceCategories.isEmpty {
            let records = customFinanceCategories.map { createCustomFinanceCategoryRecord(from: $0) }
            do {
                try await batchSaveRecords(records)
                print(" Initial upload: \(customFinanceCategories.count) custom finance categories uploaded")
            } catch {
                print(" Initial custom finance categories upload failed: \(error) — will retry next launch")
                return
            }
        }
        
        // Upload finance settings
        let financeSettings: [String: Any] = await MainActor.run {
            let fm = FinanceManager.shared
            return [
                "finance_startingBalance": fm.startingBalance,
                "finance_monthlyBudgetTarget": fm.monthlyBudgetTarget,
                "finance_savingsGoalPercent": fm.savingsGoalPercent,
                "finance_savingsGoalAmount": fm.savingsGoalAmount,
                "finance_savingsGoalIsPercent": fm.savingsGoalIsPercent,
                "finance_monthlyIncomeGoal": fm.monthlyIncomeGoal,
                "finance_selectedCurrency": fm.selectedCurrency.rawValue,
                "lastUpdated": Date().timeIntervalSince1970,
                "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
            ]
        }
        do {
            let recordID = CKRecord.ID(recordName: "AppSettings", zoneID: zoneID)
            let record: CKRecord
            do {
                record = try await privateDatabase.record(for: recordID)
            } catch let ckError as CKError where ckError.code == .unknownItem || ckError.code == .zoneNotFound || ckError.code == .userDeletedZone {
                record = CKRecord(recordType: settingsRecordType, recordID: recordID)
            }
            var mergedSettings: [String: Any] = createSettings(from: record) ?? [:]
            for (key, value) in financeSettings { mergedSettings[key] = value }
            let jsonCompatible = makeJSONCompatible(mergedSettings)
            if let data = try? JSONSerialization.data(withJSONObject: jsonCompatible) {
                record["settings"] = data
            }
            record["lastUpdated"] = Date()
            _ = try await privateDatabase.save(record)
            print("✅ Initial upload: finance settings uploaded")
        } catch {
            print("⚠️ Initial finance settings upload failed: \(error) — will retry next launch")
            return
        }

        // Mark as done only if everything succeeded
        UserDefaults.standard.set(true, forKey: uploadDoneKey)
        print(" Initial upload completed successfully")
    }
    
    private func batchSaveRecords(_ records: [CKRecord]) async throws {
        let batchSize = 100
        for i in stride(from: 0, to: records.count, by: batchSize) {
            let batch = Array(records[i..<min(i + batchSize, records.count)])
            let operation = CKModifyRecordsOperation(recordsToSave: batch)
            operation.savePolicy = .allKeys
            operation.isAtomic = false
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                operation.modifyRecordsCompletionBlock = { _, _, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
                self.privateDatabase.add(operation)
            }
            markUploaded(batch)
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
        var financeEntries: [FinanceEntry] = []
        var financeBudgets: [FinanceBudget] = []
        var financialGoals: [FinancialGoal] = []
        var customFinanceCategories: [CustomFinanceCategory] = []
        var taskListOrders: [TaskListOrder] = []
        var deviceTimeTracking: [(deviceId: String, hours: TimeTrackingStats.Hours, metadata: TimeTrackingStats.Metadata)] = []
        struct DeletionMarkerEvent {
            let type: String
            let id: String
        }
        var deletionMarkers: [DeletionMarkerEvent] = []
        var deletedRecords: [(id: CKRecord.ID, type: String)] = []
    }
    
    /// Fetches everything that changed since the last sync, all pages of it (iCloud sends large
    /// sets in several batches), and the token to store once the changes are applied.
    private func fetchChanges() async throws -> (SyncChanges, CKServerChangeToken?) {
        var changes = SyncChanges()
        var token = serverChangeToken
        var moreComing = true
        var restarts = 0
        
        while moreComing {
            let page: (modificationResultsByID: [CKRecord.ID: Result<CKDatabase.RecordZoneChange.Modification, Error>],
                       deletions: [CKDatabase.RecordZoneChange.Deletion],
                       changeToken: CKServerChangeToken,
                       moreComing: Bool)
            do {
                page = try await privateDatabase.recordZoneChanges(inZoneWith: zoneID, since: token)
            } catch let error as CKError where error.code == .changeTokenExpired && restarts < 2 {
                print(" Change token expired, fetching everything again")
                restarts += 1
                token = nil
                changes = SyncChanges()
                continue
            }
            
            for (_, result) in page.modificationResultsByID {
                if case .success(let modification) = result {
                    collect(modification.record, into: &changes)
                }
            }
            for deletion in page.deletions {
                changes.deletedRecords.append((deletion.recordID, deletion.recordType))
            }
            token = page.changeToken
            moreComing = page.moreComing
        }
        
        // A record changed and then deleted within the same fetch must not come back.
        if !changes.deletedRecords.isEmpty {
            let deleted = Set(changes.deletedRecords.map { $0.id.recordName })
            changes.tasks.removeAll { deleted.contains($0.id.uuidString) }
            changes.categories.removeAll { deleted.contains($0.id.uuidString) }
            changes.rewards.removeAll { deleted.contains($0.id.uuidString) }
            changes.trackingSessions.removeAll { deleted.contains($0.id.uuidString) }
        }
        
        return (changes, token)
    }
    
    private func collect(_ record: CKRecord, into changes: inout SyncChanges) {
        switch record.recordType {
        case taskRecordType:
            if let task = createTask(from: record) { changes.tasks.append(task) }
        case categoryRecordType:
            if let category = createCategory(from: record) { changes.categories.append(category) }
        case rewardRecordType:
            if let reward = createReward(from: record) { changes.rewards.append(reward) }
        case pointsHistoryRecordType:
            break // points are worked out on each device from tasks and redemptions
        case settingsRecordType:
            if let settings = createSettings(from: record) { changes.settings = settings }
        case trackingSessionRecordType:
            if let session = createTrackingSession(from: record) { changes.trackingSessions.append(session) }
        case journalEntryRecordType:
            if let entry = createJournalEntry(from: record) { changes.journalEntries.append(entry) }
        case financeEntryRecordType:
            if let entry = createFinanceEntry(from: record) { changes.financeEntries.append(entry) }
        case financeBudgetRecordType:
            if let budget = createFinanceBudget(from: record) { changes.financeBudgets.append(budget) }
        case financialGoalRecordType:
            if let goal = createFinancialGoal(from: record) { changes.financialGoals.append(goal) }
        case customFinanceCategoryRecordType:
            if let category = createCustomFinanceCategory(from: record) { changes.customFinanceCategories.append(category) }
        case taskListOrderRecordType:
            if let order = createTaskListOrder(from: record) { changes.taskListOrders.append(order) }
        case deviceTimeTrackingRecordType:
            if let deviceId = record["deviceId"] as? String,
               let hoursData = record["hours"] as? Data,
               let hours = (try? JSONSerialization.jsonObject(with: hoursData)) as? TimeTrackingStats.Hours {
                let metadata = (record["metadata"] as? Data).flatMap { (try? JSONSerialization.jsonObject(with: $0)) as? TimeTrackingStats.Metadata } ?? [:]
                changes.deviceTimeTracking.append((deviceId, hours, metadata))
            }
        case deletionMarkerRecordType:
            if let type = record["type"] as? String, let itemId = record["itemId"] as? String {
                changes.deletionMarkers.append(.init(type: type, id: itemId))
            }
        default:
            break
        }
    }
    

    private func processChanges(_ changes: SyncChanges) async {
        // First apply tombstones so we don't resurrect items in merge steps
        await processDeletionMarkers(changes.deletionMarkers)
        await processDeletions(changes.deletedRecords)
        
        await mergeTasks(changes.tasks)
        await mergeCategories(changes.categories)
        await mergeRewards(changes.rewards)
        await mergeTrackingSessions(changes.trackingSessions)
        await mergeJournalEntries(changes.journalEntries)
        await mergeFinanceData(entries: changes.financeEntries, budgets: changes.financeBudgets, goals: changes.financialGoals, customCategories: changes.customFinanceCategories)
        TaskOrderManager.shared.mergeRemote(changes.taskListOrders)
        
        if !changes.deviceTimeTracking.isEmpty {
            for copy in changes.deviceTimeTracking {
                TimeTrackingStats.applyRemote(deviceId: copy.deviceId, hours: copy.hours, metadata: copy.metadata)
            }
            NotificationCenter.default.post(name: .timeTrackingUpdated, object: nil)
        }
        
        if !changes.settings.isEmpty {
            await applySettings(changes.settings)
        }
        
        // Points come from completed tasks and redemptions: bring them in line with what arrived.
        let deletedTypes = Set(changes.deletedRecords.map(\.type))
        let pointsSourcesChanged = !changes.tasks.isEmpty || !changes.rewards.isEmpty
            || deletedTypes.contains(taskRecordType) || deletedTypes.contains(rewardRecordType)
            || changes.deletionMarkers.contains { ["TodoTask", "Task", "Reward"].contains($0.type) }
        if pointsSourcesChanged {
            RewardManager.shared.recalculateDailyPointsFromSources()
        }
        
        NotificationCenter.default.post(name: .cloudKitDataChanged, object: nil)
    }
    
    private func processDeletions(_ deleted: [(id: CKRecord.ID, type: String)]) async {
        for (recordID, type) in deleted {
            let idString = recordID.recordName
            
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

            case financeEntryRecordType:
                let entries = FinanceManager.shared.entries
                if let idx = entries.firstIndex(where: { $0.id == uuid }) {
                    let entry = entries[idx]
                    FinanceManager.shared.removeEntry(entry)
                    markAsDeleted(itemID: entry.id.uuidString, type: .financeEntry)
                    print(" Deleted finance entry from remote: \(entry.name)")
                }

            case financeBudgetRecordType:
                let budgets = FinanceManager.shared.budgets
                if let idx = budgets.firstIndex(where: { $0.id == uuid }) {
                    let budget = budgets[idx]
                    FinanceManager.shared.removeBudget(budget)
                    markAsDeleted(itemID: budget.id.uuidString, type: .financeBudget)
                    print(" Deleted finance budget from remote: \(budget.category.displayName)")
                }

            case financialGoalRecordType:
                let goals = FinanceManager.shared.financialGoals
                if let idx = goals.firstIndex(where: { $0.id == uuid }) {
                    let goal = goals[idx]
                    FinanceManager.shared.removeFinancialGoal(goal)
                    markAsDeleted(itemID: goal.id.uuidString, type: .financialGoal)
                    print(" Deleted financial goal from remote: \(goal.name)")
                }

            case customFinanceCategoryRecordType:
                let categories = FinanceManager.shared.customCategories
                if let idx = categories.firstIndex(where: { $0.id == uuid }) {
                    let category = categories[idx]
                    FinanceManager.shared.removeCustomCategory(category)
                    markAsDeleted(itemID: category.id.uuidString, type: .customFinanceCategory)
                    print(" Deleted custom finance category from remote: \(category.name)")
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
                
            case "FinanceEntry":
                let entries = FinanceManager.shared.entries
                if let idx = entries.firstIndex(where: { $0.id == uuid }) {
                    let entry = entries[idx]
                    FinanceManager.shared.removeEntry(entry)
                    print(" Applied tombstone for FinanceEntry \(entry.name)")
                }
                
            case "FinanceBudget":
                let budgets = FinanceManager.shared.budgets
                if let idx = budgets.firstIndex(where: { $0.id == uuid }) {
                    let budget = budgets[idx]
                    FinanceManager.shared.removeBudget(budget)
                    print(" Applied tombstone for FinanceBudget \(budget.category.displayName)")
                }
                
            case "FinancialGoal":
                let goals = FinanceManager.shared.financialGoals
                if let idx = goals.firstIndex(where: { $0.id == uuid }) {
                    let goal = goals[idx]
                    FinanceManager.shared.removeFinancialGoal(goal)
                    print(" Applied tombstone for FinancialGoal \(goal.name)")
                }
                
            case "CustomFinanceCategory":
                let categories = FinanceManager.shared.customCategories
                if let idx = categories.firstIndex(where: { $0.id == uuid }) {
                    let category = categories[idx]
                    FinanceManager.shared.removeCustomCategory(category)
                    print(" Applied tombstone for CustomFinanceCategory \(category.name)")
                }
                
            default:
                print(" Unknown tombstone type \(marker.type) for id \(idString)")
            }
        }
    }
    
    private func mergeTasks(_ remoteTasks: [TodoTask]) async {
        guard !remoteTasks.isEmpty else { return }
        
        let localTasks = TaskManager.shared.tasks
        let localMap = Dictionary(localTasks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let deleted = deletedItems.tasks
        
        var mergedTasks = localTasks
        var hasChanges = false
        var toUpload: [TodoTask] = []
        
        for remoteTask in remoteTasks {
            if deleted.contains(remoteTask.id.uuidString) {
                continue 
            }
            
            if let localTask = localMap[remoteTask.id] {
                // Fields from the copy edited last; completions day by day (newest change wins).
                // iCloud keeps dates to the millisecond: this device's own copy coming back is
                // the same edit, not an older one.
                let remoteWins = remoteTask.lastModifiedDate >= localTask.lastModifiedDate.addingTimeInterval(-0.002)
                var mergedTask = remoteWins ? remoteTask : localTask
                let completions = TodoTask.mergedCompletions(local: localTask, remote: remoteTask, preferRemote: remoteWins)
                mergedTask.completions = completions.completions
                mergedTask.completionDates = completions.completionDates
                // Notifications are scheduled per device: keep this device's.
                if localTask.hasNotification && !remoteTask.hasNotification && remoteWins {
                    mergedTask.hasNotification = true
                }
                mergedTask.notificationId = localTask.notificationId ?? mergedTask.notificationId
                
                syncSubtaskCompletionStates(&mergedTask)
                // Files of photos/memos the kept version no longer has (removed on the other
                // device, or downloaded for a copy that lost).
                removeAttachments(of: localTask, notIn: mergedTask)
                removeAttachments(of: remoteTask, notIn: mergedTask)
                // iCloud lacks something this device has (a day completed here, a newer edit):
                // send the combined copy so the other devices get it too.
                // (Edits to the other fields are sent by the save that made them, or the outbox.)
                if mergedTask.completions != remoteTask.completions
                    || Set(mergedTask.completionDates) != Set(remoteTask.completionDates) {
                    toUpload.append(mergedTask)
                }
                
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
        for task in toUpload {
            saveTask(task)
        }
    }
    
    private func mergeCategories(_ remoteCategories: [Category]) async {
        guard !remoteCategories.isEmpty else { return }
        
        let deleted = deletedItems.categories
        // A category edited here and still uploading must not be overwritten by the old copy.
        let incoming = remoteCategories.filter {
            !deleted.contains($0.id.uuidString) && !pendingCategoryUploads.contains($0.id)
        }
        CategoryManager.shared.applyRemoteCategories(incoming)
    }
    
    private func mergeRewards(_ remoteRewards: [Reward]) async {
        guard !remoteRewards.isEmpty else { return }
        
        let deleted = deletedItems.rewards
        let localMap = Dictionary(RewardManager.shared.rewards.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var incoming: [Reward] = []
        var toUpload: [Reward] = []
        
        for remoteReward in remoteRewards where !deleted.contains(remoteReward.id.uuidString) {
            guard let localReward = localMap[remoteReward.id] else {
                var added = remoteReward
                added.redemptions = Reward.normalizedRedemptions(added.redemptions)
                incoming.append(added)
                print(" Added reward from remote: \(remoteReward.name)")
                continue
            }
            let merged = Reward.merged(local: localReward, remote: remoteReward)
            if merged != localReward { incoming.append(merged) }
            // iCloud is behind (a newer local edit, redemptions it lacks, or duplicates to clean):
            // send the merged copy so every device ends up with the same reward.
            if merged != remoteReward { toUpload.append(merged) }
        }
        
        if !incoming.isEmpty {
            RewardManager.shared.importRewards(incoming)
        }
        for reward in toUpload {
            saveReward(reward)
        }
    }
    
    private func mergeTrackingSessions(_ remoteSessions: [TrackingSession]) async {
        guard !remoteSessions.isEmpty else { return }
        
        let localSessions = TaskManager.shared.getTrackingSessions()
        let localMap = Dictionary(localSessions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let deleted = deletedItems.trackingSessions
        
        var mergedSessions = localSessions
        var hasChanges = false
        
        for remoteSession in remoteSessions {
            if deleted.contains(remoteSession.id.uuidString) {
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
        let localMap = Dictionary(localEntries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        
        var hasChanges = false
        let mergeEpsilon: TimeInterval = 120
        
        let deleted = deletedItems
        for remoteEntryRaw in remoteEntries {
            var remoteEntry = remoteEntryRaw
            
            remoteEntry.photos.removeAll { deleted.journalPhotos.contains($0.id.uuidString) }
            remoteEntry.voiceMemos.removeAll { deleted.journalVoiceMemos.contains($0.id.uuidString) }
            
            if deleted.journalEntries.contains(remoteEntry.id.uuidString) {
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
    
    private func mergeFinanceData(entries: [FinanceEntry], budgets: [FinanceBudget], goals: [FinancialGoal], customCategories: [CustomFinanceCategory]) async {
        guard !entries.isEmpty || !budgets.isEmpty || !goals.isEmpty || !customCategories.isEmpty else { return }
        
        // Deleted here, or edited here and still uploading: iCloud's older copy must not win.
        let deleted = deletedItems
        let entries = entries.filter { !deleted.financeEntries.contains($0.id.uuidString) && !pendingUploads.contains($0.id.uuidString) }
        let budgets = budgets.filter { !deleted.financeBudgets.contains($0.id.uuidString) && !pendingUploads.contains($0.id.uuidString) }
        let goals = goals.filter { !deleted.financialGoals.contains($0.id.uuidString) && !pendingUploads.contains($0.id.uuidString) }
        let customCategories = customCategories.filter { !deleted.customFinanceCategories.contains($0.id.uuidString) && !pendingUploads.contains($0.id.uuidString) }
        
        let hasEntryChanges = FinanceManager.shared.mergeEntriesFromCloud(entries)
        let hasBudgetChanges = FinanceManager.shared.mergeBudgetsFromCloud(budgets)
        let hasGoalChanges = FinanceManager.shared.mergeGoalsFromCloud(goals)
        let hasCategoryChanges = FinanceManager.shared.mergeCustomCategoriesFromCloud(customCategories)
        
        if hasEntryChanges || hasBudgetChanges || hasGoalChanges || hasCategoryChanges {
            print(" Merged finance data from cloud: \(entries.count) entries, \(budgets.count) budgets, \(goals.count) goals, \(customCategories.count) categories")
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
    /// Task fields added in 1.8: left out when the production schema does not have them yet.
    private static let taskFields18 = ["photosMeta", "totalTrackedTime", "lastTrackedDate", "domainId", "goalId"]
    
    private func createTaskRecord(from task: TodoTask, includeFields18: Bool = true) -> CKRecord {
        let recordID = CKRecord.ID(recordName: task.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: taskRecordType, recordID: recordID)
        
        record["name"] = task.name.isEmpty ? "untitled_task".localized : task.name
        record["taskDescription"] = task.description
        record["startTime"] = task.startTime
        record["hasSpecificDay"] = task.hasSpecificDay
        record["hasSpecificTime"] = task.hasSpecificTime
        record["hasNotification"] = task.hasNotification
        record["notificationLeadTimeMinutes"] = task.notificationLeadTimeMinutes
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
        record["autoCarryOver"] = task.autoCarryOver
        if includeFields18 {
            record["totalTrackedTime"] = task.totalTrackedTime
            record["lastTrackedDate"] = task.lastTrackedDate
            record["domainId"] = task.domainId?.uuidString
            record["goalId"] = task.goalId?.uuidString
        }
        
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
        
        setTaskMedia(on: record, for: task, includeFields18: includeFields18)
        
        return record
    }
    
    private func createTask(from record: CKRecord) -> TodoTask? {
        guard let name = record["name"] as? String,
              let uuid = UUID(uuidString: record.recordID.recordName) else {
            return nil
        }
        
        let description = record["taskDescription"] as? String
        let startTime = record["startTime"] as? Date ?? Date()
        let hasSpecificDay = record["hasSpecificDay"] as? Bool ?? false
        let hasSpecificTime = record["hasSpecificTime"] as? Bool ?? true
        let hasNotification = record["hasNotification"] as? Bool ?? false
        let notificationLeadTimeMinutes = record["notificationLeadTimeMinutes"] as? Int ?? 0
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
        let autoCarryOver = record["autoCarryOver"] as? Bool ?? false
        
        var task = TodoTask(
            id: uuid,
            name: name,
            description: description,
            location: location,
            startTime: startTime,
            hasSpecificDay: hasSpecificDay,
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
            hasNotification: hasNotification,
            notificationId: nil,
            timeScope: decodedTimeScope,
            scopeStartDate: decodedScopeStart,
            scopeEndDate: decodedScopeEnd,
            notificationLeadTimeMinutes: notificationLeadTimeMinutes,
            autoCarryOver: autoCarryOver
        )
        
        task.completions = completions
        task.completionDates = completionDates
        task.creationDate = creationDate ?? Date()
        task.lastModifiedDate = lastModifiedDate ?? Date()
        
        task.totalTrackedTime = record["totalTrackedTime"] as? TimeInterval ?? 0
        task.lastTrackedDate = record["lastTrackedDate"] as? Date
        task.domainId = (record["domainId"] as? String).flatMap(UUID.init(uuidString:))
        task.goalId = (record["goalId"] as? String).flatMap(UUID.init(uuidString:))
        
        importTaskMedia(from: record, into: &task)
        
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
        record["icon"] = category.icon
        
        return record
    }
    
    private func createCategory(from record: CKRecord) -> Category? {
        guard let name = record["name"] as? String,
              let color = record["color"] as? String,
              let uuid = UUID(uuidString: record.recordID.recordName) else {
            return nil
        }
        
        return Category(id: uuid, name: name, color: color, icon: record["icon"] as? String)
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
        
        // Added in 1.8 (need the production schema): category rewards used to sync as general ones.
        record["categoryId"] = reward.categoryId?.uuidString
        record["categoryName"] = reward.categoryName
        record["archivedDate"] = reward.archivedDate
        
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
        reward.categoryId = (record["categoryId"] as? String).flatMap(UUID.init(uuidString:))
        reward.categoryName = record["categoryName"] as? String
        reward.archivedDate = record["archivedDate"] as? Date
        reward.creationDate = creationDate ?? Date()
        reward.lastModifiedDate = lastModifiedDate ?? Date()
        
        return reward
    }
    
    private func createTaskListOrderRecord(from order: TaskListOrder) -> CKRecord {
        let recordID = CKRecord.ID(recordName: "order-\(order.listKey)", zoneID: zoneID)
        let record = CKRecord(recordType: taskListOrderRecordType, recordID: recordID)
        record["listKey"] = order.listKey
        record["taskIds"] = order.taskIds.map { $0.uuidString }
        record["orderLastModified"] = order.lastModified
        return record
    }
    
    private func createTaskListOrder(from record: CKRecord) -> TaskListOrder? {
        guard let listKey = record["listKey"] as? String,
              let taskIds = record["taskIds"] as? [String] else { return nil }
        let lastModified = record["orderLastModified"] as? Date ?? record.modificationDate ?? .distantPast
        return TaskListOrder(
            listKey: listKey,
            taskIds: taskIds.compactMap { UUID(uuidString: $0) },
            lastModified: lastModified
        )
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
    
    private func createJournalEntry(from record: CKRecord) -> JournalEntry? {
        guard let date = record["date"] as? Date,
              let uuid = UUID(uuidString: record.recordID.recordName) else {
            return nil
        }
        
        let title = record["title"] as? String ?? ""
        let text = record["text"] as? String ?? ""
        let worthItText = record["worthItText"] as? String ?? ""
        let isWorthItHidden = (record["isWorthItHidden"] as? NSNumber)?.boolValue ?? (record["isWorthItHidden"] as? Bool) ?? false
        let createdAt = record["entryCreatedAt"] as? Date ?? record.creationDate ?? Date()
        let updatedAt = record["entryUpdatedAt"] as? Date ?? record.modificationDate ?? createdAt
        
        var mood: MoodType?
        if let moodRaw = record["mood"] as? String {
            mood = MoodType(rawValue: moodRaw)
        }
        
        let tags = record["tags"] as? [String] ?? []
        
        let (photos, voiceMemos) = importJournalMedia(from: record, entryId: uuid)
        
        return JournalEntry(
            id: uuid,
            date: date,
            title: title,
            text: text,
            worthItText: worthItText,
            isWorthItHidden: isWorthItHidden,
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
            _ = try await saveOverwriting(record)
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
            isPaused: isPaused,
            deviceType: deviceType,
            deviceName: deviceName,
            creationDate: creationDate,
            lastModifiedDate: lastModifiedDate
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
            let debugMessage = cloudKitDebugMessage(for: ckError)
            switch ckError.code {
            case .networkFailure, .networkUnavailable:
                syncStatus = .error(debugMessage)
            case .quotaExceeded:
                syncStatus = .error(debugMessage)
            case .notAuthenticated:
                syncStatus = .error(debugMessage)
            case .zoneNotFound, .userDeletedZone:
                syncStatus = .error("zone_missing_recreating".localized)
                serverChangeToken = nil
                try? await ensureZoneExists()
                if syncRetryCount < maxSyncRetries {
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                        await performFullSync()
                    }
                }
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
                syncStatus = .error(debugMessage)
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
                    syncStatus = .error(debugMessage)
                }
            }
        } else {
            syncStatus = .error(String(describing: error))
        }
    }
    
    private func handleCloudKitError(_ error: CKError) async {
        print(" CloudKit error: \(error.localizedDescription)")
        let debugMessage = cloudKitDebugMessage(for: error)
        
        switch error.code {
        case .networkFailure, .networkUnavailable:
            syncStatus = .error(debugMessage)
        case .quotaExceeded:
            syncStatus = .error(debugMessage)
        case .notAuthenticated:
            syncStatus = .error(debugMessage)
        case .invalidArguments:
            syncStatus = .error(debugMessage)
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
            syncStatus = .error(debugMessage)
        case .zoneNotFound, .userDeletedZone:
            syncStatus = .error("zone_missing_recreating".localized)
            serverChangeToken = nil
            try? await ensureZoneExists()
            if syncRetryCount < maxSyncRetries {
                Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    await performFullSync()
                }
            }
        case .limitExceeded:
            syncStatus = .error(debugMessage)
        default:
            syncStatus = .error(debugMessage)
        }
    }

    private func cloudKitDebugMessage(for error: CKError) -> String {
        var parts: [String] = []
        parts.append("CloudKit")
        parts.append("\(error.code)")

        if let retry = error.userInfo[CKErrorRetryAfterKey] as? NSNumber {
            parts.append("retryAfter=\(retry)")
        }

        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? Error {
            parts.append("underlying=\(String(describing: underlying))")
        }

        if let partial = error.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error], !partial.isEmpty {
            parts.append("partialErrors=\(partial.count)")
        }

        let message = parts.joined(separator: " | ")
        return message.isEmpty ? "sync_error".localized : message
    }
    
    // MARK: - Remote Notifications
    func processRemoteNotification(_ userInfo: [AnyHashable: Any]) {
        Task { _ = await handleRemoteNotification(userInfo) }
    }
    
    /// Syncs for a push sent by iCloud when another device changed something. Returns whether
    /// it was ours; it waits for the sync so the system keeps the app awake until it is done.
    func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) async -> Bool {
        guard isCloudKitEnabled,
              let notification = CKNotification(fromRemoteNotificationDictionary: userInfo),
              notification.subscriptionID == subscriptionID else { return false }
        print(" Received CloudKit notification")
        await syncAndWait()
        return true
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
                "journalVoiceMemos": deletedItems.journalVoiceMemos.count,
                "financeEntries": deletedItems.financeEntries.count,
                "financeBudgets": deletedItems.financeBudgets.count,
                "financialGoals": deletedItems.financialGoals.count,
                "customFinanceCategories": deletedItems.customFinanceCategories.count
            ]
        ]
    }
    
    func saveJournalEntry(_ entry: JournalEntry) {
        guard isCloudKitEnabled else { return }
        
        Task {
            // Built from this device's copy and written over iCloud's: no need to download the
            // day (with all its photos and memos) before saving it. Edits made on two devices
            // are reconciled when they are fetched (`mergeJournalEntries`).
            let recordID = CKRecord.ID(recordName: entry.id.uuidString, zoneID: zoneID)
            let record = CKRecord(recordType: journalEntryRecordType, recordID: recordID)
            applyJournalEntry(entry, to: record)
            do {
                try await saveOverwriting(record)
                markUploaded([record])
                syncStatus = .success
                lastSyncDate = Date()
            } catch let error as CKError {
                await handleCloudKitError(error)
            } catch {
                await handleSyncError(error)
            }
        }
    }
    
    func deleteJournalEntry(_ entry: JournalEntry) {
        guard isCloudKitEnabled else { return }
        
        markAsDeleted(itemID: entry.id.uuidString, type: .journalEntry)
        
        Task {
            do {
                let recordID = CKRecord.ID(recordName: entry.id.uuidString, zoneID: zoneID)
                try await deleteRecordQueued(recordID)
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
        record["worthItText"] = entry.worthItText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : entry.worthItText
        record["isWorthItHidden"] = entry.isWorthItHidden ? entry.isWorthItHidden : nil
        record["entryCreatedAt"] = entry.createdAt
        record["entryUpdatedAt"] = entry.updatedAt
        
        if let mood = entry.mood {
            record["mood"] = mood.rawValue
        } else {
            record["mood"] = nil
        }
        
        record["tags"] = entry.tags.isEmpty ? nil : entry.tags
        
        setJournalMedia(on: record, for: entry)
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

// MARK: - Finance Data CloudKit Extension

extension CloudKitService {
    
    // MARK: - Save/Delete Operations
    
    func saveFinanceEntry(_ entry: FinanceEntry) {
        guard isCloudKitEnabled else { return }
        let recordName = entry.id.uuidString
        pendingUploads.insert(recordName)
        
        Task {
            defer { pendingUploads.remove(recordName) }
            do {
                let record = createFinanceEntryRecord(from: entry)
                _ = try await saveOverwriting(record)
                print(" Finance entry saved: \(entry.name)")
            } catch {
                print(" Failed to save finance entry: \(error)")
            }
        }
    }
    
    func deleteFinanceEntry(_ entry: FinanceEntry) {
        guard isCloudKitEnabled else { return }
        
        Task {
            do {
                let recordID = CKRecord.ID(recordName: entry.id.uuidString, zoneID: zoneID)
                try await deleteRecordQueued(recordID)
                await saveDeletionMarker(type: "FinanceEntry", id: entry.id.uuidString)
                print(" Finance entry deleted: \(entry.name)")
            } catch let error as CKError where error.code == .unknownItem {
                await saveDeletionMarker(type: "FinanceEntry", id: entry.id.uuidString)
            } catch {
                print(" Failed to delete finance entry: \(error)")
            }
        }
    }
    
    func saveFinanceBudget(_ budget: FinanceBudget) {
        guard isCloudKitEnabled else { return }
        let recordName = budget.id.uuidString
        pendingUploads.insert(recordName)
        
        Task {
            defer { pendingUploads.remove(recordName) }
            do {
                let record = createFinanceBudgetRecord(from: budget)
                _ = try await saveOverwriting(record)
                print(" Finance budget saved: \(budget.category.displayName)")
            } catch {
                print(" Failed to save finance budget: \(error)")
            }
        }
    }
    
    func deleteFinanceBudget(_ budget: FinanceBudget) {
        guard isCloudKitEnabled else { return }
        
        Task {
            do {
                let recordID = CKRecord.ID(recordName: budget.id.uuidString, zoneID: zoneID)
                try await deleteRecordQueued(recordID)
                await saveDeletionMarker(type: "FinanceBudget", id: budget.id.uuidString)
                print(" Finance budget deleted: \(budget.category.displayName)")
            } catch let error as CKError where error.code == .unknownItem {
                await saveDeletionMarker(type: "FinanceBudget", id: budget.id.uuidString)
            } catch {
                print(" Failed to delete finance budget: \(error)")
            }
        }
    }
    
    func saveFinancialGoal(_ goal: FinancialGoal) {
        guard isCloudKitEnabled else { return }
        let recordName = goal.id.uuidString
        pendingUploads.insert(recordName)
        
        Task {
            defer { pendingUploads.remove(recordName) }
            do {
                let record = createFinancialGoalRecord(from: goal)
                _ = try await saveOverwriting(record)
                print(" Financial goal saved: \(goal.name)")
            } catch {
                print(" Failed to save financial goal: \(error)")
            }
        }
    }
    
    func deleteFinancialGoal(_ goal: FinancialGoal) {
        guard isCloudKitEnabled else { return }
        
        Task {
            do {
                let recordID = CKRecord.ID(recordName: goal.id.uuidString, zoneID: zoneID)
                try await deleteRecordQueued(recordID)
                await saveDeletionMarker(type: "FinancialGoal", id: goal.id.uuidString)
                print(" Financial goal deleted: \(goal.name)")
            } catch let error as CKError where error.code == .unknownItem {
                await saveDeletionMarker(type: "FinancialGoal", id: goal.id.uuidString)
            } catch {
                print(" Failed to delete financial goal: \(error)")
            }
        }
    }
    
    func saveCustomFinanceCategory(_ category: CustomFinanceCategory) {
        guard isCloudKitEnabled else { return }
        let recordName = category.id.uuidString
        pendingUploads.insert(recordName)
        
        Task {
            defer { pendingUploads.remove(recordName) }
            do {
                let record = createCustomFinanceCategoryRecord(from: category)
                _ = try await saveOverwriting(record)
                print(" Custom finance category saved: \(category.name)")
            } catch {
                print(" Failed to save custom finance category: \(error)")
            }
        }
    }
    
    func deleteCustomFinanceCategory(_ category: CustomFinanceCategory) {
        guard isCloudKitEnabled else { return }
        
        Task {
            do {
                let recordID = CKRecord.ID(recordName: category.id.uuidString, zoneID: zoneID)
                try await deleteRecordQueued(recordID)
                await saveDeletionMarker(type: "CustomFinanceCategory", id: category.id.uuidString)
                print(" Custom finance category deleted: \(category.name)")
            } catch let error as CKError where error.code == .unknownItem {
                await saveDeletionMarker(type: "CustomFinanceCategory", id: category.id.uuidString)
            } catch {
                print(" Failed to delete custom finance category: \(error)")
            }
        }
    }
    
    // MARK: - Record Creation (Model -> CKRecord)
    
    private func createFinanceEntryRecord(from entry: FinanceEntry) -> CKRecord {
        let recordID = CKRecord.ID(recordName: entry.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: financeEntryRecordType, recordID: recordID)
        
        record["entryId"] = entry.id.uuidString
        record["name"] = entry.name
        record["amount"] = entry.amount
        record["type"] = entry.type.rawValue
        record["category"] = entry.category.rawValue
        record["customCategoryId"] = entry.customCategoryId?.uuidString
        record["date"] = entry.date
        record["notes"] = entry.notes
        record["isRecurring"] = entry.isRecurring
        record["recurringFrequency"] = entry.recurringFrequency?.rawValue
        record["recurringEndDate"] = entry.recurringEndDate
        record["tags"] = entry.tags.isEmpty ? nil : entry.tags
        record["createdAt"] = entry.creationDate
        record["updatedAt"] = entry.lastModifiedDate
        
        return record
    }
    
    private func createFinanceBudgetRecord(from budget: FinanceBudget) -> CKRecord {
        let recordID = CKRecord.ID(recordName: budget.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: financeBudgetRecordType, recordID: recordID)
        
        record["budgetId"] = budget.id.uuidString
        record["category"] = budget.category.rawValue
        record["customCategoryId"] = budget.customCategoryId?.uuidString
        record["monthlyLimit"] = budget.monthlyLimit
        record["isActive"] = budget.isActive
        record["createdAt"] = budget.creationDate
        
        return record
    }
    
    private func createFinancialGoalRecord(from goal: FinancialGoal) -> CKRecord {
        let recordID = CKRecord.ID(recordName: goal.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: financialGoalRecordType, recordID: recordID)
        
        record["goalId"] = goal.id.uuidString
        record["name"] = goal.name
        record["targetAmount"] = goal.targetAmount
        record["currentAmount"] = goal.currentAmount
        record["targetDate"] = goal.targetDate
        record["type"] = goal.type.rawValue
        record["isActive"] = goal.isActive
        record["createdAt"] = goal.creationDate
        record["updatedAt"] = goal.lastModifiedDate
        
        return record
    }
    
    private func createCustomFinanceCategoryRecord(from category: CustomFinanceCategory) -> CKRecord {
        let recordID = CKRecord.ID(recordName: category.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: customFinanceCategoryRecordType, recordID: recordID)
        
        record["categoryId"] = category.id.uuidString
        record["name"] = category.name
        record["icon"] = category.icon
        record["colorHex"] = category.colorHex
        record["isExpenseCategory"] = category.isExpenseCategory
        record["createdAt"] = category.creationDate
        
        return record
    }
    
    // MARK: - Record Parsing (CKRecord -> Model)
    
    internal func createFinanceEntry(from record: CKRecord) -> FinanceEntry? {
        guard let idString = record["entryId"] as? String,
              let id = UUID(uuidString: idString),
              let name = record["name"] as? String,
              let amount = record["amount"] as? Double,
              let typeString = record["type"] as? String,
              let type = FinanceEntryType(rawValue: typeString),
              let categoryString = record["category"] as? String,
              let category = FinanceCategory(rawValue: categoryString),
              let date = record["date"] as? Date else {
            return nil
        }
        
        let customCategoryId = (record["customCategoryId"] as? String).flatMap { UUID(uuidString: $0) }
        let notes = record["notes"] as? String
        let isRecurring = record["isRecurring"] as? Bool ?? false
        let recurringFrequency = (record["recurringFrequency"] as? String).flatMap { SubscriptionFrequency(rawValue: $0) }
        let recurringEndDate = record["recurringEndDate"] as? Date
        let tags = record["tags"] as? [String] ?? []
        let creationDate = record["createdAt"] as? Date ?? record.creationDate ?? Date()
        let lastModifiedDate = record["updatedAt"] as? Date ?? record.modificationDate ?? creationDate
        
        return FinanceEntry(
            id: id,
            name: name,
            amount: amount,
            type: type,
            category: category,
            customCategoryId: customCategoryId,
            date: date,
            notes: notes,
            isRecurring: isRecurring,
            recurringFrequency: recurringFrequency,
            recurringEndDate: recurringEndDate,
            tags: tags,
            creationDate: creationDate,
            lastModifiedDate: lastModifiedDate
        )
    }
    
    internal func createFinanceBudget(from record: CKRecord) -> FinanceBudget? {
        guard let idString = record["budgetId"] as? String,
              let id = UUID(uuidString: idString),
              let categoryString = record["category"] as? String,
              let category = FinanceCategory(rawValue: categoryString),
              let monthlyLimit = record["monthlyLimit"] as? Double,
              let isActive = record["isActive"] as? Bool else {
            return nil
        }

        let customCategoryId = (record["customCategoryId"] as? String).flatMap { UUID(uuidString: $0) }
        let creationDate = record["createdAt"] as? Date ?? record.creationDate ?? Date()
        
        return FinanceBudget(
            id: id,
            category: category,
            customCategoryId: customCategoryId,
            monthlyLimit: monthlyLimit,
            isActive: isActive,
            creationDate: creationDate
        )
    }
    
    internal func createFinancialGoal(from record: CKRecord) -> FinancialGoal? {
        guard let idString = record["goalId"] as? String,
              let id = UUID(uuidString: idString),
              let name = record["name"] as? String,
              let targetAmount = record["targetAmount"] as? Double,
              let currentAmount = record["currentAmount"] as? Double,
              let typeString = record["type"] as? String,
              let type = FinancialGoalType(rawValue: typeString),
              let isActive = record["isActive"] as? Bool else {
            return nil
        }
        
        let targetDate = record["targetDate"] as? Date
        let creationDate = record["createdAt"] as? Date ?? record.creationDate ?? Date()
        let lastModifiedDate = record["updatedAt"] as? Date ?? record.modificationDate ?? creationDate
        
        return FinancialGoal(
            id: id,
            name: name,
            targetAmount: targetAmount,
            currentAmount: currentAmount,
            targetDate: targetDate,
            type: type,
            isActive: isActive,
            creationDate: creationDate,
            lastModifiedDate: lastModifiedDate
        )
    }
    
    internal func createCustomFinanceCategory(from record: CKRecord) -> CustomFinanceCategory? {
        guard let idString = record["categoryId"] as? String,
              let id = UUID(uuidString: idString),
              let name = record["name"] as? String,
              let icon = record["icon"] as? String,
              let isExpenseCategory = record["isExpenseCategory"] as? Bool else {
            return nil
        }
        
        let colorHex = record["colorHex"] as? String
        let creationDate = record["createdAt"] as? Date ?? record.creationDate ?? Date()
        
        return CustomFinanceCategory(
            id: id,
            name: name,
            icon: icon,
            colorHex: colorHex,
            isExpenseCategory: isExpenseCategory,
            creationDate: creationDate
        )
    }
}
// MARK: - Attachments (photos and voice memos)
// Files go to iCloud only when the set of photos/memos of a task or journal day changes. Before,
// every save (even ticking a task off) uploaded all its files again, and every device wrote
// them to disk again under new names on each sync.
extension CloudKitService {
    private static let knownMediaKey = "cloudkit_known_media_v1"
    
    private struct CloudTaskPhotoMeta: Codable {
        let id: UUID
        let createdAt: Date
    }
    
    /// What iCloud holds for a record's files, as last uploaded or fetched (nil: unknown).
    private func knownMedia(for recordName: String) -> String? {
        if knownMediaCache == nil {
            knownMediaCache = UserDefaults.standard.dictionary(forKey: Self.knownMediaKey) as? [String: String] ?? [:]
        }
        return knownMediaCache?[recordName]
    }
    
    private func setKnownMedia(_ signature: String?, for recordName: String) {
        _ = knownMedia(for: recordName)
        knownMediaCache?[recordName] = signature
    }
    
    func persistKnownMedia() {
        guard let cache = knownMediaCache else { return }
        UserDefaults.standard.set(cache, forKey: Self.knownMediaKey)
    }
    
    /// Called once iCloud confirmed the save of these records.
    func markUploaded(_ records: [CKRecord]) {
        var changed = false
        for record in records {
            let name = record.recordID.recordName
            if let signature = mediaAwaitingUpload.removeValue(forKey: name) {
                setKnownMedia(signature, for: name)
                changed = true
            }
        }
        if changed { persistKnownMedia() }
    }
    
    private static func mediaSignature(photoIDs: [UUID], memos: [(id: UUID, name: String?)]) -> String {
        let photos = photoIDs.map(\.uuidString).joined(separator: ",")
        let memoPart = memos.map { "\($0.id.uuidString)=\($0.name ?? "")" }.joined(separator: ",")
        return "p:\(photos)|m:\(memoPart)"
    }
    
    // MARK: Tasks
    
    func setTaskMedia(on record: CKRecord, for task: TodoTask, includeFields18: Bool) {
        let photos = task.photos.map { ($0, AttachmentService.resolveFilePath($0.photoPath)) }
        let memos = task.voiceMemos.map { ($0, AttachmentService.resolveFilePath($0.audioPath)) }
        let legacyPath = task.photos.isEmpty ? task.photoPath : nil
        let legacyFile = legacyPath.flatMap(AttachmentService.resolveFilePath)
        
        // A file this device can't find (moved, or never downloaded): leave iCloud's copy alone
        // instead of deleting it there.
        guard !photos.contains(where: { $0.1 == nil }), !memos.contains(where: { $0.1 == nil }),
              legacyPath == nil || legacyFile != nil else { return }
        
        let name = record.recordID.recordName
        // Single photo saved by old versions: no id to compare, so it is always sent.
        let signature = legacyFile == nil
            ? Self.mediaSignature(photoIDs: photos.map(\.0.id), memos: memos.map { ($0.0.id, $0.0.name) })
            : nil
        if let signature, knownMedia(for: name) == signature { return }
        
        record["photos"] = photos.isEmpty ? nil : photos.map { CKAsset(fileURL: URL(fileURLWithPath: $0.1!)) }
        if includeFields18 {
            record["photosMeta"] = photos.isEmpty ? nil
                : try? JSONEncoder().encode(photos.map { CloudTaskPhotoMeta(id: $0.0.id, createdAt: $0.0.createdAt) })
        }
        record["photo"] = legacyFile.map { CKAsset(fileURL: URL(fileURLWithPath: $0)) }
        record["voiceMemosAssets"] = memos.isEmpty ? nil : memos.map { CKAsset(fileURL: URL(fileURLWithPath: $0.1!)) }
        record["voiceMemosMeta"] = memos.isEmpty ? nil
            : try? JSONEncoder().encode(memos.map { CloudVoiceMemoMeta(id: $0.0.id, duration: $0.0.duration, createdAt: $0.0.createdAt, name: $0.0.name) })
        mediaAwaitingUpload[name] = signature
    }
    
    /// Reads a task's files from its record, reusing the ones this device already has.
    func importTaskMedia(from record: CKRecord, into task: inout TodoTask) {
        let local = TaskManager.shared.tasks.first { $0.id == task.id }
        var signatureKnown = true
        var photoIDs: [UUID] = []
        var memoKeys: [(id: UUID, name: String?)] = []
        
        if let assets = record["photos"] as? [CKAsset], !assets.isEmpty {
            let metas = (record["photosMeta"] as? Data).flatMap { try? JSONDecoder().decode([CloudTaskPhotoMeta].self, from: $0) }
            if let metas, metas.count == assets.count {
                task.photos = zip(assets, metas).compactMap { asset, meta in
                    if let existing = local?.photos.first(where: { $0.id == meta.id }),
                       let path = AttachmentService.resolveFilePath(existing.photoPath) {
                        let thumb = AttachmentService.resolveFilePath(existing.thumbnailPath) ?? existing.thumbnailPath
                        return TaskPhoto(id: meta.id, photoPath: path, thumbnailPath: thumb, createdAt: meta.createdAt)
                    }
                    guard let url = asset.fileURL, let data = try? Data(contentsOf: url) else { return nil }
                    return AttachmentService.addPhoto(for: task.id, imageData: data, id: meta.id, createdAt: meta.createdAt)
                }
                photoIDs = metas.map(\.id)
            } else {
                // Saved by a version without photo ids: keep this device's copies if it has them all.
                signatureKnown = false
                if let local, local.photos.count == assets.count,
                   local.photos.allSatisfy({ AttachmentService.resolveFilePath($0.photoPath) != nil }) {
                    task.photos = local.photos
                } else {
                    task.photos = assets.compactMap { asset in
                        guard let url = asset.fileURL, let data = try? Data(contentsOf: url) else { return nil }
                        return AttachmentService.addPhoto(for: task.id, imageData: data)
                    }
                }
            }
            task.photoPath = task.photos.first?.photoPath
            task.photoThumbnailPath = task.photos.first?.thumbnailPath
        } else if let asset = record["photo"] as? CKAsset {
            signatureKnown = false
            if let local, let path = local.photoPath.flatMap(AttachmentService.resolveFilePath) {
                task.photoPath = path
                task.photoThumbnailPath = local.photoThumbnailPath.flatMap(AttachmentService.resolveFilePath) ?? local.photoThumbnailPath
            } else if let url = asset.fileURL, let data = try? Data(contentsOf: url),
                      let saved = AttachmentService.savePhoto(for: task.id, imageData: data) {
                task.photoPath = saved.photoPath
                task.photoThumbnailPath = saved.thumbnailPath
            }
        }
        
        if let assets = record["voiceMemosAssets"] as? [CKAsset], !assets.isEmpty,
           let metaData = record["voiceMemosMeta"] as? Data,
           let metas = try? JSONDecoder().decode([CloudVoiceMemoMeta].self, from: metaData) {
            // Older versions could list more memos than files: the pairs may be off, re-send later.
            if metas.count != assets.count { signatureKnown = false }
            task.voiceMemos = zip(assets, metas).compactMap { asset, meta in
                if let existing = local?.voiceMemos.first(where: { $0.id == meta.id }),
                   let path = AttachmentService.resolveFilePath(existing.audioPath) {
                    return TaskVoiceMemo(id: meta.id, audioPath: path, duration: meta.duration, createdAt: meta.createdAt, name: meta.name)
                }
                guard let url = asset.fileURL, let data = try? Data(contentsOf: url) else { return nil }
                return saveVoiceMemoData(taskId: task.id, data: data, id: meta.id, duration: meta.duration, createdAt: meta.createdAt, name: meta.name)
            }.sorted { $0.createdAt > $1.createdAt }
            memoKeys = metas.map { ($0.id, $0.name) }
        }
        
        setKnownMedia(signatureKnown ? Self.mediaSignature(photoIDs: photoIDs, memos: memoKeys) : nil,
                      for: record.recordID.recordName)
    }
    
    /// Deletes the files of `old`'s photos and memos that `new` no longer has.
    func removeAttachments(of old: TodoTask, notIn new: TodoTask) {
        let keptPhotos = Set(new.photos.map(\.id))
        for photo in old.photos where !keptPhotos.contains(photo.id) {
            let stillUsed = new.photos.contains { $0.photoPath == photo.photoPath }
            if !stillUsed { AttachmentService.deletePhoto(for: old.id, photo: photo) }
        }
        let keptMemos = Set(new.voiceMemos.map(\.id))
        for memo in old.voiceMemos where !keptMemos.contains(memo.id) {
            if !new.voiceMemos.contains(where: { $0.audioPath == memo.audioPath }) {
                try? FileManager.default.removeItem(atPath: memo.audioPath)
            }
        }
    }
    
    // MARK: Journal
    
    func setJournalMedia(on record: CKRecord, for entry: JournalEntry) {
        let photos = entry.photos.map { ($0, AttachmentService.resolveFilePath($0.photoPath)) }
        let memos = entry.voiceMemos.map { ($0, AttachmentService.resolveFilePath($0.audioPath)) }
        guard !photos.contains(where: { $0.1 == nil }), !memos.contains(where: { $0.1 == nil }) else { return }
        
        let name = record.recordID.recordName
        let signature = Self.mediaSignature(photoIDs: photos.map(\.0.id), memos: memos.map { ($0.0.id, $0.0.name) })
        if knownMedia(for: name) == signature { return }
        
        record["photos"] = photos.isEmpty ? nil : photos.map { CKAsset(fileURL: URL(fileURLWithPath: $0.1!)) }
        record["journalPhotosMeta"] = photos.isEmpty ? nil
            : try? JSONEncoder().encode(photos.map { CloudJournalPhotoMeta(id: $0.0.id, createdAt: $0.0.createdAt) })
        record["journalVoiceMemosAssets"] = memos.isEmpty ? nil : memos.map { CKAsset(fileURL: URL(fileURLWithPath: $0.1!)) }
        record["journalVoiceMemosMeta"] = memos.isEmpty ? nil
            : try? JSONEncoder().encode(memos.map { CloudJournalVoiceMemoMeta(id: $0.0.id, duration: $0.0.duration, createdAt: $0.0.createdAt, name: $0.0.name) })
        mediaAwaitingUpload[name] = signature
    }
    
    func importJournalMedia(from record: CKRecord, entryId: UUID) -> (photos: [JournalPhoto], memos: [JournalVoiceMemo]) {
        let local = JournalManager.shared.entriesByDay.values.first { $0.id == entryId }
        var signatureKnown = true
        var photos: [JournalPhoto] = []
        var memos: [JournalVoiceMemo] = []
        var photoIDs: [UUID] = []
        var memoKeys: [(id: UUID, name: String?)] = []
        
        if let assets = record["photos"] as? [CKAsset], !assets.isEmpty {
            let metas = (record["journalPhotosMeta"] as? Data).flatMap { try? JSONDecoder().decode([CloudJournalPhotoMeta].self, from: $0) }
            if let metas, metas.count == assets.count {
                photos = zip(assets, metas).compactMap { asset, meta in
                    if let existing = local?.photos.first(where: { $0.id == meta.id }),
                       let path = AttachmentService.resolveFilePath(existing.photoPath) {
                        let thumb = AttachmentService.resolveFilePath(existing.thumbnailPath) ?? existing.thumbnailPath
                        return JournalPhoto(id: meta.id, photoPath: path, thumbnailPath: thumb, createdAt: meta.createdAt)
                    }
                    guard let url = asset.fileURL, let data = try? Data(contentsOf: url) else { return nil }
                    return saveJournalPhotoData(entryId: entryId, data: data, id: meta.id, createdAt: meta.createdAt)
                }
                photoIDs = metas.map(\.id)
            } else {
                signatureKnown = false
                if let local, local.photos.count == assets.count,
                   local.photos.allSatisfy({ AttachmentService.resolveFilePath($0.photoPath) != nil }) {
                    photos = local.photos
                } else {
                    photos = assets.compactMap { asset in
                        guard let url = asset.fileURL, let data = try? Data(contentsOf: url) else { return nil }
                        return saveJournalPhotoData(entryId: entryId, data: data)
                    }
                }
            }
        }
        
        if let assets = record["journalVoiceMemosAssets"] as? [CKAsset], !assets.isEmpty,
           let metaData = record["journalVoiceMemosMeta"] as? Data,
           let metas = try? JSONDecoder().decode([CloudJournalVoiceMemoMeta].self, from: metaData) {
            if metas.count != assets.count { signatureKnown = false }
            memos = zip(assets, metas).compactMap { asset, meta in
                if let existing = local?.voiceMemos.first(where: { $0.id == meta.id }),
                   let path = AttachmentService.resolveFilePath(existing.audioPath) {
                    return JournalVoiceMemo(id: meta.id, audioPath: path, duration: meta.duration, createdAt: meta.createdAt, name: meta.name)
                }
                guard let url = asset.fileURL, let data = try? Data(contentsOf: url) else { return nil }
                return saveJournalVoiceMemoData(entryId: entryId, data: data, id: meta.id, duration: meta.duration, createdAt: meta.createdAt, name: meta.name)
            }
            memoKeys = metas.map { ($0.id, $0.name) }
        }
        
        setKnownMedia(signatureKnown ? Self.mediaSignature(photoIDs: photoIDs, memos: memoKeys) : nil,
                      for: record.recordID.recordName)
        return (photos, memos)
    }
}

// MARK: - Outbox
// Changes that could not reach iCloud (offline, iCloud busy, not signed in yet) are kept by
// record name and sent again at the start of every sync, rebuilt from the current local data.
// Before, a failed save or deletion was simply lost until the same item changed again.
extension CloudKitService {
    private static let outboxKey = "cloudkit_outbox_v1"
    
    private struct Outbox: Codable {
        var saves: [String: String] = [:]   // record name → record type
        var deletes: Set<String> = []
    }
    
    private var outbox: Outbox {
        get {
            guard let data = UserDefaults.standard.data(forKey: Self.outboxKey) else { return Outbox() }
            return (try? JSONDecoder().decode(Outbox.self, from: data)) ?? Outbox()
        }
        set {
            if newValue.saves.isEmpty && newValue.deletes.isEmpty {
                UserDefaults.standard.removeObject(forKey: Self.outboxKey)
            } else if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: Self.outboxKey)
            }
        }
    }
    
    static func isRetryable(_ error: Error) -> Bool {
        guard let ckError = error as? CKError else { return false }
        switch ckError.code {
        case .invalidArguments, .serverRejectedRequest, .permissionFailure, .unknownItem,
             .constraintViolation, .incompatibleVersion, .badContainer, .missingEntitlement,
             .assetFileNotFound, .assetFileModified:
            return false
        default:
            return true
        }
    }
    
    func outboxQueueSave(_ record: CKRecord) {
        var box = outbox
        box.saves[record.recordID.recordName] = record.recordType
        box.deletes.remove(record.recordID.recordName)
        outbox = box
    }
    
    func outboxQueueDelete(_ recordName: String) {
        var box = outbox
        box.saves.removeValue(forKey: recordName)
        box.deletes.insert(recordName)
        outbox = box
    }
    
    func outboxDidSave(_ recordName: String) {
        guard UserDefaults.standard.data(forKey: Self.outboxKey) != nil else { return }
        var box = outbox
        guard box.saves.removeValue(forKey: recordName) != nil else { return }
        outbox = box
    }
    
    func outboxDidDelete(_ recordName: String) {
        guard UserDefaults.standard.data(forKey: Self.outboxKey) != nil else { return }
        var box = outbox
        guard box.deletes.remove(recordName) != nil else { return }
        outbox = box
    }
    
    /// Sends what is waiting in the outbox. Items deleted locally in the meantime are dropped.
    func flushOutbox() async {
        let box = outbox
        guard !box.saves.isEmpty || !box.deletes.isEmpty else { return }
        print(" Outbox: \(box.saves.count) saves, \(box.deletes.count) deletions to send")
        
        for name in box.deletes {
            do {
                try await deleteRecordQueued(CKRecord.ID(recordName: name, zoneID: zoneID))
            } catch {
                if Self.isRetryable(error) { return } // still offline: try again next sync
            }
        }
        for (name, type) in box.saves {
            guard let record = currentRecord(type: type, name: name) else {
                outboxDidSave(name) // no longer here (deleted), or rebuilt on its own
                continue
            }
            do {
                try await saveOverwriting(record)
                markUploaded([record])
            } catch {
                if Self.isRetryable(error) { return }
                // A task rejected by a production schema without the 1.8 fields: send the rest.
                if type == taskRecordType,
                   let task = TaskManager.shared.tasks.first(where: { $0.id.uuidString == name }) {
                    let fallback = createTaskRecord(from: task, includeFields18: false)
                    if (try? await saveOverwriting(fallback)) != nil { markUploaded([fallback]) }
                }
                outboxDidSave(name) // rejected for good: don't retry forever
            }
        }
    }
    
    /// The record for an item as it is on this device now.
    private func currentRecord(type: String, name: String) -> CKRecord? {
        let uuid = UUID(uuidString: name)
        switch type {
        case taskRecordType:
            return TaskManager.shared.tasks.first { $0.id == uuid }.map { createTaskRecord(from: $0) }
        case categoryRecordType:
            return CategoryManager.shared.categories.first { $0.id == uuid }.map { createCategoryRecord(from: $0) }
        case rewardRecordType:
            return RewardManager.shared.rewards.first { $0.id == uuid }.map { createRewardRecord(from: $0) }
        case trackingSessionRecordType:
            return TaskManager.shared.getTrackingSessions().first { $0.id == uuid }.map { createTrackingSessionRecord(from: $0) }
        case journalEntryRecordType:
            guard let entry = JournalManager.shared.entriesByDay.values.first(where: { $0.id == uuid }) else { return nil }
            let record = CKRecord(recordType: journalEntryRecordType, recordID: CKRecord.ID(recordName: name, zoneID: zoneID))
            applyJournalEntry(entry, to: record)
            return record
        case financeEntryRecordType:
            return FinanceManager.shared.entries.first { $0.id == uuid }.map { createFinanceEntryRecord(from: $0) }
        case financeBudgetRecordType:
            return FinanceManager.shared.budgets.first { $0.id == uuid }.map { createFinanceBudgetRecord(from: $0) }
        case financialGoalRecordType:
            return FinanceManager.shared.financialGoals.first { $0.id == uuid }.map { createFinancialGoalRecord(from: $0) }
        case customFinanceCategoryRecordType:
            return FinanceManager.shared.customCategories.first { $0.id == uuid }.map { createCustomFinanceCategoryRecord(from: $0) }
        case taskListOrderRecordType:
            let listKey = String(name.dropFirst("order-".count))
            return TaskOrderManager.shared.orders[listKey].map { createTaskListOrderRecord(from: $0) }
        case deletionMarkerRecordType:
            // Named "<type>-<id>": the id is the last five dash-separated parts (a UUID).
            let parts = name.split(separator: "-")
            guard parts.count > 5 else { return nil }
            let id = parts.suffix(5).joined(separator: "-")
            let markerType = parts.dropLast(5).joined(separator: "-")
            return createDeletionMarker(type: markerType, id: id)
        default:
            return nil // settings and statistics are re-sent on their own
        }
    }
}
