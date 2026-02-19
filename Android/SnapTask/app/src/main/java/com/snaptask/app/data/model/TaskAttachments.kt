package com.snaptask.app.data.model

import java.util.UUID

/**
 * Photo attachment for a task, matching iOS TaskPhoto struct.
 */
data class TaskPhoto(
    val id: UUID = UUID.randomUUID(),
    val photoPath: String,
    val thumbnailPath: String,
    val createdAt: Long = System.currentTimeMillis(),
)

/**
 * Voice memo attachment for a task, matching iOS TaskVoiceMemo struct.
 */
data class TaskVoiceMemo(
    val id: UUID = UUID.randomUUID(),
    val audioPath: String,
    val duration: Double, // seconds
    val createdAt: Long = System.currentTimeMillis(),
    val name: String? = null,
) {
    val displayName: String
        get() = name ?: "Voice Memo"
}
