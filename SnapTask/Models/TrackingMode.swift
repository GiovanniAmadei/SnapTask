import Foundation

enum TrackingMode: String, CaseIterable, Codable {
    case simple = "simple"
    case pomodoro = "pomodoro"
    
    var displayName: String {
        switch self {
        case .simple:
            return "simple_timer".localized
        case .pomodoro:
            return "pomodoro_mode".localized
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
            return "simple_timer_description".localized
        case .pomodoro:
            return "pomodoro_mode_description".localized
        }
    }
}