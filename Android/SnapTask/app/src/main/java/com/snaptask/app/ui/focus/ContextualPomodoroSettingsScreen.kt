package com.snaptask.app.ui.focus

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

/**
 * Contextual Pomodoro Settings matching iOS ContextualPomodoroSettingsView.
 * Per-task pomodoro customization (work/break durations, rounds).
 */
@Composable
fun ContextualPomodoroSettingsScreen(
    workDuration: Int,
    shortBreakDuration: Int,
    longBreakDuration: Int,
    sessionsBeforeLongBreak: Int,
    autoStartBreaks: Boolean,
    autoStartWork: Boolean,
    onWorkDurationChanged: (Int) -> Unit,
    onShortBreakChanged: (Int) -> Unit,
    onLongBreakChanged: (Int) -> Unit,
    onSessionsBeforeLongBreakChanged: (Int) -> Unit,
    onAutoStartBreaksChanged: (Boolean) -> Unit,
    onAutoStartWorkChanged: (Boolean) -> Unit,
    onDismiss: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(24.dp),
    ) {
        // Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                "Pomodoro Settings",
                style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
            )
            TextButton(onClick = onDismiss) {
                Text("Done", fontWeight = FontWeight.SemiBold)
            }
        }

        Spacer(modifier = Modifier.height(8.dp))
        Text(
            "Customize pomodoro settings for this task",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        Spacer(modifier = Modifier.height(20.dp))

        // Duration settings
        Text(
            "DURATIONS",
            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(modifier = Modifier.height(8.dp))

        Card(
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
            ),
        ) {
            Column(modifier = Modifier.padding(4.dp)) {
                DurationSettingRow(
                    icon = Icons.Filled.WorkHistory,
                    label = "Work Duration",
                    value = workDuration,
                    unit = "min",
                    min = 5,
                    max = 90,
                    step = 5,
                    onValueChange = onWorkDurationChanged,
                )
                HorizontalDivider(
                    modifier = Modifier.padding(horizontal = 12.dp),
                    color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.3f),
                )
                DurationSettingRow(
                    icon = Icons.Filled.Coffee,
                    label = "Short Break",
                    value = shortBreakDuration,
                    unit = "min",
                    min = 1,
                    max = 30,
                    step = 1,
                    onValueChange = onShortBreakChanged,
                )
                HorizontalDivider(
                    modifier = Modifier.padding(horizontal = 12.dp),
                    color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.3f),
                )
                DurationSettingRow(
                    icon = Icons.Filled.Weekend,
                    label = "Long Break",
                    value = longBreakDuration,
                    unit = "min",
                    min = 5,
                    max = 60,
                    step = 5,
                    onValueChange = onLongBreakChanged,
                )
                HorizontalDivider(
                    modifier = Modifier.padding(horizontal = 12.dp),
                    color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.3f),
                )
                DurationSettingRow(
                    icon = Icons.Filled.Repeat,
                    label = "Sessions Before Long Break",
                    value = sessionsBeforeLongBreak,
                    unit = "",
                    min = 1,
                    max = 10,
                    step = 1,
                    onValueChange = onSessionsBeforeLongBreakChanged,
                )
            }
        }

        Spacer(modifier = Modifier.height(20.dp))

        // Auto-start settings
        Text(
            "AUTOMATION",
            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(modifier = Modifier.height(8.dp))

        Card(
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
            ),
        ) {
            Column(modifier = Modifier.padding(4.dp)) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(
                        Icons.Filled.PlayCircle,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(20.dp),
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            "Auto-start Breaks",
                            style = MaterialTheme.typography.bodyMedium,
                        )
                        Text(
                            "Automatically start breaks after work",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    Switch(
                        checked = autoStartBreaks,
                        onCheckedChange = onAutoStartBreaksChanged,
                    )
                }
                HorizontalDivider(
                    modifier = Modifier.padding(horizontal = 12.dp),
                    color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.3f),
                )
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(
                        Icons.Filled.SkipNext,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(20.dp),
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            "Auto-start Work",
                            style = MaterialTheme.typography.bodyMedium,
                        )
                        Text(
                            "Automatically start work after breaks",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    Switch(
                        checked = autoStartWork,
                        onCheckedChange = onAutoStartWorkChanged,
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(20.dp))

        // Reset to defaults
        OutlinedButton(
            onClick = {
                onWorkDurationChanged(25)
                onShortBreakChanged(5)
                onLongBreakChanged(15)
                onSessionsBeforeLongBreakChanged(4)
                onAutoStartBreaksChanged(false)
                onAutoStartWorkChanged(false)
            },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp),
        ) {
            Icon(Icons.Filled.RestartAlt, contentDescription = null, modifier = Modifier.size(18.dp))
            Spacer(modifier = Modifier.width(8.dp))
            Text("Reset to Defaults")
        }

        Spacer(modifier = Modifier.height(24.dp))
    }
}

@Composable
private fun DurationSettingRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    value: Int,
    unit: String,
    min: Int,
    max: Int,
    step: Int,
    onValueChange: (Int) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            icon,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.primary,
            modifier = Modifier.size(20.dp),
        )
        Spacer(modifier = Modifier.width(12.dp))
        Text(
            label,
            style = MaterialTheme.typography.bodyMedium,
            modifier = Modifier.weight(1f),
        )
        IconButton(
            onClick = { if (value - step >= min) onValueChange(value - step) },
            modifier = Modifier.size(30.dp),
        ) {
            Icon(Icons.Filled.Remove, contentDescription = "Decrease", modifier = Modifier.size(16.dp))
        }
        Text(
            if (unit.isNotEmpty()) "$value $unit" else "$value",
            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
            modifier = Modifier.padding(horizontal = 8.dp),
        )
        IconButton(
            onClick = { if (value + step <= max) onValueChange(value + step) },
            modifier = Modifier.size(30.dp),
        ) {
            Icon(Icons.Filled.Add, contentDescription = "Increase", modifier = Modifier.size(16.dp))
        }
    }
}
