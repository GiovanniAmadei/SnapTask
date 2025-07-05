import Foundation

enum Priority: String, CaseIterable, Codable {
    case low
    case medium
    case high
    
    var displayName: String {
        switch self {
        case .low: return "low_priority".localized
        case .medium: return "medium_priority".localized  
        case .high: return "high_priority".localized
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "arrow.down"
        case .medium: return "minus"
        case .high: return "arrow.up"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "#00FF00"
        case .medium: return "#FFA500"
        case .high: return "#FF0000"
        }
    }
}