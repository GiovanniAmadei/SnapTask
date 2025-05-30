import Foundation
import CloudKit

struct CloudKitSyncUtilities {
    
    // MARK: - Conflict Resolution Strategies
    
    enum ConflictResolution {
        case preferLocal
        case preferRemote
        case preferMostRecent
        case merge
    }
    
    // MARK: - Task Conflict Resolution
    
    static func resolveTaskConflict(
        local: TodoTask,
        remote: TodoTask,
        strategy: ConflictResolution = .preferMostRecent
    ) -> TodoTask {
        switch strategy {
        case .preferLocal:
            return local
        case .preferRemote:
            return remote
        case .preferMostRecent:
            return local.lastModifiedDate > remote.lastModifiedDate ? local : remote
        case .merge:
            return mergeTask(local: local, remote: remote)
        }
    }
    
    private static func mergeTask(local: TodoTask, remote: TodoTask) -> TodoTask {
        var merged = local.lastModifiedDate > remote.lastModifiedDate ? local : remote
        
        // Merge completions - combine both local and remote completions
        let allCompletions = mergeCompletions(
            local: local.completions,
            remote: remote.completions
        )
        merged.completions = allCompletions
        
        // Merge completion dates
        let allCompletionDates = Array(Set(local.completionDates + remote.completionDates)).sorted()
        merged.completionDates = allCompletionDates
        
        // Merge subtasks - prefer most complete set
        if !local.subtasks.isEmpty || !remote.subtasks.isEmpty {
            merged.subtasks = mergeSubtasks(local: local.subtasks, remote: remote.subtasks)
        }
        
        // Update modification date to indicate merge
        merged.lastModifiedDate = Date()
        
        return merged
    }
    
    private static func mergeCompletions(
        local: [Date: TaskCompletion],
        remote: [Date: TaskCompletion]
    ) -> [Date: TaskCompletion] {
        var merged = local
        
        for (date, remoteCompletion) in remote {
            if let localCompletion = merged[date] {
                // Merge completions for the same date
                let mergedCompletion = TaskCompletion(
                    isCompleted: localCompletion.isCompleted || remoteCompletion.isCompleted,
                    completedSubtasks: Set(localCompletion.completedSubtasks).union(remoteCompletion.completedSubtasks)
                )
                merged[date] = mergedCompletion
            } else {
                merged[date] = remoteCompletion
            }
        }
        
        return merged
    }
    
    private static func mergeSubtasks(local: [Subtask], remote: [Subtask]) -> [Subtask] {
        let localMap = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        let remoteMap = Dictionary(uniqueKeysWithValues: remote.map { ($0.id, $0) })
        let allIDs = Set(localMap.keys).union(Set(remoteMap.keys))
        
        var mergedSubtasks: [Subtask] = []
        
        for id in allIDs {
            if let localSubtask = localMap[id], let remoteSubtask = remoteMap[id] {
                // Merge subtask - prefer completed state
                let mergedSubtask = Subtask(
                    id: id,
                    name: localSubtask.name, // Prefer local name
                    isCompleted: localSubtask.isCompleted || remoteSubtask.isCompleted
                )
                mergedSubtasks.append(mergedSubtask)
            } else if let localSubtask = localMap[id] {
                mergedSubtasks.append(localSubtask)
            } else if let remoteSubtask = remoteMap[id] {
                mergedSubtasks.append(remoteSubtask)
            }
        }
        
        return mergedSubtasks.sorted(by: { $0.name < $1.name })
    }
    
    // MARK: - Reward Conflict Resolution
    
    static func resolveRewardConflict(
        local: Reward,
        remote: Reward,
        strategy: ConflictResolution = .merge
    ) -> Reward {
        switch strategy {
        case .preferLocal:
            return local
        case .preferRemote:
            return remote
        case .preferMostRecent:
            return local.lastModifiedDate > remote.lastModifiedDate ? local : remote
        case .merge:
            return mergeReward(local: local, remote: remote)
        }
    }
    
    private static func mergeReward(local: Reward, remote: Reward) -> Reward {
        var merged = local.lastModifiedDate > remote.lastModifiedDate ? local : remote
        
        // Merge redemptions - combine all unique redemption dates
        let allRedemptions = Array(Set(local.redemptions + remote.redemptions)).sorted()
        merged.redemptions = allRedemptions
        
        // Update modification date
        merged.lastModifiedDate = Date()
        
        return merged
    }
    
    // MARK: - Points History Merge
    
    static func mergePointsHistory(
        local: [Date: Int],
        remote: [PointsHistory]
    ) -> [Date: Int] {
        var merged = local
        
        for entry in remote {
            let startOfDay = Calendar.current.startOfDay(for: entry.date)
            
            // Only add if we don't have local data for this date
            if merged[startOfDay] == nil {
                merged[startOfDay] = entry.points
            }
        }
        
        return merged
    }
    
    // MARK: - Data Validation
    
    static func validateTask(_ task: TodoTask) -> (isValid: Bool, errors: [String]) {
        var errors: [String] = []
        
        if task.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Task name cannot be empty")
        }
        
        if task.name.count > 500 {
            errors.append("Task name is too long (max 500 characters)")
        }
        
        if let description = task.description, description.count > 2000 {
            errors.append("Task description is too long (max 2000 characters)")
        }
        
        if task.duration < 0 {
            errors.append("Task duration cannot be negative")
        }
        
        if task.duration > 86400 { // 24 hours in seconds
            errors.append("Task duration cannot exceed 24 hours")
        }
        
        if task.rewardPoints < 0 {
            errors.append("Reward points cannot be negative")
        }
        
        if task.rewardPoints > 10000 {
            errors.append("Reward points cannot exceed 10,000")
        }
        
        return (errors.isEmpty, errors)
    }
    
    static func validateCategory(_ category: Category) -> (isValid: Bool, errors: [String]) {
        var errors: [String] = []
        
        if category.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Category name cannot be empty")
        }
        
        if category.name.count > 100 {
            errors.append("Category name is too long (max 100 characters)")
        }
        
        // Validate color format (hex color)
        let hexPattern = "^[0-9A-Fa-f]{6}$"
        let hexPredicate = NSPredicate(format: "SELF MATCHES %@", hexPattern)
        if !hexPredicate.evaluate(with: category.color) {
            errors.append("Invalid color format (must be 6-digit hex)")
        }
        
        return (errors.isEmpty, errors)
    }
    
    static func validateReward(_ reward: Reward) -> (isValid: Bool, errors: [String]) {
        var errors: [String] = []
        
        if reward.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Reward name cannot be empty")
        }
        
        if reward.name.count > 200 {
            errors.append("Reward name is too long (max 200 characters)")
        }
        
        if let description = reward.description, description.count > 1000 {
            errors.append("Reward description is too long (max 1000 characters)")
        }
        
        if reward.pointsCost <= 0 {
            errors.append("Reward cost must be positive")
        }
        
        if reward.pointsCost > 100000 {
            errors.append("Reward cost cannot exceed 100,000 points")
        }
        
        return (errors.isEmpty, errors)
    }
    
    // MARK: - Sync Statistics
    
    struct SyncStatistics {
        let tasksAdded: Int
        let tasksUpdated: Int
        let tasksDeleted: Int
        let rewardsAdded: Int
        let rewardsUpdated: Int
        let rewardsDeleted: Int
        let categoriesAdded: Int
        let categoriesUpdated: Int
        let categoriesDeleted: Int
        let pointsEntriesAdded: Int
        let syncDuration: TimeInterval
        let syncDate: Date
        
        var totalChanges: Int {
            return tasksAdded + tasksUpdated + tasksDeleted +
                   rewardsAdded + rewardsUpdated + rewardsDeleted +
                   categoriesAdded + categoriesUpdated + categoriesDeleted +
                   pointsEntriesAdded
        }
    }
    
    // MARK: - Error Recovery
    
    static func shouldRetryError(_ error: Error) -> Bool {
        guard let ckError = error as? CKError else { return false }
        
        switch ckError.code {
        case .networkFailure, .networkUnavailable, .serviceUnavailable:
            return true
        case .requestRateLimited:
            return true
        case .zoneBusy:
            return true
        default:
            return false
        }
    }
    
    static func retryDelayForError(_ error: Error, attempt: Int) -> TimeInterval {
        guard let ckError = error as? CKError else { return 0 }
        
        switch ckError.code {
        case .requestRateLimited:
            if let retryAfter = ckError.retryAfterSeconds {
                return retryAfter
            }
            return Double(attempt * attempt) // Exponential backoff
        case .zoneBusy:
            return Double(attempt * 2) // Linear backoff
        default:
            return Double(attempt * attempt) // Exponential backoff
        }
    }
    
    // MARK: - Data Integrity
    
    static func checksumForTasks(_ tasks: [TodoTask]) -> String {
        let sortedTasks = tasks.sorted { $0.id.uuidString < $1.id.uuidString }
        let taskData = sortedTasks.map { "\($0.id.uuidString):\($0.lastModifiedDate.timeIntervalSince1970)" }
        let combined = taskData.joined(separator: "|")
        return combined.sha256
    }
    
    static func checksumForRewards(_ rewards: [Reward]) -> String {
        let sortedRewards = rewards.sorted { $0.id.uuidString < $1.id.uuidString }
        let rewardData = sortedRewards.map { "\($0.id.uuidString):\($0.lastModifiedDate.timeIntervalSince1970)" }
        let combined = rewardData.joined(separator: "|")
        return combined.sha256
    }
    
    static func checksumForCategories(_ categories: [Category]) -> String {
        let sortedCategories = categories.sorted { $0.id.uuidString < $1.id.uuidString }
        let categoryData = sortedCategories.map { "\($0.id.uuidString):\($0.name)" }
        let combined = categoryData.joined(separator: "|")
        return combined.sha256
    }
}

// MARK: - String Extension for Checksum
extension String {
    var sha256: String {
        let data = Data(self.utf8)
        let hash = data.withUnsafeBytes { bytes in
            return SHA256.hash(data: data)
        }
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

import CryptoKit

// MARK: - CloudKit Record Size Estimation
extension CloudKitSyncUtilities {
    
    static func estimateRecordSize<T: Codable>(_ object: T) -> Int {
        guard let data = try? JSONEncoder().encode(object) else { return 0 }
        return data.count
    }
    
    static func canUploadToCloudKit<T: Codable>(_ object: T) -> Bool {
        let size = estimateRecordSize(object)
        return size < 1_000_000 // 1MB limit for CloudKit records
    }
    
    // MARK: - Batch Operations
    
    static func batchItems<T>(_ items: [T], batchSize: Int = 100) -> [[T]] {
        return stride(from: 0, to: items.count, by: batchSize).map {
            Array(items[$0..<min($0 + batchSize, items.count)])
        }
    }
}