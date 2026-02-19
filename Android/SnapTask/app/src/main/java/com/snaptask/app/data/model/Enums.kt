package com.snaptask.app.data.model

/**
 * Time tracking mode, matching iOS TrackingMode enum.
 */
enum class TrackingMode(val displayName: String) {
    STOPWATCH("Simple Timer"),
    POMODORO("Pomodoro");

    companion object {
        fun fromString(value: String): TrackingMode = when (value.lowercase()) {
            "pomodoro" -> POMODORO
            else -> STOPWATCH
        }
    }
}

/**
 * Time scope for tasks, matching iOS TaskTimeScope enum.
 */
enum class TaskTimeScope(val value: String, val displayName: String, val icon: String, val scopeColor: Long) {
    TODAY("today", "Today", "today", 0xFF4CAF50),
    WEEK("week", "This Week", "date_range", 0xFF2196F3),
    MONTH("month", "This Month", "calendar_month", 0xFF9C27B0),
    YEAR("year", "This Year", "calendar_today", 0xFFFF9800),
    LONG_TERM("longTerm", "Long Term", "flag", 0xFFE91E63),
    ALL("all", "All Time", "all_inclusive", 0xFF607D8B);

    companion object {
        fun fromString(value: String): TaskTimeScope = entries.find { it.value == value } ?: TODAY
    }
}

/**
 * View mode for the timeline screen, matching iOS TimelineViewMode.
 */
enum class TimelineViewMode(val icon: String) {
    LIST("view_list"),
    TIMELINE("schedule");
}

/**
 * Organization mode for task grouping, matching iOS TimelineOrganization.
 */
enum class TimelineOrganization(val displayName: String, val icon: String) {
    NONE("Default", "sort"),
    TIME("By Time", "schedule"),
    CATEGORY("By Category", "label"),
    PRIORITY("By Priority", "flag"),
    EISENHOWER("Eisenhower", "grid_view");
}

/**
 * Time sort order for task sorting, matching iOS TimeSortOrder.
 */
enum class TimeSortOrder(val displayName: String) {
    ASCENDING("Early to Late"),
    DESCENDING("Late to Early");
}

/**
 * Represents organized tasks with either a flat list or grouped sections.
 */
sealed class OrganizedTasks {
    data class Single(val tasks: List<TodoTask>) : OrganizedTasks()
    data class Sections(val sections: List<TaskSection>) : OrganizedTasks()
}

/**
 * A section of tasks for organized display.
 */
data class TaskSection(
    val id: String = java.util.UUID.randomUUID().toString(),
    val title: String,
    val icon: String? = null,
    val color: String? = null,
    val tasks: List<TodoTask>,
)

/**
 * Device type for tracking sessions, adapted from iOS DeviceType for Android.
 */
enum class DeviceType(val displayName: String, val iconName: String) {
    PHONE("Phone", "smartphone"),
    TABLET("Tablet", "tablet"),
    WATCH("Watch", "watch"),
    UNKNOWN("Unknown", "device_unknown");

    companion object {
        fun fromString(value: String): DeviceType = when (value.lowercase()) {
            "phone", "iphone" -> PHONE
            "tablet", "ipad" -> TABLET
            "watch", "apple watch" -> WATCH
            else -> UNKNOWN
        }
    }
}
