import Foundation

struct TaskVoiceMemo: Identifiable, Codable, Equatable {
    let id: UUID
    let audioPath: String
    let duration: TimeInterval
    let createdAt: Date

    init(id: UUID = UUID(), audioPath: String, duration: TimeInterval, createdAt: Date = Date()) {
        self.id = id
        self.audioPath = audioPath
        self.duration = duration
        self.createdAt = createdAt
    }
}