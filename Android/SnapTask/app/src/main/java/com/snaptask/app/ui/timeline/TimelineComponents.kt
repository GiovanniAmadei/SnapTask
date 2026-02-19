package com.snaptask.app.ui.timeline

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.*
import com.snaptask.app.data.model.*
import java.text.SimpleDateFormat
import java.util.*

/**
 * Timeline Header View - matches iOS TimelineHeaderView
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TimelineHeaderView(
    viewModel: TimelineViewModel,
    selectedDayOffset: Int,
    onDayOffsetChange: (Int) -> Unit,
    onSettingsClick: () -> Unit,
    onJournalClick: () -> Unit,
    onCalendarClick: () -> Unit,
    onScopeChange: (TaskTimeScope) -> Unit,
) {
    val selectedDate by viewModel.selectedDate.collectAsState()
    val selectedScope by viewModel.selectedScope.collectAsState()
    val currentPeriodString = viewModel.currentPeriodString
    val configuration = LocalConfiguration.current

    Column(modifier = Modifier.fillMaxWidth()) {
        // Top row: Period title and action buttons
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = currentPeriodString,
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                maxLines = 1,
                modifier = Modifier.weight(1f),
            )

            // Settings button
            IconButton(
                onClick = onSettingsClick,
                modifier = Modifier
                    .size(40.dp)
                    .background(
                        color = MaterialTheme.colorScheme.primary.copy(alpha = 0.12f),
                        shape = RoundedCornerShape(10.dp),
                    )
            ) {
                Icon(
                    imageVector = Icons.Default.Settings,
                    contentDescription = "Settings",
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(20.dp),
                )
            }

            Spacer(modifier = Modifier.width(8.dp))

            // Journal button
            IconButton(
                onClick = onJournalClick,
                modifier = Modifier
                    .size(40.dp)
                    .background(
                        color = MaterialTheme.colorScheme.primary.copy(alpha = 0.12f),
                        shape = RoundedCornerShape(10.dp),
                    )
            ) {
                Icon(
                    imageVector = Icons.Default.MenuBook,
                    contentDescription = "Journal",
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(20.dp),
                )
            }

            Spacer(modifier = Modifier.width(8.dp))

            // Navigation arrows for week/month/year
            if (selectedScope != TaskTimeScope.TODAY &&
                selectedScope != TaskTimeScope.LONG_TERM &&
                selectedScope != TaskTimeScope.ALL) {
                IconButton(
                    onClick = { viewModel.navigateToPrevious() },
                    enabled = viewModel.canNavigatePrevious,
                ) {
                    Icon(
                        imageVector = Icons.Default.ChevronLeft,
                        contentDescription = "Previous",
                        tint = MaterialTheme.colorScheme.primary,
                    )
                }

                IconButton(
                    onClick = { viewModel.navigateToNext() },
                    enabled = viewModel.canNavigateNext,
                ) {
                    Icon(
                        imageVector = Icons.Default.ChevronRight,
                        contentDescription = "Next",
                        tint = MaterialTheme.colorScheme.primary,
                    )
                }
            }

            // Scope selector dropdown
            ExposedDropdownMenuBox(
                expanded = false,
                onExpandedChange = { },
            ) {
                AssistChip(
                    onClick = { /* Show scope menu */ },
                    label = {
                        Text(selectedScope.displayName)
                    },
                    leadingIcon = {
                        Icon(
                            imageVector = when (selectedScope) {
                                TaskTimeScope.TODAY -> Icons.Default.Today
                                TaskTimeScope.WEEK -> Icons.Default.DateRange
                                TaskTimeScope.MONTH -> Icons.Default.CalendarMonth
                                TaskTimeScope.YEAR -> Icons.Default.CalendarToday
                                TaskTimeScope.LONG_TERM -> Icons.Default.Flag
                                TaskTimeScope.ALL -> Icons.Default.AllInclusive
                            },
                            contentDescription = null,
                            tint = Color(selectedScope.scopeColor),
                            modifier = Modifier.size(16.dp),
                        )
                    },
                    trailingIcon = {
                        Icon(
                            imageVector = Icons.Default.ExpandMore,
                            contentDescription = null,
                            modifier = Modifier.size(16.dp),
                        )
                    },
                )
            }

            // Calendar picker for TODAY scope
            if (selectedScope == TaskTimeScope.TODAY) {
                IconButton(onClick = onCalendarClick) {
                    Icon(
                        imageVector = Icons.Default.CalendarToday,
                        contentDescription = "Select Date",
                        tint = MaterialTheme.colorScheme.primary,
                    )
                }
            }
        }

        // Date selector for TODAY scope
        if (selectedScope == TaskTimeScope.TODAY) {
            DateSelectorView(
                selectedDayOffset = selectedDayOffset,
                onDayOffsetChange = onDayOffsetChange,
                viewModel = viewModel,
            )
        }
    }
}

/**
 * Date Selector View - Horizontal scrollable day picker matching iOS
 */
@Composable
fun DateSelectorView(
    selectedDayOffset: Int,
    onDayOffsetChange: (Int) -> Unit,
    viewModel: TimelineViewModel,
) {
    val listState = rememberLazyListState()
    val haptic = LocalHapticFeedback.current

    LaunchedEffect(selectedDayOffset) {
        listState.animateScrollToItem(selectedDayOffset + 365, 0)
    }

    LazyRow(
        state = listState,
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        contentPadding = PaddingValues(horizontal = 16.dp),
    ) {
        items((-365..365).toList()) { offset ->
            val date = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, offset)
            }.time

            DayCell(
                date = date,
                isSelected = offset == selectedDayOffset,
                onClick = {
                    haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                    onDayOffsetChange(offset)
                },
            )
        }
    }
}

/**
 * Single day cell in the date selector
 */
@Composable
internal fun DayCell(
    date: Date,
    isSelected: Boolean,
    onClick: () -> Unit,
) {
    val calendar = Calendar.getInstance()
    calendar.time = date

    val isToday = TodoTask.isSameDay(date, Date())
    val dayName = SimpleDateFormat("EEE", Locale.getDefault()).format(date).lowercase()
    val dayNumber = calendar.get(Calendar.DAY_OF_MONTH).toString()

    val backgroundColor = when {
        isSelected -> MaterialTheme.colorScheme.primary
        isToday -> MaterialTheme.colorScheme.primary.copy(alpha = 0.1f)
        else -> MaterialTheme.colorScheme.surface
    }

    val textColor = when {
        isSelected -> MaterialTheme.colorScheme.onPrimary
        isToday -> MaterialTheme.colorScheme.primary
        else -> MaterialTheme.colorScheme.onSurface
    }

    Column(
        modifier = Modifier
            .width(50.dp)
            .height(64.dp)
            .background(
                color = backgroundColor,
                shape = RoundedCornerShape(16.dp),
            )
            .border(
                width = if (isToday && !isSelected) 1.dp else 0.dp,
                color = if (isToday && !isSelected) MaterialTheme.colorScheme.primary.copy(alpha = 0.3f) else Color.Transparent,
                shape = RoundedCornerShape(16.dp),
            )
            .clickable(onClick = onClick)
            .padding(vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            text = dayName.take(3),
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Medium,
            color = textColor,
        )
        Text(
            text = dayNumber,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = textColor,
        )
    }
}

/**
 * View Control Bar - matches iOS ViewControlBarView
 */
@Composable
fun ViewControlBarView(
    viewModel: TimelineViewModel,
    onFilterClick: () -> Unit,
) {
    val viewMode by viewModel.viewMode.collectAsState()
    val selectedScope by viewModel.selectedScope.collectAsState()
    val organization by viewModel.organization.collectAsState()
    val showAllHistory by viewModel.showAllHistory.collectAsState()

    val availableViewModes = if (selectedScope == TaskTimeScope.TODAY) {
        TimelineViewMode.entries
    } else {
        listOf(TimelineViewMode.LIST)
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 14.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        // View mode toggle
        Row(
            modifier = Modifier
                .background(
                    color = MaterialTheme.colorScheme.primary.copy(alpha = 0.08f),
                    shape = RoundedCornerShape(8.dp),
                )
                .border(
                    width = 1.dp,
                    color = MaterialTheme.colorScheme.primary.copy(alpha = if (viewMode == TimelineViewMode.LIST) 0.6f else 0.25f),
                    shape = RoundedCornerShape(8.dp),
                ),
        ) {
            availableViewModes.forEach { mode ->
                val isSelected = viewMode == mode
                val label = if (mode == TimelineViewMode.LIST) "List" else "Time"
                val icon = if (mode == TimelineViewMode.LIST) Icons.Default.ViewList else Icons.Default.Schedule

                Button(
                    onClick = { viewModel.setViewMode(mode) },
                    colors = ButtonDefaults.buttonColors(
                        containerColor = if (isSelected) MaterialTheme.colorScheme.primary else Color.Transparent,
                        contentColor = if (isSelected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.primary,
                    ),
                    shape = RoundedCornerShape(6.dp),
                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 8.dp),
                ) {
                    Icon(
                        imageVector = icon,
                        contentDescription = null,
                        modifier = Modifier.size(16.dp),
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = label,
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                    )
                }
            }
        }

        // Show history toggle for ALL scope
        if (selectedScope == TaskTimeScope.ALL) {
            FilterChip(
                selected = showAllHistory,
                onClick = { viewModel.toggleShowAllHistory() },
                label = { Text("History") },
                leadingIcon = if (showAllHistory) {
                    { Icon(Icons.Default.Check, null, modifier = Modifier.size(16.dp)) }
                } else null,
            )
        }

        Spacer(modifier = Modifier.weight(1f))

        // Organization status chip
        Surface(
            shape = RoundedCornerShape(6.dp),
            color = MaterialTheme.colorScheme.surfaceVariant,
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 6.dp),
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
            ) {
                Icon(
                    imageVector = when (organization) {
                        TimelineOrganization.NONE -> Icons.Default.Sort
                        TimelineOrganization.TIME -> Icons.Default.Schedule
                        TimelineOrganization.CATEGORY -> Icons.Default.Label
                        TimelineOrganization.PRIORITY -> Icons.Default.Flag
                        TimelineOrganization.EISENHOWER -> Icons.Default.GridView
                    },
                    contentDescription = null,
                    modifier = Modifier.size(14.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(modifier = Modifier.width(4.dp))
                Text(
                    text = viewModel.organizationStatusText,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        // Filter button
        IconButton(
            onClick = onFilterClick,
            modifier = Modifier
                .size(40.dp)
                .background(
                    color = MaterialTheme.colorScheme.primary.copy(alpha = 0.08f),
                    shape = CircleShape,
                ),
        ) {
            Icon(
                imageVector = Icons.Default.FilterList,
                contentDescription = "Filter",
                tint = MaterialTheme.colorScheme.primary,
            )
        }

        // Reset button (only when organization is not NONE)
        if (organization != TimelineOrganization.NONE) {
            IconButton(
                onClick = { viewModel.resetView() },
                modifier = Modifier
                    .size(36.dp)
                    .background(
                        color = MaterialTheme.colorScheme.surfaceVariant,
                        shape = CircleShape,
                    ),
            ) {
                Icon(
                    imageVector = Icons.Default.Refresh,
                    contentDescription = "Reset",
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(18.dp),
                )
            }
        }
    }
}

/**
 * Timeline Content View - Hourly view matching iOS TimelineContentView
 */
@Composable
fun TimelineContentView(
    viewModel: TimelineViewModel,
    tasks: List<TodoTask>,
    onAddTaskClick: () -> Unit,
    onTaskClick: (TodoTask) -> Unit,
) {
    val listState = rememberLazyListState()
    val scope = rememberCoroutineScope()
    val currentHour = viewModel.currentHour

    val allDayTasks = viewModel.allDayTasks(tasks)
    val timelineRange = viewModel.getTimelineRange(tasks)

    Box(modifier = Modifier.fillMaxSize()) {
        LazyColumn(
            state = listState,
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
        ) {
            // All-day tasks section
            if (allDayTasks.isNotEmpty()) {
                item {
                    AllDayTasksSection(
                        tasks = allDayTasks,
                        viewModel = viewModel,
                        onTaskClick = onTaskClick,
                    )
                }
            }

            // Hourly timeline
            items(timelineRange.toList()) { hour ->
                val tasksForHour = viewModel.tasksForHour(tasks, hour)
                val isCurrentHour = viewModel.isToday && currentHour == hour

                TimelineHourRow(
                    hour = hour,
                    tasks = tasksForHour,
                    isCurrentHour = isCurrentHour,
                    currentMinute = if (isCurrentHour) viewModel.currentMinute else null,
                    viewModel = viewModel,
                    isLastHour = hour == timelineRange.last,
                    onTaskClick = onTaskClick,
                )
            }

            // Bottom padding for FAB
            item { Spacer(modifier = Modifier.height(100.dp)) }
        }

        // Scroll to current hour on first load
        LaunchedEffect(Unit) {
            val index = timelineRange.indexOf(currentHour).coerceAtLeast(0)
            if (allDayTasks.isNotEmpty()) {
                listState.scrollToItem(index + 1)
            } else {
                listState.scrollToItem(index)
            }
        }

        // Add Task Button
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(bottom = 16.dp),
            contentAlignment = Alignment.BottomCenter,
        ) {
            AddTaskButton(
                onClick = onAddTaskClick,
                scope = viewModel.selectedScope.value,
            )
        }
    }
}

/**
 * All-day tasks section
 */
@Composable
internal fun AllDayTasksSection(
    tasks: List<TodoTask>,
    viewModel: TimelineViewModel,
    onTaskClick: (TodoTask) -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 12.dp)
            .background(
                color = MaterialTheme.colorScheme.primary.copy(alpha = 0.05f),
                shape = RoundedCornerShape(12.dp),
            )
            .padding(12.dp),
    ) {
        Text(
            text = "All Day",
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface,
        )

        Spacer(modifier = Modifier.height(8.dp))

        tasks.forEach { task ->
            CompactTimelineTaskView(
                task = task,
                viewModel = viewModel,
                onClick = { onTaskClick(task) },
            )
        }
    }
}

/**
 * Single hour row in the timeline
 */
@Composable
internal fun TimelineHourRow(
    hour: Int,
    tasks: List<TodoTask>,
    isCurrentHour: Boolean,
    currentMinute: Int?,
    viewModel: TimelineViewModel,
    isLastHour: Boolean,
    onTaskClick: (TodoTask) -> Unit,
) {
    val hourString = String.format("%02d:00", hour)

    Column(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.Top,
        ) {
            // Time column
            Column(
                modifier = Modifier.width(60.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(
                    text = hourString,
                    style = MaterialTheme.typography.labelSmall,
                    fontFamily = FontFamily.Monospace,
                    fontWeight = if (isCurrentHour) FontWeight.Bold else FontWeight.Medium,
                    color = if (isCurrentHour) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                )

                if (isCurrentHour) {
                    Spacer(modifier = Modifier.height(4.dp))
                    Box(
                        modifier = Modifier
                            .size(10.dp)
                            .background(
                                color = MaterialTheme.colorScheme.primary,
                                shape = CircleShape,
                            ),
                    )
                    currentMinute?.let {
                        Text(
                            text = String.format("%02d", it),
                            style = MaterialTheme.typography.labelSmall,
                            fontFamily = FontFamily.Monospace,
                            color = MaterialTheme.colorScheme.primary,
                            fontWeight = FontWeight.Bold,
                        )
                    }
                    Text(
                        text = "NOW",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.primary,
                        fontWeight = FontWeight.Bold,
                    )
                }
            }

            // Task content area
            Column(
                modifier = Modifier
                    .weight(1f)
                    .padding(start = 12.dp),
            ) {
                if (tasks.isNotEmpty()) {
                    tasks.forEach { task ->
                        EnhancedTimelineTaskView(
                            task = task,
                            viewModel = viewModel,
                            onClick = { onTaskClick(task) },
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                    }
                } else {
                    // Empty state with current time indicator
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(50.dp)
                            .background(
                                color = if (isCurrentHour) {
                                    MaterialTheme.colorScheme.primary.copy(alpha = 0.08f)
                                } else {
                                    MaterialTheme.colorScheme.surfaceVariant
                                },
                                shape = RoundedCornerShape(12.dp),
                            ),
                        contentAlignment = Alignment.CenterStart,
                    ) {
                        if (isCurrentHour && currentMinute != null) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier.padding(horizontal = 12.dp),
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(6.dp)
                                        .background(
                                            color = MaterialTheme.colorScheme.primary,
                                            shape = CircleShape,
                                        ),
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Box(
                                    modifier = Modifier
                                        .weight(1f)
                                        .height(2.dp)
                                        .background(
                                            color = MaterialTheme.colorScheme.primary.copy(alpha = 0.6f),
                                        ),
                                )
                            }
                        }
                    }
                }
            }
        }

        // Connection line to next hour
        if (!isLastHour) {
            Row {
                Spacer(modifier = Modifier.width(30.dp))
                Column(
                    modifier = Modifier.weight(1f),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    if (tasks.isNotEmpty()) {
                        Box(
                            modifier = Modifier
                                .width(2.dp)
                                .height(20.dp)
                                .background(
                                    brush = Brush.verticalGradient(
                                        colors = listOf(
                                            if (isCurrentHour) MaterialTheme.colorScheme.primary.copy(alpha = 0.6f) else MaterialTheme.colorScheme.outline,
                                            MaterialTheme.colorScheme.outline.copy(alpha = 0.1f),
                                        ),
                                    ),
                                ),
                        )
                    } else {
                        // Dotted line
                        Column(
                            verticalArrangement = Arrangement.spacedBy(2.dp),
                        ) {
                            repeat(4) {
                                Box(
                                    modifier = Modifier
                                        .size(2.dp)
                                        .background(
                                            color = MaterialTheme.colorScheme.outline,
                                            shape = CircleShape,
                                        ),
                                )
                            }
                        }
                    }

                    Divider(
                        color = if (isCurrentHour) {
                            MaterialTheme.colorScheme.primary.copy(alpha = 0.4f)
                        } else {
                            MaterialTheme.colorScheme.outlineVariant
                        },
                    )
                }
            }
        }
    }
}

/**
 * Compact task view for all-day section
 */
@Composable
internal fun CompactTimelineTaskView(
    task: TodoTask,
    viewModel: TimelineViewModel,
    onClick: () -> Unit,
) {
    val isCompleted = viewModel.isTaskCompleted(task)

    Card(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface,
        ),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // Category dot
            task.category?.let { category ->
                Box(
                    modifier = Modifier
                        .size(8.dp)
                        .background(
                            color = Color(android.graphics.Color.parseColor(category.color)),
                            shape = CircleShape,
                        ),
                )
                Spacer(modifier = Modifier.width(8.dp))
            } ?: run {
                Spacer(modifier = Modifier.width(16.dp))
            }

            // Task name
            Text(
                text = task.name,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                textDecoration = if (isCompleted) androidx.compose.ui.text.style.TextDecoration.LineThrough else null,
                color = if (isCompleted) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

/**
 * Enhanced task view for timeline hour row
 */
@Composable
internal fun EnhancedTimelineTaskView(
    task: TodoTask,
    viewModel: TimelineViewModel,
    onClick: () -> Unit,
) {
    val isCompleted = viewModel.isTaskCompleted(task)
    val selectedDate by viewModel.selectedDate.collectAsState()

    // Get occurrence time for today
    val occurrenceTime = remember(task, selectedDate) {
        if (task.recurrence != null) {
            task.occurrenceDate(selectedDate)
        } else {
            task.startTime
        }
    }

    val timeString = SimpleDateFormat("HH:mm", Locale.getDefault()).format(occurrenceTime)

    // Calculate time until task
    val timeUntilTask = remember(occurrenceTime) {
        val now = Date()
        val diffMs = occurrenceTime.time - now.time
        val diffMinutes = diffMs / (1000 * 60)

        when {
            diffMinutes > 0 && diffMinutes < 60 -> "in ${diffMinutes}m"
            diffMinutes >= 60 -> "in ${diffMinutes / 60}h"
            diffMinutes > -60 -> "now"
            else -> null
        }
    }

    Card(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface,
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // Completion button
            IconButton(
                onClick = {
                    viewModel.toggleTaskCompletion(task.id)
                },
                modifier = Modifier.size(32.dp),
            ) {
                Icon(
                    imageVector = if (isCompleted) Icons.Default.CheckCircle else Icons.Default.RadioButtonUnchecked,
                    contentDescription = if (isCompleted) "Completed" else "Not completed",
                    tint = if (isCompleted) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(24.dp),
                )
            }

            Spacer(modifier = Modifier.width(8.dp))

            // Category dot
            task.category?.let { category ->
                Box(
                    modifier = Modifier
                        .size(8.dp)
                        .background(
                            color = Color(android.graphics.Color.parseColor(category.color)),
                            shape = CircleShape,
                        ),
                )
                Spacer(modifier = Modifier.width(8.dp))
            }

            // Task content
            Column(
                modifier = Modifier.weight(1f),
            ) {
                Text(
                    text = task.name,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    textDecoration = if (isCompleted) androidx.compose.ui.text.style.TextDecoration.LineThrough else null,
                    color = if (isCompleted) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface,
                )

                task.description?.let { desc ->
                    if (desc.isNotBlank()) {
                        Text(
                            text = desc,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 2,
                            overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
                        )
                    }
                }

                // Priority indicator
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Icon(
                        imageVector = when (task.priority) {
                            Priority.HIGH -> Icons.Default.PriorityHigh
                            Priority.MEDIUM -> Icons.Default.Flag
                            Priority.LOW -> Icons.Default.LowPriority
                        },
                        contentDescription = null,
                        modifier = Modifier.size(14.dp),
                        tint = task.priority.color,
                    )

                    if (task.pomodoroSettings != null) {
                        Surface(
                            color = MaterialTheme.colorScheme.primary.copy(alpha = 0.15f),
                            shape = RoundedCornerShape(8.dp),
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Timer,
                                    contentDescription = null,
                                    modifier = Modifier.size(12.dp),
                                    tint = MaterialTheme.colorScheme.primary,
                                )
                                Spacer(modifier = Modifier.width(4.dp))
                                Text(
                                    text = "Focus",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.primary,
                                )
                            }
                        }
                    }
                }
            }

            // Time info
            Column(
                horizontalAlignment = Alignment.End,
            ) {
                Surface(
                    shape = RoundedCornerShape(4.dp),
                    color = MaterialTheme.colorScheme.surfaceVariant,
                ) {
                    Text(
                        text = timeString,
                        style = MaterialTheme.typography.labelSmall,
                        fontFamily = FontFamily.Monospace,
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                    )
                }

                timeUntilTask?.let {
                    Text(
                        text = it,
                        style = MaterialTheme.typography.labelSmall,
                        color = if (it == "now") Color(0xFFFFA500) else MaterialTheme.colorScheme.onSurfaceVariant,
                        fontWeight = FontWeight.Medium,
                    )
                }
            }
        }
    }
}

/**
 * Add Task Floating Button
 */
@Composable
internal fun AddTaskButton(
    onClick: () -> Unit,
    scope: TaskTimeScope,
) {
    ExtendedFloatingActionButton(
        onClick = onClick,
        icon = {
            Icon(
                imageVector = Icons.Default.Add,
                contentDescription = "Add Task",
            )
        },
        text = {
            Text(
                text = "New ${scope.displayName} Task",
                style = MaterialTheme.typography.labelLarge,
            )
        },
        containerColor = MaterialTheme.colorScheme.primary,
        contentColor = MaterialTheme.colorScheme.onPrimary,
    )
}

/**
 * Organized Task Section - for category/priority grouping
 */
@Composable
fun OrganizedTaskSection(
    section: TaskSection,
    viewModel: TimelineViewModel,
    onTaskClick: (TodoTask) -> Unit,
    onToggleComplete: (TodoTask) -> Unit,
    onToggleSubtask: (TodoTask, UUID) -> Unit,
) {
    val sectionColor = section.color?.let { Color(android.graphics.Color.parseColor(it)) }
        ?: MaterialTheme.colorScheme.primary

    Column(
        modifier = Modifier.fillMaxWidth(),
    ) {
        // Section header
        Surface(
            shape = RoundedCornerShape(12.dp),
            color = MaterialTheme.colorScheme.surfaceVariant,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                section.icon?.let { iconName ->
                    Icon(
                        imageVector = when (iconName) {
                            "label" -> Icons.Default.Label
                            "flag" -> Icons.Default.Flag
                            "priority_high" -> Icons.Default.PriorityHigh
                            "event" -> Icons.Default.Event
                            "person" -> Icons.Default.Person
                            "grid_view" -> Icons.Default.GridView
                            else -> Icons.Default.Folder
                        },
                        contentDescription = null,
                        modifier = Modifier.size(18.dp),
                        tint = sectionColor,
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                }

                Text(
                    text = section.title,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.weight(1f),
                )

                Surface(
                    shape = RoundedCornerShape(4.dp),
                    color = MaterialTheme.colorScheme.surface,
                ) {
                    Text(
                        text = "${section.tasks.size}",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(8.dp))

        // Tasks in section
        section.tasks.forEach { task ->
            TimelineTaskCard(
                task = task,
                viewModel = viewModel,
                onToggleComplete = { onToggleComplete(task) },
                onToggleSubtask = { subtaskId -> onToggleSubtask(task, subtaskId) },
                onClick = { onTaskClick(task) },
            )
            Spacer(modifier = Modifier.height(8.dp))
        }
    }
}

/**
 * Task Card for list view
 */
@Composable
internal fun TimelineTaskCard(
    task: TodoTask,
    viewModel: TimelineViewModel,
    onToggleComplete: () -> Unit,
    onToggleSubtask: (UUID) -> Unit,
    onClick: () -> Unit,
) {
    val isCompleted = viewModel.isTaskCompleted(task)
    val selectedDate by viewModel.selectedDate.collectAsState()
    val completedSubtasks = viewModel.completedSubtasks(task)
    val progress = viewModel.completionProgress(task)

    Card(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface,
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp),
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
            ) {
                // Completion checkbox
                IconButton(
                    onClick = onToggleComplete,
                    modifier = Modifier.size(32.dp),
                ) {
                    Icon(
                        imageVector = if (isCompleted) Icons.Default.CheckCircle else Icons.Default.RadioButtonUnchecked,
                        contentDescription = null,
                        tint = if (isCompleted) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.size(24.dp),
                    )
                }

                Spacer(modifier = Modifier.width(12.dp))

                // Task info
                Column(
                    modifier = Modifier.weight(1f),
                ) {
                    Text(
                        text = task.name,
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.SemiBold,
                        textDecoration = if (isCompleted) androidx.compose.ui.text.style.TextDecoration.LineThrough else null,
                        color = if (isCompleted) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface,
                    )

                    // Time info
                    if (task.hasSpecificTime) {
                        val timeStr = SimpleDateFormat("HH:mm", Locale.getDefault()).format(task.startTime)
                        Text(
                            text = timeStr,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }

                // Category indicator
                task.category?.let { category ->
                    Box(
                        modifier = Modifier
                            .size(12.dp)
                            .background(
                                color = Color(android.graphics.Color.parseColor(category.color)),
                                shape = CircleShape,
                            ),
                    )
                }
            }

            // Subtasks
            if (task.subtasks.isNotEmpty()) {
                Spacer(modifier = Modifier.height(8.dp))

                LinearProgressIndicator(
                    progress = { progress.toFloat() },
                    modifier = Modifier.fillMaxWidth(),
                )

                Spacer(modifier = Modifier.height(4.dp))

                task.subtasks.forEach { subtask ->
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.padding(start = 44.dp),
                    ) {
                        Checkbox(
                            checked = completedSubtasks.contains(subtask.id),
                            onCheckedChange = { onToggleSubtask(subtask.id) },
                            modifier = Modifier.size(20.dp),
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = subtask.name,
                            style = MaterialTheme.typography.bodySmall,
                            textDecoration = if (completedSubtasks.contains(subtask.id)) {
                                androidx.compose.ui.text.style.TextDecoration.LineThrough
                            } else null,
                        )
                    }
                }
            }
        }
    }
}
