import Foundation
import CloudKit

class CloudKitService: ObservableObject {
    static let shared = CloudKitService()
    
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let zoneID: CKRecordZone.ID
    
    private let taskRecordType = "TodoTask"
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?
    
    private init() {
        container = CKContainer.default()
        privateDatabase = container.privateCloudDatabase
        zoneID = CKRecordZone.ID(zoneName: "SnapTaskZone", ownerName: CKCurrentUserDefaultName)
        
        checkCloudKitAvailability()
    }
    
    // MARK: - Public Methods
    
    func syncTasks() {
        isSyncing = true
        
        // For the watch, we'll just fetch all tasks from CloudKit
        fetchAllTasks { [weak self] remoteTasks, error in
            guard let self = self else { return }
            
            if let error = error {
                self.handleSyncError(error)
                return
            }
            
            if let tasks = remoteTasks {
                DispatchQueue.main.async {
                    TaskManager.shared.updateAllTasks(tasks)
                    self.isSyncing = false
                    self.lastSyncDate = Date()
                }
            }
        }
    }
    
    func saveTask(_ task: TodoTask) {
        let record = taskToRecord(task)
        
        privateDatabase.save(record) { [weak self] (record, error) in
            if let error = error {
                self?.handleSyncError(error)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func checkCloudKitAvailability() {
        container.accountStatus { [weak self] (status, error) in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    break
                case .noAccount, .restricted, .couldNotDetermine:
                    if let error = error {
                        self?.syncError = error
                    } else {
                        self?.syncError = NSError(domain: "CloudKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "iCloud account not available"])
                    }
                @unknown default:
                    self?.syncError = NSError(domain: "CloudKit", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unknown iCloud account status."])
                }
            }
        }
    }
    
    private func fetchAllTasks(completion: @escaping ([TodoTask]?, Error?) -> Void) {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: taskRecordType, predicate: predicate)
        
        privateDatabase.perform(query, inZoneWith: zoneID) { (records, error) in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let records = records else {
                completion([], nil)
                return
            }
            
            let tasks = records.compactMap { self.recordToTask($0) }
            completion(tasks, nil)
        }
    }
    
    private func taskToRecord(_ task: TodoTask) -> CKRecord {
        let recordID = CKRecord.ID(recordName: task.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: taskRecordType, recordID: recordID)
        
        // Basic properties
        record["name"] = task.name as CKRecordValue
        record["description"] = task.description as CKRecordValue?
        record["startTime"] = task.startTime as CKRecordValue
        record["duration"] = task.duration as CKRecordValue
        record["hasDuration"] = task.hasDuration as CKRecordValue
        record["priority"] = task.priority.rawValue as CKRecordValue
        record["icon"] = task.icon as CKRecordValue
        record["creationDate"] = task.creationDate as CKRecordValue
        
        // Encode completions and other complex data
        do {
            let completionsData = try JSONEncoder().encode(task.completions)
            record["completions"] = completionsData as CKRecordValue
            
            if let completionDates = try? JSONEncoder().encode(task.completionDates) {
                record["completionDates"] = completionDates as CKRecordValue
            }
        } catch {
            print("Error encoding task data: \(error)")
        }
        
        return record
    }
    
    private func recordToTask(_ record: CKRecord) -> TodoTask? {
        guard let name = record["name"] as? String,
              let startTime = record["startTime"] as? Date,
              let duration = record["duration"] as? TimeInterval,
              let hasDuration = record["hasDuration"] as? Bool,
              let icon = record["icon"] as? String else {
            return nil
        }
        
        // Gestisci priorità sia come String che come Int per compatibilità
        var priority: Priority = .medium // valore predefinito
        if let priorityRaw = record["priority"] as? String {
            priority = Priority(rawValue: priorityRaw) ?? .medium
        } else if let priorityRaw = record["priority"] as? Int {
            // Per retrocompatibilità con dati salvati come Int
            let priorities: [Priority] = [.low, .medium, .high]
            if priorityRaw >= 0 && priorityRaw < priorities.count {
                priority = priorities[priorityRaw]
            }
        }
        
        // Basic task init
        let uuid = UUID(uuidString: record.recordID.recordName) ?? UUID()
        let description = record["description"] as? String
        
        var task = TodoTask(
            id: uuid,
            name: name,
            description: description,
            startTime: startTime,
            duration: duration,
            hasDuration: hasDuration,
            priority: priority,
            icon: icon
        )
        
        // Decode the complex data
        if let completionsData = record["completions"] as? Data {
            do {
                task.completions = try JSONDecoder().decode([Date: TaskCompletion].self, from: completionsData)
            } catch {
                print("Error decoding completions: \(error)")
            }
        }
        
        if let completionDatesData = record["completionDates"] as? Data {
            do {
                task.completionDates = try JSONDecoder().decode([Date].self, from: completionDatesData)
            } catch {
                print("Error decoding completion dates: \(error)")
            }
        }
        
        if let creationDate = record["creationDate"] as? Date {
            task.creationDate = creationDate
        }
        
        return task
    }
    
    private func handleSyncError(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.syncError = error
            self?.isSyncing = false
        }
    }
} 