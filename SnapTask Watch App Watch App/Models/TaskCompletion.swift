import Foundation

struct TaskCompletion: Codable, Equatable {
    var isCompleted: Bool
    var completedSubtasks: Set<UUID>
    var trackedTime: TimeInterval = 0
    
    init(isCompleted: Bool = false, completedSubtasks: Set<UUID> = [], trackedTime: TimeInterval = 0) {
        self.isCompleted = isCompleted
        self.completedSubtasks = completedSubtasks
        self.trackedTime = trackedTime
    }
}
