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
    internal let publicDatabase: CKDatabase
    internal let zoneID: CKRecordZone.ID
    private let recordZone: CKRecordZone
    
    internal let taskRecordType = "TodoTask"
    internal let categoryRecordType = "Category"
    internal let feedbackRecordType = "FeedbackItem"
    internal let voteRecordType = "FeedbackVote"
    private let subscriptionID = "SnapTaskZone-changes"
    
    // MARK: - State Management
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    @Published var isSyncing = false
    
    enum SyncStatus: Equatable {
        case idle
        case syncing
        case success
        case error(String)
        
        var description: String {
            switch self {
            case .idle: return "Ready to sync"
            case .syncing: return "Syncing..."
            case .success: return "Up to date"
            case .error(let message): return message
            }
        }
    }
    
    // MARK: - Sync Control
    private var lastSyncTime: Date = .distantPast
    private let minSyncInterval: TimeInterval = 3.0
    private var activeSyncTask: Task<Void, Never>?
    
    // MARK: - Deletion Tracking
    private let deletedTasksKey = "cloudkit_deleted_tasks"
    private let deletedCategoriesKey = "cloudkit_deleted_categories"
    
    private var deletedTaskIDs: Set<String> {
        get { loadDeletedIDs(key: deletedTasksKey) }
        set { saveDeletedIDs(newValue, key: deletedTasksKey) }
    }
    
    private var deletedCategoryIDs: Set<String> {
        get { loadDeletedIDs(key: deletedCategoriesKey) }
        set { saveDeletedIDs(newValue, key: deletedCategoriesKey) }
    }
    
    // MARK: - Initialization
    private init() {
        container = CKContainer.default()
        privateDatabase = container.privateCloudDatabase
        publicDatabase = container.publicCloudDatabase
        zoneID = CKRecordZone.ID(zoneName: "SnapTaskZone", ownerName: CKCurrentUserDefaultName)
        recordZone = CKRecordZone(zoneID: zoneID)
        
        Task {
            await initializeCloudKit()
        }
    }
    
    // MARK: - Feedback Operations
    func saveFeedback(_ feedback: FeedbackItem) async throws {
        let record = createFeedbackRecord(from: feedback)
        _ = try await publicDatabase.save(record)
        print("✅ Feedback saved to CloudKit: \(feedback.title)")
    }
    
    func fetchFeedback() async throws -> [FeedbackItem] {
        return try await withCheckedThrowingContinuation { continuation in
            let query = CKQuery(recordType: feedbackRecordType, predicate: NSPredicate(value: true))
            query.sortDescriptors = [NSSortDescriptor(key: "votes", ascending: false)]
            
            let operation = CKQueryOperation(query: query)
            operation.resultsLimit = 100
            
            var items: [FeedbackItem] = []
            
            operation.recordMatchedBlock = { [weak self] (recordID, recordResult) in
                switch recordResult {
                case .success(let record):
                    if let feedback = self?.createFeedbackItem(from: record) {
                        items.append(feedback)
                    }
                case .failure(let error):
                    print("⚠️ Failed to process feedback record: \(error)")
                }
            }
            
            operation.queryResultBlock = { operationResult in
                switch operationResult {
                case .success(_):
                    continuation.resume(returning: items)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            publicDatabase.add(operation)
        }
    }
    
    func toggleVote(for feedback: FeedbackItem) async throws -> Bool {
        let userId = getCurrentUserId()
        let hasVoted = try await checkIfUserVoted(for: feedback, userId: userId)
        
        if hasVoted {
            try await removeVote(for: feedback, userId: userId)
            return false
        } else {
            try await addVote(for: feedback, userId: userId)
            return true
        }
    }
    
    private func addVote(for feedback: FeedbackItem, userId: String) async throws {
        // Add vote record
        let voteRecord = CKRecord(recordType: voteRecordType)
        voteRecord["feedbackId"] = feedback.id.uuidString
        voteRecord["userId"] = userId
        _ = try await publicDatabase.save(voteRecord)
        
        // Update feedback vote count
        let feedbackRecordID = CKRecord.ID(recordName: feedback.id.uuidString)
        let feedbackRecord = try await publicDatabase.record(for: feedbackRecordID)
        let currentVotes = feedbackRecord["votes"] as? Int ?? 0
        feedbackRecord["votes"] = currentVotes + 1
        _ = try await publicDatabase.save(feedbackRecord)
    }
    
    private func removeVote(for feedback: FeedbackItem, userId: String) async throws {
        // Find and remove vote record
        let predicate = NSPredicate(format: "feedbackId == %@ AND userId == %@", feedback.id.uuidString, userId)
        let query = CKQuery(recordType: voteRecordType, predicate: predicate)
        
        let results = try await publicDatabase.records(matching: query)
        let records = results.matchResults.compactMap { try? $0.1.get() }
        
        if let voteRecord = records.first {
            _ = try await publicDatabase.deleteRecord(withID: voteRecord.recordID)
            
            // Update feedback vote count
            let feedbackRecordID = CKRecord.ID(recordName: feedback.id.uuidString)
            let feedbackRecord = try await publicDatabase.record(for: feedbackRecordID)
            let currentVotes = feedbackRecord["votes"] as? Int ?? 0
            feedbackRecord["votes"] = max(0, currentVotes - 1)
            _ = try await publicDatabase.save(feedbackRecord)
        }
    }
    
    private func checkIfUserVoted(for feedback: FeedbackItem, userId: String) async throws -> Bool {
        let predicate = NSPredicate(format: "feedbackId == %@ AND userId == %@", feedback.id.uuidString, userId)
        let query = CKQuery(recordType: voteRecordType, predicate: predicate)
        
        let results = try await publicDatabase.records(matching: query)
        return !results.matchResults.isEmpty
    }
    
    private func createFeedbackRecord(from feedback: FeedbackItem) -> CKRecord {
        let record = CKRecord(recordType: feedbackRecordType, recordID: CKRecord.ID(recordName: feedback.id.uuidString))
        
        record["title"] = feedback.title
        record["description"] = feedback.description
        record["category"] = feedback.category.rawValue
        record["status"] = feedback.status.rawValue
        record["submissionDate"] = feedback.creationDate // Changed from creationDate
        record["authorId"] = feedback.authorId
        record["authorName"] = feedback.authorName
        record["votes"] = feedback.votes
        
        return record
    }
    
    private func createFeedbackItem(from record: CKRecord) -> FeedbackItem? {
        guard let title = record["title"] as? String,
              let description = record["description"] as? String,
              let categoryRaw = record["category"] as? String,
              let category = FeedbackCategory(rawValue: categoryRaw),
              let statusRaw = record["status"] as? String,
              let status = FeedbackStatus(rawValue: statusRaw),
              let submissionDate = record["submissionDate"] as? Date,
              let uuid = UUID(uuidString: record.recordID.recordName) else {
            return nil
        }
        
        let votes = record["votes"] as? Int ?? 0
        let authorId = record["authorId"] as? String
        let authorName = record["authorName"] as? String
        
        return FeedbackItem(
            id: uuid,
            title: title,
            description: description,
            category: category,
            status: status,
            creationDate: submissionDate,
            authorId: authorId,
            authorName: authorName,
            votes: votes
        )
    }
    
    private func getCurrentUserId() -> String {
        // Use a persistent random ID instead of device ID
        let userIdKey = "feedback_user_id"
        if let existingId = UserDefaults.standard.string(forKey: userIdKey) {
            return existingId
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: userIdKey)
            return newId
        }
    }

    // MARK: - Public API
    func syncNow() {
        guard canPerformSync() else { return }
        
        activeSyncTask?.cancel()
        activeSyncTask = Task {
            await performFullSync()
        }
    }
    
    func saveTask(_ task: TodoTask) {
        Task {
            await performTaskOperation(.save(task))
        }
    }
    
    func deleteTask(_ task: TodoTask) {
        markAsDeleted(taskID: task.id.uuidString)
        Task {
            await performTaskOperation(.delete(task.id))
        }
    }
    
    func saveCategory(_ category: Category) {
        Task {
            await performCategoryOperation(.save(category))
        }
    }
    
    func deleteCategory(_ category: Category) {
        markAsDeleted(categoryID: category.id.uuidString)
        Task {
            await performCategoryOperation(.delete(category.id))
        }
    }
    
    // MARK: - CloudKit Operations
    private enum TaskOperation {
        case save(TodoTask)
        case delete(UUID)
    }
    
    private enum CategoryOperation {
        case save(Category)
        case delete(UUID)
    }
    
    private func performTaskOperation(_ operation: TaskOperation) async {
        do {
            switch operation {
            case .save(let task):
                await withCheckedContinuation { continuation in
                    let record = createTaskRecord(from: task)
                    self.privateDatabase.save(record) { savedRecord, error in
                        if let error = error {
                            print("❌ Failed to save task: \(error)")
                        } else {
                            print("✅ Task saved: \(task.name)")
                        }
                        continuation.resume()
                    }
                }
                
            case .delete(let taskID):
                await withCheckedContinuation { continuation in
                    let recordID = CKRecord.ID(recordName: taskID.uuidString, zoneID: self.zoneID)
                    self.privateDatabase.delete(withRecordID: recordID) { [weak self] deletedRecordID, error in
                        if let error = error as? CKError, error.code != .unknownItem {
                            print("❌ Failed to delete task: \(error)")
                        } else {
                            print("✅ Task deleted: \(taskID)")
                            self?.removeFromDeleted(taskID: taskID.uuidString)
                        }
                        continuation.resume()
                    }
                }
            }
        } catch {
            await handleOperationError(error, context: "Task operation")
        }
    }
    
    private func performCategoryOperation(_ operation: CategoryOperation) async {
        do {
            switch operation {
            case .save(let category):
                await withCheckedContinuation { continuation in
                    let record = createCategoryRecord(from: category)
                    self.privateDatabase.save(record) { savedRecord, error in
                        if let error = error {
                            print("❌ Failed to save category: \(error)")
                        } else {
                            print("✅ Category saved: \(category.name)")
                        }
                        continuation.resume()
                    }
                }
                
            case .delete(let categoryID):
                await withCheckedContinuation { continuation in
                    let recordID = CKRecord.ID(recordName: categoryID.uuidString, zoneID: self.zoneID)
                    self.privateDatabase.delete(withRecordID: recordID) { [weak self] deletedRecordID, error in
                        if let error = error as? CKError, error.code != .unknownItem {
                            print("❌ Failed to delete category: \(error)")
                        } else {
                            print("✅ Category deleted: \(categoryID)")
                            self?.removeFromDeleted(categoryID: categoryID.uuidString)
                        }
                        continuation.resume()
                    }
                }
            }
        } catch {
            await handleOperationError(error, context: "Category operation")
        }
    }
    
    // MARK: - Sync Implementation
    private func performFullSync() async {
        guard !isSyncing else { return }
        
        isSyncing = true
        syncStatus = .syncing
        lastSyncTime = Date()
        
        defer {
            isSyncing = false
        }
        
        do {
            // Parallel sync for better performance
            async let tasksSync = syncTasks()
            async let categoriesSync = syncCategories()
            
            let (tasksResult, categoriesResult) = await (tasksSync, categoriesSync)
            
            if tasksResult && categoriesResult {
                syncStatus = .success
                lastSyncDate = Date()
                print("✅ Full sync completed successfully")
            } else {
                syncStatus = .error("Partial sync failure")
                print("⚠️ Sync completed with some errors")
            }
            
        } catch {
            await handleSyncError(error)
        }
    }
    
    private func syncTasks() async -> Bool {
        do {
            let remoteTasks = try await fetchRemoteTasks()
            let localTasks = TaskManager.shared.tasks
            
            let syncResult = await mergeTasks(local: localTasks, remote: remoteTasks)
            
            // Apply changes
            TaskManager.shared.updateAllTasks(syncResult.mergedTasks)
            
            // Upload changes to CloudKit
            if !syncResult.toSave.isEmpty || !syncResult.toDelete.isEmpty {
                try await applyTaskChanges(toSave: syncResult.toSave, toDelete: syncResult.toDelete)
            }
            
            return true
        } catch {
            print("❌ Task sync failed: \(error)")
            return false
        }
    }
    
    private func syncCategories() async -> Bool {
        do {
            let remoteCategories = try await fetchRemoteCategories()
            let localCategories = CategoryManager.shared.categories
            
            let syncResult = await mergeCategories(local: localCategories, remote: remoteCategories)
            
            // Apply changes
            CategoryManager.shared.importCategoriesWithCheck(syncResult.mergedCategories)
            
            // Upload changes to CloudKit
            if !syncResult.toSave.isEmpty || !syncResult.toDelete.isEmpty {
                try await applyCategoryChanges(toSave: syncResult.toSave, toDelete: syncResult.toDelete)
            }
            
            return true
        } catch {
            print("❌ Category sync failed: \(error)")
            return false
        }
    }
    
    // MARK: - Data Fetching
    private func fetchRemoteTasks() async throws -> [TodoTask] {
        return try await withCheckedThrowingContinuation { continuation in
            let query = CKQuery(recordType: taskRecordType, predicate: NSPredicate(value: true))
            let operation = CKQueryOperation(query: query)
            operation.zoneID = zoneID
            operation.resultsLimit = CKQueryOperation.maximumResults
            
            var tasks: [TodoTask] = []
            
            operation.recordMatchedBlock = { [weak self] (recordID, recordResult) in
                switch recordResult {
                case .success(let record):
                    if let self = self, !self.deletedTaskIDs.contains(record.recordID.recordName) {
                        if let task = self.createTask(from: record) {
                            tasks.append(task)
                        }
                    }
                case .failure(let error):
                    print("⚠️ Failed to process task record: \(error)")
                }
            }
            
            operation.queryResultBlock = { operationResult in
                switch operationResult {
                case .success(_):
                    continuation.resume(returning: tasks)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            self.privateDatabase.add(operation)
        }
    }
    
    private func fetchRemoteCategories() async throws -> [Category] {
        return try await withCheckedThrowingContinuation { continuation in
            let query = CKQuery(recordType: categoryRecordType, predicate: NSPredicate(value: true))
            let operation = CKQueryOperation(query: query)
            operation.zoneID = zoneID
            operation.resultsLimit = CKQueryOperation.maximumResults
            
            var categories: [Category] = []
            
            operation.recordMatchedBlock = { [weak self] (recordID, recordResult) in
                switch recordResult {
                case .success(let record):
                    if let self = self, !self.deletedCategoryIDs.contains(record.recordID.recordName) {
                        if let category = self.createCategory(from: record) {
                            categories.append(category)
                        }
                    }
                case .failure(let error):
                    print("⚠️ Failed to process category record: \(error)")
                }
            }
            
            operation.queryResultBlock = { operationResult in
                switch operationResult {
                case .success(_):
                    continuation.resume(returning: categories)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            self.privateDatabase.add(operation)
        }
    }
    
    // MARK: - Data Merging
    private struct TaskSyncResult {
        let mergedTasks: [TodoTask]
        let toSave: [CKRecord]
        let toDelete: [CKRecord.ID]
    }
    
    private struct CategorySyncResult {
        let mergedCategories: [Category]
        let toSave: [CKRecord]
        let toDelete: [CKRecord.ID]
    }
    
    private func mergeTasks(local: [TodoTask], remote: [TodoTask]) async -> TaskSyncResult {
        let localMap = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        let remoteMap = Dictionary(uniqueKeysWithValues: remote.map { ($0.id, $0) })
        let allIDs = Set(localMap.keys).union(Set(remoteMap.keys))
        
        var mergedTasks: [TodoTask] = []
        var toSave: [CKRecord] = []
        var toDelete: [CKRecord.ID] = []
        
        for id in allIDs {
            let localTask = localMap[id]
            let remoteTask = remoteMap[id]
            
            // Handle deleted tasks
            if deletedTaskIDs.contains(id.uuidString) {
                if remoteTask != nil {
                    toDelete.append(CKRecord.ID(recordName: id.uuidString, zoneID: zoneID))
                }
                continue
            }
            
            // Merge logic
            if let local = localTask, let remote = remoteTask {
                // Both exist - use most recent
                if local.lastModifiedDate >= remote.lastModifiedDate {
                    mergedTasks.append(local)
                    if local.lastModifiedDate > remote.lastModifiedDate {
                        toSave.append(createTaskRecord(from: local))
                    }
                } else {
                    mergedTasks.append(remote)
                }
            } else if let local = localTask {
                // Local only
                mergedTasks.append(local)
                toSave.append(createTaskRecord(from: local))
            } else if let remote = remoteTask {
                // Remote only
                mergedTasks.append(remote)
            }
        }
        
        return TaskSyncResult(mergedTasks: mergedTasks, toSave: toSave, toDelete: toDelete)
    }
    
    private func mergeCategories(local: [Category], remote: [Category]) async -> CategorySyncResult {
        let localMap = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        let remoteMap = Dictionary(uniqueKeysWithValues: remote.map { ($0.id, $0) })
        let allIDs = Set(localMap.keys).union(Set(remoteMap.keys))
        
        var mergedCategories: [Category] = []
        var toSave: [CKRecord] = []
        var toDelete: [CKRecord.ID] = []
        
        for id in allIDs {
            let localCategory = localMap[id]
            let remoteCategory = remoteMap[id]
            
            // Handle deleted categories
            if deletedCategoryIDs.contains(id.uuidString) {
                if remoteCategory != nil {
                    toDelete.append(CKRecord.ID(recordName: id.uuidString, zoneID: zoneID))
                }
                continue
            }
            
            // Merge logic
            if let local = localCategory, let remote = remoteCategory {
                // Both exist - local wins, but check for changes
                mergedCategories.append(local)
                if local.name != remote.name || local.color != remote.color {
                    toSave.append(createCategoryRecord(from: local))
                }
            } else if let local = localCategory {
                // Local only
                mergedCategories.append(local)
                toSave.append(createCategoryRecord(from: local))
            } else if let remote = remoteCategory {
                // Remote only
                mergedCategories.append(remote)
            }
        }
        
        return CategorySyncResult(mergedCategories: mergedCategories, toSave: toSave, toDelete: toDelete)
    }
    
    // MARK: - CloudKit Change Application
    private func applyTaskChanges(toSave: [CKRecord], toDelete: [CKRecord.ID]) async throws {
        guard !toSave.isEmpty || !toDelete.isEmpty else { return }
        
        await withCheckedContinuation { continuation in
            let operation = CKModifyRecordsOperation(recordsToSave: toSave, recordIDsToDelete: toDelete)
            operation.savePolicy = .changedKeys
            
            operation.modifyRecordsCompletionBlock = { [weak self] savedRecords, deletedRecordIDs, error in
                if let error = error {
                    print("❌ Failed to apply task changes: \(error)")
                } else {
                    print("✅ Applied task changes: \(savedRecords?.count ?? 0) saved, \(deletedRecordIDs?.count ?? 0) deleted")
                    
                    // Clean up successful deletions
                    deletedRecordIDs?.forEach { recordID in
                        self?.removeFromDeleted(taskID: recordID.recordName)
                    }
                }
                continuation.resume()
            }
            
            self.privateDatabase.add(operation)
        }
    }
    
    private func applyCategoryChanges(toSave: [CKRecord], toDelete: [CKRecord.ID]) async throws {
        guard !toSave.isEmpty || !toDelete.isEmpty else { return }
        
        await withCheckedContinuation { continuation in
            let operation = CKModifyRecordsOperation(recordsToSave: toSave, recordIDsToDelete: toDelete)
            operation.savePolicy = .changedKeys
            
            operation.modifyRecordsCompletionBlock = { [weak self] savedRecords, deletedRecordIDs, error in
                if let error = error {
                    print("❌ Failed to apply category changes: \(error)")
                } else {
                    print("✅ Applied category changes: \(savedRecords?.count ?? 0) saved, \(deletedRecordIDs?.count ?? 0) deleted")
                    
                    // Clean up successful deletions
                    deletedRecordIDs?.forEach { recordID in
                        self?.removeFromDeleted(categoryID: recordID.recordName)
                    }
                }
                continuation.resume()
            }
            
            self.privateDatabase.add(operation)
        }
    }
    
    // MARK: - CloudKit Setup
    private func initializeCloudKit() async {
        do {
            let accountStatus = try await container.accountStatus()
            
            guard accountStatus == .available else {
                await updateSyncStatus(for: accountStatus)
                return
            }
            
            syncStatus = .idle
            
            // Setup CloudKit infrastructure
            try await ensureZoneExists()
            await setupSubscription()
            
            // Perform initial sync
            await performFullSync()
            
        } catch {
            await handleSyncError(error)
        }
    }
    
    private func ensureZoneExists() async throws {
        await withCheckedContinuation { continuation in
            self.privateDatabase.fetch(withRecordZoneID: self.zoneID) { [weak self] fetchedZone, error in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                if let error = error as? CKError, error.code == .zoneNotFound {
                    print("📦 Creating zone...")
                    self.privateDatabase.save(self.recordZone) { savedZone, saveError in
                        if let saveError = saveError {
                            print("❌ Failed to create zone: \(saveError)")
                        } else {
                            print("✅ Zone created")
                        }
                        continuation.resume()
                    }
                } else if let error = error {
                    print("❌ Zone check error: \(error)")
                    continuation.resume()
                } else {
                    print("✅ Zone exists")
                    continuation.resume()
                }
            }
        }
    }
    
    private func setupSubscription() async {
        await withCheckedContinuation { continuation in
            self.privateDatabase.fetchAllSubscriptions { [weak self] subscriptions, error in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                if let error = error {
                    print("⚠️ Subscription setup failed: \(error)")
                    continuation.resume()
                    return
                }
                
                let exists = subscriptions?.contains {
                    ($0 as? CKRecordZoneSubscription)?.zoneID == self.zoneID
                } ?? false
                
                if !exists {
                    let subscription = CKRecordZoneSubscription(zoneID: self.zoneID, subscriptionID: self.subscriptionID)
                    let notificationInfo = CKSubscription.NotificationInfo()
                    notificationInfo.shouldSendContentAvailable = true
                    subscription.notificationInfo = notificationInfo
                    
                    self.privateDatabase.save(subscription) { savedSubscription, saveError in
                        if let saveError = saveError {
                            print("⚠️ Subscription creation failed: \(saveError)")
                        } else {
                            print("✅ Subscription created")
                        }
                        continuation.resume()
                    }
                } else {
                    print("ℹ️ Subscription already exists")
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Record Conversion
    private func createTaskRecord(from task: TodoTask) -> CKRecord {
        let recordID = CKRecord.ID(recordName: task.id.uuidString, zoneID: zoneID)
        var record = CKRecord(recordType: taskRecordType, recordID: recordID)
        
        // Basic properties
        record["name"] = task.name as CKRecordValue
        record["creationDate"] = task.creationDate as NSDate
        record["lastModifiedDate"] = task.lastModifiedDate as NSDate
        record["startTime"] = task.startTime as NSDate
        record["duration"] = task.duration as CKRecordValue
        record["hasDuration"] = task.hasDuration as CKRecordValue
        record["icon"] = task.icon as CKRecordValue
        record["priority"] = task.priority.rawValue as CKRecordValue
        
        if let description = task.description, !description.isEmpty {
            record["description"] = description as CKRecordValue
        }
        
        // Complex properties as encoded data
        encodeToRecord(&record, key: "category", value: task.category)
        encodeToRecord(&record, key: "recurrence", value: task.recurrence)
        encodeToRecord(&record, key: "pomodoroSettings", value: task.pomodoroSettings)
        encodeToRecord(&record, key: "subtasks", value: task.subtasks.isEmpty ? nil : task.subtasks)
        encodeToRecord(&record, key: "completions", value: task.completions.isEmpty ? nil : task.completions)
        encodeToRecord(&record, key: "completionDates", value: task.completionDates.isEmpty ? nil : task.completionDates)
        
        return record
    }
    
    private func createTask(from record: CKRecord) -> TodoTask? {
        guard let name = record["name"] as? String,
              let uuid = UUID(uuidString: record.recordID.recordName) else {
            return nil
        }
        
        let creationDate = record["creationDate"] as? Date ?? record.creationDate ?? Date()
        let lastModifiedDate = record["lastModifiedDate"] as? Date ?? record.modificationDate ?? creationDate
        let startTime = record["startTime"] as? Date ?? creationDate
        let duration = record["duration"] as? TimeInterval ?? 0.0
        let hasDuration = record["hasDuration"] as? Bool ?? false
        let icon = record["icon"] as? String ?? "circle.fill"
        let description = record["description"] as? String
        let priority = Priority(rawValue: record["priority"] as? String ?? "") ?? .medium
        
        // Decode complex properties
        let category: Category? = decodeFromRecord(record, key: "category")
        let recurrence: Recurrence? = decodeFromRecord(record, key: "recurrence")
        let pomodoroSettings: PomodoroSettings? = decodeFromRecord(record, key: "pomodoroSettings") ?? .defaultSettings
        let subtasks: [Subtask] = decodeFromRecord(record, key: "subtasks") ?? []
        let completions: [Date: TaskCompletion] = decodeFromRecord(record, key: "completions") ?? [:]
        let completionDates: [Date] = decodeFromRecord(record, key: "completionDates") ?? []
        
        var task = TodoTask(
            id: uuid,
            name: name,
            description: description,
            startTime: startTime,
            duration: duration,
            hasDuration: hasDuration,
            category: category,
            priority: priority,
            icon: icon,
            recurrence: recurrence,
            pomodoroSettings: pomodoroSettings,
            subtasks: subtasks
        )
        
        task.completions = completions
        task.completionDates = completionDates
        task.creationDate = creationDate
        task.lastModifiedDate = lastModifiedDate
        
        return task
    }
    
    private func createCategoryRecord(from category: Category) -> CKRecord {
        let recordID = CKRecord.ID(recordName: category.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: categoryRecordType, recordID: recordID)
        
        record["name"] = category.name as CKRecordValue
        record["color"] = category.color as CKRecordValue
        
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
    
    // MARK: - Helper Methods
    private func encodeToRecord<T: Codable>(_ record: inout CKRecord, key: String, value: T?) {
        guard let value = value,
              let data = try? JSONEncoder().encode(value) else { return }
        record[key] = data as NSData
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
        
        return true
    }
    
    private func markAsDeleted(taskID: String) {
        var ids = deletedTaskIDs
        ids.insert(taskID)
        deletedTaskIDs = ids
    }
    
    private func markAsDeleted(categoryID: String) {
        var ids = deletedCategoryIDs
        ids.insert(categoryID)
        deletedCategoryIDs = ids
    }
    
    private func removeFromDeleted(taskID: String) {
        var ids = deletedTaskIDs
        ids.remove(taskID)
        deletedTaskIDs = ids
    }
    
    private func removeFromDeleted(categoryID: String) {
        var ids = deletedCategoryIDs
        ids.remove(categoryID)
        deletedCategoryIDs = ids
    }
    
    private func loadDeletedIDs(key: String) -> Set<String> {
        guard let data = UserDefaults.standard.data(forKey: key),
              let ids = try? JSONDecoder().decode([String].self, from: data) else {
            return Set<String>()
        }
        return Set(ids)
    }
    
    private func saveDeletedIDs(_ ids: Set<String>, key: String) {
        if let data = try? JSONEncoder().encode(Array(ids)) {
            UserDefaults.standard.set(data, forKey: key)
        }
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
                // Attempt to recreate zone
                try? await ensureZoneExists()
            default:
                syncStatus = .error("Sync failed")
            }
        } else {
            syncStatus = .error("Sync failed")
        }
    }
    
    private func handleOperationError(_ error: Error, context: String) async {
        print("❌ \(context) error: \(error)")
        
        // Don't update global sync status for individual operations
        // unless it's a critical error
        if let ckError = error as? CKError {
            switch ckError.code {
            case .unknownItem:
                print("ℹ️ Item not found - may have been already deleted")
            case .serverRecordChanged:
                print("⚠️ Record conflict - triggering sync")
                syncNow()
            default:
                break
            }
        }
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
}

// MARK: - Task Content Hashing
extension TodoTask {
    func contentHash() -> Int {
        var hasher = Hasher()
        hasher.combine(name)
        hasher.combine(description)
        hasher.combine(startTime)
        hasher.combine(duration)
        hasher.combine(hasDuration)
        hasher.combine(priority)
        hasher.combine(icon)
        return hasher.finalize()
    }
}
