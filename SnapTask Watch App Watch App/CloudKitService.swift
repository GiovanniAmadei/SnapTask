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
    private let deletedTasksKey = "deletedTaskIDs_watch" // Key for tracking deleted tasks on watch
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?
    
    private var subscriptions = Set<AnyCancellable>()
    // private var changedRecordZoneIDs: [CKRecordZone.ID] = [] // Not typically used in basic sync
    
    // Tracking deleted task IDs - Watch specific UserDefaults key
    private var deletedTaskIDs: Set<String> {
        get {
            // Use App Group UserDefaults if data needs to be shared with the main app directly
            // For now, using standard UserDefaults for the watch extension
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
        container = CKContainer(identifier: "iCloud.com.giovanniamadei.SnapTask") 
        privateDatabase = container.privateCloudDatabase
        zoneID = CKRecordZone.ID(zoneName: "SnapTaskZone", ownerName: CKCurrentUserDefaultName)
        recordZone = CKRecordZone(zoneID: zoneID)
        
        checkCloudKitAvailability()
    }
    
    // MARK: - Public Methods
    
    func setup() {
        createCustomZoneIfNeeded()
        subscribeToChanges() // Enable if using push notifications for sync
    }
    
    func syncTasks() {
        isSyncing = true
        // Access TaskManager specific to the Watch App if it's different
        // Assuming TaskManager.shared is appropriate for watch context
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
        let record = taskToRecord(task)
        saveRecord(record) { [weak self] success, error in
            if let error = error {
                print("Watch CKService: Error saving task '\(task.name)': \(error.localizedDescription)")
                self?.handleSyncError(error)
            }
        }
    }
    
    func deleteTask(_ task: TodoTask) {
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
        container.accountStatus { [weak self] (status, error) in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch status {
                case .available:
                    print("Watch CKService: iCloud Account Available. Setting up zone.")
                    self.setup()
                case .noAccount:
                    print("Watch CKService: No iCloud account found.")
                    self.syncError = NSError(domain: "CloudKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "No iCloud account found."])
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
        print("Watch CKService: Executing createCustomZone() for 'SnapTaskZone'.")
        privateDatabase.save(recordZone) { [weak self] (zone, error) in
            guard let self = self else { return }
            if let error = error {
                print("Watch CKService: Error creating zone: \(error.localizedDescription)")
                self.handleSyncError(error)
            } else {
                print("Watch CKService: Zone 'SnapTaskZone' created successfully.")
                self.syncError = nil
                self.syncTasks() // Sync after zone creation
            }
        }
    }
    
    private func subscribeToChanges() {
        let subscription = CKRecordZoneSubscription(zoneID: zoneID)
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true // For silent background updates
        subscription.notificationInfo = notificationInfo
        
        privateDatabase.save(subscription) { (savedSubscription, error) in
            if let error = error {
                print("Watch CKService: Error saving subscription: \(error.localizedDescription)")
                // self.handleSyncError(error) // Decide if this is a critical sync error
            } else {
                print("Watch CKService: Successfully subscribed to zone changes.")
            }
        }
    }
    
    private func fetchAllTasks(completion: @escaping ([TodoTask]?, Error?) -> Void) {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: taskRecordType, predicate: predicate)
        print("Watch CKService: Fetching all tasks from CloudKit")
        
        // Prima ottieni task locali per confrontarle con quelle remote
        let localTasks = TaskManager.shared.tasks
        let localTasksIDs = Set(localTasks.map { $0.id.uuidString })
        
        // Registra i timestamp di creazione per poter distinguere tra task nuove e vecchie
        let newTaskThreshold: TimeInterval = 60 * 5 // 5 minuti
        let recentlyCreatedTaskIDs = Set(localTasks
            .filter { Date().timeIntervalSince($0.creationDate) < newTaskThreshold }
            .map { $0.id.uuidString })
        
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
                
                // Non marcare come eliminate le task create di recente che non sono ancora state sincronizzate
                if !localTasks.isEmpty {
                    print("Watch CKService: No records on server, but \(localTasks.count) local tasks.")
                    for localTask in localTasks {
                        let taskIDString = localTask.id.uuidString
                        
                        // Se la task non è stata creata di recente e non è già nella lista delle eliminate
                        if !recentlyCreatedTaskIDs.contains(taskIDString) && !self.isTaskDeleted(taskID: taskIDString) {
                            print("Watch CKService: Task \(taskIDString) might have been deleted remotely. Adding to deletion list.")
                            self.addToDeletedTasks(taskID: taskIDString)
                        } else if recentlyCreatedTaskIDs.contains(taskIDString) {
                            print("Watch CKService: Task \(taskIDString) was recently created. Not marking as deleted.")
                        }
                    }
                }
                
                completion([], nil)
                return
            }
            
            print("Watch CKService: Found \(records.count) records in CloudKit")
            
            // Raccoglie tutti gli ID dei record remoti
            let remoteTaskIDs = Set(records.map { $0.recordID.recordName })
            
            // Trova task locali che non esistono più sul server (potrebbero essere state eliminate da altri dispositivi)
            let missingTaskIDs = localTasksIDs.subtracting(remoteTaskIDs)
            
            for taskID in missingTaskIDs {
                // Se la task non è recente e non è già nella lista delle task eliminate
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
                print("Watch CKService: Error saving record: \(error.localizedDescription)")
                completion(false, error)
                return
            }
            print("Watch CKService: Record saved successfully. Count: \(savedRecords?.count ?? 0)")
            completion(true, nil)
        }
        privateDatabase.add(modifyOperation)
    }
    
    private func mergeTasksSafely(localTasks: [TodoTask], remoteTasks: [TodoTask]) {
        print("Watch CKService: mergeTasksSafely - Local: \(localTasks.count), Remote: \(remoteTasks.count)")
        let localDeviceDeletedIDs = self.deletedTaskIDs
        var finalLocalState = [UUID: TodoTask]()
        var recordsToSaveToCloudKit = [CKRecord]()
        var recordIDsToDeleteFromCloudKit = Set<CKRecord.ID>()
        
        // Registra i timestamp di creazione per poter distinguere tra task nuove e vecchie
        let newTaskThreshold: TimeInterval = 60 * 5 // 5 minuti
        let recentlyCreatedTasks = localTasks.filter { Date().timeIntervalSince($0.creationDate) < newTaskThreshold }
        let recentlyCreatedTaskIDs = Set(recentlyCreatedTasks.map { $0.id.uuidString })
        
        // Prepara tutte le task recenti per l'upload a CloudKit
        for task in recentlyCreatedTasks {
            print("Watch CKService: Merge - Scheduling recent task '\(task.name)' for upload to CloudKit.")
            recordsToSaveToCloudKit.append(self.taskToRecord(task))
            finalLocalState[task.id] = task
        }
        
        // Store task IDs present in the remote dataset
        var remoteTaskIDsSet = Set<String>()

        localDeviceDeletedIDs.forEach {
            // Non programmare l'eliminazione delle task create di recente
            if !recentlyCreatedTaskIDs.contains($0) {
                recordIDsToDeleteFromCloudKit.insert(CKRecord.ID(recordName: $0, zoneID: self.zoneID))
            } else {
                print("Watch CKService: Merge - Not deleting recently created task with ID: \($0)")
            }
        }

        let localTasksMap = Dictionary(localTasks.map { ($0.id, $0) }, uniquingKeysWith: { (first, _) in first })
        let remoteTasksMap = Dictionary(remoteTasks.map { ($0.id, $0) }, uniquingKeysWith: { (first, _) in first })
        
        // Collect all the task IDs that exist in the remote dataset
        remoteTasksMap.keys.forEach { taskID in
            remoteTaskIDsSet.insert(taskID.uuidString)
        }
        
        // Check if there are tasks in localTasks that don't exist in remoteTasks anymore
        // This could indicate they were deleted by another device
        for localTask in localTasks {
            let taskIDString = localTask.id.uuidString
            
            // Non considerare le task recenti
            if recentlyCreatedTaskIDs.contains(taskIDString) {
                continue
            }
            
            if !remoteTaskIDsSet.contains(taskIDString) && !localDeviceDeletedIDs.contains(taskIDString) {
                // The task exists locally but not remotely, and this device didn't delete it
                // This suggests it was deleted by another device
                print("Watch CKService: Merge - Task '\(localTask.name)' missing from remote, likely deleted by another device. Adding to local deletion list.")
                addToDeletedTasks(taskID: taskIDString)
                recordIDsToDeleteFromCloudKit.insert(CKRecord.ID(recordName: taskIDString, zoneID: self.zoneID))
            }
        }
        
        let allConsideredIDs = Set(localTasksMap.keys).union(remoteTasksMap.keys)

        for taskID in allConsideredIDs {
            let idString = taskID.uuidString
            
            // Se questa è una task recente, è già stata aggiunta a finalLocalState e recordsToSaveToCloudKit
            if recentlyCreatedTaskIDs.contains(idString) {
                continue
            }
            
            let localTask = localTasksMap[taskID]
            let remoteTask = remoteTasksMap[taskID]

            // Skip tasks that are marked for deletion
            if localDeviceDeletedIDs.contains(idString) {
                print("Watch CKService: Merge - Task \(idString) in local deleted list. Ensuring server delete.")
                continue
            }

            if let lt = localTask, let rt = remoteTask {
                // Both devices have the task - choose the most recent version
                if lt.lastModifiedDate >= rt.lastModifiedDate {
                    finalLocalState[taskID] = lt
                    if lt.lastModifiedDate > rt.lastModifiedDate {
                        print("Watch CKService: Merge - Local task '\(lt.name)' is more recently modified. Scheduling for server update.")
                        recordsToSaveToCloudKit.append(self.taskToRecord(lt))
                    } else {
                        print("Watch CKService: Merge - Local task '\(lt.name)' and remote task have same modification date.")
                    }
                } else {
                    finalLocalState[taskID] = rt
                    print("Watch CKService: Merge - Remote task '\(rt.name)' is more recently modified. Updating local state.")
                }
            } else if let lt = localTask {
                // Task exists locally but not remotely - likely a new local task
                finalLocalState[taskID] = lt
                print("Watch CKService: Merge - Task '\(lt.name)' local-only. Adding to server.")
                recordsToSaveToCloudKit.append(self.taskToRecord(lt))
            } else if let rt = remoteTask {
                // Task exists remotely but not locally - new task from another device
                finalLocalState[taskID] = rt
                print("Watch CKService: Merge - Remote task '\(rt.name)' new. Adding locally.")
            }
        }
        
        // Ensure we don't try to save any task that's also marked for deletion
        // This prevents the "You can't save and delete the same record" error
        recordsToSaveToCloudKit = recordsToSaveToCloudKit.filter { record in
            let recordIDString = record.recordID.recordName
            if recordIDsToDeleteFromCloudKit.contains(where: { $0.recordName == recordIDString }) {
                // Ma mantieni le task recenti indipendentemente dalla lista delle eliminazioni
                if recentlyCreatedTaskIDs.contains(recordIDString) {
                    print("Watch CKService: Merge - Keeping recently created task \(recordIDString) even though it's in the deletion list")
                    return true
                }
                print("Watch CKService: Merge - Preventing save of task \(recordIDString) since it's also marked for deletion")
                return false
            }
            return true
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Prima applica le eliminazioni per assicurarsi che le task eliminate vengano rimosse
            self.applyDeletions(protectedIDs: recentlyCreatedTaskIDs)
            
            // Poi aggiorna le task rimanenti
            let tasksForManager = Array(finalLocalState.values)
            print("Watch CKService: Merge - Updating TaskManager with \(tasksForManager.count) tasks.")
            TaskManager.shared.updateAllTasks(tasksForManager) // Assumes TaskManager.shared is correct for Watch

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
                            print("Watch CKService: Merge - CKModifyRecordsOp success. Saved: \(savedRecords?.count ?? 0), Deleted: \(deletedRecordIDs?.count ?? 0).")
                            // Clean up UserDefaults after confirmed server deletion
                            deletedRecordIDs?.forEach { self.removeFromDeletedTasks(taskID: $0.recordName) }
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
    
    // Metodo per applicare le eliminazioni localmente
    private func applyDeletions(protectedIDs: Set<String> = Set<String>()) {
        let localTasks = TaskManager.shared.tasks
        let deletedIDs = self.deletedTaskIDs
        
        // Trova le task che dovrebbero essere eliminate ma sono ancora presenti localmente
        let tasksToRemove = localTasks.filter { 
            let taskID = $0.id.uuidString
            // Non eliminare le task protette (come quelle appena create)
            return deletedIDs.contains(taskID) && !protectedIDs.contains(taskID) 
        }
        
        if !tasksToRemove.isEmpty {
            print("Watch CKService: Applying \(tasksToRemove.count) pending deletions locally")
            
            // Per ciascuna task da eliminare, rimuovila direttamente dall'array di task del TaskManager
            var updatedTasks = localTasks
            updatedTasks.removeAll { task in
                let taskID = task.id.uuidString
                let shouldRemove = deletedIDs.contains(taskID) && !protectedIDs.contains(taskID)
                if shouldRemove {
                    print("Watch CKService: Removing locally task with ID: \(taskID)")
                }
                return shouldRemove
            }
            
            // Aggiorna il TaskManager con la lista di task filtrata
            if updatedTasks.count != localTasks.count {
                TaskManager.shared.updateAllTasks(updatedTasks)
            }
        }
    }
    
    private func taskToRecord(_ task: TodoTask) -> CKRecord {
        let recordID = CKRecord.ID(recordName: task.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: taskRecordType, recordID: recordID)
        // Basic properties
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
        // Complex properties as NSData
        do {
            if let category = task.category { record["category"] = try JSONEncoder().encode(category) as NSData }
            if let recurrence = task.recurrence { record["recurrence"] = try JSONEncoder().encode(recurrence) as NSData }
            if let pomodoroSettings = task.pomodoroSettings { record["pomodoroSettings"] = try JSONEncoder().encode(pomodoroSettings) as NSData }
            if !task.subtasks.isEmpty { record["subtasks"] = try JSONEncoder().encode(task.subtasks) as NSData }
            if !task.completions.isEmpty { record["completions"] = try JSONEncoder().encode(task.completions) as NSData }
            if !task.completionDates.isEmpty { record["completionDates"] = try JSONEncoder().encode(task.completionDates) as NSData }
        } catch {
            print("Watch CKService: Error encoding task data for '\(task.name)': \(error.localizedDescription)")
        }
        return record
    }
    
    private func recordToTask(_ record: CKRecord) -> TodoTask? {
        print("Watch CKService: recordToTask - Processing record ID: \(record.recordID.recordName)")
        do {
            guard let name = record["name"] as? String else { return nil }
            let modelCreationDate = record["appCreationDate"] as? Date ?? record.creationDate ?? Date()
            let lastModifiedDate = record["lastModifiedDate"] as? Date ?? record.modificationDate ?? modelCreationDate
            let startTime = record["startTime"] as? Date ?? modelCreationDate
            let duration = record["duration"] as? TimeInterval ?? 0.0
            let hasDuration = record["hasDuration"] as? Bool ?? false
            let icon = record["icon"] as? String ?? "circle.fill"
            let description = record["description"] as? String
            var priority: Priority = .medium
            if let priorityRaw = record["priority"] as? String { priority = Priority(rawValue: priorityRaw) ?? .medium }
            // Simplified complex property decoding, add individual catch blocks if needed for fine-grained error handling
            let category = (record["category"] as? Data).flatMap { try? JSONDecoder().decode(Category.self, from: $0) }
            let recurrence = (record["recurrence"] as? Data).flatMap { try? JSONDecoder().decode(Recurrence.self, from: $0) }
            let pomodoroSettings = (record["pomodoroSettings"] as? Data).flatMap { try? JSONDecoder().decode(PomodoroSettings.self, from: $0) }
            let subtasks = (record["subtasks"] as? Data).flatMap { try? JSONDecoder().decode([Subtask].self, from: $0) } ?? []
            let completions = (record["completions"] as? Data).flatMap { try? JSONDecoder().decode([Date: TaskCompletion].self, from: $0) } ?? [:]
            let completionDates = (record["completionDates"] as? Data).flatMap { try? JSONDecoder().decode([Date].self, from: $0) } ?? []
            let uuid = UUID(uuidString: record.recordID.recordName) ?? UUID()
            
            var task = TodoTask(id: uuid, name: name, description: description, startTime: startTime, duration: duration, hasDuration: hasDuration, category: category, priority: priority, icon: icon, recurrence: recurrence, pomodoroSettings: pomodoroSettings, subtasks: subtasks)
            task.completions = completions
            task.completionDates = completionDates
            task.creationDate = modelCreationDate
            task.lastModifiedDate = lastModifiedDate
            return task
        } catch {
            print("Watch CKService: recordToTask - Error processing record ID \(record.recordID.recordName): \(error.localizedDescription)")
            return nil
        }
    }
    
    private func handleSyncError(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            print("Watch CKService: Sync Error - \(error.localizedDescription)")
            self?.syncError = error
            self?.isSyncing = false
        }
    }
}

// Ensure TaskManager, TodoTask, Category, Priority, etc. are available to the Watch target
// And that their definitions are consistent with the iOS app target.

// If .tasksDidUpdate notification is used, ensure it's defined and posted correctly in watch context.
// extension Notification.Name {
//    static let tasksDidUpdate = Notification.Name("tasksDidUpdate_watch")
// } 