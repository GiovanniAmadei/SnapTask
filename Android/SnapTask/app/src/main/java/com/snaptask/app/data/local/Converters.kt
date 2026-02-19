package com.snaptask.app.data.local

import androidx.room.TypeConverter
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import com.snaptask.app.data.model.*
import java.util.Date
import java.util.UUID

/**
 * Room type converters for complex types.
 */
class Converters {
    private val gson = Gson()

    // ---- Date ----
    @TypeConverter
    fun fromTimestamp(value: Long?): Date? = value?.let { Date(it) }

    @TypeConverter
    fun dateToTimestamp(date: Date?): Long? = date?.time

    // ---- UUID ----
    @TypeConverter
    fun fromUUID(uuid: UUID?): String? = uuid?.toString()

    @TypeConverter
    fun toUUID(value: String?): UUID? = value?.let { UUID.fromString(it) }

    // ---- Priority ----
    @TypeConverter
    fun fromPriority(priority: Priority): String = priority.name

    @TypeConverter
    fun toPriority(value: String): Priority =
        Priority.entries.find { it.name == value } ?: Priority.MEDIUM

    // ---- TaskTimeScope ----
    @TypeConverter
    fun fromTaskTimeScope(scope: TaskTimeScope): String = scope.value

    @TypeConverter
    fun toTaskTimeScope(value: String): TaskTimeScope = TaskTimeScope.fromString(value)

    // ---- TrackingMode ----
    @TypeConverter
    fun fromTrackingMode(mode: TrackingMode): String = mode.name

    @TypeConverter
    fun toTrackingMode(value: String): TrackingMode = TrackingMode.fromString(value)

    // ---- DeviceType ----
    @TypeConverter
    fun fromDeviceType(type: DeviceType): String = type.name

    @TypeConverter
    fun toDeviceType(value: String): DeviceType = DeviceType.fromString(value)

    // ---- Category ----
    @TypeConverter
    fun fromCategory(category: Category?): String? =
        category?.let { gson.toJson(it) }

    @TypeConverter
    fun toCategory(value: String?): Category? =
        value?.let { gson.fromJson(it, Category::class.java) }

    // ---- TaskLocation ----
    @TypeConverter
    fun fromTaskLocation(location: TaskLocation?): String? =
        location?.let { gson.toJson(it) }

    @TypeConverter
    fun toTaskLocation(value: String?): TaskLocation? =
        value?.let { gson.fromJson(it, TaskLocation::class.java) }

    // ---- Recurrence (JSON) ----
    @TypeConverter
    fun fromRecurrence(recurrence: Recurrence?): String? =
        recurrence?.let { gson.toJson(it) }

    @TypeConverter
    fun toRecurrence(value: String?): Recurrence? =
        value?.let { gson.fromJson(it, Recurrence::class.java) }

    // ---- PomodoroSettings ----
    @TypeConverter
    fun fromPomodoroSettings(settings: PomodoroSettings?): String? =
        settings?.let { gson.toJson(it) }

    @TypeConverter
    fun toPomodoroSettings(value: String?): PomodoroSettings? =
        value?.let { gson.fromJson(it, PomodoroSettings::class.java) }

    // ---- Map<Long, TaskCompletion> (completions) ----
    @TypeConverter
    fun fromCompletions(completions: Map<Long, TaskCompletion>): String =
        gson.toJson(completions)

    @TypeConverter
    fun toCompletions(value: String): Map<Long, TaskCompletion> {
        val type = object : TypeToken<Map<Long, TaskCompletion>>() {}.type
        return gson.fromJson(value, type) ?: emptyMap()
    }

    // ---- List<Subtask> ----
    @TypeConverter
    fun fromSubtasks(subtasks: List<Subtask>): String = gson.toJson(subtasks)

    @TypeConverter
    fun toSubtasks(value: String): List<Subtask> {
        val type = object : TypeToken<List<Subtask>>() {}.type
        return gson.fromJson(value, type) ?: emptyList()
    }

    // ---- List<Date> ----
    @TypeConverter
    fun fromDateList(dates: List<Date>): String = gson.toJson(dates.map { it.time })

    @TypeConverter
    fun toDateList(value: String): List<Date> {
        val type = object : TypeToken<List<Long>>() {}.type
        val longs: List<Long> = gson.fromJson(value, type) ?: emptyList()
        return longs.map { Date(it) }
    }

    // ---- List<TaskPhoto> ----
    @TypeConverter
    fun fromPhotos(photos: List<TaskPhoto>): String = gson.toJson(photos)

    @TypeConverter
    fun toPhotos(value: String): List<TaskPhoto> {
        val type = object : TypeToken<List<TaskPhoto>>() {}.type
        return gson.fromJson(value, type) ?: emptyList()
    }

    // ---- List<TaskVoiceMemo> ----
    @TypeConverter
    fun fromVoiceMemos(memos: List<TaskVoiceMemo>): String = gson.toJson(memos)

    @TypeConverter
    fun toVoiceMemos(value: String): List<TaskVoiceMemo> {
        val type = object : TypeToken<List<TaskVoiceMemo>>() {}.type
        return gson.fromJson(value, type) ?: emptyList()
    }

    // ---- Mood ----
    @TypeConverter
    fun fromMood(mood: Mood?): Int? = mood?.value

    @TypeConverter
    fun toMood(value: Int?): Mood? = value?.let { Mood.fromValue(it) }

    // ---- List<String> ----
    @TypeConverter
    fun fromStringList(list: List<String>): String = gson.toJson(list)

    @TypeConverter
    fun toStringList(value: String): List<String> {
        val type = object : TypeToken<List<String>>() {}.type
        return gson.fromJson(value, type) ?: emptyList()
    }

    // ---- RewardFrequency ----
    @TypeConverter
    fun fromRewardFrequency(freq: RewardFrequency): String = freq.name

    @TypeConverter
    fun toRewardFrequency(value: String): RewardFrequency = RewardFrequency.fromString(value)

    // ---- FinanceEntryType ----
    @TypeConverter
    fun fromFinanceEntryType(type: FinanceEntryType): String = type.name

    @TypeConverter
    fun toFinanceEntryType(value: String): FinanceEntryType = FinanceEntryType.fromString(value)

    // ---- FinanceCategory ----
    @TypeConverter
    fun fromFinanceCategory(category: FinanceCategory): String = category.name

    @TypeConverter
    fun toFinanceCategory(value: String): FinanceCategory = FinanceCategory.fromString(value)

    // ---- SubscriptionFrequency ----
    @TypeConverter
    fun fromSubscriptionFrequency(freq: SubscriptionFrequency): String = freq.name

    @TypeConverter
    fun toSubscriptionFrequency(value: String): SubscriptionFrequency =
        SubscriptionFrequency.fromString(value)

    // ---- Set<UUID> ----
    @TypeConverter
    fun fromUUIDSet(set: Set<UUID>): String = gson.toJson(set.map { it.toString() })

    @TypeConverter
    fun toUUIDSet(value: String): Set<UUID> {
        val type = object : TypeToken<List<String>>() {}.type
        val strings: List<String> = gson.fromJson(value, type) ?: emptyList()
        return strings.mapNotNull { runCatching { UUID.fromString(it) }.getOrNull() }.toSet()
    }
}
