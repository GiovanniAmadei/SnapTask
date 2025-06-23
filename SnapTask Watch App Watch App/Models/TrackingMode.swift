import Foundation

enum TrackingMode: String, CaseIterable, Codable {
    case simple = "simple"
    case pomodoro = "pomodoro"
    
    var displayName: String {
        switch self {
        case .simple:
            return "Simple Timer"
        case .pomodoro:
            return "Pomodoro Mode"
        }
    }
    
    var icon: String {
        switch self {
        case .simple:
            return "timer"
        case .pomodoro:
            return "clock.fill"
        }
    }
    
    var description: String {
        switch self {
        case .simple:
            return "Track time continuously"
        case .pomodoro:
            return "Work in focused intervals"
        }
    }
}