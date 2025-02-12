import Foundation

struct PomodoroSettings: Codable, Equatable {
    var workDuration: Double
    var breakDuration: Double
    var longBreakDuration: Double
    var sessionsUntilLongBreak: Int
    
    static let defaultSettings = PomodoroSettings(
        workDuration: 25 * 60,    // 25 minutes in seconds
        breakDuration: 5 * 60,    // 5 minutes
        longBreakDuration: 15 * 60, // 15 minutes
        sessionsUntilLongBreak: 4
    )
    
    // Computed properties for session management
    var sessionDuration: Double {
        workDuration
    }
    
    var sessions: Int {
        sessionsUntilLongBreak
    }
}