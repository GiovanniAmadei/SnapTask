import Foundation

struct Quote: Codable, Equatable {
    let id: String
    let content: String
    let author: String
    
    static let placeholder = Quote(
        id: "placeholder",
        content: "The best way to predict the future is to create it.",
        author: "Peter Drucker"
    )
} 