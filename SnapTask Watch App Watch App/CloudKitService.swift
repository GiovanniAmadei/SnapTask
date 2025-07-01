import Foundation
import CloudKit
import Combine

class CloudKitService: ObservableObject {
    static let shared = CloudKitService()
    
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let recordZone: CKRecordZone
    private let zoneID: CKRecordZone.ID
    
    private let taskRecordType = "TodoTask"
    private let deletedTasksKey = "deletedTaskIDs_watch"
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?
    
    private var subscriptions = Set<AnyCancellable>()
    
    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    private var deletedTaskIDs: Set<String> {
        get {
            if let data = UserDefaults.standard.data(forKey: deletedTasksKey),
               let ids = try? JSONDecoder().decode([String].self, from: data) {
                return Set(ids)
            }
            return Set<String>()
        }
        set {
            if let data = try? JSONEncoder().encode(Array(newValue)) {
                UserDefaults.standard.set(data, forKey: deletedTasksKey)
            }
        }
    }
    
    private init() {
        container = CKContainer(identifier: "iCloud.com.giovanniamadei.SnapTaskProAlpha")
        privateDatabase = container.privateCloudDatabase
        zoneID = CKRecordZone.ID(zoneName: "SnapTaskZone", ownerName: CKCurrentUserDefaultName)
        recordZone = CKRecordZone(zoneID: zoneID)
        
        checkCloudKitAvailability()
    }
    
    func setup() {
        guard !isSimulator else {
            print("Watch CKService: Skipping CloudKit setup on simulator")
            return
        }
        
        createCustomZoneIfNeeded()
        subscribeToChanges()
    }
    
    func syncTasks() {
        guard !isSimulator else {
            print("Watch CKService: Skipping CloudKit sync on simulator")
            return
        }
        
        isSyncing = true
        let localTasks = TaskManager.shared.tasks
        
        fetchAllTasks { [weak self] remoteTasks, error in
            guard let self = self else { return }
            
            if let error = error {
                self.handleSyncError(error)
                return
            }
            self.mergeTasksSafely(localTasks: localTasks, remoteTasks: remoteTasks ?? [])
        }
    }
    
    func saveTask(_ task: TodoTask) {
        guard !isSimulator else {
            print("Watch CKService: Skipping CloudKit save on simulator")
            return
        }
        
        let record = taskToRecord(task)
        saveRecord(record) { [weak self] success, error in
            if let error = error {
                print("Watch CKService: Error saving task '\(task.name)': \(error.localizedDescription)")
                self?.handleSyncError(error)
            }
        }
    }
    
    func deleteTask(_ task: TodoTask) {
        guard !isSimulator else {
            print("Watch CKService: Skipping CloudKit delete on simulator")
            return
        }
        
        let recordID = CKRecord.ID(recordName: task.id.uuidString, zoneID: zoneID)
        print("Watch CKService: Attempting to delete task with ID: \(task.id.uuidString)")
        addToDeletedTasks(taskID: task.id.uuidString)
        
        privateDatabase.delete(withRecordID: recordID) { [weak self] (deletedRecordID, error) in
            if let error = error as? CKError {
                if error.code != .unknownItem {
                    print("Watch CKService: Error deleting task: \(error.localizedDescription)")
                    self?.handleSyncError(error)
                } else {
                    print("Watch CKService: Task already deleted or not found in CloudKit")
                }
            } else if let error = error {
                print("Watch CKService: Error deleting task: \(error.localizedDescription)")
                self?.handleSyncError(error)
            } else {
                print("Watch CKService: Task successfully deleted from CloudKit")
                DispatchQueue.main.async {
                    self?.lastSyncDate = Date()
                }
            }
        }
    }
    
    private func addToDeletedTasks(taskID: String) {
        var ids = deletedTaskIDs
        ids.insert(taskID)
        deletedTaskIDs = ids
    }
    
    private func removeFromDeletedTasks(taskID: String) {
        var ids = deletedTaskIDs
        ids.remove(taskID)
        deletedTaskIDs = ids
    }
    
    private func isTaskDeleted(taskID: String) -> Bool {
        return deletedTaskIDs.contains(taskID)
    }
        
    private func checkCloudKitAvailability() {
        print("Watch CKService: Checking CloudKit availability with container: iCloud.com.giovanniamadei.SnapTaskProAlpha")
        
        container.accountStatus { [weak self] (status, error) in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch status {
                case .available:
                    print("Watch CKService: iCloud Account Available. Setting up zone.")
                    self.setup()
                case .noAccount:
                    print("Watch CKService: No iCloud account found. Please sign in to iCloud on the paired iPhone.")
                    self.syncError = NSError(domain: "CloudKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "No iCloud account found. Please sign in to iCloud on the paired iPhone."])
                case .restricted:
                    print("Watch CKService: iCloud access restricted.")
                    self.syncError = NSError(domain: "CloudKit", code: 2, userInfo: [NSLocalizedDescriptionKey: "iCloud access restricted."])
                case .couldNotDetermine:
                    let errDesc = error?.localizedDescription ?? "Could not determine iCloud account status."
                    print("Watch CKService: Could not determine iCloud status. Error: \(errDesc)")
                    self.syncError = error ?? NSError(domain: "CloudKit", code: 3, userInfo: [NSLocalizedDescriptionKey: errDesc])
                @unknown default:
                    print("Watch CKService: Unknown iCloud account status.")
                    self.syncError = NSError(domain: "CloudKit", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unknown iCloud status."])
                }
            }
        }
    }
    
    private func createCustomZoneIfNeeded() {
        privateDatabase.fetch(withRecordZoneID: zoneID) { [weak self] (zone, error) in
            guard let self = self else { return }
            if let error = error as? CKError, error.code == .zoneNotFound {
                print("Watch CKService: Zone 'SnapTaskZone' not found. Attempting to create.")
                self.createCustomZone()
            } else if let error = error {
                print("Watch CKService: Error fetching zone: \(error.localizedDescription)")
                self.handleSyncError(error)
            } else {
                print("Watch CKService: Zone 'SnapTaskZone' already exists.")
            }
        }
    }
    
    private func createCustomZone() {
        privateDatabase.save(recordZone) { [weak self] (zone, error) in
            guard let self = self else { return }
            if let error = error {
                print("Watch CKService: Error creating zone: \(error.localizedDescription)")
                self.handleSyncError(error)
            } else {
                print("Watch CKService: Zone 'SnapTaskZone' created successfully.")
                self.syncError = nil
                self.syncTasks()
            }
        }
    }
    
    private func subscribeToChanges() {
        let subscription = CKRecordZoneSubscription(zoneID: zoneID)
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        privateDatabase.save(subscription) { (savedSubscription, error) in
            if let error = error {
                print("Watch CKService: Error saving subscription: \(error.localizedDescription)")
            } else {
                print("Watch CKService: Successfully subscribed to zone changes.")
            }
        }
    }
    
    private func fetchAllTasks(completion: @escaping ([TodoTask]?, Error?) -> Void) {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: taskRecordType, predicate: predicate)
        print("Watch CKService: Fetching all tasks from CloudKit")
        
        privateDatabase.perform(query, inZoneWith: zoneID) { [weak self] (records, error) in
            guard let self = self else {
                completion(nil, NSError(domain: "CloudKitService.Watch", code: -1, userInfo: [NSLocalizedDescriptionKey: "Self is nil in fetchAllTasks"]))
                return
            }
            
            if let error = error {
                print("Watch CKService: Error fetching tasks: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            guard let records = records else {
                print("Watch CKService: No records found")
                completion([], nil)
                return
            }
            
            let localTasks = TaskManager.shared.tasks
            let localTasksIDs = Set(localTasks.map { $0.id.uuidString })
            
            let newTaskThreshold: TimeInterval = 60 * 5
            let recentlyCreatedTaskIDs = Set(localTasks
                .filter { Date().timeIntervalSince($0.creationDate) < newTaskThreshold }
                .map { $0.id.uuidString })
            
            let remoteTaskIDs = Set(records.map { $0.recordID.recordName })
            let missingTaskIDs = localTasksIDs.subtracting(remoteTaskIDs)
            
            for taskID in missingTaskIDs {
                if !recentlyCreatedTaskIDs.contains(taskID) && !self.isTaskDeleted(taskID: taskID) {
                    print("Watch CKService: Task \(taskID) exists locally but not remotely. Adding to deletion list.")
                    self.addToDeletedTasks(taskID: taskID)
                } else if recentlyCreatedTaskIDs.contains(taskID) {
                    print("Watch CKService: Task \(taskID) was recently created but not yet on server. Not marking as deleted.")
                }
            }
            
            let tasks = records.compactMap { record -> TodoTask? in
                if self.isTaskDeleted(taskID: record.recordID.recordName) {
                    print("Watch CKService: Skipping deleted task with ID: \(record.recordID.recordName)")
                    return nil
                }
                return self.recordToTask(record)
            }
            completion(tasks, nil)
        }
    }
    
    private func saveRecord(_ record: CKRecord, completion: @escaping (Bool, Error?) -> Void) {
        let modifyOperation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        modifyOperation.savePolicy = .changedKeys
        
        modifyOperation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
            if let error = error {
                completion(false, error)
                return
            }
            completion(true, nil)
        }
        privateDatabase.add(modifyOperation)
    }
    
    private func mergeTasksSafely(localTasks: [TodoTask], remoteTasks: [TodoTask]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let localDeviceDeletedIDs = self.deletedTaskIDs
            var finalLocalState = [UUID: TodoTask]()
            var recordsToSaveToCloudKit = [CKRecord]()
            var recordIDsToDeleteFromCloudKit = Set<CKRecord.ID>()
            
            let newTaskThreshold: TimeInterval = 60 * 5
            let recentlyCreatedTasks = localTasks.filter { Date().timeIntervalSince($0.creationDate) < newTaskThreshold }
            let recentlyCreatedTaskIDs = Set(recentlyCreatedTasks.map { $0.id.uuidString })
            
            for task in recentlyCreatedTasks {
                print("Watch CKService: Merge - Scheduling recent task '\(task.name)' for upload to CloudKit.")
                recordsToSaveToCloudKit.append(self.taskToRecord(task))
                finalLocalState[task.id] = task
            }
            
            localDeviceDeletedIDs.forEach {
                if !recentlyCreatedTaskIDs.contains($0) {
                    recordIDsToDeleteFromCloudKit.insert(CKRecord.ID(recordName: $0, zoneID: self.zoneID))
                } else {
                    print("Watch CKService: Merge - Not deleting recently created task with ID: \($0)")
                }
            }
            
            let localTasksMap = Dictionary(localTasks.map { ($0.id, $0) }, uniquingKeysWith: { (first, _) in first })
            let remoteTasksMap = Dictionary(remoteTasks.map { ($0.id, $0) }, uniquingKeysWith: { (first, _) in first })
            
            remoteTasksMap.keys.forEach { taskID in
                let remoteTask = remoteTasksMap[taskID]
                var task = remoteTask
                
                if let localTask = localTasksMap[taskID] {
                    if localTask.lastModifiedDate >= task?.lastModifiedDate ?? Date() {
                        task = localTask
                        print("Watch CKService: Merge - Local task '\(localTask.name)' is more recently modified. Using local version.")
                    }
                }
                
                finalLocalState[taskID] = task
                if recentlyCreatedTaskIDs.contains(taskID.uuidString) {
                    recordsToSaveToCloudKit.append(self.taskToRecord(task!))
                }
            }
            
            recordsToSaveToCloudKit = recordsToSaveToCloudKit.filter { record in
                let recordIDString = record.recordID.recordName
                if recordIDsToDeleteFromCloudKit.contains(where: { $0.recordName == recordIDString }) {
                    if recentlyCreatedTaskIDs.contains(recordIDString) {
                        print("Watch CKService: Merge - Keeping recently created task \(recordIDString) even though it's in the deletion list")
                        return true
                    }
                    print("Watch CKService: Merge - Preventing save of task \(recordIDString) since it's also marked for deletion")
                    return false
                }
                return true
            }
            
            self.applyDeletions(protectedIDs: recentlyCreatedTaskIDs)
            
            let tasksForManager = Array(finalLocalState.values)
            print("Watch CKService: Merge - Updating TaskManager with \(tasksForManager.count) tasks.")
            TaskManager.shared.updateAllTasks(tasksForManager)

            let finalRecordIDsToDelete = Array(recordIDsToDeleteFromCloudKit)
            if !recordsToSaveToCloudKit.isEmpty || !finalRecordIDsToDelete.isEmpty {
                print("Watch CKService: Merge - CloudKit: Save \(recordsToSaveToCloudKit.count), Delete \(finalRecordIDsToDelete.count)")
                let modifyOp = CKModifyRecordsOperation(recordsToSave: recordsToSaveToCloudKit, recordIDsToDelete: finalRecordIDsToDelete)
                modifyOp.savePolicy = .changedKeys
                
                modifyOp.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("Watch CKService: Merge - CKModifyRecordsOp error: \(error.localizedDescription)")
                            self.handleSyncError(error)
                        } else {
                            print("Watch CKService: Merge - CKModifyRecordsOp success. Saved: \(recordsToSaveToCloudKit.count), Deleted: \(finalRecordIDsToDelete.count).")
                            finalRecordIDsToDelete.forEach { self.removeFromDeletedTasks(taskID: $0.recordName) }
                            self.syncError = nil
                        }
                        self.isSyncing = false
                        self.lastSyncDate = Date()
                    }
                }
                self.privateDatabase.add(modifyOp)
            } else {
                print("Watch CKService: Merge - No CloudKit operations needed.")
                self.isSyncing = false
                self.lastSyncDate = Date()
                self.syncError = nil
            }
        }
    }
    
    private func applyDeletions(protectedIDs: Set<String> = Set<String>()) {
        let localTasks = TaskManager.shared.tasks
        let deletedIDs = self.deletedTaskIDs
        
        let tasksToRemove = localTasks.filter {
            let taskID = $0.id.uuidString
            return deletedIDs.contains(taskID) && !protectedIDs.contains(taskID)
        }
        
        if !tasksToRemove.isEmpty {
            print("Watch CKService: Applying \(tasksToRemove.count) pending deletions locally")
            
            var updatedTasks = localTasks
            updatedTasks.removeAll { task in
                let taskID = task.id.uuidString
                let shouldRemove = deletedIDs.contains(taskID) && !protectedIDs.contains(taskID)
                if shouldRemove {
                    print("Watch CKService: Removing locally task with ID: \(taskID)")
                }
                return shouldRemove
            }
            
            if updatedTasks.count != localTasks.count {
                TaskManager.shared.updateAllTasks(updatedTasks)
            }
        }
    }
    
    private func taskToRecord(_ task: TodoTask) -> CKRecord {
        let recordID = CKRecord.ID(recordName: task.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: taskRecordType, recordID: recordID)
        record["name"] = task.name as CKRecordValue
        record["appCreationDate"] = task.creationDate as NSDate
        record["lastModifiedDate"] = task.lastModifiedDate as NSDate
        record["startTime"] = task.startTime as NSDate
        record["duration"] = task.duration as CKRecordValue
        record["hasDuration"] = task.hasDuration as CKRecordValue
        record["icon"] = task.icon as CKRecordValue
        record["priority"] = task.priority.rawValue as CKRecordValue
        
        if let description = task.description, !description.isEmpty {
            record["description"] = description as CKRecordValue
        } else {
            record["description"] = nil
        }
        
        do {
            if let category = task.category {
                record["category"] = try JSONEncoder().encode(category) as NSData
            }
            if let recurrence = task.recurrence {
                record["recurrence"] = try JSONEncoder().encode(recurrence) as NSData
            }
            if let pomodoroSettings = task.pomodoroSettings {
                record["pomodoroSettings"] = try JSONEncoder().encode(pomodoroSettings) as NSData
            }
            if !task.subtasks.isEmpty {
                record["subtasks"] = try JSONEncoder().encode(task.subtasks) as NSData
            }
            if !task.completions.isEmpty {
                record["completions"] = try JSONEncoder().encode(task.completions) as NSData
            }
            if !task.completionDates.isEmpty {
                record["completionDates"] = try JSONEncoder().encode(task.completionDates) as NSData
            }
        } catch {
            print("Watch CKService: Error encoding task data: \(error)")
        }
        
        return record
    }
    
    private func recordToTask(_ record: CKRecord) -> TodoTask? {
        guard let name = record["name"] as? String else { return nil }
        
        let modelCreationDate = record["appCreationDate"] as? Date ?? record.creationDate ?? Date()
        let lastModifiedDate = record["lastModifiedDate"] as? Date ?? record.modificationDate ?? modelCreationDate
        let startTime = record["startTime"] as? Date ?? modelCreationDate
        let duration = record["duration"] as? TimeInterval ?? 0.0
        let hasDuration = record["hasDuration"] as? Bool ?? false
        let icon = record["icon"] as? String ?? "circle.fill"
        let description = record["description"] as? String
        let priority = Priority(rawValue: record["priority"] as? String ?? "") ?? .medium
        
        let category = (record["category"] as? Data).flatMap { try? JSONDecoder().decode(Category.self, from: $0) }
        let recurrence = (record["recurrence"] as? Data).flatMap { try? JSONDecoder().decode(Recurrence.self, from: $0) }
        let pomodoroSettings = (record["pomodoroSettings"] as? Data).flatMap { try? JSONDecoder().decode(PomodoroSettings.self, from: $0) }
        let subtasks = (record["subtasks"] as? Data).flatMap { try? JSONDecoder().decode([Subtask].self, from: $0) } ?? []
        let completions = (record["completions"] as? Data).flatMap { try? JSONDecoder().decode([Date: TaskCompletion].self, from: $0) } ?? [:]
        let completionDates = (record["completionDates"] as? Data).flatMap { try? JSONDecoder().decode([Date].self, from: $0) } ?? []
        
        let uuid = UUID(uuidString: record.recordID.recordName) ?? UUID()
        
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
        task.creationDate = modelCreationDate
        task.lastModifiedDate = lastModifiedDate
        
        return task
    }
    
    private func handleSyncError(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            print("Watch CKService: Sync Error - \(error.localizedDescription)")
            self?.syncError = error
            self?.isSyncing = false
        }
    }
}
