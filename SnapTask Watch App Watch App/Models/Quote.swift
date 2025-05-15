import Foundation

struct Quote: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    var author: String
    var lastUpdated: Date
    
    init(id: UUID = UUID(), text: String, author: String, lastUpdated: Date = Date()) {
        self.id = id
        self.text = text
        self.author = author
        self.lastUpdated = lastUpdated
    }
    
    static let placeholder = Quote(
        text: "The journey of a thousand miles begins with a single step.",
        author: "Lao Tzu"
    )
} 