package com.snaptask.app.ui.focus

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.snaptask.app.R
import com.snaptask.app.data.model.TodoTask
import com.snaptask.app.data.model.TrackingSession

// ──────────────────────────────────────────
// Focus Hub Screen (matches iOS FocusTabView)
// ──────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FocusScreen(
    viewModel: PomodoroViewModel = hiltViewModel(),
    timeTrackerViewModel: TimeTrackerViewModel = hiltViewModel(),
    pendingPomodoroTask: TodoTask? = null,
    onClearPendingPomodoroTask: () -> Unit = {},
) {
    val pomodoroState by viewModel.state.collectAsState()

    // When opened with a pending task (e.g. from Task Detail or Timeline), start Pomodoro for that task
    LaunchedEffect(pendingPomodoroTask) {
        pendingPomodoroTask?.let { task ->
            viewModel.setActiveTask(task)
            viewModel.start()
            onClearPendingPomodoroTask()
        }
    }
    val activeSessions by timeTrackerViewModel.activeSessions.collectAsState()
    val todayFocusTime by timeTrackerViewModel.todayFocusTime.collectAsState()
    val todaySessionCount by timeTrackerViewModel.todaySessionCount.collectAsState()
    val recentSessions by timeTrackerViewModel.recentSessions.collectAsState()

    // Navigation state
    var showTimeTracker by remember { mutableStateOf(false) }
    var showPomodoro by remember { mutableStateOf(false) }
    var showPomodoroSettings by remember { mutableStateOf(false) }

    val hasActivePomodoro = pomodoroState != PomodoroState.NOT_STARTED &&
            pomodoroState != PomodoroState.COMPLETED

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp),
    ) {
        Spacer(modifier = Modifier.height(16.dp))

        // Title
        Text(
            text = stringResource(R.string.focus_mode),
            style = MaterialTheme.typography.headlineLarge.copy(fontWeight = FontWeight.Bold),
        )

        Spacer(modifier = Modifier.height(20.dp))

        // Active session widgets (horizontal)
        if (activeSessions.isNotEmpty() || hasActivePomodoro) {
            ActiveSessionWidgets(
                activeSessions = activeSessions,
                pomodoroViewModel = viewModel,
                hasActivePomodoro = hasActivePomodoro,
                onTapTimer = { showTimeTracker = true },
                onTapPomodoro = { showPomodoro = true },
            )
            Spacer(modifier = Modifier.height(20.dp))
        }

        // Focus mode cards
        FocusModeCard(
            title = stringResource(R.string.focus_simple_timer),
            description = stringResource(R.string.focus_simple_timer_desc),
            icon = Icons.Filled.Timer,
            gradientColors = listOf(Color(0xFFF59E0B), Color(0xFFF97316)),
            onClick = { showTimeTracker = true },
        )

        Spacer(modifier = Modifier.height(12.dp))

        FocusModeCard(
            title = stringResource(R.string.focus_pomodoro_technique),
            description = stringResource(R.string.focus_pomodoro_technique_desc),
            icon = Icons.Filled.Alarm,
            gradientColors = listOf(Color(0xFFEF4444), Color(0xFFEC4899)),
            onClick = {
                if (!hasActivePomodoro) {
                    viewModel.initializeGeneralSession()
                }
                showPomodoro = true
            },
        )

        Spacer(modifier = Modifier.height(24.dp))

        // Today's stats
        TodayStatsCard(
            totalFocusTime = todayFocusTime,
            sessionsCount = todaySessionCount,
        )

        Spacer(modifier = Modifier.height(16.dp))

        // Recent sessions
        if (recentSessions.isNotEmpty()) {
            RecentSessionsCard(sessions = recentSessions)
        }

        Spacer(modifier = Modifier.height(32.dp))
    }

    // ── Sheet: Simple Timer ──
    if (showTimeTracker) {
        ModalBottomSheet(
            onDismissRequest = { showTimeTracker = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        ) {
            TimeTrackerScreen(
                viewModel = timeTrackerViewModel,
                onDismiss = { showTimeTracker = false },
            )
        }
    }

    // ── Sheet: Pomodoro ──
    if (showPomodoro) {
        ModalBottomSheet(
            onDismissRequest = { showPomodoro = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        ) {
            PomodoroScreen(
                viewModel = viewModel,
                onDismiss = { showPomodoro = false },
                onOpenSettings = { showPomodoroSettings = true },
            )
        }
    }

    // ── Sheet: Pomodoro Settings ──
    if (showPomodoroSettings) {
        ModalBottomSheet(
            onDismissRequest = { showPomodoroSettings = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        ) {
            PomodoroSettingsScreen(
                viewModel = viewModel,
                onDismiss = { showPomodoroSettings = false },
            )
        }
    }
}

// ──────────────────────────────────────────
// Focus Mode Card (matches iOS FocusModeCard)
// ──────────────────────────────────────────

@Composable
private fun FocusModeCard(
    title: String,
    description: String,
    icon: ImageVector,
    gradientColors: List<Color>,
    isDisabled: Boolean = false,
    onClick: () -> Unit,
) {
    Surface(
        onClick = { if (!isDisabled) onClick() },
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surface,
        shadowElevation = 2.dp,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(
            modifier = Modifier.padding(20.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            // Gradient icon circle
            Box(
                modifier = Modifier
                    .size(60.dp)
                    .clip(CircleShape)
                    .background(
                        Brush.linearGradient(
                            colors = if (isDisabled)
                                listOf(Color.Gray.copy(alpha = 0.3f))
                            else
                                gradientColors.map { it.copy(alpha = 0.2f) }
                        )
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    modifier = Modifier.size(28.dp),
                    tint = if (isDisabled) Color.Gray else gradientColors.first(),
                )
            }

            // Text content
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
                    color = if (isDisabled) MaterialTheme.colorScheme.onSurfaceVariant
                    else MaterialTheme.colorScheme.onSurface,
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = description,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            // Chevron
            Icon(
                imageVector = if (isDisabled) Icons.Filled.Lock else Icons.Filled.ChevronRight,
                contentDescription = null,
                tint = if (isDisabled) Color.Gray else MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(20.dp),
            )
        }
    }
}

// ──────────────────────────────────────────
// Active Session Widgets
// ──────────────────────────────────────────

@Composable
private fun ActiveSessionWidgets(
    activeSessions: List<TrackingSession>,
    pomodoroViewModel: PomodoroViewModel,
    hasActivePomodoro: Boolean,
    onTapTimer: () -> Unit,
    onTapPomodoro: () -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        // Timer widgets
        activeSessions.forEach { session ->
            MiniTimerWidget(
                session = session,
                onClick = onTapTimer,
                modifier = Modifier.weight(1f),
            )
        }

        // Pomodoro widget
        if (hasActivePomodoro) {
            MiniPomodoroWidget(
                viewModel = pomodoroViewModel,
                onClick = onTapPomodoro,
                modifier = if (activeSessions.isEmpty()) Modifier.weight(1f) else Modifier.weight(1f),
            )
        }
    }
}

@Composable
private fun MiniTimerWidget(
    session: TrackingSession,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val elapsed = session.elapsedTime.toLong()
    val minutes = (elapsed % 3600) / 60
    val seconds = elapsed % 60

    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.primaryContainer,
        modifier = modifier,
    ) {
        Row(
            modifier = Modifier.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Icon(
                Icons.Filled.Timer,
                contentDescription = null,
                modifier = Modifier.size(16.dp),
                tint = MaterialTheme.colorScheme.onPrimaryContainer,
            )
            Column {
                Text(
                    text = session.taskName ?: "Timer",
                    style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = String.format("%02d:%02d", minutes, seconds),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.7f),
                )
            }
            if (session.isRunning) {
                PulsingDot(color = Color(0xFF22C55E))
            }
        }
    }
}

@Composable
private fun MiniPomodoroWidget(
    viewModel: PomodoroViewModel,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val state by viewModel.state.collectAsState()
    val activeTask by viewModel.activeTask.collectAsState()

    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(12.dp),
        color = if (state == PomodoroState.ON_BREAK)
            MaterialTheme.colorScheme.tertiaryContainer
        else
            MaterialTheme.colorScheme.errorContainer,
        modifier = modifier,
    ) {
        Row(
            modifier = Modifier.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Icon(
                Icons.Filled.Alarm,
                contentDescription = null,
                modifier = Modifier.size(16.dp),
            )
            Column {
                Text(
                    text = activeTask?.name ?: "Pomodoro",
                    style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = viewModel.formattedTime,
                    style = MaterialTheme.typography.labelSmall,
                )
            }
            if (state == PomodoroState.WORKING || state == PomodoroState.ON_BREAK) {
                PulsingDot(
                    color = if (state == PomodoroState.WORKING) Color(0xFFEF4444) else Color(0xFF22C55E),
                )
            }
        }
    }
}

@Composable
private fun PulsingDot(color: Color) {
    val infiniteTransition = rememberInfiniteTransition(label = "pulse")
    val alpha by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = 0.3f,
        animationSpec = infiniteRepeatable(
            animation = tween(800),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "alpha",
    )
    Box(
        modifier = Modifier
            .size(8.dp)
            .clip(CircleShape)
            .background(color.copy(alpha = alpha))
    )
}

// ──────────────────────────────────────────
// Today's Stats Card
// ──────────────────────────────────────────

@Composable
private fun TodayStatsCard(
    totalFocusTime: Double,
    sessionsCount: Int,
) {
    val hours = (totalFocusTime / 3600).toInt()
    val minutes = ((totalFocusTime % 3600) / 60).toInt()
    val timeString = if (hours > 0) "${hours}h ${minutes}m" else "${minutes}m"

    Surface(
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier.padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    Icons.Filled.BarChart,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(20.dp),
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = "Today's Focus",
                    style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly,
            ) {
                StatBadge(
                    value = timeString,
                    label = "Focus Time",
                    icon = Icons.Filled.Schedule,
                    color = MaterialTheme.colorScheme.primary,
                )
                StatBadge(
                    value = "$sessionsCount",
                    label = "Sessions",
                    icon = Icons.Filled.Repeat,
                    color = Color(0xFF22C55E),
                )
            }
        }
    }
}

@Composable
private fun StatBadge(
    value: String,
    label: String,
    icon: ImageVector,
    color: Color,
) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Icon(icon, contentDescription = null, modifier = Modifier.size(16.dp), tint = color)
            Text(
                text = value,
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                color = color,
            )
        }
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

// ──────────────────────────────────────────
// Recent Sessions Card
// ──────────────────────────────────────────

@Composable
private fun RecentSessionsCard(sessions: List<TrackingSession>) {
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier.padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    Icons.Filled.History,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(20.dp),
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = "Recent Sessions",
                    style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
                )
            }

            sessions.forEach { session ->
                RecentSessionRow(session)
            }
        }
    }
}

@Composable
private fun RecentSessionRow(session: TrackingSession) {
    val durationMin = (session.effectiveWorkTime / 60).toInt()
    val hours = durationMin / 60
    val minutes = durationMin % 60
    val durationText = if (hours > 0) "${hours}h ${minutes}m" else "${minutes}m"

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(MaterialTheme.colorScheme.surface)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = if (session.mode == com.snaptask.app.data.model.TrackingMode.STOPWATCH)
                Icons.Filled.Timer else Icons.Filled.Alarm,
            contentDescription = null,
            modifier = Modifier.size(16.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(modifier = Modifier.width(8.dp))
        Text(
            text = session.taskName ?: "General Focus",
            style = MaterialTheme.typography.bodySmall,
            modifier = Modifier.weight(1f),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        Text(
            text = durationText,
            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
            color = MaterialTheme.colorScheme.primary,
        )
    }
}

// ──────────────────────────────────────────
// Circular Timer Ring (shared)
// ──────────────────────────────────────────

@Composable
fun CircularTimerRing(
    progress: Float,
    color: Color,
    trackColor: Color,
    modifier: Modifier = Modifier,
) {
    val sweepAngle by animateFloatAsState(
        targetValue = progress * 360f,
        animationSpec = tween(300, easing = LinearOutSlowInEasing),
        label = "sweepAngle",
    )

    val gradientColors = listOf(
        color,
        color.copy(alpha = 0.7f),
    )

    Canvas(modifier = modifier) {
        val strokeWidth = 12.dp.toPx()
        val diameter = size.minDimension - strokeWidth
        val topLeft = Offset(
            (size.width - diameter) / 2,
            (size.height - diameter) / 2,
        )

        // Track
        drawArc(
            color = trackColor,
            startAngle = 0f,
            sweepAngle = 360f,
            useCenter = false,
            topLeft = topLeft,
            size = Size(diameter, diameter),
            style = Stroke(width = strokeWidth, cap = StrokeCap.Round),
        )

        // Progress
        drawArc(
            brush = Brush.sweepGradient(gradientColors),
            startAngle = -90f,
            sweepAngle = sweepAngle,
            useCenter = false,
            topLeft = topLeft,
            size = Size(diameter, diameter),
            style = Stroke(width = strokeWidth, cap = StrokeCap.Round),
        )
    }
}
