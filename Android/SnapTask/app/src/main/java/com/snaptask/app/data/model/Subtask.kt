package com.snaptask.app.data.model

import java.util.UUID

/**
 * Subtask within a TodoTask, matching iOS Subtask struct.
 */
data class Subtask(
    val id: UUID = UUID.randomUUID(),
    val name: String,
    val isCompleted: Boolean = false,
)
