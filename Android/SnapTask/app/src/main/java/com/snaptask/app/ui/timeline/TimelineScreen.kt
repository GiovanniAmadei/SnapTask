package com.snaptask.app.ui.timeline

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Label
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.automirrored.filled.Sort
import androidx.compose.material.icons.automirrored.filled.ViewList
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import androidx.hilt.navigation.compose.hiltViewModel
import com.snaptask.app.data.model.*
import com.snaptask.app.R
import com.snaptask.app.ui.components.parseHexColor
import java.text.SimpleDateFormat
import java.util.*
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * Faithful port of iOS TimelineView.swift (2259 lines).
 * Replicates: header with scope selector, date strip, view mode toggle,
 * organization bar, task list/timeline view, swipe actions, category gradients,
 * streaks, date/time badges, and floating add button.
 */
@Composable
fun TimelineScreen(
    viewModel: TimelineViewModel = hiltViewModel(),
    onNavigateToTaskDetail: (UUID) -> Unit = {},
    onNavigateToCreateTask: () -> Unit = {},
    onNavigateToSettings: () -> Unit = {},
    onNavigateToJournal: () -> Unit = {},
    onOpenCalendar: () -> Unit = {},
    onOpenTimelineOrganization: () -> Unit = {},
    onStartPomodoroForTask: (TodoTask) -> Unit = {},
) {
    val tasks by viewModel.tasksForSelectedDate.collectAsState()
    val selectedDate by viewModel.selectedDate.collectAsState()
    val selectedScope by viewModel.selectedScope.collectAsState()
    val viewMode by viewModel.viewMode.collectAsState()
    val organization by viewModel.organization.collectAsState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background),
    ) {
        // ---- Header (matches iOS TimelineHeaderView) ----
        TimelineHeaderView(
            viewModel = viewModel,
            selectedScope = selectedScope,
            selectedDate = selectedDate,
            onSettingsClick = onNavigateToSettings,
            onOpenJournal = onNavigateToJournal,
            onOpenCalendar = onOpenCalendar,
        )

        // The iOS header keeps the seven-day rail directly below the title.
        // Keeping it above the view controls makes the date context visible
        // before the user changes list/timeline organization.
        if (selectedScope == TaskTimeScope.TODAY) {
            DateSelectorView(
                viewModel = viewModel,
                selectedDate = selectedDate,
            )
        }

        HorizontalDivider(
            modifier = Modifier.padding(horizontal = 16.dp),
            color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.3f),
        )

        // ---- View Control Bar (matches iOS ViewControlBarView) ----
        ViewControlBarView(
            viewModel = viewModel,
            viewMode = viewMode,
            organization = organization,
            selectedScope = selectedScope,
            onOpenTimelineOrganization = onOpenTimelineOrganization,
        )

        HorizontalDivider(
            modifier = Modifier.padding(horizontal = 16.dp),
            color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.3f),
        )

        // ---- Content ----
        Box(
            modifier = Modifier
                .fillMaxSize()
                .weight(1f),
        ) {
            if (viewMode == TimelineViewMode.TIMELINE && selectedScope == TaskTimeScope.TODAY) {
                TimelineContentView(
                    viewModel = viewModel,
                    tasks = tasks,
                    onNavigateToTaskDetail = onNavigateToTaskDetail,
                    onStartPomodoroForTask = onStartPomodoroForTask,
                )
            } else if (organization == TimelineOrganization.EISENHOWER) {
                EisenhowerMatrixView(
                    viewModel = viewModel,
                    onTaskClick = { task -> onNavigateToTaskDetail(task.id) },
                )
            } else {
                TaskListView(
                    viewModel = viewModel,
                    tasks = tasks,
                    organization = organization,
                    onNavigateToTaskDetail = onNavigateToTaskDetail,
                    onStartPomodoroForTask = onStartPomodoroForTask,
                )
            }

            // Floating Add Button (matches iOS AddTaskButton)
            AddTaskButton(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 16.dp),
                onClick = onNavigateToCreateTask,
            )
        }
    }
}

// ============================================================================
// MARK: - TimelineHeaderView (iOS lines 801-1004)
// ============================================================================
@Composable
private fun TimelineHeaderView(
    viewModel: TimelineViewModel,
    selectedScope: TaskTimeScope,
    selectedDate: java.util.Date,
    onSettingsClick: () -> Unit,
    onOpenJournal: () -> Unit,
    onOpenCalendar: () -> Unit,
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(60.dp)
                .padding(horizontal = 20.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // Period string (title)
            Text(
                text = viewModel.currentPeriodString,
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
                modifier = Modifier.weight(1f, fill = false),
            )

            Spacer(modifier = Modifier.width(8.dp))

            // iOS only exposes the journal shortcut for the daily timeline.
            if (selectedScope == TaskTimeScope.TODAY) {
                Box(
                    modifier = Modifier
                        .size(34.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.12f))
                        .border(
                            width = 1.dp,
                            color = MaterialTheme.colorScheme.primary.copy(alpha = 0.35f),
                            shape = RoundedCornerShape(8.dp),
                        )
                        .clickable { onOpenJournal() },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        Icons.AutoMirrored.Filled.MenuBook,
                        contentDescription = stringResource(id = R.string.journal),
                        modifier = Modifier.size(16.dp),
                        tint = MaterialTheme.colorScheme.primary,
                    )
                }
                Spacer(modifier = Modifier.width(8.dp))
            }

            // Navigation arrows (for non-today scopes)
            if (selectedScope != TaskTimeScope.TODAY &&
                selectedScope != TaskTimeScope.LONG_TERM &&
                selectedScope != TaskTimeScope.ALL
            ) {
                IconButton(
                    onClick = { viewModel.navigateToPrevious() },
                    modifier = Modifier.size(32.dp),
                ) {
                    Box(
                        modifier = Modifier
                            .size(32.dp)
                            .clip(CircleShape)
                            .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.1f)),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            Icons.Default.ChevronLeft,
                            contentDescription = stringResource(id = R.string.journal_previous_day),
                            modifier = Modifier.size(14.dp),
                            tint = MaterialTheme.colorScheme.primary,
                        )
                    }
                }

                IconButton(
                    onClick = { viewModel.navigateToNext() },
                    modifier = Modifier.size(32.dp),
                ) {
                    Box(
                        modifier = Modifier
                            .size(32.dp)
                            .clip(CircleShape)
                            .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.1f)),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            Icons.Default.ChevronRight,
                            contentDescription = stringResource(id = R.string.journal_next_day),
                            modifier = Modifier.size(14.dp),
                            tint = MaterialTheme.colorScheme.primary,
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.weight(1f))

            // Scope selector dropdown (matches iOS Menu)
            ScopeDropdown(
                selectedScope = selectedScope,
                onScopeSelected = { viewModel.selectScope(it) },
            )

            // Calendar picker button (for Today scope)
            if (selectedScope == TaskTimeScope.TODAY) {
                Spacer(modifier = Modifier.width(4.dp))
                IconButton(
                    onClick = onOpenCalendar,
                    modifier = Modifier.size(32.dp),
                ) {
                    Box(
                        modifier = Modifier
                            .size(32.dp)
                            .clip(CircleShape)
                            .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.1f)),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            Icons.Default.CalendarMonth,
                            contentDescription = stringResource(id = R.string.task_detail_date),
                            modifier = Modifier.size(16.dp),
                            tint = MaterialTheme.colorScheme.primary,
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.width(8.dp))

            // Settings is the trailing action, as in TimelineHeaderView on iOS.
            Box(
                modifier = Modifier
                    .size(34.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.12f))
                    .border(
                        width = 1.dp,
                        color = MaterialTheme.colorScheme.primary.copy(alpha = 0.35f),
                        shape = RoundedCornerShape(8.dp),
                    )
                    .clickable { onSettingsClick() },
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Default.Settings,
                    contentDescription = stringResource(id = R.string.settings_title),
                    modifier = Modifier.size(16.dp),
                    tint = MaterialTheme.colorScheme.primary,
                )
            }
        }
    }
}

// ============================================================================
// MARK: - ScopeDropdown (matching iOS Menu for TaskTimeScope)
// ============================================================================
@Composable
private fun ScopeDropdown(
    selectedScope: TaskTimeScope,
    onScopeSelected: (TaskTimeScope) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }

    Box {
        Row(
            modifier = Modifier
                .clip(RoundedCornerShape(10.dp))
                .background(MaterialTheme.colorScheme.surface)
                .border(
                    width = 1.dp,
                    color = MaterialTheme.colorScheme.outlineVariant,
                    shape = RoundedCornerShape(10.dp),
                )
                .clickable { expanded = true }
                .padding(horizontal = 8.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Text(
                text = selectedScope.displayName,
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
            )
            Icon(
                Icons.Default.ExpandMore,
                contentDescription = null,
                modifier = Modifier.size(10.dp),
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
        ) {
            TaskTimeScope.entries.forEach { scope ->
                DropdownMenuItem(
                    text = {
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(
                                text = scope.displayName,
                                style = MaterialTheme.typography.bodyMedium,
                            )
                            Spacer(modifier = Modifier.weight(1f))
                            if (selectedScope == scope) {
                                Icon(
                                    Icons.Default.Check,
                                    contentDescription = null,
                                    modifier = Modifier.size(12.dp),
                                    tint = MaterialTheme.colorScheme.primary,
                                )
                            }
                        }
                    },
                    onClick = {
                        onScopeSelected(scope)
                        expanded = false
                    },
                )
            }
        }
    }
}

// ============================================================================
// MARK: - ViewControlBarView (iOS lines 86-250)
// ============================================================================
@Composable
private fun ViewControlBarView(
    viewModel: TimelineViewModel,
    viewMode: TimelineViewMode,
    organization: TimelineOrganization,
    selectedScope: TaskTimeScope,
    onOpenTimelineOrganization: () -> Unit,
) {
    val availableViewModes = if (selectedScope == TaskTimeScope.TODAY) {
        TimelineViewMode.entries.toList()
    } else {
        listOf(TimelineViewMode.LIST)
    }
    val showAllHistory by viewModel.showAllHistory.collectAsState()

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        // View mode toggle (matches iOS segmented control)
        Row(
            modifier = Modifier
                .clip(RoundedCornerShape(8.dp))
                .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.08f))
                .border(
                    width = 1.dp,
                    color = MaterialTheme.colorScheme.primary.copy(alpha = 0.15f),
                    shape = RoundedCornerShape(8.dp),
                ),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            availableViewModes.forEach { mode ->
                val isSelected = viewMode == mode
                val bgColor = if (isSelected) MaterialTheme.colorScheme.primary else Color.Transparent
                val textColor = if (isSelected) MaterialTheme.colorScheme.onPrimary
                else MaterialTheme.colorScheme.primary

                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(6.dp))
                        .background(bgColor)
                        .clickable { viewModel.setViewMode(mode) }
                        .padding(horizontal = 9.dp, vertical = 7.dp),
                ) {
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(3.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(
                            imageVector = if (mode == TimelineViewMode.LIST) Icons.AutoMirrored.Filled.ViewList
                            else Icons.Default.Schedule,
                            contentDescription = null,
                            modifier = Modifier.size(11.dp),
                            tint = textColor,
                        )
                        Text(
                            text = if (mode == TimelineViewMode.LIST) stringResource(R.string.timeline_view_mode_list)
                            else stringResource(R.string.timeline_view_mode_time),
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.SemiBold,
                            color = textColor,
                        )
                    }
                }
            }
        }

        // Show History button for ALL scope (matches iOS)
        if (selectedScope == TaskTimeScope.ALL) {
            Row(
                modifier = Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .background(
                        if (showAllHistory) MaterialTheme.colorScheme.primary
                        else MaterialTheme.colorScheme.primary.copy(alpha = 0.08f)
                    )
                    .clickable { viewModel.toggleShowAllHistory() }
                    .padding(horizontal = 10.dp, vertical = 7.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Icon(
                    imageVector = Icons.Default.History,
                    contentDescription = null,
                    modifier = Modifier.size(14.dp),
                    tint = if (showAllHistory) MaterialTheme.colorScheme.onPrimary
                    else MaterialTheme.colorScheme.primary,
                )
                Text(
                    text = stringResource(R.string.timeline_history),
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = if (showAllHistory) MaterialTheme.colorScheme.onPrimary
                    else MaterialTheme.colorScheme.primary,
                )
            }
        }

        Spacer(modifier = Modifier.weight(1f))

        // Organization status text (matches iOS)
        val organizationText by remember(organization) {
            mutableStateOf(viewModel.organizationStatusText)
        }
        Row(
            modifier = Modifier
                .clip(RoundedCornerShape(6.dp))
                .background(MaterialTheme.colorScheme.surface)
                .padding(horizontal = 7.dp, vertical = 5.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Icon(
                imageVector = when (organization) {
                    TimelineOrganization.NONE -> Icons.AutoMirrored.Filled.Sort
                    TimelineOrganization.TIME -> Icons.Default.Schedule
                    TimelineOrganization.CATEGORY -> Icons.AutoMirrored.Filled.Label
                    TimelineOrganization.PRIORITY -> Icons.Default.Flag
                    TimelineOrganization.EISENHOWER -> Icons.Default.GridView
                },
                contentDescription = null,
                modifier = Modifier.size(11.dp),
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                text = organizationText,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        // Filter button (matches iOS organize picker)
        IconButton(
            onClick = onOpenTimelineOrganization,
            modifier = Modifier.size(32.dp),
        ) {
            Icon(
                Icons.Default.FilterList,
                contentDescription = "Filter",
                modifier = Modifier.size(19.dp),
                tint = MaterialTheme.colorScheme.primary,
            )
        }

        // Reset button (visible when organization != NONE)
        if (organization != TimelineOrganization.NONE) {
            IconButton(
                onClick = { viewModel.resetView() },
                modifier = Modifier.size(32.dp),
            ) {
                Icon(
                    Icons.Default.Refresh,
                    contentDescription = "Reset view",
                    modifier = Modifier.size(17.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        // Organization buttons (matches iOS organize picker)
        TimelineOrganization.entries.forEach { org ->
            if (org == TimelineOrganization.TIME && selectedScope != TaskTimeScope.TODAY) return@forEach

            val isSelected = organization == org
            Box(
                modifier = Modifier
                    .size(28.dp)
                    .clip(CircleShape)
                    .background(
                        if (isSelected) MaterialTheme.colorScheme.primary.copy(alpha = 0.15f)
                        else Color.Transparent,
                    )
                    .clickable { viewModel.setOrganization(org) },
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = when (org) {
                        TimelineOrganization.NONE -> Icons.AutoMirrored.Filled.Sort
                        TimelineOrganization.TIME -> Icons.Default.Schedule
                        TimelineOrganization.CATEGORY -> Icons.AutoMirrored.Filled.Label
                        TimelineOrganization.PRIORITY -> Icons.Default.Flag
                        TimelineOrganization.EISENHOWER -> Icons.Default.GridView
                    },
                    contentDescription = org.displayName,
                    modifier = Modifier.size(14.dp),
                    tint = if (isSelected) MaterialTheme.colorScheme.primary
                    else MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

// ============================================================================
// MARK: - DateSelectorView (iOS lines 1006-1099)
// ============================================================================
@Composable
private fun DateSelectorView(
    viewModel: TimelineViewModel,
    selectedDate: Date,
) {
    // Match iOS: -365..365 offsets
    val today = remember { Calendar.getInstance() }
    val listState = rememberLazyListState(initialFirstVisibleItemIndex = 365)

    // Auto-scroll to selected date on first composition
    LaunchedEffect(Unit) {
        listState.scrollToItem(365, scrollOffset = -200)
    }

    LazyRow(
        state = listState,
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        contentPadding = PaddingValues(horizontal = 16.dp),
    ) {
        items(731) { index ->
            val offset = index - 365
            val cal = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, offset)
            }
            val date = cal.time
            val isSelected = TodoTask.isSameDay(date, selectedDate)
            val isToday = TodoTask.isSameDay(date, Date())

            DayCell(
                date = date,
                isSelected = isSelected,
                isToday = isToday,
                onClick = { viewModel.selectDate(date) },
            )
        }
    }
}

// ============================================================================
// MARK: - DayCell (iOS lines 1375-1443)
// ============================================================================
@Composable
private fun DayCell(
    date: Date,
    isSelected: Boolean,
    isToday: Boolean,
    onClick: () -> Unit,
) {
    val dayNameFmt = remember { SimpleDateFormat("EEE", Locale.getDefault()) }
    val dayNumberFmt = remember { SimpleDateFormat("d", Locale.getDefault()) }

    val bgColor by animateColorAsState(
        targetValue = when {
            isSelected -> MaterialTheme.colorScheme.primary
            isToday -> MaterialTheme.colorScheme.primary.copy(alpha = 0.1f)
            else -> MaterialTheme.colorScheme.surface
        },
        label = "dayCellBg",
    )

    val textColor = when {
        isSelected -> MaterialTheme.colorScheme.onPrimary
        isToday -> MaterialTheme.colorScheme.primary
        else -> MaterialTheme.colorScheme.onSurface
    }

    val subtextColor = when {
        isSelected -> MaterialTheme.colorScheme.onPrimary
        isToday -> MaterialTheme.colorScheme.primary
        else -> MaterialTheme.colorScheme.onSurfaceVariant
    }

    val scale by animateFloatAsState(
        targetValue = if (isSelected) 1.08f else 1.0f,
        animationSpec = spring(dampingRatio = 0.7f, stiffness = 400f),
        label = "dayCellScale",
    )

    Column(
        modifier = Modifier
            .width(45.dp)
            .height(60.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(bgColor)
            .border(
                width = 1.dp,
                color = when {
                    isSelected -> Color.Transparent
                    isToday -> MaterialTheme.colorScheme.primary.copy(alpha = 0.3f)
                    else -> MaterialTheme.colorScheme.outlineVariant
                },
                shape = RoundedCornerShape(16.dp),
            )
            .clickable { onClick() }
            .padding(vertical = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            text = dayNameFmt.format(date).take(3).lowercase(),
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Medium,
            color = subtextColor,
            fontSize = 10.sp,
        )
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = dayNumberFmt.format(date),
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.Bold,
            color = textColor,
        )
    }
}

// ============================================================================
// MARK: - TaskListView (iOS lines 1101-1281)
// ============================================================================
@Composable
private fun TaskListView(
    viewModel: TimelineViewModel,
    tasks: List<TodoTask>,
    organization: TimelineOrganization,
    onNavigateToTaskDetail: (UUID) -> Unit,
    onStartPomodoroForTask: (TodoTask) -> Unit = {},
) {
    if (tasks.isEmpty()) {
        // Empty state (matches iOS)
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center,
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Icon(
                    Icons.Default.CalendarMonth,
                    contentDescription = null,
                    modifier = Modifier.size(64.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
                )
                Text(
                    text = viewModel.progressText(tasks),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Text(
                    text = stringResource(R.string.timeline_empty_state_cta),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                )
            }
        }
    } else {
        val organized = viewModel.organizedTasks(tasks)

        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .clickable(
                    interactionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() },
                    indication = null,
                ) { viewModel.closeAllSwipeMenus() },
            contentPadding = PaddingValues(horizontal = 4.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            when (organized) {
                is OrganizedTasks.Single -> {
                    items(organized.tasks, key = { it.id }) { task ->
                        TimelineTaskCard(
                            task = task,
                            viewModel = viewModel,
                            onNavigateToTaskDetail = onNavigateToTaskDetail,
                            onStartPomodoroForTask = onStartPomodoroForTask,
                        )
                    }
                }
                is OrganizedTasks.Sections -> {
                    organized.sections.forEach { section ->
                        item(key = "section-${section.id}") {
                            OrganizedTaskSectionView(
                                section = section,
                                viewModel = viewModel,
                                onNavigateToTaskDetail = onNavigateToTaskDetail,
                                onStartPomodoroForTask = onStartPomodoroForTask,
                            )
                        }
                    }
                }
            }

            // Bottom spacer for FAB
            item { Spacer(modifier = Modifier.height(100.dp)) }
        }
    }
}

// ============================================================================
// MARK: - OrganizedTaskSection (iOS lines 1283-1335)
// ============================================================================
@Composable
private fun OrganizedTaskSectionView(
    section: TaskSection,
    viewModel: TimelineViewModel,
    onNavigateToTaskDetail: (UUID) -> Unit,
    onStartPomodoroForTask: (TodoTask) -> Unit = {},
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        // Section header
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(MaterialTheme.colorScheme.surface)
                .border(
                    width = 1.dp,
                    color = section.color?.let { parseHexColor(it).copy(alpha = 0.2f) }
                        ?: MaterialTheme.colorScheme.outlineVariant,
                    shape = RoundedCornerShape(12.dp),
                )
                .padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                text = section.title,
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Spacer(modifier = Modifier.weight(1f))
            Text(
                text = "${section.tasks.size}",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier
                    .background(
                        MaterialTheme.colorScheme.surface,
                        RoundedCornerShape(4.dp),
                    )
                    .padding(horizontal = 6.dp, vertical = 2.dp),
            )
        }

        // Section tasks
        section.tasks.forEach { task ->
            TimelineTaskCard(
                task = task,
                viewModel = viewModel,
                onNavigateToTaskDetail = onNavigateToTaskDetail,
                onStartPomodoroForTask = onStartPomodoroForTask,
                onTrackTask = onStartPomodoroForTask,
            )
        }
    }
}

// ============================================================================
// MARK: - TimelineTaskCard (iOS lines 1445-2072)
// Full task card with swipe actions, category gradient, streaks, badges
// ============================================================================
@Composable
private fun TimelineTaskCard(
    task: TodoTask,
    viewModel: TimelineViewModel,
    onNavigateToTaskDetail: (UUID) -> Unit,
    onStartPomodoroForTask: (TodoTask) -> Unit = {},
    onTrackTask: (TodoTask) -> Unit = {},
) {
    var isExpanded by remember { mutableStateOf(false) }
    var dragOffset by remember { mutableFloatStateOf(0f) }
    val selectedDate by viewModel.selectedDate.collectAsState()
    val selectedScope by viewModel.selectedScope.collectAsState()
    val isCompleted = viewModel.isTaskCompleted(task)
    val completedSubtasks = viewModel.completedSubtasks(task)
    val completionProgress = viewModel.completionProgress(task)
    val currentStreak = task.streakForDate(selectedDate)

    // Category gradient background (matches iOS categoryGradient)
    val categoryColor = task.category?.let { parseHexColor(it.color) }
    val categoryGradient = if (categoryColor != null) {
        Brush.linearGradient(
            colors = listOf(
                categoryColor.copy(alpha = 0.12f),
                categoryColor.copy(alpha = 0.06f),
                categoryColor.copy(alpha = 0.02f),
                Color.Transparent,
            ),
        )
    } else null

    // Swipe state
    val isSwipeOpen by viewModel.openSwipeTaskId.collectAsState()
    val animatedOffset by animateFloatAsState(
        targetValue = dragOffset,
        animationSpec = spring(stiffness = 400f, dampingRatio = 0.75f),
        label = "swipeOffset",
    )

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 4.dp),
    ) {
        // Background swipe actions (matches iOS: Track, Edit, Delete)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .matchParentSize(),
            horizontalArrangement = Arrangement.End,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            val swipeVisible = abs(animatedOffset) > 40f
            AnimatedVisibility(visible = swipeVisible) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    // Track button
                    SwipeActionButton(
                        icon = Icons.Rounded.PlayArrow,
                        label = stringResource(id = R.string.task_detail_track),
                        color = Color(0xFFFFC107), // Amber/Yellow
                        onClick = {
                            dragOffset = 0f
                            viewModel.closeAllSwipeMenus()
                            onTrackTask(task)
                        },
                    )
                    // Edit button
                    SwipeActionButton(
                        icon = Icons.Default.Edit,
                        label = stringResource(id = R.string.action_edit),
                        color = Color(0xFFFF9800),
                        onClick = {
                            dragOffset = 0f
                            viewModel.closeAllSwipeMenus()
                            onNavigateToTaskDetail(task.id)
                        },
                    )
                    // Delete button
                    SwipeActionButton(
                        icon = Icons.Default.Delete,
                        label = stringResource(id = R.string.action_delete),
                        color = Color(0xFFF44336),
                        onClick = {
                            dragOffset = 0f
                            viewModel.closeAllSwipeMenus()
                            viewModel.deleteTask(task.id)
                        },
                    )
                }
            }
        }

        // Main card content
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .offset { IntOffset(animatedOffset.roundToInt(), 0) }
                .clip(RoundedCornerShape(14.dp))
                .shadow(
                    elevation = 2.dp,
                    shape = RoundedCornerShape(14.dp),
                    clip = false,
                )
                .background(MaterialTheme.colorScheme.surface)
                .then(
                    if (categoryGradient != null) Modifier.background(categoryGradient)
                    else Modifier
                )
                .then(
                    if (categoryColor != null) {
                        Modifier.border(
                            width = 1.dp,
                            brush = Brush.linearGradient(
                                colors = listOf(
                                    categoryColor.copy(alpha = 0.25f),
                                    categoryColor.copy(alpha = 0.08f),
                                ),
                            ),
                            shape = RoundedCornerShape(14.dp),
                        )
                    } else Modifier
                )
                .pointerInput(task.id) {
                    detectHorizontalDragGestures(
                        onDragEnd = {
                            if (dragOffset < -60f) {
                                viewModel.setOpenSwipeTask(task.id)
                                dragOffset = -180f
                            } else {
                                dragOffset = 0f
                                viewModel.closeAllSwipeMenus()
                            }
                        },
                        onHorizontalDrag = { _, dragAmount ->
                            if (dragAmount < 0 || dragOffset < 0) {
                                dragOffset = (dragOffset + dragAmount).coerceIn(-280f, 0f) // Increased swipe limit for 3 buttons
                            }
                        },
                    )
                }
                .clickable {
                    if (dragOffset != 0f) {
                        dragOffset = 0f
                        viewModel.closeAllSwipeMenus()
                    } else {
                        onNavigateToTaskDetail(task.id)
                    }
                }
                .animateContentSize(),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                // Category color bar (left edge, matches iOS 4px vertical bar)
                Box(
                    modifier = Modifier
                        .width(4.dp)
                        .height(40.dp)
                        .clip(RoundedCornerShape(2.dp))
                        .background(
                            brush = Brush.verticalGradient(
                                colors = listOf(
                                    categoryColor ?: MaterialTheme.colorScheme.onSurfaceVariant,
                                    (categoryColor ?: MaterialTheme.colorScheme.onSurfaceVariant)
                                        .copy(alpha = 0.7f),
                                ),
                            ),
                        ),
                )

                // Title + description column
                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(2.dp),
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        Text(
                            text = task.name,
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.weight(1f, fill = false),
                        )

                        // Streak badge (matches iOS flame icon)
                        if (task.recurrence != null && currentStreak > 0) {
                            Row(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(4.dp))
                                    .background(Color(0xFFFF9800).copy(alpha = 0.15f))
                                    .padding(horizontal = 4.dp, vertical = 1.dp),
                                horizontalArrangement = Arrangement.spacedBy(2.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Text(
                                    text = "🔥",
                                    fontSize = 12.sp,
                                )
                                Text(
                                    text = "$currentStreak",
                                    style = MaterialTheme.typography.labelSmall,
                                    fontWeight = FontWeight.Bold,
                                    color = Color(0xFFFF9800),
                                )
                            }
                        }
                    }

                    // Description
                    task.description?.let { desc ->
                        Text(
                            text = desc,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                }

                // Time/date badges (matches iOS trailing time info)
                if (selectedScope == TaskTimeScope.TODAY) {
                    if (task.hasSpecificTime) {
                        val timeFmt = remember { SimpleDateFormat("HH:mm", Locale.getDefault()) }
                        val t = if (task.recurrence != null) task.occurrenceDate(selectedDate)
                        else task.startTime
                        Text(
                            text = timeFmt.format(t),
                            style = MaterialTheme.typography.labelSmall,
                            fontFamily = FontFamily.Monospace,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier
                                .background(
                                    MaterialTheme.colorScheme.surface,
                                    RoundedCornerShape(4.dp),
                                )
                                .padding(horizontal = 6.dp, vertical = 2.dp),
                        )
                    } else {
                        Text(
                            text = stringResource(id = R.string.task_form_all_day),
                            style = MaterialTheme.typography.labelSmall,
                            color = Color(0xFF2196F3),
                            modifier = Modifier
                                .background(
                                    Color(0xFF2196F3).copy(alpha = 0.1f),
                                    RoundedCornerShape(4.dp),
                                )
                                .padding(horizontal = 6.dp, vertical = 2.dp),
                        )
                    }
                } else {
                    // Non-today scopes: Show Date Badge (+ Time if specific)
                    val dateBadgeText = remember(task, selectedScope, selectedDate) {
                        val date = if (task.recurrence != null) task.occurrenceDate(selectedDate) else task.startTime
                        val pattern = when (selectedScope) {
                            TaskTimeScope.WEEK -> "EEE d"
                            TaskTimeScope.MONTH, TaskTimeScope.YEAR -> "d MMM"
                            else -> "d MMM yyyy"
                        }
                        SimpleDateFormat(pattern, Locale.getDefault()).format(date)
                    }
                    
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text(
                            text = dateBadgeText,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier
                                .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(4.dp))
                                .padding(horizontal = 6.dp, vertical = 2.dp)
                        )
                        
                        if (task.hasSpecificTime) {
                            val timeFmt = remember { SimpleDateFormat("HH:mm", Locale.getDefault()) }
                            val t = if (task.recurrence != null) task.occurrenceDate(selectedDate) else task.startTime
                            Text(
                                text = timeFmt.format(t),
                                style = MaterialTheme.typography.labelSmall,
                                fontFamily = FontFamily.Monospace,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier
                                    .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(4.dp))
                                    .padding(horizontal = 6.dp, vertical = 2.dp)
                            )
                        }
                    }
                }

                // Priority icon
                Icon(
                    imageVector = when (task.priority) {
                        Priority.HIGH -> Icons.Default.ArrowUpward
                        Priority.MEDIUM -> Icons.Default.Remove
                        Priority.LOW -> Icons.Default.ArrowDownward
                    },
                    contentDescription = task.priority.displayName,
                    modifier = Modifier.size(12.dp),
                    tint = task.priority.color,
                )

                // Pomodoro button (matches iOS 36dp circle)
                if (task.pomodoroSettings != null) {
                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .clip(CircleShape)
                            .background(MaterialTheme.colorScheme.tertiary.copy(alpha = 0.15f))
                            .border(
                                width = 1.dp,
                                color = MaterialTheme.colorScheme.tertiary.copy(alpha = 0.5f),
                                shape = CircleShape,
                            )
                            .clickable { onStartPomodoroForTask(task) },
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            Icons.Default.Timer,
                            contentDescription = "Focus",
                            modifier = Modifier.size(16.dp),
                            tint = categoryColor ?: MaterialTheme.colorScheme.tertiary,
                        )
                    }
                }

                // Expand chevron (for subtasks, matches iOS)
                if (task.subtasks.isNotEmpty()) {
                    val rotation by animateFloatAsState(
                        targetValue = if (isExpanded) 180f else 0f,
                        animationSpec = spring(stiffness = 400f, dampingRatio = 0.6f),
                        label = "chevronRotation",
                    )
                    IconButton(
                        onClick = { isExpanded = !isExpanded },
                        modifier = Modifier.size(24.dp),
                    ) {
                        Icon(
                            Icons.Default.ExpandMore,
                            contentDescription = if (isExpanded) "Collapse" else "Expand",
                            modifier = Modifier
                                .size(12.dp)
                                .rotate(rotation),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }

                // Completion button (matches iOS: circle with progress ring + checkmark)
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clickable {
                            viewModel.toggleTaskCompletion(task.id)
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    // Outer circle border
                    Box(
                        modifier = Modifier
                            .size(32.dp)
                            .border(
                                width = 2.dp,
                                color = MaterialTheme.colorScheme.outlineVariant,
                                shape = CircleShape,
                            ),
                    )

                    // Progress ring for subtasks
                    if (task.subtasks.isNotEmpty() && completionProgress > 0) {
                        CircularProgressIndicator(
                            progress = { completionProgress.toFloat() },
                            modifier = Modifier.size(32.dp),
                            color = MaterialTheme.colorScheme.primary,
                            strokeWidth = 3.dp,
                            trackColor = Color.Transparent,
                        )
                    }

                    // Checkmark icon
                    Icon(
                        imageVector = if (isCompleted) Icons.Default.CheckCircle
                        else Icons.Outlined.Circle,
                        contentDescription = if (isCompleted) "Completed" else "Mark complete",
                        modifier = Modifier.size(28.dp),
                        tint = if (isCompleted) Color(0xFF4CAF50)
                        else MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }

            // Subtasks (expanded, matches iOS)
            if (isExpanded && task.subtasks.isNotEmpty()) {
                Column(
                    modifier = Modifier.padding(vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    task.subtasks.forEach { subtask ->
                        TimelineSubtaskRow(
                            subtask = subtask,
                            isCompleted = subtask.id in completedSubtasks,
                            onToggle = { viewModel.toggleSubtask(task.id, subtask.id) },
                        )
                    }
                }
            }
        }
    }
}

// ============================================================================
// MARK: - SwipeActionButton
// ============================================================================
@Composable
private fun SwipeActionButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    color: Color,
    onClick: () -> Unit,
) {
    Column(
        modifier = Modifier.clickable { onClick() },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Box(
            modifier = Modifier
                .size(50.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(color),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = label,
                modifier = Modifier.size(18.dp),
                tint = Color.White,
            )
        }
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Medium,
            color = color,
            fontSize = 10.sp,
        )
    }
}

// ============================================================================
// MARK: - TimelineSubtaskRow (iOS lines 2124-2150)
// ============================================================================
@Composable
private fun TimelineSubtaskRow(
    subtask: Subtask,
    isCompleted: Boolean,
    onToggle: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(32.dp)
                .clickable { onToggle() },
            contentAlignment = Alignment.Center,
        ) {
            SubtaskCheckmark(isCompleted = isCompleted)
        }
        Text(
            text = subtask.name,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface,
        )
        Spacer(modifier = Modifier.weight(1f))
    }
}

@Composable
private fun SubtaskCheckmark(isCompleted: Boolean) {
    Box(modifier = Modifier.size(18.dp), contentAlignment = Alignment.Center) {
        if (isCompleted) {
            Box(
                modifier = Modifier
                    .size(18.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.primary),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    Icons.Default.Check,
                    contentDescription = "Completed",
                    modifier = Modifier.size(10.dp),
                    tint = Color.White,
                )
            }
        } else {
            Box(
                modifier = Modifier
                    .size(18.dp)
                    .border(1.5.dp, Color.Gray.copy(alpha = 0.5f), CircleShape),
            )
        }
    }
}

// ============================================================================
// MARK: - TimelineContentView (hourly timeline, iOS lines 266-412)
// ============================================================================
@Composable
private fun TimelineContentView(
    viewModel: TimelineViewModel,
    tasks: List<TodoTask>,
    onNavigateToTaskDetail: (UUID) -> Unit,
    onStartPomodoroForTask: (TodoTask) -> Unit = {},
) {
    val currentHour = remember { Calendar.getInstance().get(Calendar.HOUR_OF_DAY) }
    val currentMinute = remember { Calendar.getInstance().get(Calendar.MINUTE) }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 8.dp),
    ) {
        // All-day tasks section
        val allDay = viewModel.allDayTasks(tasks)
        if (allDay.isNotEmpty()) {
            item {
                Column(
                    modifier = Modifier.padding(bottom = 12.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Text(
                        text = stringResource(id = R.string.task_form_all_day),
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(start = 8.dp),
                    )
                    allDay.forEach { task ->
                        TimelineTaskCard(
                            task = task,
                            viewModel = viewModel,
                            onNavigateToTaskDetail = onNavigateToTaskDetail,
                            onStartPomodoroForTask = onStartPomodoroForTask,
                        )
                    }
                    HorizontalDivider(
                        color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.3f),
                    )
                }
            }
        }

        // Hourly rows (0-23)
        items(24) { hour ->
            val hourTasks = viewModel.tasksForHour(tasks, hour)
            val isCurrentHour = hour == currentHour

            EnhancedTimelineHourRow(
                hour = hour,
                tasks = hourTasks,
                isCurrentHour = isCurrentHour,
                currentMinute = if (isCurrentHour) currentMinute else null,
                viewModel = viewModel,
                onNavigateToTaskDetail = onNavigateToTaskDetail,
                onStartPomodoroForTask = onStartPomodoroForTask,
                isLastHour = hour == 23,
            )
        }

        // Bottom spacer for FAB
        item { Spacer(modifier = Modifier.height(100.dp)) }
    }
}

// ============================================================================
// MARK: - EnhancedTimelineHourRow (iOS lines 414-583)
// ============================================================================
@Composable
private fun EnhancedTimelineHourRow(
    hour: Int,
    tasks: List<TodoTask>,
    isCurrentHour: Boolean,
    currentMinute: Int?,
    viewModel: TimelineViewModel,
    onNavigateToTaskDetail: (UUID) -> Unit,
    onStartPomodoroForTask: (TodoTask) -> Unit = {},
    isLastHour: Boolean,
) {
    val hourString = remember(hour) { String.format(Locale.getDefault(), "%02d:00", hour) }

    Column {
        Row(
            modifier = Modifier.padding(vertical = 6.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // Time column (matches iOS 60dp width)
            Column(
                modifier = Modifier.width(60.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text(
                    text = hourString,
                    style = MaterialTheme.typography.labelSmall,
                    fontFamily = FontFamily.Monospace,
                    fontWeight = if (isCurrentHour) FontWeight.Bold else FontWeight.Medium,
                    color = if (isCurrentHour) MaterialTheme.colorScheme.primary
                    else MaterialTheme.colorScheme.onSurfaceVariant,
                )

                if (isCurrentHour) {
                    Box(
                        modifier = Modifier
                            .size(10.dp)
                            .clip(CircleShape)
                            .background(MaterialTheme.colorScheme.primary),
                    )
                    currentMinute?.let { min ->
                        Text(
                            text = String.format(Locale.getDefault(), "%02d", min),
                            style = MaterialTheme.typography.labelSmall,
                            fontFamily = FontFamily.Monospace,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.primary,
                            fontSize = 10.sp,
                        )
                    }
                    Text(
                        text = "NOW",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.primary,
                        fontSize = 10.sp,
                    )
                }
            }

            // Task content area
            Column(
                modifier = Modifier
                    .weight(1f)
                    .then(
                        if (isCurrentHour) {
                            Modifier
                                .clip(RoundedCornerShape(16.dp))
                                .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.05f))
                                .border(
                                    1.5.dp,
                                    MaterialTheme.colorScheme.primary.copy(alpha = 0.2f),
                                    RoundedCornerShape(16.dp),
                                )
                        } else Modifier
                    ),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                if (tasks.isNotEmpty()) {
                    tasks.forEach { task ->
                        TimelineTaskCard(
                            task = task,
                            viewModel = viewModel,
                            onNavigateToTaskDetail = onNavigateToTaskDetail,
                            onStartPomodoroForTask = onStartPomodoroForTask,
                        )
                    }
                } else {
                    // Empty slot
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(50.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(
                                if (isCurrentHour) MaterialTheme.colorScheme.primary.copy(alpha = 0.08f)
                                else MaterialTheme.colorScheme.surface,
                            ),
                        contentAlignment = Alignment.CenterStart,
                    ) {
                        if (isCurrentHour && currentMinute != null) {
                            // Current time indicator line
                            Row(
                                modifier = Modifier.padding(horizontal = 12.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(6.dp)
                                        .clip(CircleShape)
                                        .background(MaterialTheme.colorScheme.primary),
                                )
                                Box(
                                    modifier = Modifier
                                        .weight(1f)
                                        .height(2.dp)
                                        .background(
                                            MaterialTheme.colorScheme.primary.copy(alpha = 0.6f),
                                        ),
                                )
                            }
                        }
                    }
                }
            }
        }

        // Connection line between hours (matches iOS)
        if (!isLastHour) {
            Row(modifier = Modifier.padding(start = 30.dp)) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    if (tasks.isNotEmpty()) {
                        Box(
                            modifier = Modifier
                                .width(2.dp)
                                .height(20.dp)
                                .background(
                                    brush = Brush.verticalGradient(
                                        colors = listOf(
                                            if (isCurrentHour) MaterialTheme.colorScheme.primary.copy(alpha = 0.6f)
                                            else MaterialTheme.colorScheme.outlineVariant,
                                            MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.1f),
                                        ),
                                    ),
                                ),
                        )
                    } else {
                        // Dotted line for empty periods
                        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                            repeat(4) {
                                Box(
                                    modifier = Modifier
                                        .size(2.dp)
                                        .clip(CircleShape)
                                        .background(MaterialTheme.colorScheme.outlineVariant),
                                )
                            }
                        }
                    }
                    HorizontalDivider(
                        color = if (isCurrentHour) MaterialTheme.colorScheme.primary.copy(alpha = 0.4f)
                        else MaterialTheme.colorScheme.outlineVariant,
                    )
                }
            }
        }
    }
}

// ============================================================================
// MARK: - AddTaskButton (iOS lines 2074-2122)
// ============================================================================
@Composable
private fun AddTaskButton(
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    var isPressed by remember { mutableStateOf(false) }

    val scale by animateFloatAsState(
        targetValue = if (isPressed) 0.95f else 1.0f,
        animationSpec = spring(stiffness = 600f, dampingRatio = 0.6f),
        label = "fabScale",
    )

    Box(
        modifier = modifier
            .size(56.dp)
            .shadow(
                elevation = 8.dp,
                shape = CircleShape,
                clip = false,
            )
            .clip(CircleShape)
            .background(
                brush = Brush.linearGradient(
                    colors = listOf(
                        MaterialTheme.colorScheme.primary,
                        MaterialTheme.colorScheme.secondary,
                    ),
                ),
            )
            .clickable {
                isPressed = true
                onClick()
            },
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            Icons.Default.Add,
            contentDescription = "Add Task",
            modifier = Modifier.size(24.dp),
            tint = MaterialTheme.colorScheme.onPrimary,
        )
    }
}
