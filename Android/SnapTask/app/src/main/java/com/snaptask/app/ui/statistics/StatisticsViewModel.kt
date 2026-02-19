package com.snaptask.app.ui.statistics

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.snaptask.app.data.model.*
import com.snaptask.app.data.repository.TaskRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import java.util.*
import javax.inject.Inject

@HiltViewModel
class StatisticsViewModel @Inject constructor(
    private val taskRepository: TaskRepository,
) : ViewModel() {

    // ---- Enums ----

    enum class TimeRange(val displayName: String) {
        TODAY("Today"),
        WEEK("Week"),
        MONTH("Month"),
        YEAR("Year"),
        ALL_TIME("All Time");

        val dateRange: Pair<Date, Date>
            get() {
                val calendar = Calendar.getInstance()
                val end = calendar.time
                when (this) {
                    TODAY -> {
                        calendar.set(Calendar.HOUR_OF_DAY, 0)
                        calendar.set(Calendar.MINUTE, 0)
                        calendar.set(Calendar.SECOND, 0)
                        calendar.set(Calendar.MILLISECOND, 0)
                    }
                    WEEK -> calendar.add(Calendar.DAY_OF_YEAR, -7)
                    MONTH -> calendar.add(Calendar.MONTH, -1)
                    YEAR -> calendar.add(Calendar.YEAR, -1)
                    ALL_TIME -> calendar.add(Calendar.YEAR, -10)
                }
                return Pair(calendar.time, end)
            }
    }

    enum class ConsistencyTimeRange(val displayName: String) {
        WEEK("Week"),
        MONTH("Month"),
        YEAR("Year");

        val daysCount: Int
            get() = when (this) {
                WEEK -> 7
                MONTH -> 30
                YEAR -> 365
            }
    }

    enum class ImprovementTrend(val displayName: String) {
        IMPROVING("Improving"),
        STABLE("Stable"),
        DECLINING("Declining"),
        INSUFFICIENT("Insufficient Data");

        val icon: String
            get() = when (this) {
                IMPROVING -> "trending_up"
                STABLE -> "trending_flat"
                DECLINING -> "trending_down"
                INSUFFICIENT -> "help_outline"
            }

        val colorHex: String
            get() = when (this) {
                IMPROVING -> "#22C55E"
                STABLE -> "#3B82F6"
                DECLINING -> "#F97316"
                INSUFFICIENT -> "#9CA3AF"
            }
    }

    // ---- Data Classes ----

    data class CategoryStat(
        val id: UUID = UUID.randomUUID(),
        val name: String,
        val hours: Double,
        val color: String,
    )

    data class WeeklyStat(
        val day: String,
        val completedTasks: Int,
        val totalTasks: Int,
        val completionRate: Double,
    )

    data class TaskStreak(
        val id: UUID = UUID.randomUUID(),
        val taskId: UUID,
        val taskName: String,
        val categoryName: String?,
        val categoryColor: String?,
        val currentStreak: Int,
        val bestStreak: Int,
        val totalOccurrences: Int,
        val completedOccurrences: Int,
        val completionRate: Double,
        val streakHistory: List<StreakPoint>,
    )

    data class StreakPoint(
        val id: UUID = UUID.randomUUID(),
        val date: Date,
        val streakValue: Int,
        val wasCompleted: Boolean,
    )

    data class TaskPerformanceAnalytics(
        val id: UUID = UUID.randomUUID(),
        val taskId: UUID,
        val taskName: String,
        val categoryName: String?,
        val categoryColor: String?,
        val completions: List<TaskCompletionAnalytics>,
        val averageDifficulty: Double?,
        val averageQuality: Double?,
        val averageDuration: Double?,
        val estimationAccuracy: Double?,
        val improvementTrend: ImprovementTrend,
    )

    data class TaskCompletionAnalytics(
        val id: UUID = UUID.randomUUID(),
        val date: Date,
        val actualDuration: Double?,
        val difficultyRating: Int?,
        val qualityRating: Int?,
        val estimatedDuration: Double?,
        val wasTracked: Boolean,
    )

    // ---- State ----

    private val _allTasks = MutableStateFlow<List<TodoTask>>(emptyList())

    private val _selectedTimeRange = MutableStateFlow(TimeRange.WEEK)
    val selectedTimeRange: StateFlow<TimeRange> = _selectedTimeRange.asStateFlow()

    private val _categoryStats = MutableStateFlow<List<CategoryStat>>(emptyList())
    val categoryStats: StateFlow<List<CategoryStat>> = _categoryStats.asStateFlow()

    private val _currentStreak = MutableStateFlow(0)
    val currentStreak: StateFlow<Int> = _currentStreak.asStateFlow()

    private val _bestStreak = MutableStateFlow(0)
    val bestStreak: StateFlow<Int> = _bestStreak.asStateFlow()

    private val _taskStreaks = MutableStateFlow<List<TaskStreak>>(emptyList())
    val taskStreaks: StateFlow<List<TaskStreak>> = _taskStreaks.asStateFlow()

    private val _recurringTasks = MutableStateFlow<List<TodoTask>>(emptyList())
    val recurringTasks: StateFlow<List<TodoTask>> = _recurringTasks.asStateFlow()

    private val _consistency = MutableStateFlow<List<TodoTask>>(emptyList())
    val consistency: StateFlow<List<TodoTask>> = _consistency.asStateFlow()

    private val _taskPerformanceAnalytics = MutableStateFlow<List<TaskPerformanceAnalytics>>(emptyList())
    val taskPerformanceAnalytics: StateFlow<List<TaskPerformanceAnalytics>> = _taskPerformanceAnalytics.asStateFlow()

    private val _topPerformingTasks = MutableStateFlow<List<TaskPerformanceAnalytics>>(emptyList())
    val topPerformingTasks: StateFlow<List<TaskPerformanceAnalytics>> = _topPerformingTasks.asStateFlow()

    private val _tasksNeedingImprovement = MutableStateFlow<List<TaskPerformanceAnalytics>>(emptyList())
    val tasksNeedingImprovement: StateFlow<List<TaskPerformanceAnalytics>> = _tasksNeedingImprovement.asStateFlow()

    // ---- Init ----

    init {
        viewModelScope.launch {
            taskRepository.allTasks.collect { tasks ->
                _allTasks.value = tasks
                updateRecurringTasks()
                refreshAll()
            }
        }

        viewModelScope.launch {
            _selectedTimeRange.collect {
                refreshAll()
            }
        }
    }

    fun setTimeRange(range: TimeRange) {
        _selectedTimeRange.value = range
    }

    private fun refreshAll() {
        updateCategoryStats()
        updateStreaks()
        updateTaskStreaks()
        updateTaskPerformanceAnalytics()
    }

    // ---- Category Stats ----

    private fun updateCategoryStats() {
        val tasks = _allTasks.value
        val (startDate, endDate) = _selectedTimeRange.value.dateRange
        val calendar = Calendar.getInstance()

        val categoryHours = mutableMapOf<String, Pair<Double, String>>()

        for (task in tasks) {
            val categoryName = task.category?.name ?: "Uncategorized"
            val categoryColor = task.category?.color ?: "#9CA3AF"

            for ((key, completion) in task.completions) {
                if (!completion.isCompleted) continue
                val completionDate = Date(key)
                if (completionDate.before(startDate) || completionDate.after(endDate)) continue

                val hours = if (completion.actualDuration != null) {
                    completion.actualDuration / 3600.0
                } else if (task.hasDuration) {
                    task.duration / 3600.0
                } else {
                    0.5 // default 30 min
                }

                val current = categoryHours[categoryName]
                categoryHours[categoryName] = Pair(
                    (current?.first ?: 0.0) + hours,
                    categoryColor
                )
            }
        }

        _categoryStats.value = categoryHours.map { (name, pair) ->
            CategoryStat(name = name, hours = pair.first, color = pair.second)
        }.sortedByDescending { it.hours }
    }

    // ---- Streaks ----

    private fun updateStreaks() {
        val tasks = _allTasks.value
        val calendar = Calendar.getInstance()
        val today = Recurrence.startOfDay(Date())

        calendar.time = today
        calendar.add(Calendar.YEAR, -1)
        val yearAgo = calendar.time

        val dates = mutableListOf<Date>()
        var currentDate = yearAgo
        while (!currentDate.after(today)) {
            dates.add(currentDate)
            calendar.time = currentDate
            calendar.add(Calendar.DAY_OF_YEAR, 1)
            currentDate = calendar.time
        }

        var currentStreak = 0
        var bestStreak = 0
        var tempStreak = 0

        for (date in dates.reversed()) {
            val startOfDay = Recurrence.startOfDay(date)

            val dayTasks = tasks.filter { task ->
                if (task.startTime.after(startOfDay)) return@filter false

                if (TodoTask.isSameDay(task.startTime, date)) return@filter true

                val recurrence = task.recurrence ?: return@filter false
                if (recurrence.endDate != null && recurrence.endDate.before(startOfDay)) return@filter false

                shouldTaskOccurOnDate(task, startOfDay)
            }

            val allCompletedForDay = dayTasks.isNotEmpty() && dayTasks.all { task ->
                val completion = task.completions[startOfDay.time]
                completion?.isCompleted == true
            }

            if (allCompletedForDay) {
                tempStreak++
                bestStreak = maxOf(bestStreak, tempStreak)
                if (TodoTask.isSameDay(date, Date())) {
                    currentStreak = tempStreak
                }
            } else {
                if (tempStreak > 0 && TodoTask.isSameDay(date, Date())) {
                    currentStreak = 0
                }
                tempStreak = 0
            }
        }

        _currentStreak.value = currentStreak
        _bestStreak.value = bestStreak
    }

    // ---- Task Streaks ----

    private fun updateTaskStreaks() {
        val calendar = Calendar.getInstance()
        val today = Recurrence.startOfDay(Date())
        calendar.time = today
        calendar.add(Calendar.DAY_OF_YEAR, -30)
        val thirtyDaysAgo = calendar.time

        val taskStreaksList = mutableListOf<TaskStreak>()

        for (task in _recurringTasks.value) {
            val recurrence = task.recurrence ?: continue

            val streakHistory = mutableListOf<StreakPoint>()
            var currentStreak = 0
            var bestStreak = 0
            var tempStreak = 0
            var totalOccurrences = 0
            var completedOccurrences = 0

            val dates = mutableListOf<Date>()
            var currentDate = thirtyDaysAgo
            while (!currentDate.after(today)) {
                dates.add(currentDate)
                calendar.time = currentDate
                calendar.add(Calendar.DAY_OF_YEAR, 1)
                currentDate = calendar.time
            }

            for (date in dates) {
                val startOfDay = Recurrence.startOfDay(date)

                if (shouldTaskOccurOnDate(task, startOfDay)) {
                    totalOccurrences++
                    val isCompleted = task.completions[startOfDay.time]?.isCompleted == true

                    if (isCompleted) {
                        tempStreak++
                        completedOccurrences++
                        bestStreak = maxOf(bestStreak, tempStreak)
                        if (TodoTask.isSameDay(date, today)) {
                            currentStreak = tempStreak
                        }
                    } else {
                        if (tempStreak > 0 && TodoTask.isSameDay(date, today)) {
                            currentStreak = 0
                        }
                        tempStreak = 0
                    }

                    streakHistory.add(
                        StreakPoint(
                            date = startOfDay,
                            streakValue = tempStreak,
                            wasCompleted = isCompleted
                        )
                    )
                }
            }

            val completionRate = if (totalOccurrences > 0) {
                completedOccurrences.toDouble() / totalOccurrences.toDouble()
            } else 0.0

            taskStreaksList.add(
                TaskStreak(
                    taskId = task.id,
                    taskName = task.name,
                    categoryName = task.category?.name,
                    categoryColor = task.category?.color,
                    currentStreak = currentStreak,
                    bestStreak = bestStreak,
                    totalOccurrences = totalOccurrences,
                    completedOccurrences = completedOccurrences,
                    completionRate = completionRate,
                    streakHistory = streakHistory
                )
            )
        }

        _taskStreaks.value = taskStreaksList.sortedByDescending { it.currentStreak }
    }

    private fun updateRecurringTasks() {
        _recurringTasks.value = _allTasks.value.filter { it.recurrence != null }
        _consistency.value = _recurringTasks.value
    }

    // ---- Consistency Points ----

    fun consistencyPoints(task: TodoTask, timeRange: ConsistencyTimeRange): List<Pair<Float, Float>> {
        val recurrence = task.recurrence ?: return emptyList()
        val calendar = Calendar.getInstance()
        val today = Date()
        val points = mutableListOf<Pair<Float, Float>>()
        val daysToAnalyze = timeRange.daysCount

        var cumulativeProgress = 0.0

        for (dayOffset in (1 - daysToAnalyze)..0) {
            calendar.time = today
            calendar.add(Calendar.DAY_OF_YEAR, dayOffset)
            val date = Recurrence.startOfDay(calendar.time)

            if (shouldTaskOccurOnDate(task, date)) {
                val isCompleted = task.completions[date.time]?.isCompleted == true

                if (isCompleted) {
                    cumulativeProgress += 1.0
                } else {
                    cumulativeProgress = maxOf(0.0, cumulativeProgress - 0.5)
                }

                val xPosition = (dayOffset + daysToAnalyze).toFloat() / daysToAnalyze.toFloat()
                points.add(Pair(xPosition, cumulativeProgress.toFloat()))
            }
        }

        return points
    }

    // ---- Helper ----

    fun shouldTaskOccurOnDate(task: TodoTask, date: Date): Boolean {
        val recurrence = task.recurrence ?: return false
        val calendar = Calendar.getInstance()

        if (date.before(Recurrence.startOfDay(task.startTime))) return false
        if (recurrence.endDate != null && date.after(recurrence.endDate)) return false

        return when (recurrence.type) {
            RecurrenceType.DAILY -> true
            is RecurrenceType.WEEKLY -> {
                calendar.time = date
                recurrence.type.days.contains(calendar.get(Calendar.DAY_OF_WEEK))
            }
            is RecurrenceType.MONTHLY -> {
                calendar.time = date
                recurrence.type.days.contains(calendar.get(Calendar.DAY_OF_MONTH))
            }
            is RecurrenceType.MONTHLY_ORDINAL -> recurrence.shouldOccurOn(date)
            RecurrenceType.YEARLY -> recurrence.shouldOccurOn(date)
        }
    }

    // ---- Weekly/Monthly Stats ----

    fun getWeeklyStatsForDay(date: Date): Triple<Int, Int, Double> {
        val calendar = Calendar.getInstance()
        val startOfDay = Recurrence.startOfDay(date)
        calendar.time = startOfDay
        calendar.add(Calendar.DAY_OF_YEAR, 1)
        calendar.add(Calendar.SECOND, -1)
        val endOfDay = calendar.time

        val tasks = _allTasks.value

        val singleDayTasks = tasks.filter { task ->
            task.recurrence == null && TodoTask.isSameDay(task.startTime, date)
        }

        val recurringDayTasks = tasks.filter { task ->
            val recurrence = task.recurrence ?: return@filter false
            if (task.startTime.after(endOfDay)) return@filter false
            if (recurrence.endDate != null && recurrence.endDate.before(startOfDay)) return@filter false
            shouldTaskOccurOnDate(task, startOfDay)
        }

        val allDayTasks = singleDayTasks + recurringDayTasks
        val completedCount = allDayTasks.count { task ->
            task.completions[startOfDay.time]?.isCompleted == true
        }

        val totalCount = allDayTasks.size
        val rate = if (totalCount > 0) completedCount.toDouble() / totalCount.toDouble() else 0.0

        return Triple(completedCount, totalCount, rate)
    }

    fun getWeeklyStatsForWeekOffset(weekOffset: Int): Triple<Int, Int, Double> {
        val calendar = Calendar.getInstance()
        val today = Date()
        calendar.time = today
        calendar.add(Calendar.WEEK_OF_YEAR, -weekOffset)
        val weekStart = calendar.time
        calendar.add(Calendar.DAY_OF_YEAR, 6)
        val weekEnd = calendar.time

        var totalCompleted = 0
        var totalTasks = 0

        var currentDate = weekStart
        while (!currentDate.after(weekEnd)) {
            val dayStats = getWeeklyStatsForDay(currentDate)
            totalCompleted += dayStats.first
            totalTasks += dayStats.second
            calendar.time = currentDate
            calendar.add(Calendar.DAY_OF_YEAR, 1)
            currentDate = calendar.time
        }

        val rate = if (totalTasks > 0) totalCompleted.toDouble() / totalTasks.toDouble() else 0.0
        return Triple(totalCompleted, totalTasks, rate)
    }

    fun getMonthlyStatsForMonth(month: Date): Triple<Int, Int, Double> {
        val calendar = Calendar.getInstance()
        calendar.time = month
        calendar.set(Calendar.DAY_OF_MONTH, 1)
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        val monthStart = calendar.time
        calendar.add(Calendar.MONTH, 1)
        calendar.add(Calendar.SECOND, -1)
        val monthEnd = calendar.time

        var totalCompleted = 0
        var totalTasks = 0

        var currentDate = monthStart
        while (!currentDate.after(monthEnd)) {
            val dayStats = getWeeklyStatsForDay(currentDate)
            totalCompleted += dayStats.first
            totalTasks += dayStats.second
            calendar.time = currentDate
            calendar.add(Calendar.DAY_OF_YEAR, 1)
            currentDate = calendar.time
        }

        val rate = if (totalTasks > 0) totalCompleted.toDouble() / totalTasks.toDouble() else 0.0
        return Triple(totalCompleted, totalTasks, rate)
    }

    // ---- Task Performance Analytics ----

    private fun updateTaskPerformanceAnalytics() {
        val allTasks = _allTasks.value
        val (startDate, endDate) = _selectedTimeRange.value.dateRange

        val analyticsArray = mutableListOf<TaskPerformanceAnalytics>()

        for (task in allTasks) {
            val completionAnalytics = getTaskCompletionAnalytics(task, startDate, endDate)
            if (completionAnalytics.isEmpty()) continue

            val difficulties = completionAnalytics.mapNotNull { it.difficultyRating }
            val avgDifficulty = if (difficulties.isNotEmpty()) {
                difficulties.sum().toDouble() / difficulties.size
            } else null

            val qualities = completionAnalytics.mapNotNull { it.qualityRating }
            val avgQuality = if (qualities.isNotEmpty()) {
                qualities.sum().toDouble() / qualities.size
            } else null

            val durations = completionAnalytics.mapNotNull { it.actualDuration }
            val avgDuration = if (durations.isNotEmpty()) {
                durations.sum() / durations.size
            } else null

            val estimationAccuracy = calculateEstimationAccuracy(completionAnalytics)
            val improvementTrend = calculateImprovementTrend(completionAnalytics)

            analyticsArray.add(
                TaskPerformanceAnalytics(
                    taskId = task.id,
                    taskName = task.name,
                    categoryName = task.category?.name,
                    categoryColor = task.category?.color,
                    completions = completionAnalytics,
                    averageDifficulty = avgDifficulty,
                    averageQuality = avgQuality,
                    averageDuration = avgDuration,
                    estimationAccuracy = estimationAccuracy,
                    improvementTrend = improvementTrend
                )
            )
        }

        _taskPerformanceAnalytics.value = analyticsArray

        _topPerformingTasks.value = analyticsArray
            .filter { (it.averageQuality ?: 0.0) >= 7.0 }
            .sortedByDescending { it.averageQuality ?: 0.0 }
            .take(5)

        _tasksNeedingImprovement.value = analyticsArray
            .filter { analytics ->
                (analytics.averageQuality ?: 10.0) < 6.0 ||
                        (analytics.averageDifficulty ?: 0.0) > 7.0 ||
                        analytics.improvementTrend == ImprovementTrend.DECLINING
            }
            .sortedBy { analytics ->
                (analytics.averageQuality ?: 0.0) - (analytics.averageDifficulty ?: 0.0)
            }
            .take(5)
    }

    private fun getTaskCompletionAnalytics(
        task: TodoTask,
        startDate: Date,
        endDate: Date
    ): List<TaskCompletionAnalytics> {
        val analytics = mutableListOf<TaskCompletionAnalytics>()
        val calStart = Recurrence.startOfDay(startDate)
        val calEnd = Recurrence.startOfDay(endDate)

        for ((key, completion) in task.completions) {
            if (!completion.isCompleted) continue
            val date = Date(key)
            if (date.before(calStart) || date.after(calEnd)) continue

            analytics.add(
                TaskCompletionAnalytics(
                    date = date,
                    actualDuration = completion.actualDuration,
                    difficultyRating = completion.difficultyRating,
                    qualityRating = completion.qualityRating,
                    estimatedDuration = if (task.hasDuration) task.duration else null,
                    wasTracked = completion.actualDuration != null
                )
            )
        }

        return analytics.sortedBy { it.date }
    }

    private fun calculateEstimationAccuracy(completions: List<TaskCompletionAnalytics>): Double? {
        val accuracyData = completions.mapNotNull { completion ->
            val actual = completion.actualDuration ?: return@mapNotNull null
            val estimated = completion.estimatedDuration ?: return@mapNotNull null
            if (estimated <= 0) return@mapNotNull null
            kotlin.math.abs(actual - estimated) / estimated
        }
        if (accuracyData.isEmpty()) return null
        val avgAccuracy = accuracyData.sum() / accuracyData.size
        return maxOf(0.0, 1.0 - avgAccuracy)
    }

    private fun calculateImprovementTrend(completions: List<TaskCompletionAnalytics>): ImprovementTrend {
        if (completions.size < 3) return ImprovementTrend.INSUFFICIENT

        val qualityRatings = completions.mapNotNull { it.qualityRating }
        if (qualityRatings.size < 3) return ImprovementTrend.INSUFFICIENT

        val recentHalf = qualityRatings.takeLast(qualityRatings.size / 2)
        val olderHalf = qualityRatings.take(qualityRatings.size / 2)

        val recentAvg = recentHalf.sum().toDouble() / recentHalf.size
        val olderAvg = olderHalf.sum().toDouble() / olderHalf.size
        val improvement = recentAvg - olderAvg

        return when {
            improvement > 0.5 -> ImprovementTrend.IMPROVING
            improvement < -0.5 -> ImprovementTrend.DECLINING
            else -> ImprovementTrend.STABLE
        }
    }
}
