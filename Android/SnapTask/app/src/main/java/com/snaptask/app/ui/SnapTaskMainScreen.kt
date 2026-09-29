package com.snaptask.app.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.snaptask.app.data.model.TodoTask
import com.snaptask.app.ui.focus.FocusScreen
import com.snaptask.app.ui.finance.FinanceScreen
import com.snaptask.app.ui.statistics.StatisticsScreen
import com.snaptask.app.ui.statistics.StatisticsViewModel
import com.snaptask.app.ui.statistics.TaskPerformanceDetailScreen
import com.snaptask.app.ui.navigation.BottomNavItem
import com.snaptask.app.ui.rewards.RewardsScreen
import com.snaptask.app.ui.settings.SettingsScreen
import com.snaptask.app.ui.timeline.TaskDetailScreen
import com.snaptask.app.ui.timeline.TaskFormScreen
import com.snaptask.app.ui.timeline.TimelineOrganizationView
import com.snaptask.app.ui.journal.JournalScreen
import com.snaptask.app.ui.journal.JournalViewModel
import com.snaptask.app.R
import com.snaptask.app.ui.components.TaskCreationOptionsScreen
import com.snaptask.app.ui.focus.TrackingModeSelectionScreen
import com.snaptask.app.ui.timeline.TimelineScreen
import com.snaptask.app.ui.timeline.TimelineViewModel
import com.snaptask.app.data.model.TrackingMode
import java.util.Calendar
import java.util.Date
import java.util.UUID

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SnapTaskMainScreen() {
    var selectedTab by rememberSaveable { mutableIntStateOf(0) }
    val tabs = BottomNavItem.entries

    // Shared ViewModel across timeline tab screens
    val timelineViewModel: TimelineViewModel = hiltViewModel()

    // Sheet / dialog state
    var showCreateTask by remember { mutableStateOf(false) }
    var showCreateTaskOptions by remember { mutableStateOf(false) }
    var showTaskDetail by remember { mutableStateOf<UUID?>(null) }
    var editingTask by remember { mutableStateOf<TodoTask?>(null) }
    var templatePrefill by remember { mutableStateOf<Pair<String, String>?>(null) }
    var showSettings by remember { mutableStateOf(false) }
    var showJournal by remember { mutableStateOf(false) }
    var showTimelineOrganization by remember { mutableStateOf(false) }
    var journalDate by remember { mutableStateOf(Date()) }
    var showCalendar by remember { mutableStateOf(false) }
    var pendingPomodoroTask by remember { mutableStateOf<TodoTask?>(null) }
    var showTrackingModeSheet by remember { mutableStateOf(false) }
    var performanceTaskId by remember { mutableStateOf<UUID?>(null) }
    val statisticsViewModel: StatisticsViewModel = hiltViewModel()

    Scaffold(
        bottomBar = {
            NavigationBar(
                containerColor = MaterialTheme.colorScheme.surface,
                contentColor = MaterialTheme.colorScheme.onSurface,
            ) {
                tabs.forEachIndexed { index, item ->
                    NavigationBarItem(
                        selected = selectedTab == index,
                        onClick = { selectedTab = index },
                        icon = {
                            Icon(
                                imageVector = if (selectedTab == index) item.selectedIcon else item.unselectedIcon,
                                contentDescription = stringResource(item.labelResId),
                            )
                        },
                        label = {
                            Text(
                                text = stringResource(item.labelResId),
                                fontSize = 11.sp,
                                fontWeight = if (selectedTab == index) FontWeight.SemiBold else FontWeight.Normal,
                            )
                        },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = MaterialTheme.colorScheme.primary,
                            selectedTextColor = MaterialTheme.colorScheme.primary,
                            unselectedIconColor = MaterialTheme.colorScheme.onSurfaceVariant,
                            unselectedTextColor = MaterialTheme.colorScheme.onSurfaceVariant,
                            // iOS tabs tint the selected symbol and label without
                            // the Material 3 selection pill.
                            indicatorColor = Color.Transparent,
                        ),
                    )
                }
            }
        }
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
        ) {
            when (tabs[selectedTab]) {
                BottomNavItem.TIMELINE -> {
                    val selectedDate by timelineViewModel.selectedDate.collectAsState()
                    TimelineScreen(
                        viewModel = timelineViewModel,
                        onNavigateToTaskDetail = { taskId -> showTaskDetail = taskId },
                        onNavigateToCreateTask = { showCreateTaskOptions = true },
                        onNavigateToSettings = { showSettings = true },
                        onNavigateToJournal = {
                            journalDate = selectedDate
                            showJournal = true
                        },
                        onOpenCalendar = { showCalendar = true },
                        onOpenTimelineOrganization = { showTimelineOrganization = true },
                        onStartPomodoroForTask = { task ->
                            pendingPomodoroTask = task
                            selectedTab = 1
                        },
                    )
                }
                BottomNavItem.FOCUS -> FocusScreen(
                    pendingPomodoroTask = pendingPomodoroTask,
                    onClearPendingPomodoroTask = { pendingPomodoroTask = null },
                )
                BottomNavItem.REWARDS -> RewardsScreen()
                BottomNavItem.FINANCE -> FinanceScreen()
                BottomNavItem.STATISTICS -> StatisticsScreen()
            }
        }
    }

    // Task creation options bottom sheet (matches iOS TaskCreationOptionsView)
    if (showCreateTaskOptions) {
        ModalBottomSheet(
            onDismissRequest = {
                showCreateTaskOptions = false
                templatePrefill = null
            },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        ) {
            TaskCreationOptionsScreen(
                onCreateTask = { defaultName, templateTitle ->
                    templatePrefill = defaultName to templateTitle
                    showCreateTaskOptions = false
                    showCreateTask = true
                },
                onCreateBlank = {
                    templatePrefill = null
                    showCreateTaskOptions = false
                    showCreateTask = true
                },
                onDismiss = {
                    showCreateTaskOptions = false
                    templatePrefill = null
                },
            )
        }
    }

    // Task creation bottom sheet
    if (showCreateTask) {
        val categories by timelineViewModel.categories.collectAsState()
        val selectedDate by timelineViewModel.selectedDate.collectAsState()
        val selectedScope by timelineViewModel.selectedScope.collectAsState()

        ModalBottomSheet(
            onDismissRequest = { showCreateTask = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        ) {
            TaskFormScreen(
                initialTask = editingTask ?: templatePrefill?.let { (name, templateTitle) ->
                    TodoTask(name = name, description = templateTitle)
                },
                categories = categories,
                selectedDate = selectedDate,
                initialTimeScope = selectedScope,
                onSave = { task ->
                    if (editingTask != null) {
                        timelineViewModel.updateTask(task)
                    } else {
                        timelineViewModel.addTask(task)
                    }
                    showCreateTask = false
                    editingTask = null
                    templatePrefill = null
                },
                onDismiss = {
                    showCreateTask = false
                    editingTask = null
                    templatePrefill = null
                },
            )
        }
    }

    // Task detail bottom sheet
    showTaskDetail?.let { taskId ->
        val tasks by timelineViewModel.tasksForSelectedDate.collectAsState()
        val task = tasks.find { it.id == taskId }

        if (task != null) {
            ModalBottomSheet(
                onDismissRequest = { showTaskDetail = null },
                sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
            ) {
                TaskDetailScreen(
                    task = task,
                    isCompleted = timelineViewModel.isTaskCompleted(task),
                    onToggleCompletion = { timelineViewModel.toggleTaskCompletion(task.id) },
                    onUpdateTask = { updated -> timelineViewModel.updateTask(updated) },
                    onEdit = {
                        showTaskDetail = null
                        editingTask = task
                        showCreateTask = true
                    },
                    onDelete = {
                        timelineViewModel.deleteTask(task.id)
                        showTaskDetail = null
                    },
                    onStartPomodoro = {
                        pendingPomodoroTask = task
                        showTaskDetail = null
                        selectedTab = 1
                    },
                    onShowTrackingMode = {
                        showTaskDetail = null
                        showTrackingModeSheet = true
                    },
                    onOpenPerformance = { task ->
                        performanceTaskId = task.id
                        showTaskDetail = null
                    },
                    onDismiss = { showTaskDetail = null },
                )
            }
        } else {
            showTaskDetail = null
        }
    }

    // Settings bottom sheet
    if (showSettings) {
        ModalBottomSheet(
            onDismissRequest = { showSettings = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        ) {
            SettingsScreen(
                onDismiss = { showSettings = false },
            )
        }
    }

    // Calendar picker (matches iOS MediaHubCalendarView)
    if (showCalendar) {
        val pickerDate by timelineViewModel.selectedDate.collectAsState()
        val cal = remember(pickerDate) { Calendar.getInstance().apply { time = pickerDate } }
        val datePickerState = rememberDatePickerState(
            initialSelectedDateMillis = cal.timeInMillis,
            yearRange = IntRange(cal.get(Calendar.YEAR) - 1, cal.get(Calendar.YEAR) + 1),
        )
        DatePickerDialog(
            onDismissRequest = { showCalendar = false },
            confirmButton = {
                TextButton(
                    onClick = {
                        datePickerState.selectedDateMillis?.let { millis ->
                            timelineViewModel.selectDate(Date(millis))
                        }
                        showCalendar = false
                    },
                ) {
                    Text(stringResource(R.string.action_done))
                }
            },
            dismissButton = {
                TextButton(onClick = { showCalendar = false }) {
                    Text(stringResource(R.string.action_cancel))
                }
            },
        ) {
            DatePicker(state = datePickerState)
        }
    }

    // Task Performance sheet (from Task Detail Performance link)
    performanceTaskId?.let { taskId ->
        val performanceAnalytics by statisticsViewModel.taskPerformanceAnalytics.collectAsState()
        val analytics = performanceAnalytics.find { it.taskId == taskId }
        ModalBottomSheet(
            onDismissRequest = { performanceTaskId = null },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        ) {
            if (analytics != null) {
                TaskPerformanceDetailScreen(
                    task = analytics,
                    onDismiss = { performanceTaskId = null },
                )
            } else {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(24.dp),
                ) {
                    Text(
                        text = stringResource(R.string.task_performance_no_data),
                        style = MaterialTheme.typography.bodyLarge,
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                    TextButton(
                        onClick = { performanceTaskId = null },
                    ) {
                        Text(stringResource(R.string.action_done))
                    }
                }
            }
        }
    }

    // Tracking mode selection sheet (from Task Detail Track button)
    if (showTrackingModeSheet) {
        ModalBottomSheet(
            onDismissRequest = { showTrackingModeSheet = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        ) {
            TrackingModeSelectionScreen(
                currentMode = TrackingMode.POMODORO,
                onModeSelected = {
                    showTrackingModeSheet = false
                    selectedTab = 1
                },
                onDismiss = { showTrackingModeSheet = false },
            )
        }
    }

    // Timeline Organization sheet
    if (showTimelineOrganization) {
        ModalBottomSheet(
            onDismissRequest = { showTimelineOrganization = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        ) {
            TimelineOrganizationView(
                viewModel = timelineViewModel,
                onDismiss = { showTimelineOrganization = false },
            )
        }
    }
    if (showJournal) {
        val journalViewModel: JournalViewModel = hiltViewModel()
        val journalEntries by journalViewModel.entries.collectAsState()
        ModalBottomSheet(
            onDismissRequest = { showJournal = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        ) {
            JournalScreen(
                initialDate = journalDate,
                entries = journalEntries,
                onSave = { entry -> journalViewModel.saveEntry(entry) },
                onDismiss = { showJournal = false },
            )
        }
    }
}

@Composable
private fun PlaceholderScreen(name: String) {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = name,
            style = MaterialTheme.typography.headlineMedium,
            color = MaterialTheme.colorScheme.onBackground,
        )
    }
}
