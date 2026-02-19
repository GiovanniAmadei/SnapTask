package com.snaptask.app.ui.timeline

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.snaptask.app.data.model.*
import com.snaptask.app.data.repository.TaskRepository
import com.snaptask.app.notifications.TaskNotificationScheduler
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*
import javax.inject.Inject

/**
 * Faithful port of iOS TimelineViewModel.
 * Manages all state for the timeline: date selection, scope, view mode, organization,
 * task filtering, navigation between periods, and swipe menu state.
 */
@HiltViewModel
class TimelineViewModel @Inject constructor(
    private val taskRepository: TaskRepository,
    private val taskNotificationScheduler: TaskNotificationScheduler,
) : ViewModel() {

    // ---- State ----

    private val _selectedDate = MutableStateFlow(Date())
    val selectedDate: StateFlow<Date> = _selectedDate.asStateFlow()

    private val _selectedScope = MutableStateFlow(TaskTimeScope.TODAY)
    val selectedScope: StateFlow<TaskTimeScope> = _selectedScope.asStateFlow()

    private val _viewMode = MutableStateFlow(TimelineViewMode.LIST)
    val viewMode: StateFlow<TimelineViewMode> = _viewMode.asStateFlow()

    private val _organization = MutableStateFlow(TimelineOrganization.NONE)
    val organization: StateFlow<TimelineOrganization> = _organization.asStateFlow()

    private val _timeSortOrder = MutableStateFlow(TimeSortOrder.ASCENDING)
    val timeSortOrder: StateFlow<TimeSortOrder> = _timeSortOrder.asStateFlow()

    // Sheet visibility states
    private val _showingFilterSheet = MutableStateFlow(false)
    val showingFilterSheet: StateFlow<Boolean> = _showingFilterSheet.asStateFlow()

    private val _showingTimelineView = MutableStateFlow(false)
    val showingTimelineView: StateFlow<Boolean> = _showingTimelineView.asStateFlow()

    // Timeline hours configuration
    val timelineStartHour: Int = 6
    val timelineEndHour: Int = 22

    // Period references for week/month/year navigation
    private val _currentWeek = MutableStateFlow(Recurrence.startOfWeek(Date()))
    val currentWeek: StateFlow<Date> = _currentWeek.asStateFlow()

    private val _currentMonth = MutableStateFlow(Recurrence.startOfMonth(Date()))
    val currentMonth: StateFlow<Date> = _currentMonth.asStateFlow()

    private val _currentYear = MutableStateFlow(startOfYear(Date()))
    val currentYear: StateFlow<Date> = _currentYear.asStateFlow()

    // Swipe menu state (only one task can have swipe open at a time)
    private val _openSwipeTaskId = MutableStateFlow<UUID?>(null)
    val openSwipeTaskId: StateFlow<UUID?> = _openSwipeTaskId.asStateFlow()

    // Show history toggle for ALL scope (matches iOS)
    private val _showAllHistory = MutableStateFlow(false)
    val showAllHistory: StateFlow<Boolean> = _showAllHistory.asStateFlow()

    /**
     * Tasks filtered for the selected date/scope.
     */
    val tasksForSelectedDate: StateFlow<List<TodoTask>> = combine(
        taskRepository.allTasks,
        _selectedDate,
        _selectedScope,
        _showAllHistory,
    ) { allTasks, date, scope, showHistory ->
        filterTasks(allTasks, date, scope, showHistory)
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = emptyList(),
    )

    val categories: StateFlow<List<Category>> = taskRepository.allCategories.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = emptyList(),
    )

    // ---- Computed Properties ----

    val isToday: Boolean
        get() = TodoTask.isSameDay(_selectedDate.value, Date())

    /**
     * Progress text matching iOS: "X of Y completed"
     */
    fun progressText(tasks: List<TodoTask>): String {
        val completed = tasks.count { isTaskCompleted(it) }
        return "$completed of ${tasks.size} completed"
    }

    /**
     * Header text showing current period string, matching iOS currentPeriodString.
     */
    val currentPeriodString: String
        get() {
            val scope = _selectedScope.value
            return when (scope) {
                TaskTimeScope.TODAY -> {
                    val cal = Calendar.getInstance()
                    val today = Calendar.getInstance()
                    cal.time = _selectedDate.value
                    when {
                        TodoTask.isSameDay(_selectedDate.value, Date()) -> "Today"
                        run {
                            today.add(Calendar.DAY_OF_YEAR, -1)
                            TodoTask.isSameDay(_selectedDate.value, today.time)
                        } -> "Yesterday"
                        run {
                            val tmr = Calendar.getInstance()
                            tmr.add(Calendar.DAY_OF_YEAR, 1)
                            TodoTask.isSameDay(_selectedDate.value, tmr.time)
                        } -> "Tomorrow"
                        else -> {
                            val fmt = SimpleDateFormat("EEEE, d MMM", Locale.getDefault())
                            fmt.format(_selectedDate.value)
                        }
                    }
                }
                TaskTimeScope.WEEK -> {
                    val fmt = SimpleDateFormat("d MMM", Locale.getDefault())
                    val weekEnd = Calendar.getInstance().apply {
                        time = _currentWeek.value
                        add(Calendar.DAY_OF_YEAR, 6)
                    }
                    "${fmt.format(_currentWeek.value)} - ${fmt.format(weekEnd.time)}"
                }
                TaskTimeScope.MONTH -> {
                    val fmt = SimpleDateFormat("MMMM yyyy", Locale.getDefault())
                    fmt.format(_currentMonth.value)
                }
                TaskTimeScope.YEAR -> {
                    val fmt = SimpleDateFormat("yyyy", Locale.getDefault())
                    fmt.format(_currentYear.value)
                }
                TaskTimeScope.LONG_TERM -> "Long Term"
                TaskTimeScope.ALL -> "All Tasks"
            }
        }

    val canNavigatePrevious: Boolean
        get() = _selectedScope.value != TaskTimeScope.TODAY &&
                _selectedScope.value != TaskTimeScope.LONG_TERM &&
                _selectedScope.value != TaskTimeScope.ALL

    val canNavigateNext: Boolean
        get() = canNavigatePrevious

    // ---- Actions ----

    fun selectDate(date: Date) {
        _selectedDate.value = date
    }

    fun selectDateByOffset(offset: Int) {
        val cal = Calendar.getInstance()
        cal.add(Calendar.DAY_OF_YEAR, offset)
        _selectedDate.value = cal.time
    }

    fun goToToday() {
        _selectedDate.value = Date()
        _currentWeek.value = Recurrence.startOfWeek(Date())
        _currentMonth.value = Recurrence.startOfMonth(Date())
        _currentYear.value = startOfYear(Date())
    }

    fun goToPreviousDay() {
        val cal = Calendar.getInstance()
        cal.time = _selectedDate.value
        cal.add(Calendar.DAY_OF_YEAR, -1)
        _selectedDate.value = cal.time
    }

    fun goToNextDay() {
        val cal = Calendar.getInstance()
        cal.time = _selectedDate.value
        cal.add(Calendar.DAY_OF_YEAR, 1)
        _selectedDate.value = cal.time
    }

    fun selectScope(scope: TaskTimeScope) {
        _selectedScope.value = scope
        // iOS: timeline view mode only valid for .today
        if (scope != TaskTimeScope.TODAY && _viewMode.value == TimelineViewMode.TIMELINE) {
            _viewMode.value = TimelineViewMode.LIST
        }
        if (scope != TaskTimeScope.TODAY && _organization.value == TimelineOrganization.TIME) {
            _organization.value = TimelineOrganization.NONE
        }
    }

    fun setViewMode(mode: TimelineViewMode) {
        _viewMode.value = mode
    }

    fun setOrganization(org: TimelineOrganization) {
        _organization.value = org
    }

    fun navigateToPrevious() {
        val cal = Calendar.getInstance()
        when (_selectedScope.value) {
            TaskTimeScope.WEEK -> {
                cal.time = _currentWeek.value
                cal.add(Calendar.WEEK_OF_YEAR, -1)
                _currentWeek.value = Recurrence.startOfWeek(cal.time)
            }
            TaskTimeScope.MONTH -> {
                cal.time = _currentMonth.value
                cal.add(Calendar.MONTH, -1)
                _currentMonth.value = Recurrence.startOfMonth(cal.time)
            }
            TaskTimeScope.YEAR -> {
                cal.time = _currentYear.value
                cal.add(Calendar.YEAR, -1)
                _currentYear.value = startOfYear(cal.time)
            }
            else -> {}
        }
    }

    fun navigateToNext() {
        val cal = Calendar.getInstance()
        when (_selectedScope.value) {
            TaskTimeScope.WEEK -> {
                cal.time = _currentWeek.value
                cal.add(Calendar.WEEK_OF_YEAR, 1)
                _currentWeek.value = Recurrence.startOfWeek(cal.time)
            }
            TaskTimeScope.MONTH -> {
                cal.time = _currentMonth.value
                cal.add(Calendar.MONTH, 1)
                _currentMonth.value = Recurrence.startOfMonth(cal.time)
            }
            TaskTimeScope.YEAR -> {
                cal.time = _currentYear.value
                cal.add(Calendar.YEAR, 1)
                _currentYear.value = startOfYear(cal.time)
            }
            else -> {}
        }
    }

    fun toggleTaskCompletion(taskId: UUID) {
        viewModelScope.launch {
            taskRepository.toggleCompletion(taskId, _selectedDate.value)
        }
    }

    fun toggleSubtask(taskId: UUID, subtaskId: UUID) {
        viewModelScope.launch {
            taskRepository.toggleSubtask(taskId, subtaskId)
        }
    }

    fun addTask(task: TodoTask) {
        viewModelScope.launch {
            taskRepository.addTask(task)
            taskNotificationScheduler.scheduleReminder(task)
        }
    }

    fun updateTask(task: TodoTask) {
        viewModelScope.launch {
            taskRepository.updateTask(task)
            taskNotificationScheduler.scheduleReminder(task)
        }
    }

    fun deleteTask(taskId: UUID) {
        viewModelScope.launch {
            taskNotificationScheduler.cancelReminder(taskId)
            taskRepository.deleteTaskById(taskId)
        }
    }

    // ---- Swipe menu ----

    fun setOpenSwipeTask(taskId: UUID?) {
        _openSwipeTaskId.value = taskId
    }

    fun isSwipeMenuOpen(taskId: UUID): Boolean {
        return _openSwipeTaskId.value == taskId
    }

    fun closeAllSwipeMenus() {
        _openSwipeTaskId.value = null
    }

    // ---- Show All History Toggle ----

    fun toggleShowAllHistory() {
        _showAllHistory.value = !_showAllHistory.value
    }

    // Organization status text (matches iOS)
    val organizationStatusText: String
        get() = when (_organization.value) {
            TimelineOrganization.NONE -> "Sorted by time"
            TimelineOrganization.TIME -> "Organized by time"
            TimelineOrganization.CATEGORY -> "Grouped by category"
            TimelineOrganization.PRIORITY -> "Sorted by priority"
            TimelineOrganization.EISENHOWER -> "Eisenhower matrix"
        }

    fun setTimeSortOrder(order: TimeSortOrder) {
        _timeSortOrder.value = order
    }

    fun showFilterSheet() {
        _showingFilterSheet.value = true
    }

    fun hideFilterSheet() {
        _showingFilterSheet.value = false
    }

    fun showTimelineView() {
        _showingTimelineView.value = true
    }

    fun hideTimelineView() {
        _showingTimelineView.value = false
    }

    // Timeline range calculation (matches iOS logic)
    fun getTimelineRange(tasks: List<TodoTask>): IntRange {
        val calendar = Calendar.getInstance()
        val tasksWithTime = tasks.filter { it.hasSpecificTime }

        if (tasksWithTime.isEmpty()) {
            // If no tasks, show around current time or reasonable default
            return if (isToday) {
                val currentHour = calendar.get(Calendar.HOUR_OF_DAY)
                maxOf(0, currentHour - 2)..minOf(23, currentHour + 8)
            } else {
                8..20 // Default business hours
            }
        }

        val taskHours = tasksWithTime.map { task ->
            val date = if (task.recurrence != null) {
                task.occurrenceDate(_selectedDate.value)
            } else {
                task.startTime
            }
            calendar.time = date
            calendar.get(Calendar.HOUR_OF_DAY)
        }

        val minHour = taskHours.minOrNull() ?: 8
        val maxHour = taskHours.maxOrNull() ?: 20

        // Expand range slightly for context
        val startHour = maxOf(0, minHour - 1)
        val endHour = minOf(23, maxHour + 2)

        // If viewing today, include current hour in range
        return if (isToday) {
            val currentHour = calendar.get(Calendar.HOUR_OF_DAY)
            val expandedStart = minOf(startHour, maxOf(0, currentHour - 1))
            val expandedEnd = maxOf(endHour, minOf(23, currentHour + 2))
            expandedStart..expandedEnd
        } else {
            startHour..endHour
        }
    }

    // Current hour/minute for timeline
    val currentHour: Int
        get() = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)

    val currentMinute: Int
        get() = Calendar.getInstance().get(Calendar.MINUTE)

    // Reset view to defaults
    fun resetView() {
        _organization.value = TimelineOrganization.NONE
        _viewMode.value = TimelineViewMode.LIST
    }

    // ---- Completion check ----

    fun isTaskCompleted(task: TodoTask, date: Date = _selectedDate.value): Boolean {
        val key = task.completionKey(date)
        return task.completions[key]?.isCompleted == true
    }

    fun completedSubtasks(task: TodoTask, date: Date = _selectedDate.value): Set<UUID> {
        val key = task.completionKey(date)
        return task.completions[key]?.completedSubtasks ?: emptySet()
    }

    fun completionProgress(task: TodoTask, date: Date = _selectedDate.value): Double {
        if (task.subtasks.isEmpty()) return if (isTaskCompleted(task, date)) 1.0 else 0.0
        val key = task.completionKey(date)
        val completedCount = task.completions[key]?.completedSubtasks?.size ?: 0
        return completedCount.toDouble() / task.subtasks.size
    }

    // ---- Organized Tasks (matching iOS) ----

    fun organizedTasks(tasks: List<TodoTask>): OrganizedTasks {
        return when (_organization.value) {
            TimelineOrganization.NONE, TimelineOrganization.TIME ->
                OrganizedTasks.Single(tasks)

            TimelineOrganization.CATEGORY -> {
                val grouped = tasks.groupBy { it.category?.name ?: "Uncategorized" }
                val sections = grouped.map { (name, sectionTasks) ->
                    TaskSection(
                        title = name,
                        icon = "label",
                        color = sectionTasks.firstOrNull()?.category?.color,
                        tasks = sectionTasks,
                    )
                }
                OrganizedTasks.Sections(sections)
            }

            TimelineOrganization.PRIORITY -> {
                val grouped = tasks.groupBy { it.priority }
                val sections = Priority.entries.reversed().mapNotNull { priority ->
                    val sectionTasks = grouped[priority] ?: return@mapNotNull null
                    TaskSection(
                        title = priority.displayName,
                        icon = priority.iconName,
                        tasks = sectionTasks,
                    )
                }
                OrganizedTasks.Sections(sections)
            }

            TimelineOrganization.EISENHOWER -> {
                // Eisenhower matrix: Urgent+Important, Important, Urgent, Neither
                val sections = listOf(
                    TaskSection(
                        title = "Do First",
                        icon = "priority_high",
                        color = "#FFE53935",
                        tasks = tasks.filter { it.priority == Priority.HIGH },
                    ),
                    TaskSection(
                        title = "Schedule",
                        icon = "event",
                        color = "#FF43A047",
                        tasks = tasks.filter { it.priority == Priority.MEDIUM },
                    ),
                    TaskSection(
                        title = "Delegate",
                        icon = "person",
                        color = "#FF1E88E5",
                        tasks = tasks.filter { it.priority == Priority.LOW },
                    ),
                ).filter { it.tasks.isNotEmpty() }
                OrganizedTasks.Sections(sections)
            }
        }
    }

    // ---- Tasks for timeline (hourly) view ----

    fun tasksForHour(tasks: List<TodoTask>, hour: Int): List<TodoTask> {
        val calendar = Calendar.getInstance()
        return tasks.filter { task ->
            if (!task.hasSpecificTime) return@filter false
            val t = if (task.recurrence != null) {
                task.occurrenceDate(_selectedDate.value)
            } else {
                task.startTime
            }
            calendar.time = t
            calendar.get(Calendar.HOUR_OF_DAY) == hour
        }
    }

    fun allDayTasks(tasks: List<TodoTask>): List<TodoTask> {
        return tasks.filter { !it.hasSpecificTime }
    }

    // ---- Private ----

    private fun filterTasks(
        allTasks: List<TodoTask>,
        date: Date,
        scope: TaskTimeScope,
        showAllHistory: Boolean = false,
    ): List<TodoTask> {
        val filtered = when (scope) {
            TaskTimeScope.TODAY -> allTasks.filter { task ->
                if (task.timeScope != TaskTimeScope.TODAY) return@filter false
                if (task.recurrence != null) {
                    task.occurs(date)
                } else {
                    TodoTask.isSameDay(task.startTime, date)
                }
            }
            TaskTimeScope.WEEK -> {
                val weekStart = _currentWeek.value
                allTasks.filter { task ->
                    if (task.timeScope == TaskTimeScope.TODAY) {
                        if (task.recurrence != null) task.occurs(date)
                        else TodoTask.isSameDay(task.startTime, date)
                    } else if (task.timeScope == TaskTimeScope.WEEK) {
                        val scopeStart = task.scopeStartDate ?: task.startTime
                        val scopeWeekStart = Recurrence.startOfWeek(scopeStart)
                        scopeWeekStart.time == weekStart.time
                    } else false
                }
            }
            TaskTimeScope.MONTH -> {
                val monthStart = _currentMonth.value
                allTasks.filter { task ->
                    when (task.timeScope) {
                        TaskTimeScope.TODAY -> {
                            if (task.recurrence != null) task.occurs(date)
                            else TodoTask.isSameDay(task.startTime, date)
                        }
                        TaskTimeScope.WEEK, TaskTimeScope.MONTH -> {
                            val scopeStart = task.scopeStartDate ?: task.startTime
                            val scopeMonthStart = Recurrence.startOfMonth(scopeStart)
                            scopeMonthStart.time == monthStart.time
                        }
                        else -> false
                    }
                }
            }
            TaskTimeScope.ALL -> {
                // When showAllHistory is false, only show incomplete tasks or tasks completed today
                if (!showAllHistory) {
                    allTasks.filter { task ->
                        !isTaskCompleted(task, date) || task.hasRecentTracking
                    }
                } else {
                    allTasks
                }
            }
            else -> allTasks.filter { it.timeScope == scope }
        }

        // Sort: incomplete first, then by time, then alphabetically
        return filtered.sortedWith(
            compareBy<TodoTask> { isTaskCompleted(it, date) }
                .thenBy { it.startTime }
                .thenBy { it.name.lowercase() }
        )
    }

    companion object {
        fun startOfYear(date: Date): Date {
            val cal = Calendar.getInstance().apply {
                time = date
                set(Calendar.MONTH, Calendar.JANUARY)
                set(Calendar.DAY_OF_MONTH, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            return cal.time
        }
    }
}
