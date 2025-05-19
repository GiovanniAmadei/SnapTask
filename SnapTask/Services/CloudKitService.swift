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
    
    // Remove task ID from deleted tasks list
    private func removeFromDeletedTasks(taskID: String) {
        var ids = deletedTaskIDs
        ids.remove(taskID)
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
                    
                    // Non marcare come eliminate le task create di recente che non sono ancora state sincronizzate
                    if !localTasks.isEmpty {
                        print("CloudKitService: No records on server, but \(localTasks.count) local tasks.")
                        for localTask in localTasks {
                            let taskIDString = localTask.id.uuidString
                            
                            // Se la task non è stata creata di recente e non è già nella lista delle eliminate
                            if !recentlyCreatedTaskIDs.contains(taskIDString) && !self.isTaskDeleted(taskID: taskIDString) {
                                print("CloudKitService: Task \(taskIDString) might have been deleted remotely. Adding to deletion list.")
                                self.addToDeletedTasks(taskID: taskIDString)
                            } else if recentlyCreatedTaskIDs.contains(taskIDString) {
                                print("CloudKitService: Task \(taskIDString) was recently created. Not marking as deleted.")
                            }
                        }
                    }
                    
                    completion([], nil)
                    return
                }
                
                print("CloudKitService: Found \(records.count) records in CloudKit")
                
                // Raccoglie tutti gli ID dei record remoti
                let remoteTaskIDs = Set(records.map { $0.recordID.recordName })
                
                // Trova task locali che non esistono più sul server (potrebbero essere state eliminate da altri dispositivi)
                let missingTaskIDs = localTasksIDs.subtracting(remoteTaskIDs)
                
                for taskID in missingTaskIDs {
                    // Se la task non è recente e non è già nella lista delle task eliminate
                    if !recentlyCreatedTaskIDs.contains(taskID) && !self.isTaskDeleted(taskID: taskID) {
                        print("CloudKitService: Task \(taskID) exists locally but not remotely. Adding to deletion list.")
                        self.addToDeletedTasks(taskID: taskID)
                    } else if recentlyCreatedTaskIDs.contains(taskID) {
                        print("CloudKitService: Task \(taskID) was recently created but not yet on server. Not marking as deleted.")
                    }
                }
                
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
        
        // Registra i timestamp di creazione per poter distinguere tra task nuove e vecchie
        let newTaskThreshold: TimeInterval = 60 * 5 // 5 minuti
        let recentlyCreatedTasks = localTasks.filter { Date().timeIntervalSince($0.creationDate) < newTaskThreshold }
        let recentlyCreatedTaskIDs = Set(recentlyCreatedTasks.map { $0.id.uuidString })
        
        // Prepara tutte le task recenti per l'upload a CloudKit
        for task in recentlyCreatedTasks {
            print("CloudKitService: Merge - Scheduling recent task '\(task.name)' for upload to CloudKit.")
            recordsToSaveToCloudKit.append(self.taskToRecord(task))
            finalLocalState[task.id] = task
        }
        
        // Store task IDs present in the remote dataset
        var remoteTaskIDsSet = Set<String>()

        // Ensure all tasks this device marked as deleted are indeed queued for server deletion
        localDeviceDeletedIDs.forEach { idString in
            // Non programmare l'eliminazione delle task create di recente
            if !recentlyCreatedTaskIDs.contains(idString) {
                recordIDsToDeleteFromCloudKit.insert(CKRecord.ID(recordName: idString, zoneID: self.zoneID))
            } else {
                print("CloudKitService: Merge - Not deleting recently created task with ID: \(idString)")
            }
        }

        let localTasksMap = Dictionary(localTasks.map { ($0.id, $0) }, uniquingKeysWith: { (first, _) in first })
        // remoteTasks are already filtered by localDeviceDeletedIDs during fetchAllTasks.
        // This means remoteTasksMap does not contain tasks that this device has deleted and recorded in its UserDefaults.
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
                print("CloudKitService: Merge - Task '\(localTask.name)' missing from remote dataset, likely deleted by another device. Adding to local deletion list.")
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
                print("CloudKitService: Merge - Task \(idString) in local deleted list. Ensuring server delete.")
                // Already added to recordIDsToDeleteFromCloudKit via localDeviceDeletedIDs
                continue
            }

            if let lt = localTask, let rt = remoteTask {
                // Both devices have the task - choose the most recent version
                if lt.lastModifiedDate >= rt.lastModifiedDate {
                    finalLocalState[taskID] = lt
                    if lt.lastModifiedDate > rt.lastModifiedDate {
                        print("CloudKitService: Merge - Local task '\(lt.name)' is more recently modified. Scheduling for server update.")
                        recordsToSaveToCloudKit.append(self.taskToRecord(lt))
                    } else {
                        print("CloudKitService: Merge - Local task '\(lt.name)' and remote task have same modification date.")
                    }
                } else {
                    finalLocalState[taskID] = rt
                    print("CloudKitService: Merge - Remote task '\(rt.name)' is more recently modified. Updating local state.")
                }
            } else if let lt = localTask {
                // Task exists locally, but not in remoteTasks (which are already filtered by *this device's* deletedTaskIDs).
                // This is likely a new local task that needs to be uploaded
                finalLocalState[taskID] = lt
                print("CloudKitService: Merge - Task '\(lt.name)' is local-only. Adding to server.")
                recordsToSaveToCloudKit.append(self.taskToRecord(lt))
            } else if let rt = remoteTask {
                // Task exists in remoteTasks, but not locally (and not in localDeviceDeletedIDs).
                // This means it's a new task from the server / another device.
                finalLocalState[taskID] = rt
                print("CloudKitService: Merge - Remote task '\(rt.name)' is new to this device. Adding locally.")
            }
        }

        // Ensure we don't try to save any task that's also marked for deletion
        // This prevents the "You can't save and delete the same record" error
        recordsToSaveToCloudKit = recordsToSaveToCloudKit.filter { record in
            let recordIDString = record.recordID.recordName
            if recordIDsToDeleteFromCloudKit.contains(where: { $0.recordName == recordIDString }) {
                // Ma mantieni le task recenti indipendentemente dalla lista delle eliminazioni
                if recentlyCreatedTaskIDs.contains(recordIDString) {
                    print("CloudKitService: Merge - Keeping recently created task \(recordIDString) even though it's in the deletion list")
                    return true
                }
                print("CloudKitService: Merge - Preventing save of task \(recordIDString) since it's also marked for deletion")
                return false
            }
            return true
        }

        // Perform local and remote updates
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Prima applica le eliminazioni per assicurarsi che le task eliminate vengano rimosse
            self.applyDeletions(protectedIDs: recentlyCreatedTaskIDs)
            
            // Poi aggiorna le task rimanenti
            let tasksForManager = Array(finalLocalState.values)
            print("CloudKitService: Merge - Finalizing. Updating TaskManager with \(tasksForManager.count) tasks.")
            TaskManager.shared.updateAllTasks(tasksForManager)

            // Consolidate recordIDsToDeleteFromCloudKit: ensure we don't try to delete what we're about to save if a task was rapidly changed.
            let finalRecordIDsToDelete = Array(recordIDsToDeleteFromCloudKit)

            if !recordsToSaveToCloudKit.isEmpty || !finalRecordIDsToDelete.isEmpty {
                print("CloudKitService: Merge - Preparing to save \(recordsToSaveToCloudKit.count) records and delete \(finalRecordIDsToDelete.count) record IDs from CloudKit.")
                let modifyOp = CKModifyRecordsOperation(recordsToSave: recordsToSaveToCloudKit, recordIDsToDelete: finalRecordIDsToDelete)
                modifyOp.savePolicy = .changedKeys 
                modifyOp.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
                    DispatchQueue.main.async { // Ensure UI updates on main thread
                        if let error = error {
                            print("CloudKitService: Merge - CKModifyRecordsOperation error: \(error.localizedDescription)")
                            self.handleSyncError(error)
                        } else {
                            print("CloudKitService: Merge - CKModifyRecordsOperation success. Saved: \(savedRecords?.count ?? 0), Deleted: \(deletedRecordIDs?.count ?? 0).")
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
                print("CloudKitService: Merge - No CloudKit operations needed.")
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
            print("CloudKitService: Applying \(tasksToRemove.count) pending deletions locally")
            
            // Per ciascuna task da eliminare, rimuovila direttamente dall'array di task del TaskManager
            var updatedTasks = localTasks
            updatedTasks.removeAll { task in
                let taskID = task.id.uuidString
                let shouldRemove = deletedIDs.contains(taskID) && !protectedIDs.contains(taskID)
                if shouldRemove {
                    print("CloudKitService: Removing locally task with ID: \(taskID)")
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
        print("CloudKitService: taskToRecord - Creazione record per task: \(task.name)")

        // Basic properties - Explicitly cast all values to CKRecordValue
        record["name"] = task.name as CKRecordValue
        record["appCreationDate"] = task.creationDate as NSDate // Custom field for model's creation date
        record["lastModifiedDate"] = task.lastModifiedDate as NSDate // ADDED
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
            let lastModifiedDate = record["lastModifiedDate"] as? Date ?? record.modificationDate ?? modelCreationDate // ADDED
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
            task.lastModifiedDate = lastModifiedDate // ADDED
            
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