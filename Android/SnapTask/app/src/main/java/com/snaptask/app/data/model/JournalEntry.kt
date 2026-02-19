package com.snaptask.app.data.model

import java.util.Date
import java.util.UUID

/**
 * Mood rating for journal entries.
 */
enum class Mood(val value: Int, val emoji: String, val displayName: String) {
    TERRIBLE(1, "😢", "Terrible"),
    BAD(2, "😟", "Bad"),
    OKAY(3, "😐", "Okay"),
    GOOD(4, "🙂", "Good"),
    GREAT(5, "😄", "Great");

    companion object {
        fun fromValue(value: Int): Mood = entries.find { it.value == value } ?: OKAY
    }
}

/**
 * Journal entry, matching iOS JournalEntry model.
 */
data class JournalEntry(
    val id: UUID = UUID.randomUUID(),
    val date: Date = Date(),
    val mood: Mood? = null,
    val title: String? = null,
    val content: String? = null,
    val photos: List<TaskPhoto> = emptyList(),
    val voiceMemos: List<TaskVoiceMemo> = emptyList(),
    val tags: List<String> = emptyList(),
    val gratitude: List<String> = emptyList(),
    val creationDate: Date = Date(),
    val lastModifiedDate: Date = Date(),
) {
    val hasContent: Boolean
        get() = !content.isNullOrBlank() || photos.isNotEmpty() || voiceMemos.isNotEmpty()

    val displayDate: String
        get() {
            val formatter = java.text.SimpleDateFormat("EEEE, MMMM d, yyyy", java.util.Locale.getDefault())
            return formatter.format(date)
        }
}
