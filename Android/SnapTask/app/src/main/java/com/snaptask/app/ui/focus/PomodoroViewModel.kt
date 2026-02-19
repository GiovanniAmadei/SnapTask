package com.snaptask.app.ui.focus

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.snaptask.app.data.model.PomodoroSettings
import com.snaptask.app.data.model.TodoTask
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import java.util.UUID
import javax.inject.Inject

/**
 * Pomodoro timer state enum, matching iOS PomodoroState.
 */
enum class PomodoroState {
    NOT_STARTED,
    WORKING,
    ON_BREAK,
    PAUSED,
    COMPLETED,
}

/**
 * ViewModel for the Pomodoro timer.
 * Manages work/break sessions with configurable durations.
 */
@HiltViewModel
class PomodoroViewModel @Inject constructor() : ViewModel() {

    // ---- Timer State ----

    private val _state = MutableStateFlow(PomodoroState.NOT_STARTED)
    val state: StateFlow<PomodoroState> = _state.asStateFlow()

    private val _timeRemaining = MutableStateFlow(0L) // seconds
    val timeRemaining: StateFlow<Long> = _timeRemaining.asStateFlow()

    private val _currentSession = MutableStateFlow(1)
    val currentSession: StateFlow<Int> = _currentSession.asStateFlow()

    private val _activeTask = MutableStateFlow<TodoTask?>(null)
    val activeTask: StateFlow<TodoTask?> = _activeTask.asStateFlow()

    private val _settings = MutableStateFlow(PomodoroSettings())
    val settings: StateFlow<PomodoroSettings> = _settings.asStateFlow()

    private val _completedWorkSessions = MutableStateFlow<Set<Int>>(emptySet())
    val completedWorkSessions: StateFlow<Set<Int>> = _completedWorkSessions.asStateFlow()

    private val _completedBreakSessions = MutableStateFlow<Set<Int>>(emptySet())

    private var timerJob: Job? = null
    private var pausedState: PomodoroState? = null

    // ---- Derived state ----

    val progress: StateFlow<Float> = combine(
        _state, _timeRemaining, _settings,
    ) { state, remaining, settings ->
        if (state == PomodoroState.NOT_STARTED || state == PomodoroState.COMPLETED) return@combine 0f

        val total: Double = if (state == PomodoroState.WORKING) settings.workDuration
        else {
            val session = _currentSession.value
            if (session % settings.sessionsUntilLongBreak == 0) settings.longBreakDuration
            else settings.breakDuration
        }
        if (total <= 0.0) return@combine 0f
        (1f - (remaining.toFloat() / total.toFloat())).coerceIn(0f, 1f)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), 0f)

    val totalSessions: Int
        get() = _settings.value.totalSessions

    val formattedTime: String
        get() {
            val remaining = _timeRemaining.value
            val minutes = remaining / 60
            val seconds = remaining % 60
            return String.format("%02d:%02d", minutes, seconds)
        }

    val hasActiveTask: Boolean
        get() = _activeTask.value != null && _state.value != PomodoroState.NOT_STARTED

    // ---- Actions ----

    fun setActiveTask(task: TodoTask) {
        if (_activeTask.value?.id != task.id || _state.value == PomodoroState.NOT_STARTED) {
            stop()
            _activeTask.value = task
            val taskSettings = task.pomodoroSettings ?: PomodoroSettings()
            _settings.value = taskSettings
            _timeRemaining.value = taskSettings.workDuration.toLong()
            _currentSession.value = 1
            _completedWorkSessions.value = emptySet()
            _completedBreakSessions.value = emptySet()
            _state.value = PomodoroState.NOT_STARTED
        }
    }

    fun initializeGeneralSession() {
        stop()
        _activeTask.value = null
        val defaultSettings = PomodoroSettings()
        _settings.value = defaultSettings
        _timeRemaining.value = defaultSettings.workDuration.toLong()
        _currentSession.value = 1
        _completedWorkSessions.value = emptySet()
        _completedBreakSessions.value = emptySet()
        _state.value = PomodoroState.NOT_STARTED
    }

    fun start() {
        if (timerJob != null && timerJob?.isActive == true) return

        if (_state.value == PomodoroState.PAUSED) {
            _state.value = pausedState ?: PomodoroState.WORKING
        } else {
            _state.value = PomodoroState.WORKING
        }

        startTimer()
    }

    fun pause() {
        timerJob?.cancel()
        timerJob = null
        pausedState = _state.value
        _state.value = PomodoroState.PAUSED
    }

    fun resume() {
        if (_state.value != PomodoroState.PAUSED) return
        start()
    }

    fun skip() {
        val currentState = _state.value
        val session = _currentSession.value

        if (currentState == PomodoroState.WORKING) {
            _completedWorkSessions.value = _completedWorkSessions.value + (session - 1)
            transitionToBreak()
        } else if (currentState == PomodoroState.ON_BREAK) {
            _completedBreakSessions.value = _completedBreakSessions.value + (session - 1)
            completeBreakSession()
        }
    }

    fun stop() {
        timerJob?.cancel()
        timerJob = null
        _state.value = PomodoroState.NOT_STARTED
        _timeRemaining.value = _settings.value.workDuration.toLong()
        _currentSession.value = 1
        _completedWorkSessions.value = emptySet()
        _completedBreakSessions.value = emptySet()
        pausedState = null
    }

    fun updateSettings(newSettings: PomodoroSettings) {
        _settings.value = newSettings
        if (_state.value == PomodoroState.NOT_STARTED) {
            _timeRemaining.value = newSettings.workDuration.toLong()
        }
    }

    fun isSessionCompleted(session: Int, isWork: Boolean): Boolean {
        return if (isWork) session in _completedWorkSessions.value
        else session in _completedBreakSessions.value
    }

    // ---- Timer internals ----

    private fun startTimer() {
        timerJob = viewModelScope.launch {
            while (isActive && _timeRemaining.value > 0) {
                delay(1000L)
                _timeRemaining.value = (_timeRemaining.value - 1).coerceAtLeast(0)

                if (_timeRemaining.value <= 0) {
                    handleSessionCompletion()
                }
            }
        }
    }

    private fun handleSessionCompletion() {
        when (_state.value) {
            PomodoroState.WORKING -> completeWorkSession()
            PomodoroState.ON_BREAK -> completeBreakSession()
            else -> {}
        }
    }

    private fun completeWorkSession() {
        timerJob?.cancel()
        timerJob = null

        val session = _currentSession.value
        _completedWorkSessions.value = _completedWorkSessions.value + (session - 1)

        val settings = _settings.value
        if (session >= settings.totalSessions) {
            _state.value = PomodoroState.COMPLETED
            return
        }

        transitionToBreak()
    }

    private fun transitionToBreak() {
        val settings = _settings.value
        val session = _currentSession.value

        _state.value = PomodoroState.ON_BREAK
        _timeRemaining.value = if (session % settings.sessionsUntilLongBreak == 0) {
            settings.longBreakDuration.toLong()
        } else {
            settings.breakDuration.toLong()
        }
        startTimer()
    }

    private fun completeBreakSession() {
        timerJob?.cancel()
        timerJob = null

        val session = _currentSession.value
        _completedBreakSessions.value = _completedBreakSessions.value + (session - 1)
        _currentSession.value = session + 1

        val settings = _settings.value
        if (_currentSession.value > settings.totalSessions) {
            _state.value = PomodoroState.COMPLETED
            return
        }

        _state.value = PomodoroState.WORKING
        _timeRemaining.value = settings.workDuration.toLong()
        startTimer()
    }

    override fun onCleared() {
        super.onCleared()
        timerJob?.cancel()
    }
}
