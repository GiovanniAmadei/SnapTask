import Foundation
import CloudKit

// CloudKit implementation of TaskRepository
class CloudKitRepository: TaskRepository {
    // MARK: - Properties
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let recordZone: CKRecordZone
    private let zoneID: CKRecordZone.ID
    
    private let taskRecordType = "TodoTask"
    private let localCache = UserDefaultsTaskRepository()
    private var isSyncing = false
    
    var onTasksUpdated: (() -> Void)?
    
    // MARK: - Initialization
    init() {
        container = CKContainer.default()
        privateDatabase = container.privateCloudDatabase
        zoneID = CKRecordZone.ID(zoneName: "SnapTaskZone", ownerName: CKCurrentUserDefaultName)
        recordZone = CKRecordZone(zoneID: zoneID)
        
        setupCloudKit()
    }
    
    // MARK: - Repository Interface
    func getTasks() -> [TodoTask] {
        // Return tasks from local cache for immediate access
        return localCache.getTasks()
    }
    
    func getTask(id: UUID) -> TodoTask? {
        return localCache.getTask(id: id)
    }
    
    func saveTasks(_ tasks: [TodoTask]) {
        localCache.saveTasks(tasks)
        
        // Upload to CloudKit
        for task in tasks {
            saveTaskToCloudKit(task)
        }
    }
    
    func saveTask(_ task: TodoTask) {
        // First save to local repository
        localCache.saveTask(task)
        
        // Then save to CloudKit
        saveTaskToCloudKit(task)
    }
    
    func deleteTask(_ task: TodoTask) {
        deleteTaskWithId(task.id)
    }
    
    func deleteTaskWithId(_ id: UUID) {
        // First delete from local repository
        localCache.deleteTaskWithId(id)
        
        // Then delete from CloudKit
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
        privateDatabase.delete(withRecordID: recordID) { (recordID, error) in
            if let error = error {
                // Ignore if record doesn't exist
                if (error as? CKError)?.code != .unknownItem {
                    Log("Error deleting task from CloudKit: \(error.localizedDescription)", level: LogLevel.error, subsystem: "data")
                }
            } else {
                Log("Successfully deleted task from CloudKit", level: LogLevel.info, subsystem: "data")
            }
        }
    }
    
    func toggleTaskCompletion(taskId: UUID, on date: Date) -> TodoTask? {
        // Toggle in local cache
        guard let updatedTask = localCache.toggleTaskCompletion(taskId: taskId, on: date) else {
            return nil
        }
        
        // Then save to CloudKit
        saveTaskToCloudKit(updatedTask)
        
        return updatedTask
    }
    
    func toggleSubtaskCompletion(taskId: UUID, subtaskId: UUID, on date: Date) -> TodoTask? {
        // Toggle in local cache
        guard let updatedTask = localCache.toggleSubtaskCompletion(taskId: taskId, subtaskId: subtaskId, on: date) else {
            return nil
        }
        
        // Then save to CloudKit
        saveTaskToCloudKit(updatedTask)
        
        return updatedTask
    }
    
    // MARK: - CloudKit Setup
    private func setupCloudKit() {
        checkCloudKitAvailability { [weak self] available in
            guard let self = self, available else { return }
            
            // Create custom zone if needed
            self.createCustomZoneIfNeeded {
                // Setup subscription for changes
                self.setupSubscription()
                
                // Sync data from CloudKit
                self.syncFromCloudKit()
            }
        }
    }
    
    private func checkCloudKitAvailability(completion: @escaping (Bool) -> Void) {
        container.accountStatus { (status, error) in
            DispatchQueue.main.async {
                if let error = error {
                    Log("CloudKit account error: \(error.localizedDescription)", level: LogLevel.error, subsystem: "data")
                    completion(false)
                    return
                }
                
                switch status {
                case .available:
                    Log("CloudKit account available", level: LogLevel.info, subsystem: "data")
                    completion(true)
                case .noAccount:
                    Log("No iCloud account found", level: LogLevel.warning, subsystem: "data")
                    completion(false)
                case .restricted:
                    Log("iCloud account is restricted", level: LogLevel.warning, subsystem: "data")
                    completion(false)
                case .couldNotDetermine:
                    Log("Could not determine iCloud account status", level: LogLevel.error, subsystem: "data")
                    completion(false)
                @unknown default:
                    Log("Unknown iCloud account status", level: LogLevel.error, subsystem: "data")
                    completion(false)
                }
            }
        }
    }
    
    private func createCustomZoneIfNeeded(completion: @escaping () -> Void) {
        privateDatabase.fetch(withRecordZoneID: zoneID) { [weak self] (zone, error) in
            guard let self = self else { return }
            
            if let error = error as? CKError, error.code == .zoneNotFound {
                Log("Zone 'SnapTaskZone' not found. Creating zone.", level: LogLevel.info, subsystem: "data")
                
                self.privateDatabase.save(self.recordZone) { (_, error) in
                    if let error = error {
                        Log("Error creating zone: \(error.localizedDescription)", level: LogLevel.error, subsystem: "data")
                    } else {
                        Log("Zone created successfully", level: LogLevel.info, subsystem: "data")
                        DispatchQueue.main.async {
                            completion()
                        }
                    }
                }
            } else if let error = error {
                Log("Error fetching zone: \(error.localizedDescription)", level: LogLevel.error, subsystem: "data")
            } else {
                Log("Zone already exists", level: LogLevel.info, subsystem: "data")
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }
    
    private func setupSubscription() {
        let subscription = CKRecordZoneSubscription(zoneID: zoneID)
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        privateDatabase.save(subscription) { (_, error) in
            if let error = error {
                Log("Error setting up subscription: \(error.localizedDescription)", level: LogLevel.error, subsystem: "data")
            } else {
                Log("Subscription setup successfully", level: LogLevel.info, subsystem: "data")
            }
        }
    }
    
    // MARK: - CloudKit Sync
    func syncFromCloudKit() {
        guard !isSyncing else { return }
        isSyncing = true
        
        Log("Starting CloudKit sync", level: LogLevel.info, subsystem: "data")
        
        let query = CKQuery(recordType: taskRecordType, predicate: NSPredicate(value: true))
        
        privateDatabase.perform(query, inZoneWith: zoneID) { [weak self] (records, error) in
            guard let self = self else { return }
            
            if let error = error {
                Log("Error fetching records: \(error.localizedDescription)", level: LogLevel.error, subsystem: "data")
                self.isSyncing = false
                return
            }
            
            guard let records = records else {
                Log("No records found in CloudKit", level: LogLevel.info, subsystem: "data")
                self.isSyncing = false
                return
            }
            
            Log("Found \(records.count) records in CloudKit", level: LogLevel.info, subsystem: "data")
            
            // Convert CloudKit records to TodoTask objects
            var cloudTasks: [TodoTask] = []
            
            for record in records {
                if let task = self.recordToTask(record) {
                    cloudTasks.append(task)
                }
            }
            
            // Get local tasks
            let localTasks = self.localCache.getTasks()
            
            // Merge local and cloud tasks
            self.mergeTasks(localTasks: localTasks, cloudTasks: cloudTasks) { mergedTasks in
                // Update local cache with merged tasks
                self.localCache.saveTasks(mergedTasks)
                
                // Notify observers
                DispatchQueue.main.async {
                    self.onTasksUpdated?()
                    self.isSyncing = false
                    Log("CloudKit sync completed successfully", level: LogLevel.info, subsystem: "data")
                }
            }
        }
    }
    
    private func mergeTasks(localTasks: [TodoTask], cloudTasks: [TodoTask], completion: @escaping ([TodoTask]) -> Void) {
        var mergedTasks: [TodoTask] = []
        let localTasksDict = Dictionary(uniqueKeysWithValues: localTasks.map { ($0.id, $0) })
        let cloudTasksDict = Dictionary(uniqueKeysWithValues: cloudTasks.map { ($0.id, $0) })
        
        // Get all unique IDs
        let allTaskIds = Set(localTasksDict.keys).union(cloudTasksDict.keys)
        
        for taskId in allTaskIds {
            let localTask = localTasksDict[taskId]
            let cloudTask = cloudTasksDict[taskId]
            
            if let localTask = localTask, let cloudTask = cloudTask {
                // Both exist - take the most recently modified
                if localTask.lastModifiedDate > cloudTask.lastModifiedDate {
                    mergedTasks.append(localTask)
                } else {
                    mergedTasks.append(cloudTask)
                }
            } else if let localTask = localTask {
                // Only exists locally - keep it
                mergedTasks.append(localTask)
            } else if let cloudTask = cloudTask {
                // Only exists in cloud - add it
                mergedTasks.append(cloudTask)
            }
        }
        
        completion(mergedTasks)
    }
    
    private func saveTaskToCloudKit(_ task: TodoTask) {
        let record = taskToRecord(task)
        
        privateDatabase.save(record) { (_, error) in
            if let error = error {
                Log("Error saving task to CloudKit: \(error.localizedDescription)", level: LogLevel.error, subsystem: "data")
            } else {
                Log("Successfully saved task to CloudKit: \(task.name)", level: LogLevel.info, subsystem: "data")
            }
        }
    }
    
    // MARK: - Record Conversion
    private func taskToRecord(_ task: TodoTask) -> CKRecord {
        let recordID = CKRecord.ID(recordName: task.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: taskRecordType, recordID: recordID)
        
        record["name"] = task.name as CKRecordValue
        record["appCreationDate"] = task.creationDate as CKRecordValue
        record["appLastModifiedDate"] = task.lastModifiedDate as CKRecordValue
        record["startTime"] = task.startTime as CKRecordValue
        record["duration"] = task.duration as CKRecordValue
        record["hasDuration"] = task.hasDuration as CKRecordValue
        record["icon"] = task.icon as CKRecordValue
        record["priority"] = task.priority.rawValue as CKRecordValue
        record["timeScope"] = task.timeScope.rawValue as CKRecordValue
        if let scopeStart = task.scopeStartDate { record["scopeStartDate"] = scopeStart as CKRecordValue }
        if let scopeEnd = task.scopeEndDate { record["scopeEndDate"] = scopeEnd as CKRecordValue }

        if let description = task.description, !description.isEmpty {
            record["description"] = description as CKRecordValue
        }
        
        do {
            let encoder = JSONEncoder()
            if let category = task.category { record["category"] = try encoder.encode(category) as NSData }
            if let recurrence = task.recurrence { record["recurrence"] = try encoder.encode(recurrence) as NSData }
            if let pomodoroSettings = task.pomodoroSettings { record["pomodoroSettings"] = try encoder.encode(pomodoroSettings) as NSData }
            if !task.subtasks.isEmpty { record["subtasks"] = try encoder.encode(task.subtasks) as NSData }
            if !task.completions.isEmpty { record["completions"] = try encoder.encode(task.completions) as NSData }
            if !task.completionDates.isEmpty { record["completionDates"] = try encoder.encode(task.completionDates) as NSData }
        } catch {
            Log("Error encoding task data for CloudKit: \(error.localizedDescription)", level: .error, subsystem: "data")
        }
        return record
    }
    
    private func recordToTask(_ record: CKRecord) -> TodoTask? {
        do {
            guard let name = record["name"] as? String,
                  let uuidString = record.recordID.recordName as String?,
                  let uuid = UUID(uuidString: uuidString)
            else {
                Log("CloudKitRepository: Essential data missing in CKRecord (name or UUID), cannot form TodoTask. RecordID: \(record.recordID.recordName)", level: .error, subsystem: "data")
                return nil
            }

            // Prioritize app-specific keys, then server-set dates, then current date as last resort.
            let appCreationDate = record["appCreationDate"] as? Date
            let serverCreationDate = record.creationDate
            let creationDateToUse = appCreationDate ?? serverCreationDate ?? Date()

            let appLastModifiedDate = record["appLastModifiedDate"] as? Date
            let serverModificationDate = record.modificationDate
            let lastModifiedDateToUse = appLastModifiedDate ?? serverModificationDate ?? creationDateToUse

            let startTime = record["startTime"] as? Date ?? creationDateToUse
            let duration = record["duration"] as? TimeInterval ?? 0.0
            let hasDuration = record["hasDuration"] as? Bool ?? false
            let icon = record["icon"] as? String ?? "circle"
            let description = record["description"] as? String

            var priority: Priority = .medium
            if let priorityRaw = record["priority"] as? String {
                priority = Priority(rawValue: priorityRaw) ?? .medium
            }

            let decoder = JSONDecoder()
            let category = (record["category"] as? Data).flatMap { try? decoder.decode(Category.self, from: $0) }
            let recurrence = (record["recurrence"] as? Data).flatMap { try? decoder.decode(Recurrence.self, from: $0) }
            let pomodoroSettings = (record["pomodoroSettings"] as? Data).flatMap { try? decoder.decode(PomodoroSettings.self, from: $0) }
            let subtasks = (record["subtasks"] as? Data).flatMap { try? decoder.decode([Subtask].self, from: $0) } ?? []
            let completions = (record["completions"] as? Data).flatMap { try? decoder.decode([Date: TaskCompletion].self, from: $0) } ?? [:]
            let completionDates = (record["completionDates"] as? Data).flatMap { try? decoder.decode([Date].self, from: $0) } ?? []

            let timeScopeRaw = record["timeScope"] as? String
            let decodedTimeScope = TaskTimeScope(rawValue: timeScopeRaw ?? "") ?? .today
            let decodedScopeStart = record["scopeStartDate"] as? Date
            let decodedScopeEnd = record["scopeEndDate"] as? Date

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
                subtasks: subtasks,
                timeScope: decodedTimeScope,
                scopeStartDate: decodedScopeStart,
                scopeEndDate: decodedScopeEnd
            )

            task.creationDate = creationDateToUse
            task.lastModifiedDate = lastModifiedDateToUse
            task.completions = completions
            task.completionDates = completionDates
            
            return task
        } catch {
            Log("CloudKitRepository: Error decoding TodoTask from CKRecord (POST-GUARD): \(error.localizedDescription). RecordID: \(record.recordID.recordName)", level: .error, subsystem: "data")
            return nil
        }
    }
}