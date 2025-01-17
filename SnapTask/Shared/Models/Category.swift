import Foundation

struct Category: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var color: String
}