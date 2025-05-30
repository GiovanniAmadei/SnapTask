import Foundation

struct Category: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var color: String
    
    init(name: String, color: String) {
        self.id = UUID()
        self.name = name
        self.color = color
    }
    
    init(id: UUID, name: String, color: String) {
        self.id = id
        self.name = name
        self.color = color
    }
}
