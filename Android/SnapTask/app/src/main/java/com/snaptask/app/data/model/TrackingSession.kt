package com.snaptask.app.data.model

import java.util.Date
import java.util.UUID

/**
 * Tracking session for time tracking, matching iOS TrackingSession struct.
 */
data class TrackingSession(
    val id: UUID = UUID.randomUUID(),
    val taskId: UUID? = null,
    val taskName: String? = null,
    val mode: TrackingMode = TrackingMode.STOPWATCH,
    val categoryId: UUID? = null,
    val categoryName: String? = null,
    val startTime: Date = Date(),
    val deviceType: DeviceType = DeviceType.PHONE,
    val deviceName: String = "Android",
    val creationDate: Date = Date(),
    val lastModifiedDate: Date = Date(),
    val isRunning: Boolean = false,
    val isPaused: Boolean = false,
    val elapsedTime: Double = 0.0, // seconds
    val totalDuration: Double = 0.0, // seconds
    val pausedDuration: Double = 0.0, // seconds
    val isCompleted: Boolean = false,
    val endTime: Date? = null,
    val notes: String? = null,
) {
    val effectiveWorkTime: Double
        get() = totalDuration - pausedDuration

    val isForSpecificTask: Boolean
        get() = taskId != null

    val deviceDisplayInfo: String
        get() = "${ deviceType.displayName } · $deviceName"
}
