import Foundation

struct TaskCompletion: Codable, Equatable {
    var isCompleted: Bool
    var completedSubtasks: Set<UUID>
    
    init(isCompleted: Bool = false, completedSubtasks: Set<UUID> = []) {
        self.isCompleted = isCompleted
        self.completedSubtasks = completedSubtasks
    }
} 