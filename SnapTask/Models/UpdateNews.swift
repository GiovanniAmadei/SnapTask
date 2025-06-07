import Foundation

struct UpdateNews: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let version: String?
    let date: Date?  
    let type: NewsType
    let isHighlighted: Bool
    
    enum NewsType: String, Codable, CaseIterable {
        case recentUpdate = "recent"
        case comingSoon = "coming_soon"
        case roadmap = "roadmap"
        
        var displayName: String {
            switch self {
            case .recentUpdate:
                return "Recent Update"
            case .comingSoon:
                return "Coming Soon"
            case .roadmap:
                return "Roadmap"
            }
        }
        
        var icon: String {
            switch self {
            case .recentUpdate:
                return "checkmark.circle.fill"
            case .comingSoon:
                return "clock.fill"
            case .roadmap:
                return "map.fill"
            }
        }
        
        var color: String {
            switch self {
            case .recentUpdate:
                return "#34C759" // Green
            case .comingSoon:
                return "#FF9500" // Orange
            case .roadmap:
                return "#007AFF" // Blue
            }
        }
    }
}
