package com.snaptask.app

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.MapSerializer
import kotlinx.serialization.builtins.serializer
import java.io.File
import java.util.UUID
import kotlin.math.max

/** The three states of one task occurrence. */
enum class TaskProgressState { todo, inProgress, completed }

/** Everything that runs on the main thread without blocking it, like `Task { }` from `@MainActor` code. */
val MainScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

object TaskManager {
    private const val tasksKey = "savedTasks"
    private const val trackingSessionsKey = "trackingSessions"
    private val tasksSerializer = ListSerializer(TodoTask.serializer())
    private val sessionsSerializer = ListSerializer(TrackingSession.serializer())

    var tasks by mutableStateOf<List<TodoTask>>(emptyList())
        private set
    var trackingSessions by mutableStateOf<List<TrackingSession>>(emptyList())
        private set

    private var isUpdatingFromSync = false
    private var completionSnapshot = HashMap<UUID, Map<Date, TaskCompletion>>()
    private var loaded = false

    fun load() {
        if (loaded) return
        loaded = true
        tasks = Store.load(tasksKey, tasksSerializer) ?: emptyList()
        trackingSessions = Store.load(trackingSessionsKey, sessionsSerializer) ?: emptyList()
        completionSnapshot = HashMap(tasks.associate { it.id to it.completions })
        applyCarryOverIfNeeded(force = false)
    }

    fun refreshCarryOverIfNeeded() = applyCarryOverIfNeeded(force = false)

    private fun replace(task: TodoTask) {
        tasks = tasks.map { if (it.id == task.id) task else it }
    }

    fun task(id: UUID): TodoTask? = tasks.firstOrNull { it.id == id }

    suspend fun addTask(task: TodoTask) {
        if (isUpdatingFromSync) return
        val updated = task.copy(lastModifiedDate = now())
        tasks = tasks + updated
        handleTaskNotification(updated)
        saveTasks()
        handleTaskCalendarSync(updated, isNew = true)
    }

    suspend fun updateTask(updatedTask: TodoTask) {
        if (isUpdatingFromSync) return
        val oldTask = task(updatedTask.id) ?: return
        // Completions are kept: edits from a form don't touch them.
        var task = updatedTask.copy(completions = oldTask.completions, lastModifiedDate = now())

        handleTaskNotificationUpdate(oldTask, task)
        task(updatedTask.id)?.notificationId?.let { task = task.copy(notificationId = it) }

        val todayStart = now().startOfDay()
        val taskIsInPast = when (task.timeScope) {
            TaskTimeScope.week, TaskTimeScope.month, TaskTimeScope.year -> task.scopeEndDate?.let { it.startOfDay() < todayStart } ?: false
            else -> task.startTime.startOfDay() < todayStart
        }

        if (task.hasRewardPoints && oldTask.rewardPoints != task.rewardPoints) {
            for (completionDate in task.completionDates) {
                if (oldTask.hasRewardPoints) {
                    RewardManager.addPoints(-oldTask.rewardPoints, completionDate)
                    oldTask.category?.id?.let { RewardManager.addPointsToCategory(-oldTask.rewardPoints, it, oldTask.category?.name, completionDate) }
                }
                RewardManager.addPoints(task.rewardPoints, completionDate)
                task.category?.id?.let { RewardManager.addPointsToCategory(task.rewardPoints, it, task.category?.name, completionDate) }
            }
        }

        replace(task)
        saveTasks()

        if (!oldTask.autoCarryOver && task.autoCarryOver && taskIsInPast) applyCarryOverIfNeeded(force = true)
        handleTaskCalendarSync(task, isNew = false)
    }

    /** Replaces everything: restoring a backup. */
    fun updateAllTasks(newTasks: List<TodoTask>) {
        isUpdatingFromSync = true
        tasks = newTasks
        saveTasks()
        applyCarryOverIfNeeded(force = false)
        isUpdatingFromSync = false
        MainScope.launch { TaskNotificationManager.syncTaskReminders(tasks) }
    }

    suspend fun removeTask(task: TodoTask) {
        if (isUpdatingFromSync) return
        if (task.hasRewardPoints) RewardManager.removePointsFromTask(task)
        removeTaskFromStatistics(task.id)
        AttachmentService.deleteAllMedia(task)
        tasks = tasks.filter { it.id != task.id }
        saveTasks()
        // Slow cleanups run after the task has left the list, so the list closes the gap right away.
        TaskNotificationManager.cancelAllNotificationsForTask(task.id)
        CalendarIntegrationManager.deleteTaskFromCalendar(task.id, task.recurrence != null)
    }

    /** Deletes a task and, if asked, its recorded sessions (otherwise they stay in the Focus history). */
    suspend fun removeTask(task: TodoTask, deletingSessions: Boolean) {
        if (deletingSessions) trackingSessions.filter { it.taskId == task.id }.forEach { deleteTrackingSession(it) }
        removeTask(task)
    }

    fun saveTrackingSession(session: TrackingSession) {
        if (isUpdatingFromSync) return
        trackingSessions = trackingSessions + session.completed()
        saveTrackingSessions()
    }

    fun trackingSessionCount(taskId: UUID): Int = trackingSessions.count { it.taskId == taskId }

    fun deleteTrackingSession(session: TrackingSession) {
        if (isUpdatingFromSync) return
        trackingSessions = trackingSessions.filter { it.id != session.id }
        saveTrackingSessions()
    }

    fun updateTrackingSession(session: TrackingSession) {
        if (isUpdatingFromSync) return
        if (trackingSessions.none { it.id == session.id }) return
        val updated = session.copy(lastModifiedDate = now())
        trackingSessions = trackingSessions.map { if (it.id == session.id) updated else it }
        saveTrackingSessions()
    }

    fun addTrackedTime(duration: Double, taskId: UUID) {
        if (isUpdatingFromSync) return
        val task = task(taskId) ?: return
        replace(task.copy(totalTrackedTime = task.totalTrackedTime + duration, lastTrackedDate = now(), lastModifiedDate = now()))
        saveTasks()
    }

    fun updateTaskRating(
        taskId: UUID,
        actualDuration: Double? = null,
        difficultyRating: Int? = null,
        qualityRating: Int? = null,
        notes: String? = null,
        date: Date = now(),
    ) {
        if (isUpdatingFromSync) return
        val task = task(taskId) ?: return
        val targetDate = task.completionKey(date)
        var completion = task.completions[targetDate] ?: TaskCompletion()
        val oldActualDuration = completion.actualDuration

        if (actualDuration != null) completion = completion.copy(actualDuration = if (actualDuration > 0) actualDuration else null)
        if (difficultyRating != null) completion = completion.copy(difficultyRating = if (difficultyRating == 0) null else difficultyRating)
        if (qualityRating != null) completion = completion.copy(qualityRating = if (qualityRating == 0) null else qualityRating)
        if (notes != null) completion = completion.copy(notes = notes.ifEmpty { null })
        if (completion.completionDate == null &&
            (completion.actualDuration != null || completion.difficultyRating != null || completion.qualityRating != null || completion.notes != null)
        ) completion = completion.copy(completionDate = now())

        val updated = task.copy(completions = task.completions + (targetDate to completion), lastModifiedDate = now())
        replace(updated)

        if (oldActualDuration != completion.actualDuration) {
            val duration = completion.actualDuration
            syncActualDurationWithStatistics(
                updated.category?.id, updated.category?.color, oldActualDuration,
                if (completion.isCompleted && duration != null && duration > 0) duration else null,
                targetDate,
            )
        }
        saveTasks()
    }

    private fun syncActualDurationWithStatistics(categoryId: UUID?, categoryColor: String?, oldDuration: Double?, newDuration: Double?, date: Date) {
        val dateKey = date.startOfDay().wholeSecond().toString()
        val categoryKey = categoryId?.let { "category_${it.uuidString}" } ?: "uncategorized"
        val categoryName = categoryId?.let { id -> CategoryManager.categories.firstOrNull { it.id == id }?.name ?: "Unknown Category" } ?: "Uncategorized"

        val data = TimeTrackingStore.load().toMutableMap()
        val day = (data[dateKey] ?: emptyMap()).toMutableMap()
        if (newDuration != null && newDuration > 0) {
            var hours = (day[categoryKey] ?: 0.0) + newDuration / 3600.0
            if (oldDuration != null && oldDuration > 0) hours = max(0.0, hours - oldDuration / 3600.0)
            if (hours > 0) day[categoryKey] = hours else day.remove(categoryKey)
            TimeTrackingStore.setCategoryMetadata(categoryKey, categoryName, categoryColor ?: "#6366F1")
        } else if (oldDuration != null && oldDuration > 0) {
            val hours = max(0.0, (day[categoryKey] ?: 0.0) - oldDuration / 3600.0)
            if (hours > 0) day[categoryKey] = hours else day.remove(categoryKey)
        }
        if (day.isEmpty()) data.remove(dateKey) else data[dateKey] = day
        TimeTrackingStore.save(data)
    }

    private fun removeTaskFromStatistics(taskId: UUID) {
        val taskKey = "task_${taskId.uuidString}"
        val data = TimeTrackingStore.load().toMutableMap()
        for ((dateKey, day) in data.toMap()) {
            if (taskKey in day) {
                val cleaned = day - taskKey
                if (cleaned.isEmpty()) data.remove(dateKey) else data[dateKey] = cleaned
            }
        }
        TimeTrackingStore.save(data)
    }

    fun getTrackingSessions(taskId: UUID? = null): List<TrackingSession> =
        if (taskId != null) trackingSessions.filter { it.taskId == taskId } else trackingSessions

    fun getTotalTrackedTime(taskId: UUID): Double = getTrackingSessions(taskId).sumOf { it.effectiveWorkTime }

    fun getTodaysTrackedTime(): Double {
        val today = now().startOfDay()
        val tomorrow = today.addingDays(1)
        return trackingSessions.filter { it.startTime >= today && it.startTime < tomorrow }.sumOf { it.effectiveWorkTime }
    }

    fun toggleTaskCompletion(taskId: UUID, date: Date = now()) {
        if (isUpdatingFromSync) return
        val task = task(taskId) ?: return
        val key = task.completionKey(date)
        val current = task.completions[key]
        val isCompleting = current?.isCompleted != true
        val pointsAlreadyAwarded = task.completionDates.contains(key)

        val completion = TaskCompletion(
            isCompleted = isCompleting,
            completedSubtasks = current?.completedSubtasks ?: emptySet(),
            actualDuration = current?.actualDuration,
            difficultyRating = current?.difficultyRating,
            qualityRating = current?.qualityRating,
            completionDate = current?.completionDate,
            notes = current?.notes,
        )

        var dates = task.completionDates
        if (completion.isCompleted) {
            ConfettiManager.trigger()
            if (key !in dates) dates = dates + key
        } else {
            dates = dates.filter { it != key }
        }

        val actual = completion.actualDuration
        if (isCompleting) {
            if (actual != null && actual > 0) syncActualDurationWithStatistics(task.category?.id, task.category?.color, null, actual, key)
        } else if (actual != null) {
            syncActualDurationWithStatistics(task.category?.id, task.category?.color, actual, null, key)
        }

        if (task.hasRewardPoints && task.subtasks.isEmpty()) {
            if (isCompleting && !pointsAlreadyAwarded) {
                RewardManager.addPoints(task.rewardPoints, date)
                task.category?.id?.let { RewardManager.addPointsToCategory(task.rewardPoints, it, task.category.name, date) }
            } else if (!isCompleting && pointsAlreadyAwarded) {
                RewardManager.addPoints(-task.rewardPoints, date)
                task.category?.id?.let { RewardManager.addPointsToCategory(-task.rewardPoints, it, task.category.name, date) }
            }
        }

        val updated = task.copy(completions = task.completions + (key to completion), completionDates = dates, lastModifiedDate = now())
        replace(updated)
        saveTasks()

        if (CalendarIntegrationManager.settings.autoSyncOnTaskComplete) {
            MainScope.launch { CalendarIntegrationManager.updateTaskInCalendar(updated) }
        }
    }

    fun toggleSubtask(taskId: UUID, subtaskId: UUID, date: Date = now()) {
        if (isUpdatingFromSync) return
        val task = task(taskId) ?: return
        val key = task.completionKey(date)
        var completion = task.completions[key] ?: TaskCompletion()
        val wasCompleted = subtaskId in completion.completedSubtasks
        completion = completion.copy(
            completedSubtasks = if (wasCompleted) completion.completedSubtasks - subtaskId else completion.completedSubtasks + subtaskId
        )
        val subtasks = task.subtasks.map { if (it.id == subtaskId) it.copy(isCompleted = !wasCompleted) else it }
        var dates = task.completionDates
        val shouldAutoComplete = SettingsViewModel.autoCompleteTaskWithSubtasks

        if (task.subtasks.isNotEmpty()) {
            val allCompleted = task.subtasks.all { it.id in completion.completedSubtasks }
            val wasAllCompleted = task.subtasks.all { if (it.id == subtaskId) wasCompleted else it.id in completion.completedSubtasks }
            val pointsAlreadyAwarded = key in dates

            if (task.hasRewardPoints) {
                if (allCompleted && !wasAllCompleted && !pointsAlreadyAwarded) {
                    RewardManager.addPoints(task.rewardPoints, date)
                    task.category?.id?.let { RewardManager.addPointsToCategory(task.rewardPoints, it, task.category.name, date) }
                } else if (!allCompleted && wasAllCompleted && pointsAlreadyAwarded) {
                    RewardManager.addPoints(-task.rewardPoints, date)
                    task.category?.id?.let { RewardManager.addPointsToCategory(-task.rewardPoints, it, task.category.name, date) }
                }
            }

            if (shouldAutoComplete) {
                if (allCompleted && !wasAllCompleted) {
                    completion = completion.copy(isCompleted = true)
                    if (key !in dates) dates = dates + key
                } else if (!allCompleted && wasAllCompleted) {
                    completion = completion.copy(isCompleted = false)
                    dates = dates.filter { it != key }
                }
            }
        }

        // Ticking the first subtask means the task has been started.
        if (completion.isCompleted) {
            completion = completion.copy(isInProgress = false)
        } else if (!wasCompleted && SettingsViewModel.autoMarkInProgress) {
            completion = completion.copy(isInProgress = true)
        }

        val updated = task.copy(
            completions = task.completions + (key to completion),
            subtasks = subtasks,
            completionDates = dates,
            lastModifiedDate = now(),
        )
        replace(updated)
        saveTasks()

        if (CalendarIntegrationManager.settings.autoSyncOnTaskComplete) {
            MainScope.launch { CalendarIntegrationManager.updateTaskInCalendar(updated) }
        }
    }

    // MARK: - In progress

    fun progressState(task: TodoTask, date: Date): TaskProgressState {
        val completion = task.completions[task.completionKey(date)]
        return when {
            completion?.isCompleted == true -> TaskProgressState.completed
            completion?.isInProgress == true -> TaskProgressState.inProgress
            else -> TaskProgressState.todo
        }
    }

    /** Press and hold on the task circle: "In progress" on, or off again if it already is. */
    fun toggleInProgress(taskId: UUID, date: Date) {
        val task = task(taskId) ?: return
        val next = if (progressState(task, date) == TaskProgressState.inProgress) TaskProgressState.todo else TaskProgressState.inProgress
        if (next == TaskProgressState.inProgress) Haptics.heavy() else Haptics.light()
        setProgressState(next, taskId, date)
    }

    fun setProgressState(state: TaskProgressState, taskId: UUID, date: Date) {
        if (isUpdatingFromSync) return
        val task = task(taskId) ?: return
        val current = progressState(task, date)
        if (current == state) return
        if (state == TaskProgressState.completed || current == TaskProgressState.completed) toggleTaskCompletion(taskId, date)
        if (state != TaskProgressState.completed) setInProgress(state == TaskProgressState.inProgress, taskId, date)
    }

    /** Marks an occurrence "In corso" when work on it starts (timer, Pomodoro). */
    fun markStartedIfNeeded(taskId: UUID) {
        if (!SettingsViewModel.autoMarkInProgress) return
        val task = task(taskId) ?: return
        val date = if (task.recurrence == null && task.timeScope == TaskTimeScope.today) task.startTime else now()
        if (progressState(task, date) != TaskProgressState.todo) return
        setInProgress(true, taskId, date)
    }

    private fun setInProgress(inProgress: Boolean, taskId: UUID, date: Date) {
        val task = task(taskId) ?: return
        val key = task.completionKey(date)
        val completion = task.completions[key] ?: TaskCompletion()
        if (completion.isCompleted || completion.isInProgress == inProgress) return
        replace(task.copy(completions = task.completions + (key to completion.copy(isInProgress = inProgress)), lastModifiedDate = now()))
        saveTasks()
    }

    /** Photos and voice notes whose file is gone, as after a restore from Google's cloud backup, are dropped. */
    fun dropMissingMedia() {
        val cleaned = tasks.map { task ->
            task.copy(
                photos = task.photos.filter { File(it.photoPath).exists() },
                voiceMemos = task.voiceMemos.filter { File(it.audioPath).exists() },
            )
        }
        if (cleaned == tasks) return
        tasks = cleaned
        saveTasks()
    }

    // MARK: - Persistence

    private fun saveTasks() {
        if (isUpdatingFromSync) {
            completionSnapshot = HashMap(tasks.associate { it.id to it.completions })
        } else {
            stampChangedCompletions()
        }
        val snapshot = tasks
        Store.save(tasksKey, tasksSerializer, snapshot)
        WidgetRefresher.request()
    }

    private fun saveTrackingSessions() {
        Store.save(trackingSessionsKey, sessionsSerializer, trackingSessions)
    }

    /** Marks the occurrences changed since the last save with the time of the change. */
    private fun stampChangedCompletions() {
        val stamp = now().wholeSecond()
        var changedAny = false
        val stamped = tasks.map { task ->
            val before = completionSnapshot[task.id] ?: emptyMap()
            val changed = task.completions.filter { (key, value) -> !value.hasSameContent(before[key]) }
            val result = if (changed.isEmpty()) task else {
                changedAny = true
                task.copy(completions = task.completions + changed.mapValues { it.value.copy(modifiedAt = stamp) })
            }
            completionSnapshot[task.id] = result.completions
            result
        }
        if (changedAny) tasks = stamped
    }

    fun resetUserDefaults() {
        Store.remove(tasksKey)
        Store.remove(trackingSessionsKey)
        tasks = emptyList()
        trackingSessions = emptyList()
        TaskOrderManager.removeAll()
        TaskNotificationManager.cancelAllNotifications()
        WidgetRefresher.request()
    }

    suspend fun toggleTaskNotification(taskId: UUID) {
        var task = task(taskId) ?: return
        task = task.copy(hasNotification = !task.hasNotification)
        if (task.hasNotification) {
            val id = if (task.recurrence != null) TaskNotificationManager.scheduleRecurringNotifications(task).firstOrNull()
            else TaskNotificationManager.scheduleNotification(task)
            task = task.copy(notificationId = id)
            if (id == null) task = task.copy(hasNotification = false)
        } else {
            TaskNotificationManager.cancelAllNotificationsForTask(task.id)
            task = task.copy(notificationId = null)
        }
        replace(task.copy(lastModifiedDate = now()))
        saveTasks()
    }

    private suspend fun handleTaskNotification(task: TodoTask) {
        if (!task.hasNotification || !task.hasSpecificTime) return
        val id = if (task.recurrence != null) TaskNotificationManager.scheduleRecurringNotifications(task).firstOrNull()
        else TaskNotificationManager.scheduleNotification(task)
        if (id != null) {
            task(task.id)?.let { replace(it.copy(notificationId = id)) }
        }
    }

    private suspend fun handleTaskNotificationUpdate(oldTask: TodoTask, newTask: TodoTask) {
        if (oldTask.hasNotification == newTask.hasNotification &&
            oldTask.startTime == newTask.startTime &&
            oldTask.recurrence == newTask.recurrence &&
            oldTask.name == newTask.name &&
            oldTask.notificationLeadTimeMinutes == newTask.notificationLeadTimeMinutes
        ) return
        TaskNotificationManager.cancelAllNotificationsForTask(oldTask.id)
        if (newTask.hasNotification && newTask.hasSpecificTime) handleTaskNotification(newTask)
    }

    private fun handleTaskCalendarSync(task: TodoTask, isNew: Boolean) {
        val settings = CalendarIntegrationManager.settings
        if (!settings.isEnabled) return
        if (isNew && settings.autoSyncOnTaskCreate) {
            MainScope.launch { CalendarIntegrationManager.syncTaskToCalendar(task) }
        } else if (!isNew && settings.autoSyncOnTaskUpdate) {
            MainScope.launch { CalendarIntegrationManager.updateTaskInCalendar(task) }
        }
    }

    fun syncTaskToCalendar(task: TodoTask) {
        if (!CalendarIntegrationManager.settings.isEnabled) return
        MainScope.launch { CalendarIntegrationManager.syncTaskToCalendar(task) }
    }

    private fun applyCarryOverIfNeeded(force: Boolean) {
        val todayStart = now().startOfDay()
        val lastKey = "lastCarryOverCheckDate"
        if (!force) {
            val last = Defaults.date(lastKey)
            if (last != null && last.isSameDay(todayStart)) return
        }
        val changed = ArrayList<TodoTask>()
        val result = tasks.map { task ->
            if (!task.autoCarryOver || task.recurrence != null) return@map task
            when (task.timeScope) {
                TaskTimeScope.week, TaskTimeScope.month, TaskTimeScope.year -> {
                    val moved = TaskRules.carriedOverToCurrentPeriod(task, todayStart) ?: return@map task
                    changed += moved
                    moved
                }
                TaskTimeScope.today -> {
                    val start = TaskRules.carriedOverStart(task) ?: return@map task
                    val moved = task.copy(startTime = start, lastModifiedDate = now())
                    changed += moved
                    moved
                }
                else -> task
            }
        }
        if (changed.isNotEmpty()) {
            tasks = result
            saveTasks()
            for (moved in changed) {
                if (moved.hasNotification && moved.hasSpecificTime) {
                    MainScope.launch {
                        TaskNotificationManager.cancelAllNotificationsForTask(moved.id)
                        handleTaskNotification(moved)
                    }
                }
            }
        }
        Defaults.set(lastKey, todayStart)
    }

    /** Fresh data in a shared format: what a backup contains. */
    fun replaceSessions(sessions: List<TrackingSession>) {
        trackingSessions = sessions
        saveTrackingSessions()
    }
}

/**
 * Hours tracked per category and day: the `timeTracking` dictionary of the iOS app
 * (`[ISO day: ["category_<id>": hours]]`), read by the statistics.
 */
object TimeTrackingStore {
    private const val KEY = "timeTracking"
    private const val META = "categoryMetadata"
    private val serializer = MapSerializer(String.serializer(), MapSerializer(String.serializer(), Double.serializer()))
    private val metaSerializer = MapSerializer(String.serializer(), MapSerializer(String.serializer(), String.serializer()))

    var revision by mutableStateOf(0)
        private set

    fun load(): Map<String, Map<String, Double>> = Store.load(KEY, serializer) ?: emptyMap()

    fun save(data: Map<String, Map<String, Double>>) {
        Store.save(KEY, serializer, data)
        revision++
    }

    fun metadata(): Map<String, Map<String, String>> = Store.load(META, metaSerializer) ?: emptyMap()

    fun setCategoryMetadata(key: String, name: String, color: String) {
        val meta = metadata().toMutableMap()
        meta[key] = mapOf("name" to name, "color" to color)
        Store.save(META, metaSerializer, meta)
    }

    fun clear() {
        Store.remove(KEY)
        Store.remove(META)
        revision++
    }
}

object TaskOrderManager {
    private const val storageKey = "task_list_orders_v1"
    private val serializer = MapSerializer(String.serializer(), TaskListOrder.serializer())

    var orders by mutableStateOf(runCatching { Store.load(storageKey, serializer) }.getOrNull() ?: emptyMap())
        private set

    fun sorted(tasks: List<TodoTask>, listKey: String): List<TodoTask> = TaskListOrder.sorted(tasks, orders, listKey)

    fun setOrder(taskIds: List<UUID>, listKey: String) {
        if (taskIds.isEmpty()) return
        orders = orders + (listKey to TaskListOrder(listKey, taskIds, now()))
        Store.save(storageKey, serializer, orders)
    }

    fun removeAll() {
        orders = emptyMap()
        Store.remove(storageKey)
    }
}

object ConfettiManager {
    var trigger by mutableStateOf(0)
        private set
    fun trigger() { trigger++ }
}

object SettingsViewModel {
    private fun loadBool(key: String, default: Boolean) = if (Defaults.contains(key)) Defaults.bool(key) else default
    private fun loadInt(key: String, default: Int) = if (Defaults.contains(key)) Defaults.int(key) else default

    private var _autoComplete by mutableStateOf<Boolean?>(null)
    var autoCompleteTaskWithSubtasks: Boolean
        get() = _autoComplete ?: loadBool("autoCompleteTaskWithSubtasks", true).also { _autoComplete = it }
        set(value) { _autoComplete = value; Defaults.set("autoCompleteTaskWithSubtasks", value) }

    private var _autoMark by mutableStateOf<Boolean?>(null)
    var autoMarkInProgress: Boolean
        get() = _autoMark ?: loadBool("autoMarkInProgress", true).also { _autoMark = it }
        set(value) { _autoMark = value; Defaults.set("autoMarkInProgress", value) }

    private var _gradients by mutableStateOf<Boolean?>(null)
    var showCategoryGradients: Boolean
        get() = _gradients ?: loadBool("showCategoryGradients", true).also { _gradients = it }
        set(value) { _gradients = value; Defaults.set("showCategoryGradients", value) }

    private var _todayRequire by mutableStateOf<Boolean?>(null)
    var eisenhowerTodayRequireSpecificTime: Boolean
        get() = _todayRequire ?: loadBool("eisenhowerTodayRequireSpecificTime", true).also { _todayRequire = it }
        set(value) { _todayRequire = value; Defaults.set("eisenhowerTodayRequireSpecificTime", value) }

    private var _todayHours by mutableStateOf<Int?>(null)
    var eisenhowerTodayUrgentHours: Int
        get() = _todayHours ?: loadInt("eisenhowerTodayUrgentHours", 4).also { _todayHours = it }
        set(value) { _todayHours = value; Defaults.set("eisenhowerTodayUrgentHours", value) }

    private var _weekHours by mutableStateOf<Int?>(null)
    var eisenhowerWeekUrgentHours: Int
        get() = _weekHours ?: loadInt("eisenhowerWeekUrgentHours", 24).also { _weekHours = it }
        set(value) { _weekHours = value; Defaults.set("eisenhowerWeekUrgentHours", value) }

    private var _monthDays by mutableStateOf<Int?>(null)
    var eisenhowerMonthUrgentDays: Int
        get() = _monthDays ?: loadInt("eisenhowerMonthUrgentDays", 3).also { _monthDays = it }
        set(value) { _monthDays = value; Defaults.set("eisenhowerMonthUrgentDays", value) }

    private var _yearDays by mutableStateOf<Int?>(null)
    var eisenhowerYearUrgentDays: Int
        get() = _yearDays ?: loadInt("eisenhowerYearUrgentDays", 14).also { _yearDays = it }
        set(value) { _yearDays = value; Defaults.set("eisenhowerYearUrgentDays", value) }

    private var _medium by mutableStateOf<Boolean?>(null)
    /** Off by default: only high-priority tasks count as important. */
    var eisenhowerMediumIsImportant: Boolean
        get() = _medium ?: loadBool("eisenhowerMediumIsImportant", false).also { _medium = it }
        set(value) { _medium = value; Defaults.set("eisenhowerMediumIsImportant", value) }

    fun resetEisenhowerUrgencyDefaults() {
        eisenhowerMediumIsImportant = false
        eisenhowerTodayRequireSpecificTime = true
        eisenhowerTodayUrgentHours = 4
        eisenhowerWeekUrgentHours = 24
        eisenhowerMonthUrgentDays = 3
        eisenhowerYearUrgentDays = 14
    }

    val categories: List<Category> get() = CategoryManager.categories
    fun addCategory(category: Category) = CategoryManager.addCategory(category)
    fun updateCategory(category: Category) = CategoryManager.updateCategory(category)
    fun deleteCategory(category: Category) = CategoryManager.removeCategory(category)
    suspend fun forceDeleteCategory(category: Category) = CategoryManager.forceRemoveCategory(category)
}

object CategoryManager {
    private const val categoriesKey = "savedCategories"
    private val serializer = ListSerializer(Category.serializer())

    var categories by mutableStateOf<List<Category>>(emptyList())
        private set

    /** Set when a category in use is removed: the page showing categories asks for confirmation. */
    var deletionWarning by mutableStateOf<Pair<Category, Int>?>(null)

    fun load() {
        categories = Store.load(categoriesKey, serializer) ?: emptyList()
    }

    private fun save() = Store.save(categoriesKey, serializer, categories)

    fun addCategory(category: Category) {
        if (categories.any { it.id == category.id || it.name.lowercase() == category.name.lowercase() }) return
        categories = categories + category
        save()
    }

    fun removeCategory(category: Category) {
        val using = TaskManager.tasks.count { it.category?.id == category.id }
        if (using > 0) {
            deletionWarning = category to using
            return
        }
        categories = categories.filter { it.id != category.id }
        save()
    }

    /** Removes it even if tasks are using it (tasks lose their category). */
    suspend fun forceRemoveCategory(category: Category) {
        for (task in TaskManager.tasks.filter { it.category?.id == category.id }) {
            TaskManager.updateTask(task.copy(category = null))
        }
        categories = categories.filter { it.id != category.id }
        save()
    }

    fun updateCategory(category: Category) {
        if (categories.none { it.id == category.id }) return
        categories = categories.map { if (it.id == category.id) category else it }
        save()
        val using = TaskManager.tasks.filter { it.category?.id == category.id }
        MainScope.launch { using.forEach { TaskManager.updateTask(it.copy(category = category)) } }
    }

    fun importCategories(newCategories: List<Category>) {
        val merged = ArrayList<Category>()
        val ids = HashSet<UUID>()
        val names = HashSet<String>()
        for (category in categories + newCategories) {
            val name = category.name.lowercase().trim()
            if (category.id !in ids && name !in names) {
                merged += category
                ids += category.id
                names += name
            }
        }
        categories = merged
        save()
    }

    fun performCompleteReset() {
        categories = emptyList()
        save()
    }
}
