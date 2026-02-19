package com.snaptask.app.ui.focus

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.snaptask.app.data.model.TodoTask
import com.snaptask.app.data.model.TrackingMode
import com.snaptask.app.data.model.TrackingSession
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import java.util.*
import javax.inject.Inject

/**
 * ViewModel for simple time-tracking (stopwatch) sessions.
 * Manages multiple concurrent tracking sessions, matching iOS TimeTrackerViewModel.
 */
@HiltViewModel
class TimeTrackerViewModel @Inject constructor() : ViewModel() {

    // ---- Active Sessions ----

    private val _activeSessions = MutableStateFlow<List<TrackingSession>>(emptyList())
    val activeSessions: StateFlow<List<TrackingSession>> = _activeSessions.asStateFlow()

    // ---- Completed sessions (in-memory for now) ----

    private val _completedSessions = MutableStateFlow<List<TrackingSession>>(emptyList())
    val completedSessions: StateFlow<List<TrackingSession>> = _completedSessions.asStateFlow()

    // ---- Current active session (for single-session UI) ----

    private val _currentSession = MutableStateFlow<TrackingSession?>(null)
    val currentSession: StateFlow<TrackingSession?> = _currentSession.asStateFlow()

    private var timerJob: Job? = null

    // ---- Derived state ----

    val hasActiveSessions: StateFlow<Boolean> = _activeSessions.map { it.isNotEmpty() }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), false)

    val todayFocusTime: StateFlow<Double> = _completedSessions.map { sessions ->
        val calendar = Calendar.getInstance()
        val today = calendar.apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.time
        sessions.filter { it.startTime >= today }.sumOf { it.effectiveWorkTime }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), 0.0)

    val todaySessionCount: StateFlow<Int> = _completedSessions.map { sessions ->
        val calendar = Calendar.getInstance()
        val today = calendar.apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.time
        sessions.count { it.startTime >= today }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), 0)

    val recentSessions: StateFlow<List<TrackingSession>> = _completedSessions.map { sessions ->
        sessions.sortedByDescending { it.startTime }.take(5)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    // ---- Actions ----

    fun startSession(task: TodoTask? = null, mode: TrackingMode = TrackingMode.STOPWATCH) {
        val session = TrackingSession(
            taskId = task?.id,
            taskName = task?.name,
            mode = mode,
            categoryId = task?.category?.id,
            categoryName = task?.category?.name,
            startTime = Date(),
            isRunning = true,
        )
        _currentSession.value = session
        _activeSessions.value = _activeSessions.value + session
        startTimer()
    }

    fun pauseSession() {
        val session = _currentSession.value ?: return
        if (!session.isRunning) return
        timerJob?.cancel()
        timerJob = null

        val updated = session.copy(
            isRunning = false,
            isPaused = true,
        )
        _currentSession.value = updated
        _activeSessions.value = _activeSessions.value.map {
            if (it.id == updated.id) updated else it
        }
    }

    fun resumeSession() {
        val session = _currentSession.value ?: return
        if (!session.isPaused) return

        val updated = session.copy(
            isRunning = true,
            isPaused = false,
        )
        _currentSession.value = updated
        _activeSessions.value = _activeSessions.value.map {
            if (it.id == updated.id) updated else it
        }
        startTimer()
    }

    fun stopSession(): TrackingSession? {
        timerJob?.cancel()
        timerJob = null

        val session = _currentSession.value ?: return null
        val completed = session.copy(
            isRunning = false,
            isPaused = false,
            isCompleted = true,
            endTime = Date(),
            totalDuration = session.elapsedTime,
        )
        _currentSession.value = null
        _activeSessions.value = _activeSessions.value.filter { it.id != session.id }
        _completedSessions.value = _completedSessions.value + completed
        return completed
    }

    fun discardSession() {
        timerJob?.cancel()
        timerJob = null
        val session = _currentSession.value ?: return
        _currentSession.value = null
        _activeSessions.value = _activeSessions.value.filter { it.id != session.id }
    }

    val formattedElapsedTime: String
        get() {
            val elapsed = _currentSession.value?.elapsedTime ?: 0.0
            val totalSeconds = elapsed.toLong()
            val hours = totalSeconds / 3600
            val minutes = (totalSeconds % 3600) / 60
            val seconds = totalSeconds % 60
            return if (hours > 0) {
                String.format("%02d:%02d:%02d", hours, minutes, seconds)
            } else {
                String.format("%02d:%02d", minutes, seconds)
            }
        }

    // ---- Timer internals ----

    private fun startTimer() {
        timerJob?.cancel()
        timerJob = viewModelScope.launch {
            while (isActive) {
                delay(1000L)
                val session = _currentSession.value ?: break
                if (!session.isRunning) break
                val updated = session.copy(
                    elapsedTime = session.elapsedTime + 1.0,
                )
                _currentSession.value = updated
                _activeSessions.value = _activeSessions.value.map {
                    if (it.id == updated.id) updated else it
                }
            }
        }
    }

    override fun onCleared() {
        super.onCleared()
        timerJob?.cancel()
    }
}
