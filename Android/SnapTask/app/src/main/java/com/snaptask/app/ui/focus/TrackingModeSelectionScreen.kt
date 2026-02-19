package com.snaptask.app.ui.focus

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.snaptask.app.data.model.TrackingMode

/**
 * Tracking Mode Selection matching iOS TrackingModeSelectionView.
 * Choose between Stopwatch and Pomodoro modes.
 */
@Composable
fun TrackingModeSelectionScreen(
    currentMode: TrackingMode,
    onModeSelected: (TrackingMode) -> Unit,
    onDismiss: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(24.dp),
    ) {
        // Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                "Tracking Mode",
                style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
            )
            TextButton(onClick = onDismiss) {
                Text("Done", fontWeight = FontWeight.SemiBold)
            }
        }

        Spacer(modifier = Modifier.height(8.dp))
        Text(
            "Choose how you'd like to track your focus sessions",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        Spacer(modifier = Modifier.height(20.dp))

        // Mode cards
        TrackingModeCard(
            title = "Stopwatch",
            description = "Track time freely without constraints. Start and stop whenever you want.",
            icon = Icons.Filled.Timer,
            color = Color(0xFF4CAF50),
            isSelected = currentMode == TrackingMode.STOPWATCH,
            features = listOf("Free-form timing", "No breaks needed", "Simple start/stop"),
            onClick = {
                onModeSelected(TrackingMode.STOPWATCH)
                onDismiss()
            },
        )

        Spacer(modifier = Modifier.height(12.dp))

        TrackingModeCard(
            title = "Pomodoro",
            description = "Work in focused intervals with regular breaks. The classic productivity method.",
            icon = Icons.Filled.AvTimer,
            color = Color(0xFFFF5722),
            isSelected = currentMode == TrackingMode.POMODORO,
            features = listOf("25 min work sessions", "5 min short breaks", "15 min long breaks"),
            onClick = {
                onModeSelected(TrackingMode.POMODORO)
                onDismiss()
            },
        )
    }
}

@Composable
private fun TrackingModeCard(
    title: String,
    description: String,
    icon: ImageVector,
    color: Color,
    isSelected: Boolean,
    features: List<String>,
    onClick: () -> Unit,
) {
    val borderColor = if (isSelected) color else Color.Transparent
    val bgColor = if (isSelected) color.copy(alpha = 0.06f)
    else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)

    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = bgColor),
        modifier = Modifier
            .fillMaxWidth()
            .border(
                width = if (isSelected) 2.dp else 0.dp,
                color = borderColor,
                shape = RoundedCornerShape(16.dp),
            )
            .clickable(onClick = onClick),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(18.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(color.copy(alpha = 0.15f)),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(24.dp))
                }
                Spacer(modifier = Modifier.width(14.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        title,
                        style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
                    )
                    Text(
                        description,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                if (isSelected) {
                    Icon(
                        Icons.Filled.CheckCircle,
                        contentDescription = "Selected",
                        tint = color,
                        modifier = Modifier.size(22.dp),
                    )
                }
            }

            Spacer(modifier = Modifier.height(12.dp))
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))
            Spacer(modifier = Modifier.height(10.dp))

            features.forEach { feature ->
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.padding(vertical = 3.dp),
                ) {
                    Icon(
                        Icons.Filled.Check,
                        contentDescription = null,
                        tint = color,
                        modifier = Modifier.size(14.dp),
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        feature,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}
