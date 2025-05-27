import Foundation

struct Category: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var color: String
    
    static func == (lhs: Category, rhs: Category) -> Bool {
        return lhs.id == rhs.id && 
               lhs.name == rhs.name && 
               lhs.color == rhs.color
    }
}
