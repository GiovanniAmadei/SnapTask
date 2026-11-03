@file:UseSerializers(DateSerializer::class, UUIDSerializer::class)

package com.snaptask.app

import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.UseSerializers
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.descriptors.buildClassSerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonEncoder
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonObject
import java.time.format.FormatStyle
import java.util.UUID

@Serializable
enum class TaskTimeScope(val icon: String, val colorName: String) {
    @SerialName("today") today("star.fill", "blue"),
    @SerialName("week") week("target", "green"),
    @SerialName("month") month("calendar", "orange"),
    @SerialName("year") year("trophy.fill", "purple"),
    @SerialName("longTerm") longTerm("sparkles", "pink"),
    /** Undated quick notes/tasks captured on the fly, scheduled later. */
    @SerialName("inbox") inbox("tray.fill", "indigo"),
    @SerialName("all") all("square.grid.2x2", "teal");

    val rawValue: String get() = name

    val displayName: String
        get() = when (this) {
            today -> "scope_today".localized
            week -> "scope_week".localized
            month -> "scope_month".localized
            year -> "scope_year".localized
            longTerm -> "scope_long_term".localized
            inbox -> "scope_inbox".localized
            all -> "scope_all".localized
        }
}

@Serializable
enum class Priority(val icon: String, val colorHex: String) {
    low("arrow.down", "#00FF00"),
    medium("minus", "#FFA500"),
    high("arrow.up", "#FF0000");

    val displayName: String
        get() = when (this) {
            low -> "low_priority".localized
            medium -> "medium_priority".localized
            high -> "high_priority".localized
        }
}

@Serializable
data class Category(
    val id: UUID,
    var name: String,
    var color: String,
    /** SF Symbol name, as on iOS. Optional so categories saved before icons existed still decode. */
    var icon: String? = null,
)

@Serializable
data class Subtask(
    val id: UUID = UUID.randomUUID(),
    val name: String,
    val isCompleted: Boolean = false,
)

@Serializable
data class TaskPhoto(
    val id: UUID = UUID.randomUUID(),
    val photoPath: String,
    val thumbnailPath: String,
    val createdAt: Date = now(),
)

@Serializable
data class TaskVoiceMemo(
    val id: UUID = UUID.randomUUID(),
    val audioPath: String,
    val duration: Double,
    val createdAt: Date = now(),
    val name: String? = null,
) {
    val displayName: String get() = name ?: "voice_memo".localized
}

@Serializable
data class Coordinate(val latitude: Double, val longitude: Double)

@Serializable
data class TaskPlacemark(
    val name: String? = null,
    val thoroughfare: String? = null,
    val locality: String? = null,
    val administrativeArea: String? = null,
    val country: String? = null,
    val postalCode: String? = null,
) {
    val formattedAddress: String
        get() = listOfNotNull(thoroughfare, locality, administrativeArea).joinToString(", ")
}

@Serializable
data class TaskLocation(
    val id: UUID = UUID.randomUUID(),
    val name: String,
    val address: String? = null,
    val coordinate: Coordinate? = null,
    val placemark: TaskPlacemark? = null,
) {
    val displayName: String get() = if (!address.isNullOrEmpty()) "$name - $address" else name
    val shortDisplayName: String get() = name
}

@Serializable
data class PomodoroSettings(
    val workDuration: Double,
    val breakDuration: Double,
    val longBreakDuration: Double,
    val sessionsUntilLongBreak: Int,
    val totalSessions: Int,
    val totalDuration: Double,
) {
    val sessionDuration: Double get() = workDuration
    val sessions: Int get() = totalSessions

    /** Estimated total time for all sessions including breaks. */
    val estimatedTotalTime: Double
        get() {
            val workTime = workDuration * totalSessions
            val longBreaks = totalSessions / sessionsUntilLongBreak
            val shortBreaks = maxOf(0, totalSessions - 1 - longBreaks)
            return workTime + shortBreaks * breakDuration + longBreaks * longBreakDuration
        }

    fun sessionsForDuration(targetDuration: Double): Int {
        val averageSessionTime = workDuration + breakDuration
        return maxOf(1, (targetDuration * 60 / averageSessionTime).toInt())
    }

    companion object {
        val defaultSettings = PomodoroSettings(
            workDuration = 25.0 * 60,
            breakDuration = 5.0 * 60,
            longBreakDuration = 15.0 * 60,
            sessionsUntilLongBreak = 4,
            totalSessions = 4,
            totalDuration = 120.0,
        )
    }
}

@Serializable
data class TaskCompletion(
    val isCompleted: Boolean = false,
    val completedSubtasks: Set<UUID> = emptySet(),
    val actualDuration: Double? = null,
    val difficultyRating: Int? = null,
    val qualityRating: Int? = null,
    val completionDate: Date? = null,
    val notes: String? = null,
    /** Started but not finished ("In corso"). Cleared when the occurrence is completed. */
    val isInProgress: Boolean = false,
    /** When this occurrence last changed. */
    val modifiedAt: Date? = null,
) {
    /** Same content, whenever it was changed. */
    fun hasSameContent(other: TaskCompletion?): Boolean =
        other != null && copy(modifiedAt = null) == other.copy(modifiedAt = null)

    val hasRatings: Boolean get() = actualDuration != null || difficultyRating != null || qualityRating != null
    val hasPerformanceData: Boolean get() = hasRatings
    val formattedActualDuration: String? get() = actualDuration?.let { formatHoursMinutes(it) }
}

fun formatHoursMinutes(seconds: Double): String {
    val hours = seconds.toInt() / 3600
    val minutes = seconds.toInt() % 3600 / 60
    return if (hours > 0) "${hours}h ${minutes}m" else "${minutes}m"
}

object CompletionsSerializer : KSerializer<Map<Date, TaskCompletion>> by DateKeyedMapSerializer(TaskCompletion.serializer())

@Serializable
data class TodoTask(
    val id: UUID = UUID.randomUUID(),
    val name: String = "",
    val description: String? = null,
    val location: TaskLocation? = null,
    val startTime: Date = now(),
    val hasSpecificDay: Boolean = false,
    val hasSpecificTime: Boolean = false,
    val duration: Double = 0.0,
    val hasDuration: Boolean = false,
    val category: Category? = null,
    val priority: Priority = Priority.medium,
    val icon: String = "circle",
    val recurrence: Recurrence? = null,
    val pomodoroSettings: PomodoroSettings? = null,
    @Serializable(with = CompletionsSerializer::class)
    val completions: Map<Date, TaskCompletion> = emptyMap(),
    val subtasks: List<Subtask> = emptyList(),
    val completionDates: List<Date> = emptyList(),
    val creationDate: Date = now(),
    val lastModifiedDate: Date = now(),
    val hasRewardPoints: Boolean = false,
    val rewardPoints: Int = 0,
    val totalTrackedTime: Double = 0.0,
    val lastTrackedDate: Date? = null,
    val hasNotification: Boolean = false,
    val notificationId: String? = null,
    val photoPath: String? = null,
    val photoThumbnailPath: String? = null,
    val photos: List<TaskPhoto> = emptyList(),
    val voiceMemos: List<TaskVoiceMemo> = emptyList(),
    val timeScope: TaskTimeScope = TaskTimeScope.today,
    val scopeStartDate: Date? = null,
    val scopeEndDate: Date? = null,
    val notificationLeadTimeMinutes: Int = 0,
    val autoCarryOver: Boolean = false,
    val domainId: UUID? = null,
    val goalId: UUID? = null,
    val spaceID: UUID? = null,
) {
    val displayPeriod: String
        get() = when (timeScope) {
            TaskTimeScope.today -> startTime.dateStyle(FormatStyle.MEDIUM)
            TaskTimeScope.week -> scopeStartDate?.let { start ->
                val weekStart = start.startOfWeek()
                "${weekStart.dateStyle(FormatStyle.SHORT)} - ${weekStart.addingDays(6).dateStyle(FormatStyle.SHORT)}"
            } ?: "this_week".localized
            TaskTimeScope.month -> scopeStartDate?.format("MMMM yyyy") ?: "this_month".localized
            TaskTimeScope.year -> scopeStartDate?.format("yyyy") ?: "this_year".localized
            TaskTimeScope.longTerm -> "long_term_objective".localized
            TaskTimeScope.inbox -> "scope_inbox".localized
            TaskTimeScope.all -> "all_time".localized
        }

    fun shouldShow(date: Date, scope: TaskTimeScope): Boolean {
        if (timeScope != scope) return false
        return when (scope) {
            TaskTimeScope.today -> startTime.isSameDay(date)
            TaskTimeScope.week -> if (scopeStartDate != null && scopeEndDate != null) date >= scopeStartDate && date <= scopeEndDate else startTime.isSameDay(date)
            TaskTimeScope.month -> if (scopeStartDate != null && scopeEndDate != null) date >= scopeStartDate && date <= scopeEndDate else startTime.isSameMonth(date)
            TaskTimeScope.year -> if (scopeStartDate != null && scopeEndDate != null) date >= scopeStartDate && date <= scopeEndDate else startTime.isSameYear(date)
            TaskTimeScope.longTerm, TaskTimeScope.inbox, TaskTimeScope.all -> true
        }
    }

    val completionProgress: Double
        get() {
            if (subtasks.isEmpty()) {
                return if (completions[now().startOfDay()]?.isCompleted == true) 1.0 else 0.0
            }
            return subtasks.count { it.isCompleted }.toDouble() / subtasks.size
        }

    val formattedTrackedTime: String get() = formatHoursMinutes(totalTrackedTime)
    val hasRecentTracking: Boolean get() = lastTrackedDate?.isToday() == true

    fun streakForDate(date: Date): Int {
        val recurrence = recurrence ?: return 0
        var current = date.startOfDay()
        if (current > now().startOfDay()) return 0
        var streak = 0
        var iteration = 0
        while (iteration < 1000) {
            if (current < startTime.startOfDay()) break
            val end = recurrence.endDate
            if (end != null && current > end) break
            if (shouldCheckDate(current, recurrence)) {
                if (completions[current]?.isCompleted == true) streak++ else break
            }
            current = current.addingDays(-1)
            iteration++
        }
        return streak
    }

    private fun shouldCheckDate(date: Date, recurrence: Recurrence): Boolean = when (val type = recurrence.type) {
        RecurrenceType.Daily -> true
        is RecurrenceType.Weekly -> type.days.contains(date.weekday)
        is RecurrenceType.Monthly -> type.days.contains(date.dayOfMonth)
        is RecurrenceType.MonthlyOrdinal, RecurrenceType.Yearly -> recurrence.shouldOccurOn(date)
    }

    val currentStreak: Int get() = streakForDate(now())

    fun hasRatings(date: Date): Boolean = completions[date.startOfDay()]?.hasRatings == true
    fun actualDuration(date: Date): Double? = completions[date.startOfDay()]?.actualDuration
    fun formattedActualDuration(date: Date): String? = completions[date.startOfDay()]?.formattedActualDuration
    fun difficultyRating(date: Date): Int? = completions[date.startOfDay()]?.difficultyRating
    fun qualityRating(date: Date): Int? = completions[date.startOfDay()]?.qualityRating

    /** At least 2 completions with ratings. */
    val hasHistoricalRatings: Boolean
        get() = completions.values.count { it.qualityRating != null || it.difficultyRating != null } >= 2

    fun completionKey(date: Date): Date {
        // Recurring tasks: every occurrence keeps its own state.
        if (recurrence != null) return date.startOfDay()
        return when (timeScope) {
            TaskTimeScope.today -> date.startOfDay()
            TaskTimeScope.week -> (scopeStartDate ?: date).startOfWeek()
            TaskTimeScope.month -> (scopeStartDate ?: date).startOfMonth()
            TaskTimeScope.year -> (scopeStartDate ?: date).startOfYear()
            TaskTimeScope.longTerm, TaskTimeScope.inbox, TaskTimeScope.all -> startTime.startOfDay()
        }
    }

    fun occurs(date: Date): Boolean {
        // Undated inbox items never fall on a day: their startTime is only the creation time.
        if (timeScope == TaskTimeScope.inbox) return false
        return recurrence?.shouldOccurOn(date) ?: startTime.isSameDay(date)
    }

    fun occurrenceDate(day: Date): Date {
        if (!hasSpecificTime) return day.startOfDay()
        var hour = startTime.hour
        var minute = startTime.minute
        val recurrence = recurrence
        if (recurrence != null) {
            when (val type = recurrence.type) {
                is RecurrenceType.Weekly -> recurrence.weekdayTimeOverrides?.firstOrNull { it.weekday == day.weekday }?.let {
                    hour = it.hour; minute = it.minute
                }
                is RecurrenceType.Monthly -> recurrence.monthDayTimeOverrides?.firstOrNull { it.day == day.dayOfMonth }?.let {
                    hour = it.hour; minute = it.minute
                }
                is RecurrenceType.MonthlyOrdinal -> recurrence.monthOrdinalTimeOverrides?.let { overrides ->
                    val weekday = day.weekday
                    val dayNumber = day.dayOfMonth
                    var ordinal = (dayNumber - 1) / 7 + 1
                    if (type.patterns.any { it.ordinal == -1 && it.weekday == weekday }) {
                        val lastDay = day.daysInMonth
                        for (offset in 0 until 7) {
                            val check = lastDay - offset
                            if (check < 1) break
                            if (day.withDayOfMonth(check).weekday == weekday) {
                                if (dayNumber == check) ordinal = -1
                                break
                            }
                        }
                    }
                    overrides.firstOrNull { it.weekday == weekday && it.ordinal == ordinal }?.let {
                        hour = it.hour; minute = it.minute
                    }
                }
                RecurrenceType.Yearly -> recurrence.yearlyTimeOverride?.let { hour = it.hour; minute = it.minute }
                RecurrenceType.Daily -> Unit
            }
        }
        return day.withTime(hour, minute)
    }

    fun occursInWeek(weekStart: Date): Boolean {
        val recurrence = recurrence ?: run {
            if (scopeStartDate != null && scopeEndDate != null) {
                return scopeStartDate.isSameDay(weekStart) && scopeEndDate.isSameDay(weekStart.addingDays(6))
            }
            return startTime.isSameDay(weekStart)
        }
        val anchor = recurrence.startDate.startOfWeek()
        val target = weekStart.startOfWeek()
        if (target < anchor) return false
        val end = recurrence.endDate
        if (end != null && target > end.startOfWeek()) return false
        val ordinals = recurrence.weekSelectedOrdinals
        if (!ordinals.isNullOrEmpty()) {
            if (ordinals.contains(-1) && target.addingDays(7).month != target.month) return true
            return ordinals.contains(target.weekOfMonth)
        }
        val weeks = weeksBetween(anchor, target)
        if (weeks >= 0) {
            val k = recurrence.weekModuloK
            if (k != null && k > 1 && weeks % k != (recurrence.weekModuloOffset ?: 0).toLong()) return false
            val interval = recurrence.weekInterval
            if (interval != null && interval > 1 && weeks % interval != 0L) return false
        }
        if (recurrence.weekInterval != null || recurrence.weekModuloK != null) return true
        var day = target
        repeat(7) {
            if (recurrence.shouldOccurOn(day)) return true
            day = day.addingDays(1)
        }
        return false
    }

    fun occursInMonth(monthStart: Date): Boolean {
        val recurrence = recurrence ?: return (scopeStartDate ?: startTime).isSameMonth(monthStart)
        val anchor = recurrence.startDate.startOfMonth()
        val target = monthStart.startOfMonth()
        if (target < anchor) return false
        val end = recurrence.endDate
        if (end != null && target > end.startOfMonth()) return false
        val months = monthsBetween(anchor, target)
        val interval = recurrence.monthInterval
        if (months >= 0 && interval != null && interval > 1 && months % interval != 0L) return false
        val allowed = recurrence.monthSelectedMonths
        if (!allowed.isNullOrEmpty() && !allowed.contains(target.month)) return false
        var day = target
        val until = target.addingMonths(1)
        while (day < until) {
            if (recurrence.shouldOccurOn(day)) return true
            day = day.addingDays(1)
        }
        return false
    }

    fun occursInYear(yearStart: Date): Boolean {
        val recurrence = recurrence ?: return (scopeStartDate ?: startTime).isSameYear(yearStart)
        val anchor = recurrence.startDate.startOfYear()
        val target = yearStart.startOfYear()
        if (target < anchor) return false
        val end = recurrence.endDate
        if (end != null && target > end.startOfYear()) return false
        val years = yearsBetween(anchor, target)
        if (years >= 0) {
            val k = recurrence.yearModuloK
            if (k != null && k > 1 && years % k != (recurrence.yearModuloOffset ?: 0).toLong()) return false
            val interval = recurrence.yearInterval
            if (interval != null && interval > 1 && years % interval != 0L) return false
        }
        var day = target
        val until = target.addingYears(1)
        while (day < until) {
            if (recurrence.shouldOccurOn(day)) return true
            day = day.addingDays(1)
        }
        return false
    }
}

// MARK: - Recurrence

sealed class RecurrenceType {
    data object Daily : RecurrenceType()
    data class Weekly(val days: Set<Int>) : RecurrenceType()
    data class Monthly(val days: Set<Int>) : RecurrenceType()
    data class MonthlyOrdinal(val patterns: Set<OrdinalPattern>) : RecurrenceType()
    data object Yearly : RecurrenceType()
}

/** Written as Swift writes an enum with associated values: `{"weekly":{"days":[2,3]}}`. */
object RecurrenceTypeSerializer : KSerializer<RecurrenceType> {
    override val descriptor: SerialDescriptor = buildClassSerialDescriptor("RecurrenceType")

    override fun serialize(encoder: Encoder, value: RecurrenceType) {
        val json = encoder as JsonEncoder
        fun ints(values: Set<Int>) = kotlinx.serialization.json.JsonArray(values.map { kotlinx.serialization.json.JsonPrimitive(it) })
        json.encodeJsonElement(buildJsonObject {
            when (value) {
                RecurrenceType.Daily -> putJsonObject("daily") {}
                is RecurrenceType.Weekly -> putJsonObject("weekly") { put("days", ints(value.days)) }
                is RecurrenceType.Monthly -> putJsonObject("monthly") { put("days", ints(value.days)) }
                is RecurrenceType.MonthlyOrdinal -> putJsonObject("monthlyOrdinal") {
                    put("patterns", kotlinx.serialization.json.JsonArray(value.patterns.map {
                        AppJson.encodeToJsonElement(OrdinalPattern.serializer(), it)
                    }))
                }
                RecurrenceType.Yearly -> putJsonObject("yearly") {}
            }
        })
    }

    override fun deserialize(decoder: Decoder): RecurrenceType {
        val root = (decoder as JsonDecoder).decodeJsonElement() as JsonObject
        val key = root.keys.firstOrNull() ?: return RecurrenceType.Daily
        val body = root[key] as? JsonObject
        fun ints(name: String): Set<Int> = (body?.get(name) as? kotlinx.serialization.json.JsonArray)
            ?.mapNotNull { (it as? kotlinx.serialization.json.JsonPrimitive)?.content?.toIntOrNull() }?.toSet() ?: emptySet()
        return when (key) {
            "daily" -> RecurrenceType.Daily
            "weekly" -> RecurrenceType.Weekly(ints("days"))
            "monthly" -> RecurrenceType.Monthly(ints("days"))
            "monthlyOrdinal" -> RecurrenceType.MonthlyOrdinal(
                (body?.get("patterns") as? kotlinx.serialization.json.JsonArray)
                    ?.map { AppJson.decodeFromJsonElement(OrdinalPattern.serializer(), it) }?.toSet() ?: emptySet()
            )
            else -> RecurrenceType.Yearly
        }
    }
}

@Serializable
data class OrdinalPattern(
    /** 1 = first … 4 = fourth, -1 = last */
    val ordinal: Int,
    /** 1 = Sunday, 2 = Monday, … */
    val weekday: Int,
) {
    val displayText: String
        get() {
            val ordinalText = when (ordinal) {
                1 -> "first".localized
                2 -> "second".localized
                3 -> "third".localized
                4 -> "fourth".localized
                -1 -> "last".localized
                else -> "${ordinal}th"
            }
            val weekdayText = when (weekday) {
                1 -> "sunday".localized
                2 -> "monday".localized
                3 -> "tuesday".localized
                4 -> "wednesday".localized
                5 -> "thursday".localized
                6 -> "friday".localized
                7 -> "saturday".localized
                else -> "Day"
            }
            return "$ordinalText $weekdayText"
        }
}

@Serializable data class WeekdayTimeOverride(val weekday: Int, val hour: Int, val minute: Int)
@Serializable data class MonthDayTimeOverride(val day: Int, val hour: Int, val minute: Int)
@Serializable data class MonthOrdinalTimeOverride(val ordinal: Int, val weekday: Int, val hour: Int, val minute: Int)
@Serializable data class YearlyTimeOverride(val hour: Int, val minute: Int)

@Serializable
data class Recurrence(
    @Serializable(with = RecurrenceTypeSerializer::class)
    val type: RecurrenceType,
    val startDate: Date,
    val endDate: Date? = null,
    val trackInStatistics: Boolean = true,
    val dayInterval: Int? = null,
    val weekInterval: Int? = null,
    val weekModuloK: Int? = null,
    val weekModuloOffset: Int? = null,
    /** 1..5 and -1 for last */
    val weekSelectedOrdinals: Set<Int>? = null,
    val weekdayTimeOverrides: List<WeekdayTimeOverride>? = null,
    val monthDayTimeOverrides: List<MonthDayTimeOverride>? = null,
    val monthOrdinalTimeOverrides: List<MonthOrdinalTimeOverride>? = null,
    val yearlyTimeOverride: YearlyTimeOverride? = null,
    val monthInterval: Int? = null,
    /** 1..12 */
    val monthSelectedMonths: Set<Int>? = null,
    val yearInterval: Int? = null,
    val yearModuloK: Int? = null,
    val yearModuloOffset: Int? = null,
    val postponedOccurrences: Map<String, Date>? = null,
) {
    fun postponingOccurrence(from: Date, to: Date): Recurrence =
        copy(postponedOccurrences = (postponedOccurrences ?: emptyMap()) + (dayKey(from.startOfDay()) to to))

    fun shouldOccurOn(date: Date): Boolean {
        val targetDay = date.startOfDay()
        val postponed = postponedOccurrences
        if (!postponed.isNullOrEmpty()) {
            // Postponed away from this day: it no longer occurs here.
            if (postponed.containsKey(dayKey(targetDay))) return false
            // Postponed to this day: it occurs here.
            if (postponed.values.any { it.isSameDay(date) }) return true
        }
        val recurrenceStart = startDate.startOfDay()
        if (targetDay < recurrenceStart) return false
        val end = endDate
        if (end != null && targetDay > end.startOfDay()) return false

        return when (val type = type) {
            RecurrenceType.Daily -> {
                val interval = dayInterval
                if (interval != null && interval > 1) daysBetween(recurrenceStart, targetDay) % interval == 0L else true
            }
            is RecurrenceType.Weekly -> passesWeekLevelGating(targetDay) && type.days.contains(date.weekday)
            is RecurrenceType.Monthly -> passesMonthLevelGating(targetDay) && type.days.contains(date.dayOfMonth)
            is RecurrenceType.MonthlyOrdinal -> passesMonthLevelGating(targetDay) && type.patterns.any { matchesOrdinalPattern(date, it) }
            RecurrenceType.Yearly -> passesYearLevelGating(targetDay) && startDate.month == date.month && startDate.dayOfMonth == date.dayOfMonth
        }
    }

    private fun matchesOrdinalPattern(date: Date, pattern: OrdinalPattern): Boolean {
        if (date.weekday != pattern.weekday) return false
        val day = date.dayOfMonth
        if (pattern.ordinal == -1) {
            val lastDay = date.daysInMonth
            for (offset in 0 until 7) {
                val check = lastDay - offset
                if (check < 1) break
                if (date.withDayOfMonth(check).weekday == pattern.weekday) return day == check
            }
            return false
        }
        return (day - 1) / 7 + 1 == pattern.ordinal
    }

    private fun passesWeekLevelGating(date: Date): Boolean {
        val weeks = weeksBetween(startDate.startOfWeek(), date.startOfWeek())
        if (weeks < 0) return false
        val k = weekModuloK
        if (k != null && k > 1 && weeks % k != (weekModuloOffset ?: 0).toLong()) return false
        val interval = weekInterval
        if (interval != null && interval > 1 && weeks % interval != 0L) return false
        return true
    }

    private fun passesMonthLevelGating(date: Date): Boolean {
        val months = monthsBetween(startDate.startOfMonth(), date.startOfMonth())
        val interval = monthInterval
        if (months >= 0 && interval != null && interval > 1 && months % interval != 0L) return false
        val allowed = monthSelectedMonths
        if (!allowed.isNullOrEmpty() && !allowed.contains(date.month)) return false
        return true
    }

    private fun passesYearLevelGating(date: Date): Boolean {
        val years = yearsBetween(startDate.startOfYear(), date.startOfYear())
        if (years >= 0) {
            val k = yearModuloK
            if (k != null && k > 1 && years % k != (yearModuloOffset ?: 0).toLong()) return false
            val interval = yearInterval
            if (interval != null && interval > 1 && years % interval != 0L) return false
        }
        return true
    }

    companion object {
        fun dayKey(day: Date): String = day.format("yyyy-MM-dd", java.util.Locale.ROOT)
    }
}

// MARK: - Order chosen by hand (drag and drop)

@Serializable
data class TaskListOrder(
    val listKey: String,
    val taskIds: List<UUID>,
    val lastModified: Date,
) {
    companion object {
        /** Stable key of a list. Null where the order can't be changed. */
        fun listKey(scope: TaskTimeScope, date: Date): String? {
            val periodStart = when (scope) {
                TaskTimeScope.today -> date.startOfDay()
                TaskTimeScope.week -> date.startOfWeek()
                TaskTimeScope.month -> date.startOfMonth()
                TaskTimeScope.year -> date.startOfYear()
                TaskTimeScope.longTerm -> return "longTerm"
                TaskTimeScope.inbox -> return "inbox"
                TaskTimeScope.all -> return null
            }
            return "${scope.rawValue}-" + periodStart.format("yyyy-MM-dd", java.util.Locale.ROOT)
        }

        /** Applies the saved order; without one, the latest order of the same kind of list. Tasks never moved go last. */
        fun sorted(tasks: List<TodoTask>, orders: Map<String, TaskListOrder>, listKey: String): List<TodoTask> {
            val order = orders[listKey] ?: latest(orders, listKey) ?: return tasks
            val rank = HashMap<UUID, Int>()
            order.taskIds.forEachIndexed { position, id -> rank.putIfAbsent(id, position) }
            val placed = tasks.filter { rank[it.id] != null }.sortedBy { rank[it.id] ?: 0 }
            val others = tasks.filter { rank[it.id] == null }
            return placed + others
        }

        private fun latest(orders: Map<String, TaskListOrder>, listKey: String): TaskListOrder? {
            val dash = listKey.indexOf('-')
            if (dash < 0) return null
            val kind = listKey.substring(0, dash + 1)
            return orders.values.filter { it.listKey.startsWith(kind) }.maxByOrNull { it.lastModified }
        }
    }
}

// MARK: - Task rules shared with the Apple Watch on iOS (`WatchTaskRules`)

object TaskRules {
    fun isDayTask(task: TodoTask, day: Date): Boolean {
        if (task.timeScope != TaskTimeScope.today) return false
        return if (task.recurrence != null) task.occurs(day) else task.startTime.isSameDay(day)
    }

    fun carriedOverStart(task: TodoTask, today: Date = now()): Date? {
        if (!task.autoCarryOver || task.recurrence != null || task.timeScope != TaskTimeScope.today) return null
        val todayStart = today.startOfDay()
        var start = task.startTime
        var moved = false
        while (start.startOfDay() < todayStart) {
            if (task.completions[start.startOfDay()]?.isCompleted == true) break
            start = start.addingDays(1)
            moved = true
        }
        return if (moved) start else null
    }

    /** A week, month or year goal with "Rinvia automaticamente" whose period is over and wasn't completed. */
    fun carriedOverToCurrentPeriod(task: TodoTask, todayStart: Date): TodoTask? {
        if (!task.autoCarryOver || task.recurrence != null) return null
        val scopeStart = task.scopeStartDate ?: return null
        val scopeEnd = task.scopeEndDate ?: return null
        if (scopeEnd.startOfDay() >= todayStart) return null
        if (task.completions[task.completionKey(scopeStart)]?.isCompleted == true) return null
        val newStart: Date
        val newEnd: Date
        when (task.timeScope) {
            TaskTimeScope.week -> {
                newStart = todayStart.startOfWeek()
                newEnd = newStart.addingDays(6)
            }
            TaskTimeScope.month -> {
                newStart = todayStart.startOfMonth()
                newEnd = todayStart.endOfMonth()
            }
            TaskTimeScope.year -> {
                newStart = todayStart.startOfYear()
                newEnd = todayStart.endOfYear()
            }
            else -> return null
        }
        val startTime = when {
            task.hasSpecificDay && task.hasSpecificTime -> todayStart.withTime(task.startTime.hour, task.startTime.minute)
            task.hasSpecificDay -> todayStart
            else -> newStart
        }
        return task.copy(scopeStartDate = newStart, scopeEndDate = newEnd, startTime = startTime, lastModifiedDate = now())
    }

    /** The order the home builds its lists in (`TimelineViewModel.refreshTasks`). */
    fun listOrder(tasks: List<TodoTask>): List<TodoTask> = tasks.sortedWith(
        compareBy<TodoTask> { it.startTime }
            .thenBy { it.creationDate }
            .thenBy { it.name.lowercase() }
            .thenBy { it.id.uuidString }
    )

    fun byTimeOfDay(tasks: List<TodoTask>, ascending: Boolean): List<TodoTask> {
        val comparator = compareBy<TodoTask> { it.startTime.hour * 60 + it.startTime.minute }
            .thenBy { it.creationDate }
            .thenBy { it.name.lowercase() }
            .thenBy { it.id.uuidString }
        return tasks.sortedWith(if (ascending) comparator else comparator.reversed())
    }
}
