import Foundation

struct TaskPhoto: Identifiable, Codable, Equatable {
    let id: UUID
    let photoPath: String
    let thumbnailPath: String
    let createdAt: Date
    
    init(id: UUID = UUID(), photoPath: String, thumbnailPath: String, createdAt: Date = Date()) {
        self.id = id
        self.photoPath = photoPath
        self.thumbnailPath = thumbnailPath
        self.createdAt = createdAt
    }
}