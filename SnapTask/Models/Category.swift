import Foundation

struct Category: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var color: String
    /// SF Symbol name. Optional so categories saved before icons existed still decode.
    var icon: String? = nil
    
    static func == (lhs: Category, rhs: Category) -> Bool {
        return lhs.id == rhs.id && 
               lhs.name == rhs.name && 
               lhs.color == rhs.color &&
               lhs.icon == rhs.icon
    }
}
