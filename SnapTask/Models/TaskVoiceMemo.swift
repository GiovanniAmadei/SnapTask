import Foundation

struct TaskVoiceMemo: Identifiable, Codable, Equatable {
    let id: UUID
    let audioPath: String
    let duration: TimeInterval
    let createdAt: Date
    var name: String?

    init(id: UUID = UUID(), audioPath: String, duration: TimeInterval, createdAt: Date = Date(), name: String? = nil) {
        self.id = id
        self.audioPath = audioPath
        self.duration = duration
        self.createdAt = createdAt
        self.name = name
    }
    
    var displayName: String {
        return name ?? "voice_memo".localized
    }
}