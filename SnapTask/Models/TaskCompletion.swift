import Foundation

struct TaskCompletion: Codable, Equatable, Hashable {
    var isCompleted: Bool
    var completedSubtasks: Set<UUID>
    
    init(isCompleted: Bool = false, completedSubtasks: Set<UUID> = []) {
        self.isCompleted = isCompleted
        self.completedSubtasks = completedSubtasks
    }
    
    enum CodingKeys: String, CodingKey {
        case isCompleted
        case completedSubtasks
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        
        // Handle Set<UUID> decoding more robustly
        if let subtaskArray = try? container.decode([UUID].self, forKey: .completedSubtasks) {
            completedSubtasks = Set(subtaskArray)
        } else if let subtaskStrings = try? container.decode([String].self, forKey: .completedSubtasks) {
            completedSubtasks = Set(subtaskStrings.compactMap { UUID(uuidString: $0) })
        } else {
            completedSubtasks = []
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isCompleted, forKey: .isCompleted)
        
        // Encode Set<UUID> as Array for better compatibility
        let subtaskArray = Array(completedSubtasks)
        try container.encode(subtaskArray, forKey: .completedSubtasks)
    }
}
