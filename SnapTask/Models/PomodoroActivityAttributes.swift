import Foundation
import ActivityKit

/// Shared ActivityAttributes for the Pomodoro Live Activity.
/// Lives in the main app target and is also compiled into the widget
/// extension via PBXFileSystemSynchronizedBuildFileExceptionSet.
struct PomodoroActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public enum Phase: String, Codable, Hashable {
            case working
            case onBreak
            case paused
            case simpleTimer
        }

        /// Current phase of the timer.
        public var phase: Phase

        /// Absolute date the current phase is scheduled to end.
        /// Used by `Text(timerInterval:)` in the UI to auto-update
        /// without requiring frequent Activity updates.
        public var endDate: Date

        /// Total duration of the current phase when it started or resumed.
        /// This lets the widget render percentage-based progress for the
        /// active segment while `endDate` drives the live countdown.
        public var phaseTotalDuration: TimeInterval

        /// When the phase is `.paused`, holds the frozen remaining time
        /// so the UI can render a static counter.
        public var pausedTimeRemaining: TimeInterval?

        /// 1-based index of the current Pomodoro session (e.g. 2 of 4).
        public var currentSession: Int

        /// Total number of Pomodoro sessions planned for this cycle.
        public var totalSessions: Int
    }

    /// User-facing name of what is being worked on (task name or "Focus Session").
    public var taskName: String

    /// Optional category color (hex, e.g. "#FF5733") used for accents.
    public var categoryColorHex: String?

    /// Optional category name shown as a subtitle / badge.
    public var categoryName: String?
}
