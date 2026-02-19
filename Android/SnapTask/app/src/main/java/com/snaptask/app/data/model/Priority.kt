package com.snaptask.app.data.model

import androidx.compose.ui.graphics.Color
import com.snaptask.app.ui.theme.PriorityHigh
import com.snaptask.app.ui.theme.PriorityLow
import com.snaptask.app.ui.theme.PriorityMedium
import com.snaptask.app.ui.theme.PriorityNone

/**
 * Task priority levels, matching iOS Priority enum.
 */
enum class Priority(val displayName: String, val iconName: String, val color: Color) {
    LOW("Low", "arrow_downward", PriorityLow),
    MEDIUM("Medium", "remove", PriorityMedium),
    HIGH("High", "arrow_upward", PriorityHigh);

    companion object {
        fun fromString(value: String): Priority = when (value.lowercase()) {
            "low" -> LOW
            "high" -> HIGH
            else -> MEDIUM
        }
    }
}
