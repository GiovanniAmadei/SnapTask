package com.snaptask.app.ui.focus

import androidx.compose.animation.core.*
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
import androidx.compose.ui.unit.sp

/**
 * Simple stopwatch timer screen.
 * Port of iOS TimeTrackerView.
 */
@Composable
fun TimeTrackerScreen(
    viewModel: TimeTrackerViewModel,
    onDismiss: () -> Unit,
) {
    val currentSession by viewModel.currentSession.collectAsState()
    val isRunning = currentSession?.isRunning == true
    val isPaused = currentSession?.isPaused == true
    val isActive = currentSession != null

    var showCompletion by remember { mutableStateOf(false) }
    var completedSession by remember { mutableStateOf<com.snaptask.app.data.model.TrackingSession?>(null) }

    val activeColor = MaterialTheme.colorScheme.primary
    val elapsed = currentSession?.elapsedTime ?: 0.0

    // Simple progress for visual: cycles every 60s    
    val progressValue = if (isRunning || isPaused) ((elapsed % 60.0) / 60.0).toFloat() else 0f

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
            Text(
                text = "Simple Timer",
                style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
            )
            TextButton(onClick = onDismiss) { Text("Done") }
        }

        Spacer(modifier = Modifier.height(40.dp))

        // Timer ring
        Box(
            modifier = Modifier.size(220.dp),
            contentAlignment = Alignment.Center,
        ) {
            CircularTimerRing(
                progress = progressValue,
                color = activeColor,
                trackColor = activeColor.copy(alpha = 0.1f),
                modifier = Modifier.fillMaxSize(),
            )

            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    text = viewModel.formattedElapsedTime,
                    style = MaterialTheme.typography.displayMedium.copy(
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 2.sp,
                    ),
                )
                if (isActive) {
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = if (isRunning) "Running" else "Paused",
                        style = MaterialTheme.typography.bodySmall,
                        color = if (isRunning) Color(0xFF22C55E)
                        else MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(48.dp))

        // Controls
        if (!isActive) {
            // Start
            Button(
                onClick = { viewModel.startSession() },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                shape = RoundedCornerShape(16.dp),
            ) {
                Icon(Icons.Default.PlayArrow, contentDescription = null)
                Spacer(modifier = Modifier.width(8.dp))
                Text("Start Timer", fontWeight = FontWeight.Bold, fontSize = 16.sp)
            }
        } else {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                // Stop
                OutlinedButton(
                    onClick = {
                        completedSession = viewModel.stopSession()
                        showCompletion = true
                    },
                    modifier = Modifier
                        .weight(1f)
                        .height(56.dp),
                    shape = RoundedCornerShape(16.dp),
                ) {
                    Icon(Icons.Default.Stop, contentDescription = "Stop", tint = MaterialTheme.colorScheme.error)
                }

                // Pause / Resume
                Button(
                    onClick = {
                        if (isPaused) viewModel.resumeSession() else viewModel.pauseSession()
                    },
                    modifier = Modifier
                        .weight(2f)
                        .height(56.dp),
                    shape = RoundedCornerShape(16.dp),
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
            }
        }

        Spacer(modifier = Modifier.height(32.dp))
    }

    // Completion sheet
    if (showCompletion && completedSession != null) {
        TrackingCompletionScreen(
            session = completedSession!!,
            onSave = {
                showCompletion = false
                completedSession = null
            },
            onDiscard = {
                showCompletion = false
                completedSession = null
            },
            onContinue = {
                showCompletion = false
                completedSession = null
                viewModel.startSession()
            },
        )
    }
}
