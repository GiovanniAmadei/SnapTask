package com.snaptask.app.ui.focus

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.snaptask.app.data.model.TrackingSession

/**
 * Tracking session completion screen.
 * Port of iOS TrackingCompletionView.swift.
 */
@Composable
fun TrackingCompletionScreen(
    session: TrackingSession,
    onSave: () -> Unit,
    onDiscard: () -> Unit,
    onContinue: () -> Unit,
) {
    var notes by remember { mutableStateOf("") }

    val effectiveTime = session.effectiveWorkTime
    val hours = (effectiveTime / 3600).toInt()
    val minutes = ((effectiveTime % 3600) / 60).toInt()
    val durationText = if (hours > 0) "${hours}h ${minutes}m" else "${minutes}m"

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(modifier = Modifier.height(16.dp))

        // Success icon
        Icon(
            Icons.Filled.CheckCircle,
            contentDescription = null,
            modifier = Modifier.size(64.dp),
            tint = Color(0xFF22C55E),
        )

        Spacer(modifier = Modifier.height(16.dp))

        Text(
            text = "Session Complete",
            style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = "Tracked $durationText",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        Spacer(modifier = Modifier.height(24.dp))

        // Session details
        Card(
            shape = RoundedCornerShape(12.dp),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surfaceVariant,
            ),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Column(
                modifier = Modifier.padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                CompletionDetailRow(
                    "Task",
                    session.taskName ?: "General Focus",
                )
                CompletionDetailRow(
                    "Mode",
                    session.mode.displayName,
                )
                CompletionDetailRow(
                    "Effective Time",
                    durationText,
                )
                if (session.pausedDuration > 0) {
                    val pausedMin = (session.pausedDuration / 60).toInt()
                    CompletionDetailRow(
                        "Paused Time",
                        "${pausedMin}m",
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Notes
        Text(
            "Notes (optional)",
            style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.SemiBold),
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(modifier = Modifier.height(8.dp))
        OutlinedTextField(
            value = notes,
            onValueChange = { notes = it },
            placeholder = { Text("Add notes about this session...") },
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 80.dp),
            maxLines = 4,
            shape = RoundedCornerShape(12.dp),
        )

        Spacer(modifier = Modifier.height(24.dp))

        // Buttons
        Button(
            onClick = onSave,
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp),
            shape = RoundedCornerShape(12.dp),
            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF22C55E)),
        ) {
            Text("Save Session", fontWeight = FontWeight.Bold, color = Color.White)
        }

        Spacer(modifier = Modifier.height(8.dp))

        OutlinedButton(
            onClick = onContinue,
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp),
            shape = RoundedCornerShape(12.dp),
        ) {
            Text("Continue Session", fontWeight = FontWeight.Bold)
        }

        Spacer(modifier = Modifier.height(8.dp))

        TextButton(onClick = onDiscard) {
            Text("Discard Session", color = MaterialTheme.colorScheme.error)
        }

        Spacer(modifier = Modifier.height(16.dp))
    }
}

@Composable
private fun CompletionDetailRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            label,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            value,
            style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.SemiBold),
        )
    }
}
