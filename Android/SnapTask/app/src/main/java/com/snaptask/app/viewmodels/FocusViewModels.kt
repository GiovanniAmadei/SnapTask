@file:UseSerializers(UUIDSerializer::class)

package com.snaptask.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.ProcessLifecycleOwner
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import kotlinx.serialization.UseSerializers
import kotlinx.serialization.builtins.ListSerializer
import java.util.UUID
import kotlin.math.ceil

enum class PomodoroContext { general, task }

object PomodoroSettingsManager {
    private fun read(key: String) = Store.load(key, PomodoroSettings.serializer()) ?: PomodoroSettings.defaultSettings

    var generalSettings by mutableStateOf(read("generalPomodoroSettings"))
        private set
    var taskSettings by mutableStateOf(read("taskPomodoroSettings"))
        private set

    fun settings(context: PomodoroContext) = if (context == PomodoroContext.general) generalSettings else taskSettings

    fun updateSettings(settings: PomodoroSettings, context: PomodoroContext) {
        if (context == PomodoroContext.general) {
            generalSettings = settings
            Store.save("generalPomodoroSettings", PomodoroSettings.serializer(), settings)
        } else {
            taskSettings = settings
            Store.save("taskPomodoroSettings", PomodoroSettings.serializer(), settings)
        }
    }
}

enum class PomodoroState { notStarted, working, onBreak, paused, completed }

/** What iOS shows in the Live Activity: an ongoing notification with a live counter. */
private object FocusNotification {
    private const val pomodoroId = 72001

    private fun show(id: Int, title: String, text: String, chronometerBase: Date?, countDown: Boolean, tab: Int = 1) {
        if (!TaskNotificationManager.isAuthorized) return
        val context = App.context
        val open = Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP).putExtra("openTab", tab)
        val builder = NotificationCompat.Builder(context, TaskNotificationManager.timerChannelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setContentIntent(PendingIntent.getActivity(context, id, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        if (chronometerBase != null) {
            builder.setUsesChronometer(true).setWhen(chronometerBase.toEpochMilli()).setShowWhen(true).setChronometerCountDown(countDown)
        } else {
            builder.setShowWhen(false)
        }
        runCatching { NotificationManagerCompat.from(context).notify(id, builder.build()) }
    }

    fun pomodoro(title: String, text: String, end: Date?) = show(pomodoroId, title, text, end, true)
    fun endPomodoro() = NotificationManagerCompat.from(App.context).cancel(pomodoroId)

    private fun timerId(id: UUID) = 72100 + (id.hashCode() and 0xFFFF)
    fun timer(id: UUID, title: String, text: String, start: Date?) = show(timerId(id), title, text, start, false)
    fun endTimer(id: UUID) = NotificationManagerCompat.from(App.context).cancel(timerId(id))
}

object PomodoroViewModel {
    const val actionPhaseEnd = "com.snaptask.app.POMODORO_PHASE_END"
    private const val persistedKey = "pomodoro_persisted_state"
    private const val phaseEndNotificationId = 72002

    var context by mutableStateOf(PomodoroContext.general)
        private set
    private var currentTask by mutableStateOf<TodoTask?>(null)
    val activeTask: TodoTask? get() = currentTask
    var state by mutableStateOf(PomodoroState.notStarted)
        private set
    var timeRemaining by mutableStateOf(PomodoroSettings.defaultSettings.workDuration)
        private set
    var currentSession by mutableStateOf(1)
        private set
    private var completedWorkSessions by mutableStateOf<Set<Int>>(emptySet())
    private var completedBreakSessions by mutableStateOf<Set<Int>>(emptySet())
    private var pausedState by mutableStateOf<PomodoroState?>(null)

    private var ticker: Job? = null
    private var phaseEnd: Date? = null

    val settings: PomodoroSettings get() = PomodoroSettingsManager.settings(context)
    val totalSessions: Int get() = settings.totalSessions

    @Serializable
    private data class PersistedState(
        val timestamp: Double,
        val state: String,
        val timeRemaining: Double,
        val currentSession: Int,
        val context: String,
        val activeTaskId: UUID? = null,
        val pausedState: String? = null,
        val completedWorkSessions: Set<Int> = emptySet(),
        val completedBreakSessions: Set<Int> = emptySet(),
    )

    private fun persist() {
        Store.save(
            persistedKey,
            PersistedState.serializer(),
            PersistedState(
                now().toEpochMilli() / 1000.0,
                state.name,
                timeRemaining,
                currentSession,
                context.name,
                activeTask?.id,
                pausedState?.name,
                completedWorkSessions,
                completedBreakSessions,
            ),
        )
    }

    /** After the app was closed: back where it was, counting the time that went by. */
    fun load() {
        timeRemaining = settings.workDuration
        val saved = runCatching { Store.load(persistedKey, PersistedState.serializer()) }.getOrNull() ?: return
        val task = saved.activeTaskId?.let { id -> TaskManager.tasks.firstOrNull { it.id == id } }
        currentTask = task
        context = if (saved.context == "task" && task != null) PomodoroContext.task else PomodoroContext.general
        currentSession = saved.currentSession
        completedWorkSessions = saved.completedWorkSessions
        completedBreakSessions = saved.completedBreakSessions
        state = runCatching { PomodoroState.valueOf(saved.state) }.getOrDefault(PomodoroState.notStarted)
        pausedState = saved.pausedState?.let { runCatching { PomodoroState.valueOf(it) }.getOrNull() }
        timeRemaining = saved.timeRemaining
        if (state == PomodoroState.working || state == PomodoroState.onBreak) {
            val remaining = maxOf(0.0, saved.timeRemaining - maxOf(0.0, now().toEpochMilli() / 1000.0 - saved.timestamp))
            timeRemaining = remaining
            if (remaining <= 0) handleSessionCompletion() else startTimer()
        } else if (state == PomodoroState.paused) {
            updateOngoing()
        }
    }

    val effectivePhase: PomodoroState
        get() = when (state) {
            PomodoroState.paused -> pausedState ?: PomodoroState.working
            PomodoroState.notStarted -> PomodoroState.working
            else -> state
        }

    val isWorkingPhase: Boolean get() = effectivePhase == PomodoroState.working

    val totalTrackedFocusTime: Double
        get() {
            val full = completedWorkSessions.size * settings.workDuration
            val current = if (effectivePhase == PomodoroState.working) maxOf(0.0, settings.workDuration - timeRemaining) else 0.0
            return full + current
        }

    private fun breakDuration(session: Int): Double =
        if (session % maxOf(1, settings.sessionsUntilLongBreak) == 0) settings.longBreakDuration else settings.breakDuration

    private val currentPhaseDuration: Double
        get() = if (effectivePhase == PomodoroState.working) settings.workDuration else breakDuration(currentSession)

    val progress: Double
        get() {
            if (state == PomodoroState.notStarted || state == PomodoroState.completed) return 0.0
            val total = currentPhaseDuration
            if (total <= 0) return 0.0
            return (1 - timeRemaining / total).coerceIn(0.0, 1.0)
        }

    val overallProgress: Double
        get() {
            if (state == PomodoroState.notStarted) return 0.0
            val totalWork = settings.totalSessions * settings.workDuration
            if (totalWork <= 0) return 0.0
            val completed = completedWorkSessions.size * settings.workDuration
            val current = if (effectivePhase == PomodoroState.working) progress * settings.workDuration else 0.0
            return minOf(1.0, (completed + current) / totalWork)
        }

    fun clearActiveTask() {
        currentTask = null
    }

    fun setActiveTask(task: TodoTask) {
        if (activeTask?.id == task.id) return
        cancelTimer()
        FocusNotification.endPomodoro()
        currentTask = task
        context = PomodoroContext.task
        val taskSettings = task.pomodoroSettings ?: PomodoroSettingsManager.taskSettings
        PomodoroSettingsManager.updateSettings(taskSettings, PomodoroContext.task)
        reset(taskSettings.workDuration)
        persist()
    }

    fun initializeGeneralSession() {
        if (context == PomodoroContext.general && state == PomodoroState.notStarted && activeTask == null &&
            currentSession == 1 && completedWorkSessions.isEmpty() && completedBreakSessions.isEmpty()
        ) return
        stop()
        currentTask = null
        context = PomodoroContext.general
        reset(PomodoroSettingsManager.generalSettings.workDuration)
        persist()
    }

    private fun reset(work: Double) {
        timeRemaining = work
        currentSession = 1
        completedWorkSessions = emptySet()
        completedBreakSessions = emptySet()
        state = PomodoroState.notStarted
        pausedState = null
        phaseEnd = null
    }

    fun isActiveTask(task: TodoTask) = activeTask?.id == task.id && (state != PomodoroState.notStarted || hasActiveTask)

    /** Any running or paused session, also the general ones, keeps the widgets on screen. */
    val hasActiveTask: Boolean
        get() = state == PomodoroState.working || state == PomodoroState.onBreak || state == PomodoroState.paused

    fun start() {
        if (ticker != null) return
        if (state == PomodoroState.paused) {
            state = pausedState ?: PomodoroState.working
        } else {
            state = PomodoroState.working
            activeTask?.id?.let { TaskManager.markStartedIfNeeded(it) }
        }
        startTimer()
        persist()
    }

    private fun startTimer() {
        ticker?.cancel()
        phaseEnd = now().plusMillis((timeRemaining * 1000).toLong())
        ticker = MainScope.launch {
            while (isActive) {
                delay(250)
                tick()
            }
        }
        armAlarm()
        updateOngoing()
    }

    private fun cancelTimer() {
        ticker?.cancel()
        ticker = null
        phaseEnd = null
        disarmAlarm()
    }

    /** Counts from the clock, not from the ticks: nothing is lost while the system holds the app back. */
    private fun tick() {
        val end = phaseEnd ?: return
        val remaining = ceil((end.toEpochMilli() - now().toEpochMilli()) / 1000.0)
        if (remaining != timeRemaining) timeRemaining = maxOf(0.0, remaining)
        if (remaining <= 0) handleSessionCompletion()
    }

    private fun handleSessionCompletion() {
        if (state == PomodoroState.working) completeWorkSession()
        else if (state == PomodoroState.onBreak) completeBreakSession()
    }

    fun pause() {
        val end = phaseEnd
        if (end != null) timeRemaining = maxOf(0.0, ceil((end.toEpochMilli() - now().toEpochMilli()) / 1000.0))
        cancelTimer()
        if (state != PomodoroState.paused) pausedState = state
        state = PomodoroState.paused
        updateOngoing()
        persist()
    }

    fun resume() {
        if (state == PomodoroState.paused) start()
    }

    fun skip() {
        if (state == PomodoroState.working) {
            completedWorkSessions = completedWorkSessions + (currentSession - 1)
            state = PomodoroState.onBreak
            timeRemaining = breakDuration(currentSession)
            startTimer()
        } else {
            completedBreakSessions = completedBreakSessions + (currentSession - 1)
            completeBreakSession()
        }
        persist()
    }

    fun stop() {
        if (state == PomodoroState.notStarted && ticker == null && currentSession == 1 &&
            completedWorkSessions.isEmpty() && completedBreakSessions.isEmpty() && pausedState == null
        ) return
        cancelTimer()
        reset(settings.workDuration)
        FocusNotification.endPomodoro()
        Store.remove(persistedKey)
    }

    private fun finishCycle() {
        state = PomodoroState.completed
        disarmAlarm()
        FocusNotification.endPomodoro()
        Store.remove(persistedKey)
    }

    private fun completeWorkSession() {
        cancelTimer()
        completedWorkSessions = completedWorkSessions + (currentSession - 1)
        if (currentSession >= settings.totalSessions) {
            notifyPhaseEnd("session_complete".localized, "pomodoro_complete".localized)
            finishCycle()
            return
        }
        state = PomodoroState.onBreak
        timeRemaining = breakDuration(currentSession)
        notifyPhaseEnd("session_complete".localized, "break_time".localized)
        startTimer()
        persist()
    }

    private fun completeBreakSession() {
        cancelTimer()
        completedBreakSessions = completedBreakSessions + (currentSession - 1)
        currentSession += 1
        if (currentSession > settings.totalSessions) {
            notifyPhaseEnd("session_complete".localized, "pomodoro_complete".localized)
            finishCycle()
            return
        }
        state = PomodoroState.working
        timeRemaining = settings.workDuration
        notifyPhaseEnd("session_complete".localized, "focus_time".localized)
        startTimer()
        persist()
    }

    /** New settings saved: the session in progress keeps its time unless it has just begun. */
    fun applySettingsToCurrentSession() {
        val newTotal = maxOf(1, settings.totalSessions)
        if (currentSession > newTotal) currentSession = newTotal
        when {
            state == PomodoroState.notStarted -> timeRemaining = settings.workDuration
            state == PomodoroState.working && progress < 0.01 -> {
                timeRemaining = settings.workDuration
                startTimer()
            }
            state == PomodoroState.onBreak && progress < 0.01 -> {
                timeRemaining = breakDuration(currentSession)
                startTimer()
            }
        }
        if (hasActiveTask) updateOngoing()
        if (state != PomodoroState.completed) persist()
    }

    fun isSessionCompleted(session: Int, isWork: Boolean) =
        if (isWork) session in completedWorkSessions else session in completedBreakSessions

    /** Called by the alarm when the app is closed or held back. */
    fun onPhaseAlarm() = tick()

    private fun updateOngoing() {
        val title = activeTask?.name ?: "focus_session".localized
        val phase = if (effectivePhase == PomodoroState.working) "focus_time".localized else "break_time".localized
        val session = "session".localized + " $currentSession/$totalSessions"
        when (state) {
            PomodoroState.working, PomodoroState.onBreak -> FocusNotification.pomodoro(title, "$phase · $session", phaseEnd)
            PomodoroState.paused -> FocusNotification.pomodoro(title, "paused".localized + " · " + formatTimer(timeRemaining) + " · " + session, null)
            else -> FocusNotification.endPomodoro()
        }
    }

    private fun notifyPhaseEnd(title: String, body: String) {
        if (ProcessLifecycleOwner.get().lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) return
        if (!TaskNotificationManager.isAuthorized) return
        val context = App.context
        val open = Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP).putExtra("openTab", 1)
        val notification = NotificationCompat.Builder(context, TaskNotificationManager.channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setContentIntent(PendingIntent.getActivity(context, phaseEndNotificationId, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            .build()
        runCatching { NotificationManagerCompat.from(context).notify(phaseEndNotificationId, notification) }
    }

    private fun alarmOperation(flags: Int = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE): PendingIntent? =
        PendingIntent.getBroadcast(App.context, actionPhaseEnd.hashCode(), Intent(App.context, ReminderReceiver::class.java).setAction(actionPhaseEnd), flags)

    private fun armAlarm() {
        val end = phaseEnd ?: return
        val alarm = App.context.getSystemService(AlarmManager::class.java)
        val operation = alarmOperation() ?: return
        val canExact = Build.VERSION.SDK_INT < 31 || alarm.canScheduleExactAlarms()
        if (canExact) alarm.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, end.toEpochMilli(), operation)
        else alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, end.toEpochMilli(), operation)
    }

    private fun disarmAlarm() {
        val operation = alarmOperation(PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE) ?: return
        App.context.getSystemService(AlarmManager::class.java).cancel(operation)
        operation.cancel()
    }
}

object TimeTrackerViewModel {
    private const val storageKey = "activeTimerSessions"
    private const val savedAtKey = "activeTimerSessionsSavedAt"
    private val serializer = ListSerializer(TrackingSession.serializer())

    var activeSessions by mutableStateOf<List<TrackingSession>>(emptyList())
        private set
    var showingCompletion by mutableStateOf(false)
        private set
    var completedSession by mutableStateOf<TrackingSession?>(null)
        private set
    var currentSessionId by mutableStateOf<UUID?>(null)
        private set

    private var ticker: Job? = null
    private var lastTick: Date = now()
    private var lastSave: Date = now()

    fun load() {
        val saved = runCatching { Store.load(storageKey, serializer) }.getOrNull() ?: return
        val savedAt = Defaults.date(savedAtKey)
        val gone = if (savedAt != null) maxOf(0.0, now().timeIntervalSince(savedAt)) else 0.0
        activeSessions = saved
            .map { if (it.isRunning && !it.isPaused) it.copy(elapsedTime = it.elapsedTime + gone) else it }
            .filterNot { it.elapsedTime == 0.0 && !it.isRunning && !it.isPaused }
        currentSessionId = activeSessions.firstOrNull()?.id
        activeSessions.forEach { updateOngoing(it) }
        runTickerIfNeeded()
    }

    fun persist() {
        lastSave = now()
        Store.save(storageKey, serializer, activeSessions)
        Defaults.set(savedAtKey, now())
    }

    private fun change(id: UUID, block: (TrackingSession) -> TrackingSession) {
        activeSessions = activeSessions.map { if (it.id == id) block(it) else it }
    }

    private fun runTickerIfNeeded() {
        val running = activeSessions.any { it.isRunning && !it.isPaused }
        if (!running) {
            ticker?.cancel()
            ticker = null
            return
        }
        if (ticker != null) return
        lastTick = now()
        ticker = MainScope.launch {
            while (isActive) {
                delay(500)
                val time = now()
                val delta = maxOf(0.0, time.timeIntervalSince(lastTick))
                lastTick = time
                activeSessions = activeSessions.map { if (it.isRunning && !it.isPaused) it.copy(elapsedTime = it.elapsedTime + delta) else it }
                if (time.timeIntervalSince(lastSave) >= 10) persist()
            }
        }
    }

    val hasActiveSession: Boolean get() = activeSessions.any { it.isRunning || it.elapsedTime > 0 || it.isPaused }

    val currentSession: TrackingSession?
        get() = currentSessionId?.let { id -> activeSessions.firstOrNull { it.id == id } } ?: activeSessions.firstOrNull()

    fun getSession(id: UUID) = activeSessions.firstOrNull { it.id == id }

    fun startSession(task: TodoTask?, mode: TrackingMode): UUID {
        val existing = activeSessions.firstOrNull { it.taskId == task?.id }
        if (existing != null) {
            currentSessionId = existing.id
            return existing.id
        }
        if (mode == TrackingMode.simple && activeSessions.size >= 2) return activeSessions.first().id
        val session = TrackingSession(
            taskId = task?.id,
            taskName = task?.name,
            mode = mode,
            categoryId = task?.category?.id,
            categoryName = task?.category?.name,
        )
        activeSessions = activeSessions + session
        currentSessionId = session.id
        persist()
        return session.id
    }

    fun startTimer(id: UUID) {
        change(id) { it.copy(isRunning = true, isPaused = false) }
        val session = getSession(id) ?: return
        session.taskId?.let { TaskManager.markStartedIfNeeded(it) }
        runTickerIfNeeded()
        persist()
        updateOngoing(session)
    }

    fun pauseSession(id: UUID) {
        change(id) { it.copy(isPaused = true) }
        runTickerIfNeeded()
        persist()
        getSession(id)?.let { updateOngoing(it) }
    }

    fun resumeSession(id: UUID) {
        change(id) { it.copy(isPaused = false) }
        startTimer(id)
    }

    fun stopSession(id: UUID) {
        val session = getSession(id)?.completed() ?: return
        change(id) { session }
        runTickerIfNeeded()
        persist()
        updateOngoing(session)
        completedSession = session
        showingCompletion = true
    }

    fun continueAfterCompletion() {
        completedSession = null
        showingCompletion = false
    }

    private fun remove(id: UUID) {
        activeSessions = activeSessions.filter { it.id != id }
        if (currentSessionId == id) currentSessionId = activeSessions.firstOrNull()?.id
        FocusNotification.endTimer(id)
        runTickerIfNeeded()
        persist()
    }

    fun saveSession(id: UUID) {
        val session = completedSession ?: getSession(id) ?: return
        session.taskId?.let { TaskManager.addTrackedTime(session.effectiveWorkTime, it) }
        remove(id)
        continueAfterCompletion()
    }

    fun saveCurrentSession() {
        currentSession?.let { saveSession(it.id) }
    }

    fun discardSession(id: UUID) {
        remove(id)
        continueAfterCompletion()
    }

    fun discardCurrentSession() {
        currentSession?.let { discardSession(it.id) }
    }

    fun removeSession(id: UUID) = remove(id)

    fun formattedElapsedTime(id: UUID): String {
        val session = getSession(id) ?: return "00:00"
        return formatElapsed(session.elapsedTime)
    }

    private fun updateOngoing(session: TrackingSession) {
        val title = session.taskName ?: "focus_session".localized
        when {
            session.isRunning && !session.isPaused -> FocusNotification.timer(session.id, title, "simple_timer".localized, now().minusMillis((session.elapsedTime * 1000).toLong()))
            session.isPaused || session.elapsedTime > 0 -> FocusNotification.timer(session.id, title, "paused".localized + " · " + formatElapsed(session.elapsedTime), null)
            else -> FocusNotification.endTimer(session.id)
        }
    }
}

fun formatTimer(seconds: Double): String {
    val total = seconds.toInt()
    return "%02d:%02d".format(total / 60, total % 60)
}

fun formatElapsed(seconds: Double): String {
    val total = seconds.toInt()
    val hours = total / 3600
    return if (hours > 0) "%02d:%02d:%02d".format(hours, total % 3600 / 60, total % 60) else "%02d:%02d".format(total % 3600 / 60, total % 60)
}

/** "2h 5m", "25m" */
fun formatFocusDuration(seconds: Double): String {
    val total = seconds.toInt()
    val hours = total / 3600
    val minutes = total % 3600 / 60
    return if (hours > 0) "${hours}h ${minutes}m" else "${minutes}m"
}
