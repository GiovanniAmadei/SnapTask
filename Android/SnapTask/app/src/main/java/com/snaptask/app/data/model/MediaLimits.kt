package com.snaptask.app.data.model

/**
 * Centralized media limits for tasks and journal.
 * Faithful port of iOS MediaLimits.
 */
object MediaLimits {
    // ---- Task Limits ----
    const val maxPhotosPerTask: Int = 3
    const val maxVoiceMemosPerTask: Int = 3

    // ---- Journal Limits ----
    const val maxPhotosPerJournal: Int = 5
    const val maxVoiceMemosPerJournal: Int = 3

    // ---- Common Limits ----
    const val maxVoiceMemoDurationSeconds: Double = 5.0 * 60.0

    fun canAddPhoto(currentCount: Int): Boolean = currentCount < maxPhotosPerTask
    fun canAddVoiceMemo(currentCount: Int): Boolean = currentCount < maxVoiceMemosPerTask

    fun remainingPhotos(currentCount: Int): Int = kotlin.math.max(0, maxPhotosPerTask - currentCount)
    fun remainingVoiceMemos(currentCount: Int): Int = kotlin.math.max(0, maxVoiceMemosPerTask - currentCount)

    fun canAddJournalPhoto(currentCount: Int): Boolean = currentCount < maxPhotosPerJournal
    fun canAddJournalVoiceMemo(currentCount: Int): Boolean = currentCount < maxVoiceMemosPerJournal

    fun remainingJournalPhotos(currentCount: Int): Int = kotlin.math.max(0, maxPhotosPerJournal - currentCount)
    fun remainingJournalVoiceMemos(currentCount: Int): Int = kotlin.math.max(0, maxVoiceMemosPerJournal - currentCount)

    fun formattedMaxDurationMinutes(): String = "${(maxVoiceMemoDurationSeconds / 60.0).toInt()} min"
}
