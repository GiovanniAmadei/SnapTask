package com.snaptask.app.data.model

import java.util.Calendar
import java.util.Date
import java.util.UUID

/**
 * Main task model, matching iOS TodoTask struct.
 * This is the core data model for the entire app.
 */
data class TodoTask(
    val id: UUID = UUID.randomUUID(),
    val name: String,
    val description: String? = null,
    val location: TaskLocation? = null,
    val startTime: Date = Date(),
    val hasSpecificDay: Boolean = false,
    val hasSpecificTime: Boolean = false,
    val duration: Double = 0.0, // seconds
    val hasDuration: Boolean = false,
    val category: Category? = null,
    val priority: Priority = Priority.MEDIUM,
    val icon: String = "circle",
    val recurrence: Recurrence? = null,
    val pomodoroSettings: PomodoroSettings? = null,
    val completions: Map<Long, TaskCompletion> = emptyMap(), // Key: startOfDay timestamp
    val subtasks: List<Subtask> = emptyList(),
    val completionDates: List<Date> = emptyList(),
    val creationDate: Date = Date(),
    val lastModifiedDate: Date = Date(),
    // Reward points
    val hasRewardPoints: Boolean = false,
    val rewardPoints: Int = 0,
    // Time tracking
    val totalTrackedTime: Double = 0.0, // seconds
    val lastTrackedDate: Date? = null,
    // Notification
    val hasNotification: Boolean = false,
    val notificationId: String? = null,
    // Photos & Voice Memos
    val photoPath: String? = null,
    val photoThumbnailPath: String? = null,
    val photos: List<TaskPhoto> = emptyList(),
    val voiceMemos: List<TaskVoiceMemo> = emptyList(),
    // Scope
    val timeScope: TaskTimeScope = TaskTimeScope.TODAY,
    val scopeStartDate: Date? = null,
    val scopeEndDate: Date? = null,
    // Notification lead time
    val notificationLeadTimeMinutes: Int = 0,
    // Auto carry over
    val autoCarryOver: Boolean = false,
    // Life Orchestration
    val domainId: UUID? = null,
    val goalId: UUID? = null,
) {
    // ---- Computed Properties ----

    val completionProgress: Double
        get() {
            if (subtasks.isEmpty()) {
                val today = Recurrence.startOfDay(Date()).time
                val completion = completions[today]
                return if (completion?.isCompleted == true) 1.0 else 0.0
            }
            return subtasks.count { it.isCompleted }.toDouble() / subtasks.size
        }

    val formattedTrackedTime: String
        get() {
            val hours = (totalTrackedTime / 3600).toInt()
            val minutes = (totalTrackedTime % 3600 / 60).toInt()
            return if (hours > 0) "${hours}h ${minutes}m" else "${minutes}m"
        }

    val hasRecentTracking: Boolean
        get() {
            val lastTracked = lastTrackedDate ?: return false
            val calendar = Calendar.getInstance()
            val today = Calendar.getInstance()
            calendar.time = lastTracked
            return calendar.get(Calendar.YEAR) == today.get(Calendar.YEAR) &&
                    calendar.get(Calendar.DAY_OF_YEAR) == today.get(Calendar.DAY_OF_YEAR)
        }

    val currentStreak: Int
        get() = streakForDate(Date())

    val hasHistoricalRatings: Boolean
        get() {
            val ratingsCount = completions.values.count { completion ->
                completion.qualityRating != null || completion.difficultyRating != null
            }
            return ratingsCount >= 2
        }

    // ---- Methods ----

    /**
     * Check if this task occurs on the given date (for recurring tasks or non-recurring).
     */
    fun occurs(date: Date): Boolean {
        return if (recurrence != null) {
            recurrence.shouldOccurOn(date)
        } else {
            isSameDay(startTime, date)
        }
    }

    /**
     * For recurring tasks, returns the startTime mapped to the given date.
     * Preserves hour/minute from the original start time.
     */
    fun occurrenceDate(date: Date): Date {
        val cal = Calendar.getInstance().apply { time = date }
        val origCal = Calendar.getInstance().apply { time = startTime }
        cal.set(Calendar.HOUR_OF_DAY, origCal.get(Calendar.HOUR_OF_DAY))
        cal.set(Calendar.MINUTE, origCal.get(Calendar.MINUTE))
        cal.set(Calendar.SECOND, origCal.get(Calendar.SECOND))
        return cal.time
    }

    /**
     * Calculate the streak (consecutive completions) ending at the given date.
     */
    fun streakForDate(date: Date): Int {
        val recurrence = recurrence ?: return 0
        val calendar = Calendar.getInstance()
        var currentDate = Recurrence.startOfDay(date)
        var streak = 0
        val today = Recurrence.startOfDay(Date())

        if (currentDate.after(today)) return 0

        var iterationCount = 0
        val maxIterations = 1000

        while (iterationCount < maxIterations) {
            if (currentDate.before(Recurrence.startOfDay(startTime))) break
            if (recurrence.endDate != null && currentDate.after(recurrence.endDate)) break

            val shouldCheck = shouldCheckDate(currentDate, recurrence)
            if (shouldCheck) {
                val completion = completions[currentDate.time]
                if (completion?.isCompleted == true) {
                    streak++
                } else {
                    break
                }
            }

            calendar.time = currentDate
            calendar.add(Calendar.DAY_OF_YEAR, -1)
            currentDate = calendar.time
            iterationCount++
        }

        return streak
    }

    /**
     * Get the completion key (start-of-day timestamp) for a given date.
     */
    fun completionKey(date: Date): Long {
        val calendar = Calendar.getInstance()
        if (recurrence != null) {
            return Recurrence.startOfDay(date).time
        }
        return when (timeScope) {
            TaskTimeScope.TODAY -> Recurrence.startOfDay(date).time
            TaskTimeScope.WEEK -> {
                val scopeDate = scopeStartDate ?: date
                Recurrence.startOfWeek(scopeDate).time
            }
            TaskTimeScope.MONTH -> {
                val scopeDate = scopeStartDate ?: date
                Recurrence.startOfMonth(scopeDate).time
            }
            TaskTimeScope.YEAR -> {
                val cal = Calendar.getInstance().apply {
                    time = scopeStartDate ?: date
                    set(Calendar.MONTH, Calendar.JANUARY)
                    set(Calendar.DAY_OF_MONTH, 1)
                    set(Calendar.HOUR_OF_DAY, 0)
                    set(Calendar.MINUTE, 0)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }
                cal.timeInMillis
            }
            TaskTimeScope.LONG_TERM, TaskTimeScope.ALL -> {
                Recurrence.startOfDay(startTime).time
            }
        }
    }

    fun hasRatings(date: Date): Boolean {
        val key = Recurrence.startOfDay(date).time
        return completions[key]?.hasRatings == true
    }

    fun actualDuration(date: Date): Double? {
        val key = Recurrence.startOfDay(date).time
        return completions[key]?.actualDuration
    }

    fun difficultyRating(date: Date): Int? {
        val key = Recurrence.startOfDay(date).time
        return completions[key]?.difficultyRating
    }

    fun qualityRating(date: Date): Int? {
        val key = Recurrence.startOfDay(date).time
        return completions[key]?.qualityRating
    }

    private fun shouldCheckDate(date: Date, recurrence: Recurrence): Boolean {
        return when (recurrence.type) {
            RecurrenceType.DAILY -> true
            is RecurrenceType.WEEKLY -> {
                val cal = Calendar.getInstance().apply { time = date }
                recurrence.type.days.contains(cal.get(Calendar.DAY_OF_WEEK))
            }
            is RecurrenceType.MONTHLY -> {
                val cal = Calendar.getInstance().apply { time = date }
                recurrence.type.days.contains(cal.get(Calendar.DAY_OF_MONTH))
            }
            is RecurrenceType.MONTHLY_ORDINAL -> recurrence.shouldOccurOn(date)
            RecurrenceType.YEARLY -> recurrence.shouldOccurOn(date)
        }
    }

    companion object {
        fun isSameDay(date1: Date, date2: Date): Boolean {
            val cal1 = Calendar.getInstance().apply { time = date1 }
            val cal2 = Calendar.getInstance().apply { time = date2 }
            return cal1.get(Calendar.YEAR) == cal2.get(Calendar.YEAR) &&
                    cal1.get(Calendar.DAY_OF_YEAR) == cal2.get(Calendar.DAY_OF_YEAR)
        }
    }
}
