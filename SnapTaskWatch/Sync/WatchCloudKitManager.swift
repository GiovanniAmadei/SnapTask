import Foundation
import CloudKit

/// Manages CloudKit synchronization for standalone Watch operation
/// Used when iPhone is not connected via Bluetooth
@MainActor
class WatchCloudKitManager: ObservableObject {
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let zoneID: CKRecordZone.ID
    
    // Record Types (same as iOS app)
    private let taskRecordType = "TodoTask"
    private let categoryRecordType = "Category"
    private let rewardRecordType = "Reward"
    private let trackingSessionRecordType = "TrackingSession"
    private let pointsHistoryRecordType = "PointsHistory"
    
    var onDataUpdated: (([TodoTask], [Category], [Reward], Int) -> Void)?
    
    init() {
        container = CKContainer.default()
        privateDatabase = container.privateCloudDatabase
        zoneID = CKRecordZone.ID(zoneName: "SnapTaskZone", ownerName: CKCurrentUserDefaultName)
    }
    
    // MARK: - Full Sync
    func performSync() async throws {
        let tasks = try await fetchTasks()
        let categories = try await fetchCategories()
        let rewards = try await fetchRewards()
        let points = try await fetchTotalPoints()
        
        onDataUpdated?(tasks, categories, rewards, points)
    }
    
    // MARK: - Fetch Operations
    private func fetchTasks() async throws -> [TodoTask] {
        let query = CKQuery(recordType: taskRecordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "taskLastModifiedDate", ascending: false)]
        
        let (results, _) = try await privateDatabase.records(matching: query, inZoneWith: zoneID)
        
        return results.compactMap { _, result in
            guard case .success(let record) = result else { return nil }
            return createTask(from: record)
        }
    }
    
    private func fetchCategories() async throws -> [Category] {
        let query = CKQuery(recordType: categoryRecordType, predicate: NSPredicate(value: true))
        
        let (results, _) = try await privateDatabase.records(matching: query, inZoneWith: zoneID)
        
        return results.compactMap { _, result in
            guard case .success(let record) = result else { return nil }
            return createCategory(from: record)
        }
    }
    
    private func fetchRewards() async throws -> [Reward] {
        let query = CKQuery(recordType: rewardRecordType, predicate: NSPredicate(value: true))
        
        let (results, _) = try await privateDatabase.records(matching: query, inZoneWith: zoneID)
        
        return results.compactMap { _, result in
            guard case .success(let record) = result else { return nil }
            return createReward(from: record)
        }
    }
    
    private func fetchTotalPoints() async throws -> Int {
        let query = CKQuery(recordType: pointsHistoryRecordType, predicate: NSPredicate(value: true))
        
        let (results, _) = try await privateDatabase.records(matching: query, inZoneWith: zoneID)
        
        var totalPoints = 0
        for (_, result) in results {
            if case .success(let record) = result,
               let points = record["points"] as? Int {
                totalPoints += points
            }
        }
        
        return totalPoints
    }
    
    // MARK: - Save Operations
    func saveTask(_ task: TodoTask) async throws {
        let record = createTaskRecord(from: task)
        _ = try await privateDatabase.save(record)
    }
    
    func deleteTask(_ taskId: UUID) async throws {
        let recordID = CKRecord.ID(recordName: taskId.uuidString, zoneID: zoneID)
        _ = try await privateDatabase.deleteRecord(withID: recordID)
    }
    
    func saveReward(_ reward: Reward) async throws {
        let record = createRewardRecord(from: reward)
        _ = try await privateDatabase.save(record)
    }
    
    func deleteReward(_ rewardId: UUID) async throws {
        let recordID = CKRecord.ID(recordName: rewardId.uuidString, zoneID: zoneID)
        _ = try await privateDatabase.deleteRecord(withID: recordID)
    }
    
    func saveTrackingSession(_ session: TrackingSession) async throws {
        let record = createTrackingSessionRecord(from: session)
        _ = try await privateDatabase.save(record)
    }
    
    // MARK: - Record Creation (Task)
    private func createTaskRecord(from task: TodoTask) -> CKRecord {
        let recordID = CKRecord.ID(recordName: task.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: taskRecordType, recordID: recordID)
        
        record["name"] = task.name
        record["taskDescription"] = task.description
        record["startTime"] = task.startTime
        record["hasSpecificTime"] = task.hasSpecificTime
        record["duration"] = task.duration
        record["hasDuration"] = task.hasDuration
        record["icon"] = task.icon
        record["priority"] = task.priority.rawValue
        record["hasRewardPoints"] = task.hasRewardPoints
        record["rewardPoints"] = task.rewardPoints
        record["taskCreationDate"] = task.creationDate
        record["taskLastModifiedDate"] = task.lastModifiedDate
        record["timeScope"] = task.timeScope.rawValue
        
        // Encode complex objects
        if let categoryData = try? JSONEncoder().encode(task.category) {
            record["category"] = categoryData
        }
        if let recurrenceData = try? JSONEncoder().encode(task.recurrence) {
            record["recurrence"] = recurrenceData
        }
        if let pomodoroData = try? JSONEncoder().encode(task.pomodoroSettings) {
            record["pomodoroSettings"] = pomodoroData
        }
        if let subtasksData = try? JSONEncoder().encode(task.subtasks) {
            record["subtasks"] = subtasksData
        }
        if let completionsData = try? JSONEncoder().encode(task.completions) {
            record["completions"] = completionsData
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
        let timeScopeRaw = record["timeScope"] as? String
        let timeScope = TaskTimeScope(rawValue: timeScopeRaw ?? "") ?? .today
        
        // Decode complex objects
        var category: Category?
        if let categoryData = record["category"] as? Data {
            category = try? JSONDecoder().decode(Category.self, from: categoryData)
        }
        
        var recurrence: Recurrence?
        if let recurrenceData = record["recurrence"] as? Data {
            recurrence = try? JSONDecoder().decode(Recurrence.self, from: recurrenceData)
        }
        
        var pomodoroSettings: PomodoroSettings?
        if let pomodoroData = record["pomodoroSettings"] as? Data {
            pomodoroSettings = try? JSONDecoder().decode(PomodoroSettings.self, from: pomodoroData)
        }
        
        var subtasks: [Subtask] = []
        if let subtasksData = record["subtasks"] as? Data {
            subtasks = (try? JSONDecoder().decode([Subtask].self, from: subtasksData)) ?? []
        }
        
        var completions: [Date: TaskCompletion] = [:]
        if let completionsData = record["completions"] as? Data {
            completions = (try? JSONDecoder().decode([Date: TaskCompletion].self, from: completionsData)) ?? [:]
        }
        
        var task = TodoTask(
            id: uuid,
            name: name,
            description: description,
            location: nil,
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
            timeScope: timeScope
        )
        
        task.completions = completions
        task.creationDate = creationDate ?? Date()
        task.lastModifiedDate = lastModifiedDate ?? Date()
        
        return task
    }
    
    // MARK: - Record Creation (Category)
    private func createCategory(from record: CKRecord) -> Category? {
        guard let name = record["name"] as? String,
              let color = record["color"] as? String,
              let uuid = UUID(uuidString: record.recordID.recordName) else {
            return nil
        }
        
        return Category(id: uuid, name: name, color: color)
    }
    
    // MARK: - Record Creation (Reward)
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
        
        if let redemptionsData = try? JSONEncoder().encode(reward.redemptions) {
            record["redemptions"] = redemptionsData
        }
        
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
        
        var redemptions: [Date] = []
        if let redemptionsData = record["redemptions"] as? Data {
            redemptions = (try? JSONDecoder().decode([Date].self, from: redemptionsData)) ?? []
        }
        
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
    
    // MARK: - Record Creation (TrackingSession)
    private func createTrackingSessionRecord(from session: TrackingSession) -> CKRecord {
        let recordID = CKRecord.ID(recordName: session.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: trackingSessionRecordType, recordID: recordID)
        
        record["taskId"] = session.taskId?.uuidString
        record["taskName"] = session.taskName
        record["mode"] = session.mode.rawValue
        record["categoryId"] = session.categoryId?.uuidString
        record["categoryName"] = session.categoryName
        record["startTime"] = session.startTime
        record["endTime"] = session.endTime
        record["elapsedTime"] = session.elapsedTime
        record["totalDuration"] = session.totalDuration
        record["pausedDuration"] = session.pausedDuration
        record["isCompleted"] = session.isCompleted
        record["deviceType"] = session.deviceType.rawValue
        record["deviceName"] = session.deviceName
        record["creationDate"] = session.creationDate
        record["lastModifiedDate"] = session.lastModifiedDate
        
        return record
    }
}
