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
    private let deletedTasksKey = "deletedTaskIDs" // Key for tracking deleted tasks
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?
    
    private var subscriptions = Set<AnyCancellable>()
    private var changedRecordZoneIDs: [CKRecordZone.ID] = []
    
    // Tracking deleted task IDs
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
        container = CKContainer.default() 
        privateDatabase = container.privateCloudDatabase
        zoneID = CKRecordZone.ID(zoneName: "SnapTaskZone", ownerName: CKCurrentUserDefaultName)
        recordZone = CKRecordZone(zoneID: zoneID)
        
        // Ripristiniamo queste chiamate
        // setupSubscriptions() // TEMPORANEAMENTE COMMENTATO PER TEST
        checkCloudKitAvailability()
    }
    
    // MARK: - Public Methods
    
    func setup() {
        createCustomZoneIfNeeded()
        subscribeToChanges()
    }
    
    func syncTasks() {
        isSyncing = true
        
        // Fetch local tasks
        let localTasks = TaskManager.shared.tasks
        
        // Fetch remote tasks
        fetchAllTasks { [weak self] remoteTasks, error in
            guard let self = self else { return }
            
            if let error = error {
                self.handleSyncError(error)
                return
            }
            
            // Use the safer merge implementation
            self.mergeTasksSafely(localTasks: localTasks, remoteTasks: remoteTasks ?? [])
        }
    }
    
    // Versione che non lancia eccezioni
    func syncTasksSafely() {
        do {
            isSyncing = true
            
            // Fetch local tasks safely
            let localTasks = TaskManager.shared.tasks
            
            // Fetch remote tasks with error handling
            fetchAllTasks { [weak self] remoteTasks, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("CloudKit sync error: \(error.localizedDescription)")
                    self.handleSyncError(error)
                    return
                }
                
                do {
                    // Compare and merge tasks with error handling
                    self.mergeTasksSafely(localTasks: localTasks, remoteTasks: remoteTasks ?? [])
                } catch {
                    print("Error during task merging: \(error.localizedDescription)")
                    self.handleSyncError(error)
                }
            }
        } catch {
            print("Unexpected error in syncTasksSafely: \(error.localizedDescription)")
            self.handleSyncError(error)
        }
    }
    
    func saveTask(_ task: TodoTask) {
        let record = taskToRecord(task)
        
        saveRecord(record) { [weak self] success, error in
            if let error = error {
                self?.handleSyncError(error)
            }
        }
    }
    
    func deleteTask(_ task: TodoTask) {
        let recordID = CKRecord.ID(recordName: task.id.uuidString, zoneID: zoneID)
        
        print("CloudKitService: Attempting to delete task with ID: \(task.id.uuidString)")
        
        // Track this task as deleted even before server confirms
        addToDeletedTasks(taskID: task.id.uuidString)
        
        privateDatabase.delete(withRecordID: recordID) { [weak self] (recordID, error) in
            if let error = error as? CKError {
                // Don't report error if record not found - it's already deleted
                if error.code != .unknownItem {
                    print("CloudKitService: Error deleting task: \(error.localizedDescription)")
                    self?.handleSyncError(error)
                } else {
                    print("CloudKitService: Task already deleted or not found in CloudKit")
                }
            } else if let error = error {
                print("CloudKitService: Error deleting task: \(error.localizedDescription)")
                self?.handleSyncError(error)
            } else {
                print("CloudKitService: Task successfully deleted from CloudKit")
                // Update the last sync date to reflect the change
                DispatchQueue.main.async {
                    self?.lastSyncDate = Date()
                }
            }
        }
    }
    
    // Add a task ID to deleted tasks list
    private func addToDeletedTasks(taskID: String) {
        var ids = deletedTaskIDs
        ids.insert(taskID)
        deletedTaskIDs = ids
    }
    
    // Check if a task is in the deleted list
    private func isTaskDeleted(taskID: String) -> Bool {
        return deletedTaskIDs.contains(taskID)
    }
    
    // MARK: - Private Methods
    
    private func checkCloudKitAvailability() {
        container.accountStatus { [weak self] (status, error) in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    self?.setup()
                case .noAccount:
                    self?.syncError = NSError(domain: "CloudKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "No iCloud account found. Please sign in to your iCloud account."])
                case .restricted:
                    self?.syncError = NSError(domain: "CloudKit", code: 2, userInfo: [NSLocalizedDescriptionKey: "iCloud access is restricted."])
                case .couldNotDetermine:
                    if let error = error {
                        self?.syncError = error
                    } else {
                        self?.syncError = NSError(domain: "CloudKit", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not determine iCloud account status."])
                    }
                @unknown default:
                    self?.syncError = NSError(domain: "CloudKit", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unknown iCloud account status."])
                }
            }
        }
    }
    
    private func createCustomZoneIfNeeded() {
        privateDatabase.fetch(withRecordZoneID: zoneID) { [weak self] (zone, error) in
            guard let self = self else { return }
            
            if let error = error as? CKError {
                if error.code == .zoneNotFound {
                    print("CloudKitService: Zone 'SnapTaskZone' not found. Attempting to create.")
                    self.createCustomZone()
                } else {
                    print("CloudKitService: Error fetching zone 'SnapTaskZone': \(error.localizedDescription)")
                    self.handleSyncError(error)
                }
            } else if let error = error { // Handle other non-CKError types
                print("CloudKitService: Non-CKError fetching zone 'SnapTaskZone': \(error.localizedDescription)")
                self.handleSyncError(error)
            } else {
                // Zone exists
                print("CloudKitService: Zone 'SnapTaskZone' already exists.")
            }
        }
    }
    
    private func createCustomZone() {
        print("CloudKitService: Executing createCustomZone() for 'SnapTaskZone'.")
        privateDatabase.save(recordZone) { [weak self] (zone, error) in
            guard let self = self else { return }
            if let error = error {
                print("CloudKitService: ERRORE durante la creazione della zona 'SnapTaskZone': \(error.localizedDescription)")
                self.handleSyncError(error)
            } else {
                print("CloudKitService: Zona 'SnapTaskZone' creata con successo. Clearing previous sync errors.")
                self.syncError = nil // Clear error before attempting sync
                // La zona è stata creata, possiamo provare a sincronizzare di nuovo
                // per popolare i dati o aggiornare lo stato dell'interfaccia.
                // Usiamo la versione safely per coerenza con il resto dell'approccio.
                self.syncTasksSafely() 
            }
        }
    }
    
    private func subscribeToChanges() {
        let subscription = CKRecordZoneSubscription(zoneID: zoneID)
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        privateDatabase.save(subscription) { [weak self] (subscription, error) in
            if let error = error {
                self?.handleSyncError(error)
            }
        }
    }
    
    private func setupSubscriptions() {
        NotificationCenter.default.publisher(for: .tasksDidUpdate)
            .sink { [weak self] _ in
                self?.handleLocalTasksUpdated()
            }
            .store(in: &subscriptions)
        
        NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .sink { [weak self] _ in
                self?.handleRemoteChange()
            }
            .store(in: &subscriptions)
    }
    
    private func handleLocalTasksUpdated() {
        // Save all tasks to CloudKit
        for task in TaskManager.shared.tasks {
            saveTask(task)
        }
    }
    
    private func handleRemoteChange() {
        syncTasks()
    }
    
    private func fetchAllTasks(completion: @escaping ([TodoTask]?, Error?) -> Void) {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: taskRecordType, predicate: predicate)
        
        print("CloudKitService: Fetching all tasks from CloudKit")
        
        do {
            privateDatabase.perform(query, inZoneWith: zoneID) { [weak self] (records, error) in
                guard let self = self else { 
                    completion(nil, NSError(domain: "CloudKitService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Self is nil"]))
                    return
                }
                
                if let error = error {
                    print("CloudKitService: Error fetching tasks: \(error.localizedDescription)")
                    completion(nil, error)
                    return
                }
                
                guard let records = records else {
                    print("CloudKitService: No records found")
                    completion([], nil)
                    return
                }
                
                print("CloudKitService: Found \(records.count) records in CloudKit")
                
                // Process records in a safer way
                var tasks: [TodoTask] = []
                var recordProcessingErrors: [Error] = []
                
                for record in records {
                    do {
                        // Skip records for tasks we've deleted locally
                        if self.isTaskDeleted(taskID: record.recordID.recordName) {
                            print("CloudKitService: Skipping deleted task with ID: \(record.recordID.recordName)")
                            continue
                        }
                        
                        if let task = self.recordToTask(record) {
                            tasks.append(task)
                        }
                    } catch {
                        print("CloudKitService: Error processing record: \(error.localizedDescription)")
                        recordProcessingErrors.append(error)
                    }
                }
                
                if tasks.isEmpty && !recordProcessingErrors.isEmpty {
                    // If we have errors and no tasks, report the first error
                    completion(nil, recordProcessingErrors.first)
                } else {
                    // Otherwise return the tasks we successfully processed
                    completion(tasks, nil)
                }
            }
        } catch {
            print("CloudKitService: Unexpected error in fetchAllTasks: \(error.localizedDescription)")
            completion(nil, error)
        }
    }
    
    private func saveRecord(_ record: CKRecord, completion: @escaping (Bool, Error?) -> Void) {
        let modifyOperation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        modifyOperation.savePolicy = .changedKeys

        modifyOperation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
            // It's important to dispatch UI updates or completions that interact with UI
            // back to the main thread. However, the completion handler for saveRecord
            // is often called from background logic that then dispatches to main if needed.
            // For CloudKitService internal logic, operating on the callback queue is fine.
            // If handleSyncError dispatches to main, that's handled there.
            if let error = error {
                print("CloudKitService: Error saving record with CKModifyRecordsOperation: \(error.localizedDescription)")
                completion(false, error)
                return
            }
            print("CloudKitService: Record saved successfully with CKModifyRecordsOperation. Saved records: \(savedRecords?.count ?? 0)")
            completion(true, nil)
        }
        
        // Imposta la qualità del servizio se necessario, ad esempio .userInitiated
        // modifyOperation.qualityOfService = .userInitiated
        
        privateDatabase.add(modifyOperation)
    }
    
    private func mergeTasksSafely(localTasks: [TodoTask], remoteTasks: [TodoTask]) {
        // localTasks: from TaskManager at start of sync
        // remoteTasks: from CloudKit, already filtered by this device's deletedTaskIDs list (tasks this device knows were deleted by it are not included)

        print("CloudKitService: mergeTasksSafely - Starting merge. Local: \(localTasks.count), Remote (filtered by local deletes): \(remoteTasks.count)")
        let localDeviceDeletedIDs = self.deletedTaskIDs // IDs this device knows MUST be deleted

        var finalLocalState = [UUID: TodoTask]() // Accumulator for new local state
        var recordsToSaveToCloudKit = [CKRecord]()
        var recordIDsToDeleteFromCloudKit = Set<CKRecord.ID>()

        // Ensure all tasks this device marked as deleted are indeed queued for server deletion
        localDeviceDeletedIDs.forEach { idString in
            recordIDsToDeleteFromCloudKit.insert(CKRecord.ID(recordName: idString, zoneID: self.zoneID))
        }

        let localTasksMap = Dictionary(localTasks.map { ($0.id, $0) }, uniquingKeysWith: { (first, _) in first })
        // remoteTasks are already filtered by localDeviceDeletedIDs during fetchAllTasks.
        // This means remoteTasksMap does not contain tasks that this device has deleted and recorded in its UserDefaults.
        let remoteTasksMap = Dictionary(remoteTasks.map { ($0.id, $0) }, uniquingKeysWith: { (first, _) in first })
        
        let allConsideredIDs = Set(localTasksMap.keys).union(remoteTasksMap.keys)

        for taskID in allConsideredIDs {
            let idString = taskID.uuidString
            let localTask = localTasksMap[taskID]
            let remoteTask = remoteTasksMap[taskID]

            if localDeviceDeletedIDs.contains(idString) {
                // This task is marked for deletion by this device.
                // It should not be in finalLocalState. Its deletion from server is already queued.
                print("CloudKitService: Merge - Task \(localTask?.name ?? idString) is in local deleted list. Skipping for local state, ensuring server delete.")
                continue // Skip to next taskID
            }

            if let lt = localTask, let rt = remoteTask {
                // Task exists in both local cache and remote (and not in localDeviceDeletedIDs).
                // Standard merge: newer wins (using creationDate as a proxy for modificationDate).
                // For a more robust solution, a dedicated 'lastModifiedAt' timestamp managed by your app would be better.
                if lt.creationDate >= rt.creationDate { // Local is newer or same.
                    finalLocalState[taskID] = lt
                    if lt.creationDate > rt.creationDate { // Only schedule save if local is strictly newer.
                        print("CloudKitService: Merge - Local task '\(lt.name)' is newer. Scheduling for server update.")
                        recordsToSaveToCloudKit.append(self.taskToRecord(lt))
                    } else {
                        print("CloudKitService: Merge - Local task '\(lt.name)' and remote are same or local is newer/same. Keeping local version, no server update needed unless content differs (not checked here).")
                    }
                } else { // Remote is newer.
                    finalLocalState[taskID] = rt
                    print("CloudKitService: Merge - Remote task '\(rt.name)' is newer. Updating local state.")
                }
            } else if let lt = localTask {
                // Task exists locally, but not in remoteTasks (which are already filtered by *this device's* deletedTaskIDs).
                // This means:
                // a) It's a new task created on this device that hasn't successfully synced yet.
                // b) It *was* on the server, but was deleted by *another* device. This device doesn't know about that remote deletion yet.
                
                // We keep it in the local state because this device believes it exists.
                finalLocalState[taskID] = lt
                
                // We schedule it for upload.
                // If it's case (a), it gets to the server. Good.
                // If it's case (b), it might be temporarily resurrected on the server.
                // The other device, on its next sync, should re-delete it based on its local deletedTaskIDs.
                // This is preferable to new tasks never appearing.
                print("CloudKitService: Merge - Task '\(lt.name)' is local-only (or remotely deleted by another device). Keeping local and scheduling for upload/update on CloudKit.")
                recordsToSaveToCloudKit.append(self.taskToRecord(lt))

            } else if let rt = remoteTask {
                // Task exists in remoteTasks, but not locally (and not in localDeviceDeletedIDs).
                // This means it's a new task from the server / another device.
                finalLocalState[taskID] = rt
                print("CloudKitService: Merge - Remote task '\(rt.name)' is new to this device or was re-fetched. Adding/updating locally.")
            }
        }

        // Perform local and remote updates
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let tasksForManager = Array(finalLocalState.values)
            print("CloudKitService: Merge - Finalizing. Updating TaskManager with \(tasksForManager.count) tasks.")
            TaskManager.shared.updateAllTasks(tasksForManager)

            // Consolidate recordIDsToDeleteFromCloudKit: ensure we don't try to delete what we're about to save if a task was rapidly changed.
            // However, given the logic, a task to be saved shouldn't also be in localDeviceDeletedIDs.
            let finalRecordIDsToDelete = Array(recordIDsToDeleteFromCloudKit)

            if !recordsToSaveToCloudKit.isEmpty || !finalRecordIDsToDelete.isEmpty {
                print("CloudKitService: Merge - Preparing to save \(recordsToSaveToCloudKit.count) records and delete \(finalRecordIDsToDelete.count) record IDs from CloudKit.")
                let modifyOp = CKModifyRecordsOperation(recordsToSave: recordsToSaveToCloudKit, recordIDsToDelete: finalRecordIDsToDelete)
                modifyOp.savePolicy = .changedKeys 
                // modifyOp.isAtomic = false // Consider atomicity if needed, default is true per zone.
                modifyOp.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
                    DispatchQueue.main.async { // Ensure UI updates on main thread
                        if let error = error {
                            print("CloudKitService: Merge - CKModifyRecordsOperation error: \(error.localizedDescription)")
                            self.handleSyncError(error)
                        } else {
                            print("CloudKitService: Merge - CKModifyRecordsOperation success. Saved: \(savedRecords?.count ?? 0), Deleted: \(deletedRecordIDs?.count ?? 0).")
                            // Optionally, if you want to clean up UserDefaults after confirmed server deletion:
                            // deletedRecordIDs?.forEach { self.removeFromDeletedTasks(taskID: $0.recordName) }
                            self.syncError = nil
                        }
                        self.isSyncing = false
                        self.lastSyncDate = Date()
                    }
                }
                self.privateDatabase.add(modifyOp)
            } else {
                print("CloudKitService: Merge - No CloudKit operations needed.")
                self.isSyncing = false
                self.lastSyncDate = Date()
                self.syncError = nil
            }
        }
    }
    
    private func taskToRecord(_ task: TodoTask) -> CKRecord {
        let recordID = CKRecord.ID(recordName: task.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: taskRecordType, recordID: recordID)
        print("CloudKitService: taskToRecord - Creazione record per task: \(task.name)")

        // Basic properties - Explicitly cast all values to CKRecordValue
        record["name"] = task.name as CKRecordValue
        record["appCreationDate"] = task.creationDate as NSDate // Custom field for model's creation date
        record["startTime"] = task.startTime as NSDate
        record["duration"] = task.duration as CKRecordValue
        record["hasDuration"] = task.hasDuration as CKRecordValue
        record["icon"] = task.icon as CKRecordValue
        
        // Store priority as String to avoid issues
        let priorityValue = task.priority.rawValue
        record["priority"] = priorityValue as CKRecordValue
        
        // Handle optional properties more safely
        if let description = task.description, !description.isEmpty {
            print("CloudKitService: Setting description for task: \(task.name)")
            record["description"] = description as CKRecordValue
        } else {
            print("CloudKitService: No description for task: \(task.name)")
            record["description"] = nil
        }
        
        // Complex properties - encode them as Data
        do {
            // Category
            if let category = task.category {
                let categoryData = try JSONEncoder().encode(category)
                record["category"] = categoryData as NSData
            }
            
            // Recurrence
            if let recurrence = task.recurrence {
                let recurrenceData = try JSONEncoder().encode(recurrence)
                record["recurrence"] = recurrenceData as NSData
            }
            
            // PomodoroSettings
            if let pomodoroSettings = task.pomodoroSettings {
                let pomodoroData = try JSONEncoder().encode(pomodoroSettings)
                record["pomodoroSettings"] = pomodoroData as NSData
            }
            
            // Subtasks
            if !task.subtasks.isEmpty {
                let subtasksData = try JSONEncoder().encode(task.subtasks)
                record["subtasks"] = subtasksData as NSData
            }
            
            // Completions
            if !task.completions.isEmpty {
                let completionsData = try JSONEncoder().encode(task.completions)
                record["completions"] = completionsData as NSData
            }
            
            // CompletionDates
            if !task.completionDates.isEmpty {
                let completionDatesData = try JSONEncoder().encode(task.completionDates)
                record["completionDates"] = completionDatesData as NSData
            }
        } catch {
            print("CloudKitService: Error encoding task data: \(error.localizedDescription)")
        }
        
        return record
    }
    
    private func recordToTask(_ record: CKRecord) -> TodoTask? {
        // Let's provide detailed logging for debugging
        print("CloudKitService: recordToTask - Processing record with ID: \(record.recordID.recordName)")
        
        do {
            // Extract name field safely
            guard let name = record["name"] as? String else {
                print("CloudKitService: recordToTask - Campo 'name' mancante o non valido, impossibile creare TodoTask.")
                return nil
            }
            
            print("CloudKitService: recordToTask - Extracting fields for task: \(name)")
            
            // Extract other fields with safe fallbacks
            let modelCreationDate = record["appCreationDate"] as? Date ?? record.creationDate ?? Date()
            let startTime = record["startTime"] as? Date ?? modelCreationDate
            let duration = record["duration"] as? TimeInterval ?? 0.0
            let hasDuration = record["hasDuration"] as? Bool ?? false
            let icon = record["icon"] as? String ?? "circle.fill"
            let description = record["description"] as? String

            // Handle priority with better error checking
            var priority: Priority = .medium
            do {
                if let priorityRaw = record["priority"] as? String {
                    print("CloudKitService: recordToTask - Found priority (String): \(priorityRaw)")
                    priority = Priority(rawValue: priorityRaw) ?? .medium
                } else if let priorityRaw = record["priority"] as? Int {
                    print("CloudKitService: recordToTask - Found priority (Int): \(priorityRaw)")
                    let priorities: [Priority] = [.low, .medium, .high]
                    if priorityRaw >= 0 && priorityRaw < priorities.count {
                        priority = priorities[priorityRaw]
                    }
                } else {
                    print("CloudKitService: recordToTask - No valid priority found, using default")
                }
            } catch {
                print("CloudKitService: recordToTask - Error processing priority: \(error.localizedDescription)")
            }
            
            var category: Category? = nil
            if let categoryData = record["category"] as? Data {
                do {
                    category = try JSONDecoder().decode(Category.self, from: categoryData)
                } catch { print("CloudKitService: Errore decodifica category: \(error.localizedDescription)") }
            }
            
            var recurrence: Recurrence? = nil
            if let recurrenceData = record["recurrence"] as? Data {
                do {
                    recurrence = try JSONDecoder().decode(Recurrence.self, from: recurrenceData)
                } catch { print("CloudKitService: Errore decodifica recurrence: \(error.localizedDescription)") }
            }
            
            var pomodoroSettings: PomodoroSettings? = nil
            if let pomodoroData = record["pomodoroSettings"] as? Data {
                do {
                    pomodoroSettings = try JSONDecoder().decode(PomodoroSettings.self, from: pomodoroData)
                } catch { print("CloudKitService: Errore decodifica pomodoroSettings: \(error.localizedDescription)") }
            }
            
            var subtasks: [Subtask] = []
            if let subtasksData = record["subtasks"] as? Data {
                do {
                    subtasks = try JSONDecoder().decode([Subtask].self, from: subtasksData)
                } catch { print("CloudKitService: Errore decodifica subtasks: \(error.localizedDescription)") }
            }
            
            var completions: [Date: TaskCompletion] = [:]
            if let completionsData = record["completions"] as? Data {
                do {
                    completions = try JSONDecoder().decode([Date: TaskCompletion].self, from: completionsData)
                } catch { print("CloudKitService: Errore decodifica completions: \(error.localizedDescription)") }
            }
            
            var completionDates: [Date] = []
            if let completionDatesData = record["completionDates"] as? Data {
                do {
                    completionDates = try JSONDecoder().decode([Date].self, from: completionDatesData)
                } catch { print("CloudKitService: Errore decodifica completionDates: \(error.localizedDescription)") }
            }
            
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
            
            print("CloudKitService: recordToTask - Successfully created task: \(name)")
            return task
        } catch {
            print("CloudKitService: recordToTask - Unexpected error processing record: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func handleSyncError(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.syncError = error
            self?.isSyncing = false
        }
    }
}

extension Notification.Name {
    static let cloudKitDataChanged = Notification.Name("cloudKitDataChanged")
} 