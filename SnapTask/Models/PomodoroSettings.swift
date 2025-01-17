import Foundation

struct PomodoroSettings: Codable, Equatable {
    var workDuration: TimeInterval = 25 * 60  // 25 minutes
    var breakDuration: TimeInterval = 5 * 60  // 5 minutes
    var longBreakDuration: TimeInterval = 15 * 60  // 15 minutes
    var sessionsUntilLongBreak: Int = 4
}