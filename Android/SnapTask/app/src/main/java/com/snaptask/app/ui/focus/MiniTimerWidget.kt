package com.snaptask.app.ui.focus

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Mini Timer Widget matching iOS MiniTimerWidget.
 * Compact floating timer display for active sessions.
 */
@Composable
fun MiniTimerWidget(
    elapsedSeconds: Long,
    isRunning: Boolean,
    taskName: String,
    isPomodoroMode: Boolean,
    onToggle: () -> Unit,
    onExpand: () -> Unit,
) {
    val hours = elapsedSeconds / 3600
    val minutes = (elapsedSeconds % 3600) / 60
    val seconds = elapsedSeconds % 60
    val timeString = if (hours > 0) {
        String.format("%d:%02d:%02d", hours, minutes, seconds)
    } else {
        String.format("%02d:%02d", minutes, seconds)
    }

    // Pulsing animation when running
    val infiniteTransition = rememberInfiniteTransition(label = "pulse")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = if (isRunning) 1.03f else 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(1000, easing = EaseInOutSine),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "pulse_scale",
    )

    val accentColor = if (isPomodoroMode) Color(0xFFFF5722) else Color(0xFF4CAF50)

    Card(
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface,
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 6.dp),
        modifier = Modifier
            .clickable(onClick = onExpand),
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // Indicator dot
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .clip(CircleShape)
                    .background(
                        if (isRunning) accentColor
                        else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.3f),
                    ),
            )
            Spacer(modifier = Modifier.width(10.dp))

            // Timer display
            Column {
                Text(
                    timeString,
                    style = MaterialTheme.typography.titleSmall.copy(
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp,
                    ),
                )
                Text(
                    taskName,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                )
            }

            Spacer(modifier = Modifier.width(12.dp))

            // Play/Pause button
            IconButton(
                onClick = onToggle,
                modifier = Modifier
                    .size(34.dp)
                    .clip(CircleShape)
                    .background(accentColor.copy(alpha = 0.15f)),
            ) {
                Icon(
                    if (isRunning) Icons.Filled.Pause else Icons.Filled.PlayArrow,
                    contentDescription = if (isRunning) "Pause" else "Play",
                    tint = accentColor,
                    modifier = Modifier.size(18.dp),
                )
            }
        }
    }
}
