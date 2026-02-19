package com.snaptask.app.data.model

/**
 * Pomodoro timer settings for a task, matching iOS PomodoroSettings struct.
 */
data class PomodoroSettings(
    val workDuration: Double = DEFAULT_WORK_DURATION,
    val breakDuration: Double = DEFAULT_BREAK_DURATION,
    val longBreakDuration: Double = DEFAULT_LONG_BREAK_DURATION,
    val sessionsUntilLongBreak: Int = DEFAULT_SESSIONS_UNTIL_LONG_BREAK,
    val totalSessions: Int = DEFAULT_TOTAL_SESSIONS,
    val totalDuration: Double = DEFAULT_TOTAL_DURATION,
) {
    /** Work duration per session (alias for workDuration) */
    val sessionDuration: Double get() = workDuration

    /** Number of sessions (alias for totalSessions) */
    val sessions: Int get() = totalSessions

    /** Estimated total time for all sessions including breaks */
    val estimatedTotalTime: Double
        get() {
            val workTime = workDuration * totalSessions
            val shortBreaks = maxOf(0, totalSessions - 1 - (totalSessions / sessionsUntilLongBreak))
            val longBreaks = totalSessions / sessionsUntilLongBreak
            val breakTime = (shortBreaks * breakDuration) + (longBreaks * longBreakDuration)
            return workTime + breakTime
        }

    /** Calculate sessions needed to reach target duration (in minutes) */
    fun sessionsForDuration(targetDurationMinutes: Double): Int {
        val averageSessionTime = workDuration + breakDuration
        return maxOf(1, (targetDurationMinutes * 60 / averageSessionTime).toInt())
    }

    companion object {
        const val DEFAULT_WORK_DURATION = 25.0 * 60 // 25 minutes in seconds
        const val DEFAULT_BREAK_DURATION = 5.0 * 60
        const val DEFAULT_LONG_BREAK_DURATION = 15.0 * 60
        const val DEFAULT_SESSIONS_UNTIL_LONG_BREAK = 4
        const val DEFAULT_TOTAL_SESSIONS = 4
        const val DEFAULT_TOTAL_DURATION = 120.0 // 2 hours in minutes

        val default = PomodoroSettings()
    }
}
