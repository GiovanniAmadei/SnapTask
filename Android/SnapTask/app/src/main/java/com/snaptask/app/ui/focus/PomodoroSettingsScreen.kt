package com.snaptask.app.ui.focus

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.snaptask.app.data.model.PomodoroSettings

/**
 * Pomodoro settings screen matching iOS PomodoroSettingsView.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PomodoroSettingsScreen(
    viewModel: PomodoroViewModel,
    onDismiss: () -> Unit,
) {
    val currentSettings by viewModel.settings.collectAsState()
    var workMinutes by remember { mutableIntStateOf((currentSettings.workDuration / 60).toInt()) }
    var breakMinutes by remember { mutableIntStateOf((currentSettings.breakDuration / 60).toInt()) }
    var longBreakMinutes by remember { mutableIntStateOf((currentSettings.longBreakDuration / 60).toInt()) }
    var sessionsUntilLongBreak by remember { mutableIntStateOf(currentSettings.sessionsUntilLongBreak) }
    var totalSessions by remember { mutableIntStateOf(currentSettings.totalSessions) }
    var useTimeDuration by remember { mutableStateOf(false) }
    var totalDurationMinutes by remember { mutableIntStateOf(currentSettings.totalDuration.toInt()) }

    fun applySettings() {
        val newSettings = PomodoroSettings(
            workDuration = workMinutes * 60.0,
            breakDuration = breakMinutes * 60.0,
            longBreakDuration = longBreakMinutes * 60.0,
            sessionsUntilLongBreak = sessionsUntilLongBreak,
            totalSessions = totalSessions,
            totalDuration = totalDurationMinutes.toDouble(),
        )
        viewModel.updateSettings(newSettings)
    }

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
                "Pomodoro Settings",
                style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
            )
            TextButton(onClick = { applySettings(); onDismiss() }) { Text("Done") }
        }

        Spacer(modifier = Modifier.height(24.dp))

        // Work Session
        SectionCard("Work Session") {
            StepperRow(
                label = "Work Duration",
                value = workMinutes,
                unit = "min",
                range = 1..60,
                onValueChange = { workMinutes = it; applySettings() },
            )
        }

        Spacer(modifier = Modifier.height(12.dp))

        // Break
        SectionCard("Break") {
            StepperRow(
                label = "Break Duration",
                value = breakMinutes,
                unit = "min",
                range = 1..30,
                onValueChange = { breakMinutes = it; applySettings() },
            )
            Spacer(modifier = Modifier.height(8.dp))
            StepperRow(
                label = "Long Break",
                value = longBreakMinutes,
                unit = "min",
                range = 1..60,
                onValueChange = { longBreakMinutes = it; applySettings() },
            )
            Spacer(modifier = Modifier.height(8.dp))
            StepperRow(
                label = "Sessions Until Long Break",
                value = sessionsUntilLongBreak,
                unit = "",
                range = 1..10,
                onValueChange = { sessionsUntilLongBreak = it; applySettings() },
            )
        }

        Spacer(modifier = Modifier.height(12.dp))

        // Session Configuration
        SectionCard("Session Configuration") {
            // Toggle between session count and duration
            Row(modifier = Modifier.fillMaxWidth()) {
                FilterChip(
                    selected = !useTimeDuration,
                    onClick = { useTimeDuration = false },
                    label = { Text("Sessions", style = MaterialTheme.typography.labelSmall) },
                    modifier = Modifier.weight(1f),
                )
                Spacer(modifier = Modifier.width(8.dp))
                FilterChip(
                    selected = useTimeDuration,
                    onClick = { useTimeDuration = true },
                    label = { Text("Duration", style = MaterialTheme.typography.labelSmall) },
                    modifier = Modifier.weight(1f),
                )
            }

            Spacer(modifier = Modifier.height(12.dp))

            if (useTimeDuration) {
                StepperRow(
                    label = "Total Duration",
                    value = totalDurationMinutes,
                    unit = "min",
                    range = 15..480,
                    step = 15,
                    onValueChange = {
                        totalDurationMinutes = it
                        val settings = PomodoroSettings(workDuration = workMinutes * 60.0, breakDuration = breakMinutes * 60.0)
                        totalSessions = settings.sessionsForDuration(it.toDouble())
                        applySettings()
                    },
                )
                Spacer(modifier = Modifier.height(4.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text("Estimated Sessions", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text("$totalSessions", style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.SemiBold))
                }
            } else {
                StepperRow(
                    label = "Total Sessions",
                    value = totalSessions,
                    unit = "",
                    range = 1..12,
                    onValueChange = { totalSessions = it; applySettings() },
                )
                Spacer(modifier = Modifier.height(4.dp))
                val estimatedTime = PomodoroSettings(
                    workDuration = workMinutes * 60.0,
                    breakDuration = breakMinutes * 60.0,
                    longBreakDuration = longBreakMinutes * 60.0,
                    sessionsUntilLongBreak = sessionsUntilLongBreak,
                    totalSessions = totalSessions,
                ).estimatedTotalTime
                val estHours = (estimatedTime / 3600).toInt()
                val estMinutes = ((estimatedTime % 3600) / 60).toInt()
                val estText = if (estHours > 0) "${estHours}h ${estMinutes}m" else "${estMinutes}m"
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text("Estimated Duration", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(estText, style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.SemiBold))
                }
            }
        }

        Spacer(modifier = Modifier.height(12.dp))

        // Summary
        SectionCard("Summary") {
            val totalWork = workMinutes * totalSessions
            val shortBreaks = maxOf(0, totalSessions - 1 - (totalSessions / sessionsUntilLongBreak))
            val longBreaks = totalSessions / sessionsUntilLongBreak
            val totalBreak = shortBreaks * breakMinutes + longBreaks * longBreakMinutes
            val totalTime = totalWork + totalBreak
            val tHours = totalTime / 60
            val tMinutes = totalTime % 60

            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("Work Time", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text("${totalWork}m", style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.SemiBold))
            }
            Spacer(modifier = Modifier.height(4.dp))
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("Break Time", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text("${totalBreak}m", style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.SemiBold))
            }
            Spacer(modifier = Modifier.height(4.dp))
            HorizontalDivider()
            Spacer(modifier = Modifier.height(4.dp))
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("Total Time", style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.SemiBold))
                Text(
                    if (tHours > 0) "${tHours}h ${tMinutes}m" else "${tMinutes}m",
                    style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.SemiBold),
                )
            }
        }

        Spacer(modifier = Modifier.height(32.dp))
    }
}

@Composable
private fun SectionCard(
    title: String,
    content: @Composable ColumnScope.() -> Unit,
) {
    Card(
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
        ),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                title,
                style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
            )
            Spacer(modifier = Modifier.height(12.dp))
            content()
        }
    }
}

@Composable
private fun StepperRow(
    label: String,
    value: Int,
    unit: String,
    range: IntRange,
    step: Int = 1,
    onValueChange: (Int) -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            label,
            style = MaterialTheme.typography.bodySmall,
            modifier = Modifier.weight(1f),
        )
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            FilledIconButton(
                onClick = { onValueChange((value - step).coerceIn(range)) },
                modifier = Modifier.size(28.dp),
                enabled = value > range.first,
                colors = IconButtonDefaults.filledIconButtonColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer,
                ),
            ) {
                Text("−", fontWeight = FontWeight.Bold)
            }
            Text(
                "$value${if (unit.isNotEmpty()) " $unit" else ""}",
                style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Bold),
            )
            FilledIconButton(
                onClick = { onValueChange((value + step).coerceIn(range)) },
                modifier = Modifier.size(28.dp),
                enabled = value < range.last,
                colors = IconButtonDefaults.filledIconButtonColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer,
                ),
            ) {
                Text("+", fontWeight = FontWeight.Bold)
            }
        }
    }
}
