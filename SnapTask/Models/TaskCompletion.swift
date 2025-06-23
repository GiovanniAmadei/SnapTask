import Foundation

struct TaskCompletion: Codable, Equatable, Hashable {
    var isCompleted: Bool
    var completedSubtasks: Set<UUID>
    var actualDuration: TimeInterval?
    var difficultyRating: Int?  // 1-10 scale
    var qualityRating: Int?     // 1-10 scale
    var completionDate: Date?   // When this specific completion happened
    
    init(
        isCompleted: Bool = false, 
        completedSubtasks: Set<UUID> = [],
        actualDuration: TimeInterval? = nil,
        difficultyRating: Int? = nil,
        qualityRating: Int? = nil,
        completionDate: Date? = nil
    ) {
        self.isCompleted = isCompleted
        self.completedSubtasks = completedSubtasks
        self.actualDuration = actualDuration
        self.difficultyRating = difficultyRating
        self.qualityRating = qualityRating
        self.completionDate = completionDate
    }
    
    enum CodingKeys: String, CodingKey {
        case isCompleted
        case completedSubtasks
        case actualDuration
        case difficultyRating
        case qualityRating
        case completionDate
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
        
        actualDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .actualDuration)
        difficultyRating = try container.decodeIfPresent(Int.self, forKey: .difficultyRating)
        qualityRating = try container.decodeIfPresent(Int.self, forKey: .qualityRating)
        completionDate = try container.decodeIfPresent(Date.self, forKey: .completionDate)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isCompleted, forKey: .isCompleted)
        
        // Encode Set<UUID> as Array for better compatibility
        let subtaskArray = Array(completedSubtasks)
        try container.encode(subtaskArray, forKey: .completedSubtasks)
        
        try container.encodeIfPresent(actualDuration, forKey: .actualDuration)
        try container.encodeIfPresent(difficultyRating, forKey: .difficultyRating)
        try container.encodeIfPresent(qualityRating, forKey: .qualityRating)
        try container.encodeIfPresent(completionDate, forKey: .completionDate)
    }
    
    var hasRatings: Bool {
        actualDuration != nil || difficultyRating != nil || qualityRating != nil
    }
    
    var formattedActualDuration: String? {
        guard let actualDuration = actualDuration else { return nil }
        let hours = Int(actualDuration) / 3600
        let minutes = Int(actualDuration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
