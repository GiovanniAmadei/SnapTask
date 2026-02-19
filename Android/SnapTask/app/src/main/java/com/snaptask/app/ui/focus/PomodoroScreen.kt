package com.snaptask.app.ui.focus

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.layout.*
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
import androidx.compose.ui.unit.sp

/**
 * Full-screen Pomodoro timer.
 * Port of iOS PomodoroView.swift.
 */
@Composable
fun PomodoroScreen(
    viewModel: PomodoroViewModel,
    onDismiss: () -> Unit,
    onOpenSettings: () -> Unit,
) {
    val state by viewModel.state.collectAsState()
    val currentSession by viewModel.currentSession.collectAsState()
    val progress by viewModel.progress.collectAsState()
    val settings by viewModel.settings.collectAsState()
    val activeTask by viewModel.activeTask.collectAsState()

    val isWorking = state == PomodoroState.WORKING
    val isPaused = state == PomodoroState.PAUSED
    val isBreak = state == PomodoroState.ON_BREAK
    val isCompleted = state == PomodoroState.COMPLETED
    val isNotStarted = state == PomodoroState.NOT_STARTED

    val focusColor = MaterialTheme.colorScheme.primary
    val breakColor = MaterialTheme.colorScheme.tertiary

    val activeColor by animateColorAsState(
        targetValue = when {
            isWorking || isPaused -> focusColor
            isBreak -> breakColor
            isCompleted -> Color(0xFF22C55E)
            else -> focusColor
        },
        label = "activeColor",
    )

    var showCompletion by remember { mutableStateOf(false) }
    var focusTimeAtCompletion by remember { mutableStateOf(0L) }

    // Watch for completion
    LaunchedEffect(state) {
        if (state == PomodoroState.COMPLETED) {
            focusTimeAtCompletion = (settings.workDuration * settings.totalSessions).toLong()
            showCompletion = true
        }
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        // Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            TextButton(onClick = onDismiss) { Text("Minimize") }

            // Session indicator
            Surface(
                shape = RoundedCornerShape(12.dp),
                color = activeColor.copy(alpha = 0.1f),
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Icon(
                        if (isWorking || isPaused) Icons.Default.Psychology else Icons.Default.Coffee,
                        contentDescription = null,
                        tint = activeColor,
                        modifier = Modifier.size(14.dp),
                    )
                    Text(
                        text = "Session $currentSession of ${settings.totalSessions}",
                        style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
                        color = activeColor,
                    )
                }
            }

            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                IconButton(onClick = onOpenSettings, modifier = Modifier.size(32.dp)) {
                    Icon(Icons.Default.Settings, "Settings", modifier = Modifier.size(18.dp))
                }
                IconButton(onClick = { viewModel.stop(); onDismiss() }, modifier = Modifier.size(32.dp)) {
                    Icon(
                        Icons.Default.Close, "Close",
                        tint = MaterialTheme.colorScheme.error,
                        modifier = Modifier.size(18.dp),
                    )
                }
            }
        }

        // Task name
        activeTask?.let { task ->
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = task.name,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        Spacer(modifier = Modifier.height(32.dp))

        // Status label
        Text(
            text = when {
                isNotStarted -> "Ready to Focus"
                isWorking -> "Stay Focused"
                isPaused -> "Paused"
                isBreak -> "Take a Break"
                isCompleted -> "Great Work! 🎉"
                else -> "Focus"
            },
            style = MaterialTheme.typography.headlineSmall.copy(fontWeight = FontWeight.Bold),
            color = activeColor,
        )

        Spacer(modifier = Modifier.height(24.dp))

        // Timer ring
        Box(
            modifier = Modifier.size(240.dp),
            contentAlignment = Alignment.Center,
        ) {
            CircularTimerRing(
                progress = progress,
                color = activeColor,
                trackColor = activeColor.copy(alpha = 0.1f),
                modifier = Modifier.fillMaxSize(),
            )

            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    text = viewModel.formattedTime,
                    style = MaterialTheme.typography.displayMedium.copy(
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 2.sp,
                    ),
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "${(progress * 100).toInt()}%",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        // Session progress dots
        Row(
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            for (i in 0 until settings.totalSessions) {
                val dotColor by animateColorAsState(
                    targetValue = when {
                        viewModel.isSessionCompleted(i, true) -> activeColor
                        i == currentSession - 1 && isWorking -> activeColor.copy(alpha = 0.5f)
                        else -> MaterialTheme.colorScheme.outlineVariant
                    },
                    label = "dot$i",
                )
                Surface(
                    modifier = Modifier.size(
                        width = if (i == currentSession - 1) 24.dp else 8.dp,
                        height = 8.dp,
                    ),
                    shape = RoundedCornerShape(4.dp),
                    color = dotColor,
                ) {}
            }
        }

        Spacer(modifier = Modifier.height(40.dp))

        // Controls
        when {
            isNotStarted -> {
                Button(
                    onClick = viewModel::start,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(56.dp),
                    shape = RoundedCornerShape(16.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = focusColor),
                ) {
                    Icon(Icons.Default.PlayArrow, contentDescription = null)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Start Focus", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                }
            }

            isCompleted -> {
                Button(
                    onClick = {
                        viewModel.initializeGeneralSession()
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(56.dp),
                    shape = RoundedCornerShape(16.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF22C55E)),
                ) {
                    Icon(Icons.Default.Refresh, contentDescription = null)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Start New Session", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                }
            }

            else -> {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    OutlinedButton(
                        onClick = { viewModel.stop(); onDismiss() },
                        modifier = Modifier.weight(1f).height(56.dp),
                        shape = RoundedCornerShape(16.dp),
                    ) {
                        Icon(Icons.Default.Stop, "Stop", tint = MaterialTheme.colorScheme.error)
                    }

                    Button(
                        onClick = {
                            if (isPaused) viewModel.resume() else viewModel.pause()
                        },
                        modifier = Modifier.weight(2f).height(56.dp),
                        shape = RoundedCornerShape(16.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = activeColor),
                    ) {
                        Icon(
                            if (isPaused) Icons.Default.PlayArrow else Icons.Default.Pause,
                            contentDescription = null,
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            if (isPaused) "Resume" else "Pause",
                            fontWeight = FontWeight.Bold,
                        )
                    }

                    OutlinedButton(
                        onClick = viewModel::skip,
                        modifier = Modifier.weight(1f).height(56.dp),
                        shape = RoundedCornerShape(16.dp),
                    ) {
                        Icon(Icons.Default.SkipNext, "Skip")
                    }
                }
            }
        }

        // Settings card when not started
        if (isNotStarted) {
            Spacer(modifier = Modifier.height(24.dp))
            Card(
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                ),
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        "Session Settings",
                        style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    SettingRow("Work", "${(settings.workDuration / 60).toInt()} min")
                    SettingRow("Short Break", "${(settings.breakDuration / 60).toInt()} min")
                    SettingRow("Long Break", "${(settings.longBreakDuration / 60).toInt()} min")
                    SettingRow("Sessions", "${settings.totalSessions}")
                }
            }
        }

        Spacer(modifier = Modifier.height(32.dp))
    }

    // Completion screen
    if (showCompletion && isCompleted) {
        PomodoroCompletionScreen(
            taskName = activeTask?.name ?: "Pomodoro Session",
            categoryName = activeTask?.category?.name,
            categoryColor = activeTask?.category?.color,
            focusTimeCompleted = focusTimeAtCompletion.toDouble(),
            onSave = {
                showCompletion = false
                viewModel.initializeGeneralSession()
                onDismiss()
            },
            onDiscard = {
                showCompletion = false
                viewModel.initializeGeneralSession()
                onDismiss()
            },
        )
    }
}

@Composable
private fun SettingRow(label: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 6.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
        )
    }
}
