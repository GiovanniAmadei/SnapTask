import Foundation

struct PomodoroSettings: Codable, Equatable, Hashable {
    var workDuration: Double
    var breakDuration: Double
    var longBreakDuration: Double
    var sessionsUntilLongBreak: Int
    var totalSessions: Int 
    var totalDuration: Double 
    
    static let defaultSettings = PomodoroSettings(
        workDuration: 25 * 60,    // 25 minutes in seconds
        breakDuration: 5 * 60,    // 5 minutes
        longBreakDuration: 15 * 60, // 15 minutes
        sessionsUntilLongBreak: 4,
        totalSessions: 4,         // Default to 4 sessions
        totalDuration: 120        // Default to 2 hours (120 minutes)
    )
    
    // Computed properties for session management
    var sessionDuration: Double {
        workDuration
    }
    
    var sessions: Int {
        totalSessions 
    }
    
    // Calculate estimated total time for all sessions including breaks
    var estimatedTotalTime: Double {
        let workTime = workDuration * Double(totalSessions)
        let shortBreaks = max(0, totalSessions - 1 - (totalSessions / sessionsUntilLongBreak))
        let longBreaks = totalSessions / sessionsUntilLongBreak
        let breakTime = (Double(shortBreaks) * breakDuration) + (Double(longBreaks) * longBreakDuration)
        return workTime + breakTime
    }
    
    // Calculate sessions needed to reach target duration
    func sessionsForDuration(_ targetDuration: Double) -> Int {
        let averageSessionTime = workDuration + breakDuration
        return max(1, Int(targetDuration * 60 / averageSessionTime))
    }
}
