package com.snaptask.app.data.model

import java.util.Date
import java.util.UUID

/**
 * Records the completion state of a task for a specific date.
 * Matching iOS TaskCompletion struct.
 */
data class TaskCompletion(
    val isCompleted: Boolean = false,
    val completedSubtasks: Set<UUID> = emptySet(),
    val actualDuration: Double? = null, // seconds
    val difficultyRating: Int? = null, // 1-10 scale
    val qualityRating: Int? = null, // 1-10 scale
    val completionDate: Date? = null,
    val notes: String? = null,
) {
    val hasRatings: Boolean
        get() = actualDuration != null || difficultyRating != null || qualityRating != null

    val hasPerformanceData: Boolean
        get() = hasRatings

    val formattedActualDuration: String?
        get() {
            val duration = actualDuration ?: return null
            val hours = (duration / 3600).toInt()
            val minutes = (duration % 3600 / 60).toInt()
            return if (hours > 0) "${hours}h ${minutes}m" else "${minutes}m"
        }
}
