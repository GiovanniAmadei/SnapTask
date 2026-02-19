package com.snaptask.app.data.model

import java.util.UUID

/**
 * Task category, matching iOS Category struct.
 * Used as an embedded object in TodoTask, and also stored separately for management.
 */
data class Category(
    val id: UUID = UUID.randomUUID(),
    val name: String,
    val color: String, // Hex color string e.g. "#FF6366F1"
)
