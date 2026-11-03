package com.snaptask.app

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.UUID

enum class TimelineViewMode(val rawValue: String, val icon: String) {
    list("list", "list.bullet"),
    timeline("timeline", "clock");

    val displayName: String get() = if (this == list) "list_view".localized else "timeline_view".localized
}

/** A task's state on the day/period being viewed: used to group ("By status") and filter. */
enum class TaskStatusFilter(val icon: String, val colorHex: String) {
    inProgress("circle.lefthalf.filled", "#3B82F6"),
    todo("circle", "#8E8E93"),
    completed("checkmark.circle.fill", "#22C55E");

    val displayName: String
        get() = when (this) {
            todo -> "status_filter_todo".localized
            inProgress -> "status_filter_in_progress".localized
            completed -> "status_filter_completed".localized
        }

    companion object {
        fun from(state: TaskProgressState) = when (state) {
            TaskProgressState.todo -> todo
            TaskProgressState.inProgress -> inProgress
            TaskProgressState.completed -> completed
        }
    }
}

enum class TimelineOrganization(val icon: String) {
    time("clock"),
    category("folder.fill"),
    priority("exclamationmark.triangle"),
    status("circle.lefthalf.filled"),
    eisenhower("square.grid.2x2"),
    none("list.bullet");

    val displayName: String
        get() = when (this) {
            time -> "by_time".localized
            category -> "by_category".localized
            priority -> "by_priority".localized
            status -> "by_status".localized
            eisenhower -> "eisenhower_matrix".localized
            none -> "default_view".localized
        }
}

enum class TimeSortOrder {
    ascending, descending;

    val displayName: String get() = if (this == ascending) "early_to_late".localized else "late_to_early".localized
}

sealed class OrganizedTasks {
    data class Single(val tasks: List<TodoTask>) : OrganizedTasks()
    data class Sections(val sections: List<TaskSection>) : OrganizedTasks()
}

data class TaskSection(val id: String, val title: String, val color: String?, val icon: String?, val tasks: List<TodoTask>)

object TimelineViewModel {
    private const val selectedTimeScopeKey = "timeline_selectedTimeScope"
    private const val viewModeKey = "timeline_viewMode"
    private const val organizationKey = "timeline_organization"
    private const val timeSortOrderKey = "timeline_timeSortOrder"
    private const val statusFilterKey = "timeline_visibleStatuses"

    var selectedDate by mutableStateOf(now())
    var timelineStartHour by mutableStateOf(6)
    var timelineEndHour by mutableStateOf(22)

    private var _viewMode by mutableStateOf(TimelineViewMode.list)
    var viewMode: TimelineViewMode
        get() = _viewMode
        set(value) { _viewMode = value; Defaults.set(viewModeKey, value.rawValue) }

    private var _organization by mutableStateOf(TimelineOrganization.time)
    var organization: TimelineOrganization
        get() = _organization
        set(value) { _organization = value; Defaults.set(organizationKey, value.name) }

    private var _timeSortOrder by mutableStateOf(TimeSortOrder.ascending)
    var timeSortOrder: TimeSortOrder
        get() = _timeSortOrder
        set(value) { _timeSortOrder = value; Defaults.set(timeSortOrderKey, value.name) }

    private var _visibleStatuses by mutableStateOf(TaskStatusFilter.entries.toSet())
    var visibleStatuses: Set<TaskStatusFilter>
        get() = _visibleStatuses
        set(value) {
            _visibleStatuses = value
            Defaults.set(statusFilterKey, TaskStatusFilter.entries.filter { it in value }.joinToString(",") { it.name })
        }

    private var _selectedTimeScope by mutableStateOf(TaskTimeScope.today)
    var selectedTimeScope: TaskTimeScope
        get() = _selectedTimeScope
        set(value) {
            _selectedTimeScope = value
            Defaults.set(selectedTimeScopeKey, value.rawValue)
            normalizeSelectionsForCurrentScope()
        }

    var currentWeek by mutableStateOf(now().startOfWeek())
    var currentMonth by mutableStateOf(now().startOfMonth())
    var currentYear by mutableStateOf(now().startOfYear())
    var openSwipeTaskId by mutableStateOf<UUID?>(null)
    var showAllHistory by mutableStateOf(false)

    /** 1 = timeline content visible, 0 = faded out while the scope is being switched. */
    var scopeTransitionProgress by mutableFloatStateOf(1f)
        private set
    private var pendingScopeChange: Job? = null

    private var restored = false

    fun restore() {
        if (restored) return
        restored = true
        TaskTimeScope.entries.firstOrNull { it.rawValue == Defaults.string(selectedTimeScopeKey) }?.let { _selectedTimeScope = it }
        TimelineViewMode.entries.firstOrNull { it.rawValue == Defaults.string(viewModeKey) }?.let { _viewMode = it }
        val savedOrganization = TimelineOrganization.entries.firstOrNull { it.name == Defaults.string(organizationKey) }
        if (savedOrganization != null) {
            _organization = savedOrganization
        } else if (!Defaults.bool("hasShownWelcome")) {
            // Fresh install: start in the default view, where the welcome tasks keep their order.
            organization = TimelineOrganization.none
        }
        TimeSortOrder.entries.firstOrNull { it.name == Defaults.string(timeSortOrderKey) }?.let { _timeSortOrder = it }
        Defaults.string(statusFilterKey)?.let { raw ->
            val saved = raw.split(",").mapNotNull { name -> TaskStatusFilter.entries.firstOrNull { it.name == name } }.toSet()
            if (saved.isNotEmpty()) _visibleStatuses = saved
        }
        normalizeSelectionsForCurrentScope()
    }

    private fun normalizeSelectionsForCurrentScope() {
        if (_selectedTimeScope != TaskTimeScope.today) {
            if (_viewMode == TimelineViewMode.timeline) viewMode = TimelineViewMode.list
            if (_organization == TimelineOrganization.time) organization = TimelineOrganization.none
        }
    }

    val isFilteringStatus: Boolean get() = visibleStatuses.size < TaskStatusFilter.entries.size

    /** Shows or hides one state; the last visible one can't be hidden. */
    fun toggleVisibleStatus(status: TaskStatusFilter) {
        visibleStatuses = if (status in visibleStatuses) {
            if (visibleStatuses.size <= 1) return
            visibleStatuses - status
        } else visibleStatuses + status
    }

    fun showAllStatuses() { visibleStatuses = TaskStatusFilter.entries.toSet() }

    // MARK: - Manual order

    val manualOrderListKey: String?
        get() {
            val period = when (selectedTimeScope) {
                TaskTimeScope.week -> currentWeek
                TaskTimeScope.month -> currentMonth
                TaskTimeScope.year -> currentYear
                else -> selectedDate
            }
            return TaskListOrder.listKey(selectedTimeScope, period)
        }

    /** The inbox is a plain quick list: it always uses the default (manual) order. */
    val effectiveOrganization: TimelineOrganization
        get() = if (selectedTimeScope == TaskTimeScope.inbox) TimelineOrganization.none else organization

    /** Reordering by hand is only in the default view. A filtered list hides tasks, so it can't be reordered either. */
    val canReorderTasks: Boolean
        get() = effectiveOrganization == TimelineOrganization.none && manualOrderListKey != null && !isFilteringStatus

    fun moveTasks(orderedIds: List<UUID>) {
        val listKey = manualOrderListKey ?: return
        if (!canReorderTasks) return
        TaskOrderManager.setOrder(orderedIds, listKey)
        Haptics.light()
    }

    // MARK: - Status

    fun progressDate(task: TodoTask): Date {
        val scope = if (selectedTimeScope == TaskTimeScope.all) task.timeScope else selectedTimeScope
        return when (scope) {
            TaskTimeScope.today -> selectedDate
            TaskTimeScope.week -> currentWeek
            TaskTimeScope.month -> currentMonth
            TaskTimeScope.year -> currentYear
            TaskTimeScope.longTerm, TaskTimeScope.inbox -> task.startTime.startOfDay()
            TaskTimeScope.all -> now().startOfDay()
        }
    }

    fun progressState(task: TodoTask): TaskProgressState {
        val completion = task.completions[task.completionKey(progressDate(task))]
        return when {
            completion?.isCompleted == true -> TaskProgressState.completed
            completion?.isInProgress == true -> TaskProgressState.inProgress
            else -> TaskProgressState.todo
        }
    }

    fun applyingStatusFilter(source: List<TodoTask>): List<TodoTask> =
        if (!isFilteringStatus) source else source.filter { TaskStatusFilter.from(progressState(it)) in visibleStatuses }

    /** Gradual scope change: fade the content out, switch while it is invisible, fade the new content in. */
    fun changeScope(scope: TaskTimeScope) {
        if (scope == selectedTimeScope && pendingScopeChange == null) return
        pendingScopeChange?.cancel()
        // Animations need a frame clock, which only this dispatcher brings outside of a composition.
        pendingScopeChange = MainScope.launch(androidx.compose.ui.platform.AndroidUiDispatcher.Main) {
            val animation = Animatable(scopeTransitionProgress)
            animation.animateTo(0f, tween(130)) { scopeTransitionProgress = value }
            selectedTimeScope = scope
            delay(30)
            animation.animateTo(1f, tween(240)) { scopeTransitionProgress = value }
            pendingScopeChange = null
        }
    }

    // MARK: - Tasks of the current scope

    private val tasksState = derivedStateOf {
        filteredTasksForScope().sortedWith(
            compareBy<TodoTask> { it.startTime }.thenBy { it.creationDate }.thenBy { it.name.lowercase() }.thenBy { it.id.uuidString }
        )
    }
    val tasks: List<TodoTask> get() = tasksState.value

    private fun filteredTasksForScope(): List<TodoTask> {
        val all = TaskManager.tasks
        return when (selectedTimeScope) {
            TaskTimeScope.today -> tasksForDay(selectedDate, all)
            TaskTimeScope.week -> tasksForWeek(currentWeek, all)
            TaskTimeScope.month -> tasksForMonth(currentMonth, all)
            TaskTimeScope.year -> tasksForYear(currentYear, all)
            TaskTimeScope.longTerm -> all.filter { it.timeScope == TaskTimeScope.longTerm }
            TaskTimeScope.inbox -> inboxTasks(all)
            TaskTimeScope.all -> if (showAllHistory) all else {
                tasksForDay(selectedDate, all) + tasksForWeek(currentWeek, all) + tasksForMonth(currentMonth, all) +
                    tasksForYear(currentYear, all) + all.filter { it.timeScope == TaskTimeScope.longTerm } + inboxTasks(all)
            }
        }
    }

    private fun tasksForDay(date: Date, tasks: List<TodoTask>) = tasks.filter { TaskRules.isDayTask(it, date) }

    private fun tasksForWeek(weekStart: Date, tasks: List<TodoTask>): List<TodoTask> {
        val weekEnd = weekStart.addingDays(6)
        return tasks.filter { task ->
            if (task.timeScope != TaskTimeScope.week) return@filter false
            if (task.recurrence != null) return@filter task.occursInWeek(weekStart)
            val start = task.scopeStartDate
            val end = task.scopeEndDate
            start != null && end != null && start.isSameDay(weekStart) && end.isSameDay(weekEnd)
        }
    }

    private fun tasksForMonth(monthStart: Date, tasks: List<TodoTask>) = tasks.filter { task ->
        if (task.timeScope != TaskTimeScope.month) return@filter false
        if (task.recurrence != null) task.occursInMonth(monthStart) else task.scopeStartDate?.isSameMonth(monthStart) == true
    }

    private fun tasksForYear(yearStart: Date, tasks: List<TodoTask>) = tasks.filter { task ->
        if (task.timeScope != TaskTimeScope.year) return@filter false
        if (task.recurrence != null) task.occursInYear(yearStart) else task.scopeStartDate?.isSameYear(yearStart) == true
    }

    /** Open inbox items, plus the ones checked off in the last day so the tick stays visible. */
    private fun inboxTasks(tasks: List<TodoTask>): List<TodoTask> {
        val cutoff = now().minusSeconds(24 * 3600)
        return tasks.filter { task ->
            if (task.timeScope != TaskTimeScope.inbox) return@filter false
            val completion = task.completions[task.completionKey(now())]
            if (completion?.isCompleted != true) return@filter true
            (completion.completionDate ?: task.lastModifiedDate) > cutoff
        }
    }

    val openInboxCount: Int
        get() = TaskManager.tasks.count { it.timeScope == TaskTimeScope.inbox && it.completions[it.completionKey(now())]?.isCompleted != true }

    // MARK: - Period text

    val currentPeriodString: String
        get() = when (selectedTimeScope) {
            TaskTimeScope.today -> if (selectedDate.isToday()) "scope_today".localized
            else selectedDate.skeleton(if (selectedDate.isSameYear(now())) "dMMM" else "dMMMyyyy")
            TaskTimeScope.week -> {
                val end = currentWeek.addingDays(6)
                if (currentWeek.isSameMonth(end)) "${currentWeek.dayOfMonth}–${end.skeleton("dMMM")}"
                else "${currentWeek.skeleton("dMMM")} – ${end.skeleton("dMMM")}"
            }
            TaskTimeScope.month -> currentMonth.format("LLLL yyyy").replaceFirstChar { it.titlecase(appLocale) }
            TaskTimeScope.year -> currentYear.format("yyyy")
            TaskTimeScope.longTerm -> "scope_long_term".localized
            TaskTimeScope.inbox -> "scope_inbox".localized
            TaskTimeScope.all -> "all_goals".localized
        }

    /** Shorter numeric week range for when the spelled-out one doesn't fit the header. */
    val compactPeriodString: String?
        get() {
            if (selectedTimeScope != TaskTimeScope.week) return null
            return "${currentWeek.skeleton("dM")} – ${currentWeek.addingDays(6).skeleton("dM")}"
        }

    // MARK: - Navigation

    fun navigateToPrevious() = step(-1)
    fun navigateToNext() = step(1)

    private fun step(direction: Int) {
        when (selectedTimeScope) {
            TaskTimeScope.today -> selectedDate = selectedDate.addingDays(direction)
            TaskTimeScope.week -> currentWeek = currentWeek.addingWeeks(direction)
            TaskTimeScope.month -> currentMonth = currentMonth.addingMonths(direction)
            TaskTimeScope.year -> currentYear = currentYear.addingYears(direction)
            else -> Unit
        }
    }

    fun navigateToToday() {
        val today = now()
        when (selectedTimeScope) {
            TaskTimeScope.today -> selectedDate = today
            TaskTimeScope.week -> currentWeek = today.startOfWeek()
            TaskTimeScope.month -> currentMonth = today.startOfMonth()
            TaskTimeScope.year -> currentYear = today.startOfYear()
            else -> Unit
        }
    }

    val canNavigatePrevious: Boolean get() = selectedTimeScope != TaskTimeScope.longTerm && selectedTimeScope != TaskTimeScope.inbox
    val canNavigateNext: Boolean get() = canNavigatePrevious

    val isToday: Boolean get() = selectedDate.isToday()

    val isCurrentPeriod: Boolean
        get() {
            val today = now()
            return when (selectedTimeScope) {
                TaskTimeScope.today -> selectedDate.isToday()
                TaskTimeScope.week -> currentWeek.isSameDay(today.startOfWeek())
                TaskTimeScope.month -> currentMonth.isSameMonth(today)
                TaskTimeScope.year -> currentYear.isSameYear(today)
                else -> true
            }
        }

    val progressText: String
        get() {
            val tasks = tasks
            if (tasks.isEmpty()) {
                return when (selectedTimeScope) {
                    TaskTimeScope.today -> if (selectedDate.isToday()) "no_tasks_today".localized else "no_tasks_this_day".localized
                    TaskTimeScope.week -> "no_tasks_this_week".localized
                    TaskTimeScope.month -> "no_tasks_this_month".localized
                    TaskTimeScope.year -> "no_tasks_this_year".localized
                    TaskTimeScope.all -> "0 " + "tasks".localized
                    TaskTimeScope.longTerm -> "no_tasks_long_term".localized
                    TaskTimeScope.inbox -> "inbox_empty_title".localized
                }
            }
            return if (selectedTimeScope == TaskTimeScope.today) {
                "${tasks.count { getCompletion(it, selectedDate)?.isCompleted == true }}/${tasks.size} " + "completed".localized
            } else if (tasks.size == 1) "1 " + "task".localized else "${tasks.size} " + "tasks".localized
        }

    private fun completionTargetDate(task: TodoTask): Date = when (task.timeScope) {
        TaskTimeScope.today -> selectedDate
        TaskTimeScope.week -> currentWeek
        TaskTimeScope.month -> currentMonth
        TaskTimeScope.year -> currentYear
        TaskTimeScope.longTerm, TaskTimeScope.inbox -> task.startTime.startOfDay()
        TaskTimeScope.all -> now().startOfDay()
    }

    private fun targetDate(taskId: UUID): Date = when (selectedTimeScope) {
        TaskTimeScope.today -> selectedDate
        TaskTimeScope.week -> currentWeek
        TaskTimeScope.month -> currentMonth
        TaskTimeScope.year -> currentYear
        TaskTimeScope.longTerm, TaskTimeScope.inbox -> now()
        TaskTimeScope.all -> TaskManager.task(taskId)?.let { completionTargetDate(it) } ?: now().startOfDay()
    }

    fun toggleTaskCompletion(taskId: UUID) = TaskManager.toggleTaskCompletion(taskId, targetDate(taskId))
    fun toggleSubtask(taskId: UUID, subtaskId: UUID) = TaskManager.toggleSubtask(taskId, subtaskId, targetDate(taskId))

    fun getCompletion(task: TodoTask, date: Date): TaskCompletion? {
        val key = when (selectedTimeScope) {
            TaskTimeScope.today -> date.startOfDay()
            TaskTimeScope.week -> currentWeek.startOfDay()
            TaskTimeScope.month -> currentMonth.startOfDay()
            TaskTimeScope.year -> currentYear.startOfDay()
            TaskTimeScope.longTerm, TaskTimeScope.inbox -> task.startTime.startOfDay()
            TaskTimeScope.all -> completionTargetDate(task).startOfDay()
        }
        return task.completions[key]
    }

    fun postponeTask(task: TodoTask, hours: Int) {
        MainScope.launch {
            TaskManager.updateTask(task.copy(startTime = task.startTime.addingHours(hours), hasSpecificTime = true, lastModifiedDate = now()))
        }
    }

    fun moveTaskToTomorrow(task: TodoTask) {
        MainScope.launch { TaskManager.updateTask(task.copy(startTime = task.startTime.addingDays(1), lastModifiedDate = now())) }
    }

    fun duplicateTask(task: TodoTask) {
        val duplicate = task.copy(
            id = UUID.randomUUID(),
            name = "${task.name} (copia)",
            completions = emptyMap(),
            completionDates = emptyList(),
            creationDate = now(),
            totalTrackedTime = 0.0,
            lastTrackedDate = null,
            notificationId = null,
        )
        MainScope.launch { TaskManager.addTask(duplicate) }
    }

    fun deleteTask(task: TodoTask) {
        MainScope.launch { TaskManager.removeTask(task) }
    }

    // MARK: - Organization

    fun organizedTasksForSelectedDate(): OrganizedTasks {
        val scoped = applyingStatusFilter(tasks)
        if (selectedTimeScope == TaskTimeScope.all) return organizeByTimeScope(scoped)
        return when (effectiveOrganization) {
            TimelineOrganization.time -> OrganizedTasks.Single(TaskRules.byTimeOfDay(scoped, timeSortOrder == TimeSortOrder.ascending))
            TimelineOrganization.category -> organizeByCategory(scoped)
            TimelineOrganization.priority -> organizeByPriority(scoped)
            TimelineOrganization.status -> organizeByStatus(scoped)
            TimelineOrganization.eisenhower -> {
                val (q1, q2, q3, q4) = eisenhowerQuadrants(scoped)
                OrganizedTasks.Sections(
                    listOf(
                        TaskSection("q1", "urgent_important".localized, "#EF4444", "flame.fill", q1),
                        TaskSection("q2", "not_urgent_important".localized, "#3B82F6", "calendar", q2),
                        TaskSection("q3", "urgent_not_important".localized, "#F59E0B", "bolt.fill", q3),
                        TaskSection("q4", "not_urgent_not_important".localized, "#9CA3AF", "square.dashed", q4),
                    )
                )
            }
            TimelineOrganization.none -> {
                val key = manualOrderListKey ?: return OrganizedTasks.Single(scoped)
                OrganizedTasks.Single(TaskOrderManager.sorted(scoped, key))
            }
        }
    }

    fun tasksForSelectedDate(): List<TodoTask> = applyingStatusFilter(tasks)

    private val timeThenCreated = compareBy<TodoTask> { it.startTime }.thenBy { it.creationDate }

    private fun organizeByStatus(tasks: List<TodoTask>): OrganizedTasks {
        val grouped = tasks.groupBy { TaskStatusFilter.from(progressState(it)) }
        return OrganizedTasks.Sections(TaskStatusFilter.entries.mapNotNull { status ->
            val list = grouped[status]?.takeIf { it.isNotEmpty() } ?: return@mapNotNull null
            TaskSection("status_${status.name}", status.displayName, status.colorHex, status.icon, list.sortedWith(timeThenCreated))
        })
    }

    private fun organizeByCategory(tasks: List<TodoTask>): OrganizedTasks {
        val grouped = tasks.groupBy { it.category?.name ?: "no_category".localized }
        return OrganizedTasks.Sections(grouped.map { (name, list) ->
            val category = list.first().category
            TaskSection(category?.id?.uuidString ?: "no-category", name, category?.color, "folder.fill", list.sortedWith(timeThenCreated))
        }.sortedBy { it.title })
    }

    private fun organizeByPriority(tasks: List<TodoTask>): OrganizedTasks {
        val grouped = tasks.groupBy { it.priority }
        return OrganizedTasks.Sections(listOf(Priority.high, Priority.medium, Priority.low).mapNotNull { priority ->
            val list = grouped[priority]?.takeIf { it.isNotEmpty() } ?: return@mapNotNull null
            TaskSection(priority.name, priority.displayName + " " + "priority".localized, priority.colorHex, priority.icon, list.sortedWith(timeThenCreated))
        })
    }

    private fun organizeByTimeScope(tasks: List<TodoTask>): OrganizedTasks {
        fun colorHex(scope: TaskTimeScope) = when (scope) {
            TaskTimeScope.today -> "#3B82F6"
            TaskTimeScope.week -> "#10B981"
            TaskTimeScope.month -> "#F59E0B"
            TaskTimeScope.year -> "#8B5CF6"
            TaskTimeScope.longTerm -> "#EC4899"
            TaskTimeScope.inbox -> "#6366F1"
            TaskTimeScope.all -> "#14B8A6"
        }
        val grouped = tasks.groupBy { it.timeScope }
        return OrganizedTasks.Sections(
            listOf(TaskTimeScope.today, TaskTimeScope.week, TaskTimeScope.month, TaskTimeScope.year, TaskTimeScope.longTerm, TaskTimeScope.inbox).mapNotNull { scope ->
                val list = grouped[scope]?.takeIf { it.isNotEmpty() } ?: return@mapNotNull null
                TaskSection(scope.rawValue, scope.displayName, colorHex(scope), scope.icon, list.sortedWith(timeThenCreated))
            }
        )
    }

    val availableCategories: List<Category> get() = tasks.mapNotNull { it.category }.distinct().sortedBy { it.name }

    fun resetView() {
        organization = TimelineOrganization.time
        timeSortOrder = TimeSortOrder.ascending
        viewMode = TimelineViewMode.list
        showAllStatuses()
    }

    val organizationStatusText: String get() = organization.displayName

    val effectiveStartHour: Int
        get() = tasksForSelectedDate().minOfOrNull { it.startTime.hour } ?: timelineStartHour

    val effectiveEndHour: Int
        get() {
            val tasks = tasksForSelectedDate()
            if (tasks.isEmpty()) return timelineEndHour
            val latest = tasks.maxOf { it.startTime.hour + (it.duration / 3600).toInt() }
            return minOf(maxOf(latest + 1, timelineStartHour), timelineEndHour)
        }

    // MARK: - Eisenhower

    private fun isImportant(task: TodoTask) =
        task.priority == Priority.high || (task.priority == Priority.medium && SettingsViewModel.eisenhowerMediumIsImportant)

    private fun dueDate(task: TodoTask): Date? = when (task.timeScope) {
        TaskTimeScope.today -> if (task.hasSpecificTime) {
            if (task.recurrence != null) task.occurrenceDate(selectedDate) else task.startTime
        } else task.startTime.startOfDay().withTime(23, 59, 59)
        TaskTimeScope.week -> task.scopeEndDate ?: currentWeek.addingDays(6)
        TaskTimeScope.month -> task.scopeEndDate ?: currentMonth.addingMonths(1).minusSeconds(1)
        TaskTimeScope.year -> task.scopeEndDate ?: currentYear.addingYears(1).minusSeconds(1)
        else -> null
    }

    private fun isUrgent(task: TodoTask): Boolean {
        val due = dueDate(task) ?: return false
        val current = now()
        if (due <= current) return true
        val settings = SettingsViewModel
        val scope = if (selectedTimeScope == TaskTimeScope.all) task.timeScope else selectedTimeScope
        val threshold = when (scope) {
            TaskTimeScope.today -> {
                if (settings.eisenhowerTodayRequireSpecificTime && !task.hasSpecificTime) return false
                settings.eisenhowerTodayUrgentHours * 3600.0
            }
            TaskTimeScope.week -> settings.eisenhowerWeekUrgentHours * 3600.0
            TaskTimeScope.month -> settings.eisenhowerMonthUrgentDays * 24 * 3600.0
            TaskTimeScope.year -> settings.eisenhowerYearUrgentDays * 24 * 3600.0
            else -> return false
        }
        return due.timeIntervalSince(current) <= threshold
    }

    fun eisenhowerQuadrants(source: List<TodoTask>? = null): List<List<TodoTask>> {
        val q1 = ArrayList<TodoTask>()
        val q2 = ArrayList<TodoTask>()
        val q3 = ArrayList<TodoTask>()
        val q4 = ArrayList<TodoTask>()
        for (task in source ?: tasks) {
            val important = isImportant(task)
            val urgent = isUrgent(task)
            when {
                urgent && important -> q1 += task
                !urgent && important -> q2 += task
                urgent -> q3 += task
                else -> q4 += task
            }
        }
        return listOf(q1, q2, q3, q4).map { it.sortedWith(timeThenCreated) }
    }
}
