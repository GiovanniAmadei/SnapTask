import Foundation

struct Quote: Identifiable, Codable, Equatable {
    let id = UUID()
    let text: String
    let author: String
    
    static let placeholder = Quote(
        text: "The journey of a thousand miles begins with a single step.",
        author: "Lao Tzu"
    )
} 