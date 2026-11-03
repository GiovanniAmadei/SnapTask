package com.snaptask.app

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.time.DayOfWeek
import java.time.format.TextStyle as DayTextStyle
import java.time.temporal.ChronoUnit
import java.util.UUID
import kotlin.math.abs
import kotlin.math.max

enum class CalUnit {
    day, week, month, year;

    fun start(date: Date): Date = when (this) {
        day -> date.startOfDay()
        week -> date.startOfWeek()
        month -> date.startOfMonth()
        year -> date.startOfYear()
    }

    fun add(date: Date, value: Int): Date = when (this) {
        day -> date.addingDays(value)
        week -> date.addingWeeks(value)
        month -> date.addingMonths(value)
        year -> date.addingYears(value)
    }
}

private fun dayOfWeek(weekday: Int) = DayOfWeek.of(if (weekday == 1) 7 else weekday - 1)
fun shortWeekdaySymbol(weekday: Int): String = dayOfWeek(weekday).getDisplayName(DayTextStyle.SHORT, appLocale)
fun weekdaySymbol(weekday: Int): String = dayOfWeek(weekday).getDisplayName(DayTextStyle.FULL, appLocale)
fun weekdayOrder(): List<Int> = (0 until 7).map { (firstWeekdayNumber - 1 + it) % 7 + 1 }

enum class TimeRange {
    today, week, month, year, allTime;

    val localizedName: String
        get() = when (this) {
            today -> "today"
            week -> "week"
            month -> "month"
            year -> "year"
            allTime -> "all_time"
        }.localized

    val dateRangeStart: Date
        get() {
            val time = now()
            return when (this) {
                today -> time.startOfDay()
                week -> time.startOfDay().addingDays(-6)
                month -> time.startOfDay().addingDays(-29)
                year -> time.startOfMonth().addingMonths(-11)
                allTime -> time.addingYears(-10)
            }
        }

    /** Grouping used by performance charts. */
    val performanceUnit: CalUnit
        get() = when (this) {
            today, week -> CalUnit.day
            month -> CalUnit.week
            year, allTime -> CalUnit.month
        }
}

data class CategoryStat(val name: String, val color: String, val hours: Double, val categoryId: UUID? = null, val icon: String? = null)

data class PeriodOverview(
    val completed: Int = 0,
    val total: Int = 0,
    val pending: Int = 0,
    val rateCompleted: Int = 0,
    val rateTotal: Int = 0,
    val trackedHours: Double = 0.0,
    val activeDays: Int = 0,
    val daysInPeriod: Int = 0,
) {
    val rate: Double get() = if (rateTotal > 0) rateCompleted.toDouble() / rateTotal else 0.0
}

data class CompletionBucket(val start: Date, val end: Date, val completed: Int, val total: Int, val pending: Int = 0) {
    val missed: Int get() = max(0, total - completed)
    val rate: Double get() = if (total > 0) completed.toDouble() / total else 0.0
}

data class DayCount(val completed: Int, val total: Int)
data class WeekdayRate(val weekday: Int, val completed: Int, val total: Int) {
    val rate: Double get() = if (total > 0) completed.toDouble() / total else 0.0
}

enum class HabitDayState { done, missed, pending, off }
data class HabitDay(val date: Date, val state: HabitDayState)

enum class HabitCadence(val unit: CalUnit, val key: String) {
    day(CalUnit.day, "stats_cadence_day"),
    week(CalUnit.week, "stats_cadence_week"),
    month(CalUnit.month, "stats_cadence_month"),
    year(CalUnit.year, "stats_cadence_year");

    val localizedName get() = key.localized
}

data class HabitSummary(
    val taskId: UUID,
    val name: String,
    val icon: String,
    val color: String,
    val categoryName: String?,
    val currentStreak: Int,
    val bestStreak: Int,
    val periodCompleted: Int,
    val periodTotal: Int,
    val days: List<HabitDay>,
    val cadence: HabitCadence = HabitCadence.day,
    val periods: List<HabitDay> = emptyList(),
) {
    val periodRate: Double get() = if (periodTotal > 0) periodCompleted.toDouble() / periodTotal else 0.0

    /** Completion rate per calendar bucket between `start` and `end` (rolling over `window` buckets). */
    fun rateSeries(unit: CalUnit, start: Date, end: Date, window: Int = 1): List<ComparisonPoint> {
        val grouped = LinkedHashMap<Date, IntArray>()
        if (cadence != HabitCadence.day) {
            // One point per period, placed at the bucket containing its start.
            periods.filter { it.date <= end && it.state != HabitDayState.pending && cadence.unit.add(it.date, 1) > start }.forEach { period ->
                val key = unit.start(maxOf(period.date, start))
                val value = grouped.getOrPut(key) { IntArray(2) }
                value[1]++
                if (period.state == HabitDayState.done) value[0]++
            }
            return RollingRate.points(grouped.map { Triple(it.key, it.value[0], it.value[1]) }, 1)
        }
        // Every bucket of the period is present (also empty ones) so the rolling window spans real time.
        var cursor = unit.start(start)
        while (cursor <= end) {
            grouped[cursor] = IntArray(2)
            cursor = unit.add(cursor, 1)
        }
        days.filter { it.date >= start && it.date <= end && (it.state == HabitDayState.done || it.state == HabitDayState.missed) }.forEach { day ->
            val value = grouped.getOrPut(unit.start(day.date)) { IntArray(2) }
            value[1]++
            if (day.state == HabitDayState.done) value[0]++
        }
        return RollingRate.points(grouped.map { Triple(it.key, it.value[0], it.value[1]) }, window)
    }
}

data class ComparisonPoint(val date: Date, val value: Double)

object RollingRate {
    /** Rate per bucket over the last `window` buckets: a single habit has few occurrences per bucket. */
    fun points(buckets: List<Triple<Date, Int, Int>>, window: Int): List<ComparisonPoint> {
        val sorted = buckets.sortedBy { it.first }
        return sorted.indices.mapNotNull { index ->
            val slice = sorted.subList(max(0, index - window + 1), index + 1)
            val done = slice.sumOf { it.second }
            val total = slice.sumOf { it.third }
            if (sorted[index].third > 0 && total > 0) ComparisonPoint(sorted[index].first, done.toDouble() / total * 100) else null
        }
    }

    /** 7 days for daily buckets over a month, 4 weeks for weekly buckets, none otherwise. */
    fun window(unit: CalUnit, period: TimeRange): Int = when {
        unit == CalUnit.day && period == TimeRange.month -> 7
        unit == CalUnit.week -> 4
        else -> 1
    }
}

data class CategoryTaskShare(val id: UUID, val name: String, val icon: String, val hours: Double, val completions: Int)

data class CategoryDetail(
    val hours: Double,
    val previousHours: Double?,
    val completions: Int,
    val trackedSessionHours: Double,
    val buckets: List<Pair<Date, Double>>,
    val tasks: List<CategoryTaskShare>,
    val weekdayHours: List<Pair<Int, Double>>,
)

enum class ImprovementTrend(val icon: String) {
    improving("arrow.up.right"),
    stable("arrow.right"),
    declining("arrow.down.right"),
    insufficient("questionmark"),
}

data class TaskCompletionAnalytics(
    val date: Date,
    val actualDuration: Double?,
    val difficultyRating: Int?,
    val qualityRating: Int?,
    val estimatedDuration: Double?,
    val wasTracked: Boolean,
)

data class TaskPerformanceAnalytics(
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

/** Everything the screen draws, swapped in one go: never the new period with the old period's data. */
data class StatsData(
    val range: TimeRange = TimeRange.week,
    val categoryStats: List<CategoryStat> = emptyList(),
    val currentStreak: Int = 0,
    val bestStreak: Int = 0,
    val habitSummaries: List<HabitSummary> = emptyList(),
    val overview: PeriodOverview = PeriodOverview(),
    val completionBuckets: List<CompletionBucket> = emptyList(),
    val trendBuckets: List<CompletionBucket> = emptyList(),
    val weekdayRates: List<WeekdayRate> = emptyList(),
    val previousCategoryHours: Map<String, Double> = emptyMap(),
    val hasPreviousPeriod: Boolean = false,
    val dailyCompletion: Map<Date, DayCount> = emptyMap(),
    val taskPerformanceAnalytics: List<TaskPerformanceAnalytics> = emptyList(),
    val periodStart: Date = now().startOfDay(),
    val periodEnd: Date = now().startOfDay(),
)

object StatisticsViewModel {
    var selectedTimeRange by mutableStateOf(TimeRange.week)
    var data by mutableStateOf(StatsData())
        private set

    private fun statTasks() = TaskManager.tasks.filter { it.timeScope != TaskTimeScope.inbox }

    suspend fun update() {
        val range = selectedTimeRange
        val tasks = statTasks()
        data = withContext(Dispatchers.Default) { compute(range, tasks) }
    }

    // MARK: Widgets

    data class WidgetCompletionStat(val day: String, val completedTasks: Int, val totalTasks: Int)

    fun widgetCategoryStats(range: TimeRange): List<CategoryStat> = compute(range, statTasks()).categoryStats

    fun widgetCompletionStats(range: TimeRange): List<WidgetCompletionStat> {
        val tasks = statTasks()
        val singleByDay = tasks.filter { it.recurrence == null }.groupBy { it.startTime.startOfDay() }
        val recurring = tasks.filter { it.recurrence != null }
        fun dayStats(date: Date): Pair<Int, Int> {
            val endOfDay = date.addingDays(1)
            val all = (singleByDay[date] ?: emptyList()) + recurring.filter { it.startTime < endOfDay && occursOn(it, date) }
            return all.count { it.completions[date]?.isCompleted == true } to all.size
        }
        fun sum(start: Date, days: Int): Pair<Int, Int> {
            var completed = 0
            var total = 0
            repeat(days) {
                val (done, all) = dayStats(start.addingDays(it))
                completed += done
                total += all
            }
            return completed to total
        }
        val today = now().startOfDay()
        return when (range) {
            TimeRange.today -> dayStats(today).let { listOf(WidgetCompletionStat(today.format("EEE").take(2), it.first, it.second)) }
            TimeRange.week -> (0..6).map { offset ->
                val date = today.addingDays(offset - 6)
                val (done, all) = dayStats(date)
                WidgetCompletionStat(date.format("EEE").take(1).uppercase(appLocale), done, all)
            }
            TimeRange.month -> (4 downTo 0).map { weeksAgo ->
                val start = today.addingDays(-7 * weeksAgo - 6)
                val (done, all) = sum(start, 7)
                WidgetCompletionStat(start.dayOfMonth.toString(), done, all)
            }
            TimeRange.year, TimeRange.allTime -> (0 until 12).map { offset ->
                val month = today.startOfMonth().addingMonths(offset - 11)
                val (done, all) = sum(month, month.daysInMonth)
                WidgetCompletionStat(month.format("MMM").take(3), done, all)
            }
        }
    }

    fun bucketUnit(range: TimeRange, forTrend: Boolean): CalUnit = when (range) {
        TimeRange.today, TimeRange.week, TimeRange.month -> CalUnit.day
        TimeRange.year -> if (forTrend) CalUnit.week else CalUnit.month
        TimeRange.allTime -> CalUnit.month
    }

    fun cadence(task: TodoTask): HabitCadence {
        when (task.timeScope) {
            TaskTimeScope.week -> return HabitCadence.week
            TaskTimeScope.month -> return HabitCadence.month
            TaskTimeScope.year, TaskTimeScope.longTerm -> return HabitCadence.year
            else -> Unit
        }
        return when (task.recurrence?.type) {
            is RecurrenceType.Monthly, is RecurrenceType.MonthlyOrdinal -> HabitCadence.month
            is RecurrenceType.Yearly -> HabitCadence.year
            else -> HabitCadence.day
        }
    }

    private fun dateFromKey(key: String): Date? = runCatching { java.time.Instant.parse(key) }.getOrNull()

    private fun completionHours(task: TodoTask, completion: TaskCompletion): Double {
        val duration = completion.actualDuration?.takeIf { it > 0 }
            ?: task.totalTrackedTime.takeIf { it > 0 }
            ?: task.duration.takeIf { task.hasDuration && it > 0 }
            ?: 0.0
        return duration / 3600.0
    }

    private fun categoryStats(tasks: List<TodoTask>, start: Date, end: Date): List<CategoryStat> {
        val from = start.startOfDay()
        val until = end.startOfDay().addingDays(1)
        val tracked = HashMap<String, Double>()
        var uncategorized = 0.0
        val taskTracking = HashMap<String, Double>()
        for ((dateKey, day) in TimeTrackingStore.load()) {
            val date = dateFromKey(dateKey) ?: continue
            if (date < from || date >= until) continue
            for ((key, hours) in day) {
                when {
                    key == "uncategorized" -> uncategorized += hours
                    key.startsWith("category_") -> tracked[key] = (tracked[key] ?: 0.0) + hours
                    key.startsWith("task_") -> taskTracking[key] = (taskTracking[key] ?: 0.0) + hours
                }
            }
        }
        val metadata = TimeTrackingStore.metadata()
        val byId = tasks.filter { it.category != null }.groupBy { it.category!!.id }
        val byName = tasks.filter { it.category != null }.groupBy { it.category!!.name.lowercase() }
        val list = ArrayList<CategoryStat>()
        for (category in CategoryManager.categories) {
            val categoryTasks = byId[category.id] ?: byName[category.name.lowercase()] ?: emptyList()
            var hours = categoryTasks.sumOf { task ->
                task.completions.entries.sumOf { (date, completion) ->
                    if (date >= from && date < until && completion.isCompleted) completionHours(task, completion) else 0.0
                }
            }
            hours += tracked["category_${category.id.uuidString}"] ?: 0.0
            if (hours > 0) list += CategoryStat(category.name, category.color, hours, category.id, category.icon)
        }
        if (uncategorized > 0) list += CategoryStat("Uncategorized", "#9CA3AF", uncategorized)
        for ((key, hours) in taskTracking) {
            val meta = metadata[key]
            if (hours > 0 && meta != null) list += CategoryStat(meta["name"] ?: "Unknown Task", meta["color"] ?: "#6366F1", hours)
        }
        return list.sortedByDescending { it.hours }
    }

    private fun occursOn(task: TodoTask, date: Date): Boolean {
        val recurrence = task.recurrence ?: return false
        if (date < task.startTime.startOfDay()) return false
        if (recurrence.endDate?.let { date > it } == true) return false
        return recurrence.shouldOccurOn(date)
    }

    private fun compute(range: TimeRange, tasks: List<TodoTask>): StatsData {
        val today = now().startOfDay()
        val threeYearsAgo = today.addingYears(-3)
        val firstDataDay = tasks.minOfOrNull { it.startTime.startOfDay() }?.let { minOf(today, maxOf(it, threeYearsAgo)) }
        val start = if (range == TimeRange.allTime) firstDataDay ?: today else range.dateRangeStart.startOfDay()
        val end = today
        val singleByDay = tasks.filter { it.recurrence == null }.groupBy { it.startTime.startOfDay() }
        val recurring = tasks.filter { it.recurrence != null }

        fun dayStats(date: Date): Pair<Int, Int> {
            val endOfDay = date.addingDays(1)
            val all = (singleByDay[date] ?: emptyList()) + recurring.filter { it.startTime < endOfDay && occursOn(it, date) }
            return all.count { it.completions[date]?.isCompleted == true } to all.size
        }

        // Streak of active days
        val activeDays = HashSet<Date>()
        tasks.forEach { task -> task.completions.forEach { (date, completion) -> if (completion.isCompleted) activeDays += date.startOfDay() } }
        var current = 0
        var check = if (today in activeDays) today else today.addingDays(-1)
        while (check in activeDays) {
            current++
            check = check.addingDays(-1)
        }
        var best = 0
        var run = 0
        var previous: Date? = null
        for (day in activeDays.sorted()) {
            run = if (previous != null && previous.addingDays(1) == day) run + 1 else 1
            best = max(best, run)
            previous = day
        }

        val categories = categoryStats(tasks, range.dateRangeStart, now())

        // Today is still in progress: its unfinished tasks are "pending", not missed.
        val daily = LinkedHashMap<Date, Pair<Int, Int>>()
        var pendingToday = 0
        var day = start
        while (day <= end) {
            val (completed, total) = dayStats(day)
            if (day == today) {
                pendingToday = total - completed
                daily[day] = completed to completed
            } else {
                daily[day] = completed to total
            }
            day = day.addingDays(1)
        }
        val finished = daily.filterKeys { it != today }
        val overview = PeriodOverview(
            completed = daily.values.sumOf { it.first },
            total = daily.values.sumOf { it.second },
            pending = pendingToday,
            rateCompleted = finished.values.sumOf { it.first },
            rateTotal = finished.values.sumOf { it.second },
            trackedHours = categories.sumOf { it.hours },
            activeDays = activeDays.count { it >= start && it <= end },
            daysInPeriod = daily.size,
        )

        fun buckets(source: Map<Date, Pair<Int, Int>>, unit: CalUnit): List<CompletionBucket> {
            val result = ArrayList<CompletionBucket>()
            var cursor = if (unit == CalUnit.day) start else unit.start(start)
            while (cursor <= end) {
                val next = unit.add(cursor, 1)
                val last = minOf(next.addingDays(-1), end)
                var completed = 0
                var total = 0
                var current2 = maxOf(cursor, start)
                while (current2 <= last) {
                    source[current2]?.let {
                        completed += it.first
                        total += it.second
                    }
                    current2 = current2.addingDays(1)
                }
                result += CompletionBucket(cursor, last, completed, total)
                cursor = next
            }
            return result
        }

        val bars = buckets(daily, bucketUnit(range, false)).toMutableList()
        if (bars.isNotEmpty() && pendingToday > 0) bars[bars.lastIndex] = bars.last().copy(pending = pendingToday)
        val trend = buckets(finished, bucketUnit(range, true))

        val byWeekday = HashMap<Int, IntArray>()
        finished.forEach { (date, value) ->
            val entry = byWeekday.getOrPut(date.weekday) { IntArray(2) }
            entry[0] += value.first
            entry[1] += value.second
        }
        val weekdays = weekdayOrder().map { WeekdayRate(it, byWeekday[it]?.get(0) ?: 0, byWeekday[it]?.get(1) ?: 0) }

        val length = ChronoUnit.DAYS.between(start.z(), end.z()).toInt()
        val previousEnd = start.addingDays(-1)
        val previousStart = previousEnd.addingDays(-length)
        val hasPrevious = range != TimeRange.allTime && previousStart >= (firstDataDay ?: today)
        val previousHours = if (hasPrevious) categoryStats(tasks, previousStart, previousEnd).groupBy { it.name }.mapValues { (_, v) -> v.sumOf { it.hours } } else emptyMap()

        val habits = recurring.filter { it.recurrence?.trackInStatistics == true }
            .map { habitSummary(it, start, end, today) }
            .sortedWith(compareByDescending<HabitSummary> { it.currentStreak }.thenByDescending { it.bestStreak })

        return StatsData(
            range, categories, current, max(best, current), habits, overview, bars, trend, weekdays, previousHours, hasPrevious,
            finished.mapValues { DayCount(it.value.first, it.value.second) },
            performance(tasks, range), start, end,
        )
    }

    private fun habitIcon(task: TodoTask) = if (task.icon.isEmpty() || task.icon == "circle") task.category?.icon ?: "repeat" else task.icon

    private fun habitSummary(task: TodoTask, periodStart: Date, periodEnd: Date, today: Date): HabitSummary {
        val cadence = cadence(task)
        if (cadence != HabitCadence.day) return periodicSummary(task, cadence, periodStart, periodEnd, today)
        var day = maxOf(task.startTime.startOfDay(), today.addingDays(-730))
        val days = ArrayList<HabitDay>()
        var run = 0
        var best = 0
        var completed = 0
        var total = 0
        while (day <= today) {
            val state = if (occursOn(task, day)) {
                val done = task.completions[day]?.isCompleted == true
                val value = when {
                    done -> {
                        run++
                        best = max(best, run)
                        HabitDayState.done
                    }
                    day == today -> HabitDayState.pending
                    else -> {
                        run = 0
                        HabitDayState.missed
                    }
                }
                if (day >= periodStart && day <= periodEnd && value != HabitDayState.pending) {
                    total++
                    if (done) completed++
                }
                value
            } else HabitDayState.off
            days += HabitDay(day, state)
            day = day.addingDays(1)
        }
        return HabitSummary(task.id, task.name, habitIcon(task), task.category?.color ?: "#6366F1", task.category?.name, run, best, completed, total, days)
    }

    /** Non-daily habits: a period counts as done when the task was completed at least once inside it. */
    private fun periodicSummary(task: TodoTask, cadence: HabitCadence, periodStart: Date, periodEnd: Date, today: Date): HabitSummary {
        val unit = cadence.unit
        val earliest = today.addingYears(if (cadence == HabitCadence.year) -6 else -2)
        val completedDays = task.completions.filter { it.value.isCompleted }.keys.map { it.startOfDay() }
        val firstDay = minOf(task.startTime.startOfDay(), completedDays.minOrNull() ?: today)
        var cursor = unit.start(maxOf(firstDay, earliest))
        val periods = ArrayList<HabitDay>()
        var run = 0
        var best = 0
        var completed = 0
        var total = 0
        while (cursor <= today) {
            val next = unit.add(cursor, 1)
            val done = completedDays.any { it >= cursor && it < next }
            val isCurrent = today < next
            val state = if (done) HabitDayState.done else if (isCurrent) HabitDayState.pending else HabitDayState.missed
            if (done) {
                run++
                best = max(best, run)
            } else if (!isCurrent) run = 0
            if (next > periodStart && cursor <= periodEnd && state != HabitDayState.pending) {
                total++
                if (done) completed++
            }
            periods += HabitDay(cursor, state)
            cursor = next
        }
        return HabitSummary(task.id, task.name, habitIcon(task), task.category?.color ?: "#6366F1", task.category?.name, run, best, completed, total, emptyList(), cadence, periods)
    }

    private fun performance(tasks: List<TodoTask>, range: TimeRange): List<TaskPerformanceAnalytics> {
        val from = range.dateRangeStart.startOfDay()
        val until = now().startOfDay().addingDays(1)
        val sessions = TaskManager.trackingSessions.groupBy { it.taskId }
        return tasks.mapNotNull { task ->
            val sessionDays = (sessions[task.id] ?: emptyList()).map { it.startTime.startOfDay() }.toSet()
            val completions = task.completions.filter { (date, completion) -> completion.isCompleted && date >= from && date < until }.map { (date, completion) ->
                TaskCompletionAnalytics(date, completion.actualDuration, completion.difficultyRating, completion.qualityRating, if (task.hasDuration) task.duration else null, date.startOfDay() in sessionDays)
            }.sortedBy { it.date }
            if (completions.isEmpty()) return@mapNotNull null
            val difficulty = completions.mapNotNull { it.difficultyRating }
            val quality = completions.mapNotNull { it.qualityRating }
            val durations = completions.mapNotNull { it.actualDuration }
            TaskPerformanceAnalytics(
                task.id, task.name, task.category?.name, task.category?.color, completions,
                difficulty.takeIf { it.isNotEmpty() }?.average(),
                quality.takeIf { it.isNotEmpty() }?.average(),
                durations.takeIf { it.isNotEmpty() }?.average(),
                estimationAccuracy(completions),
                improvementTrend(completions),
            )
        }
    }

    private fun estimationAccuracy(completions: List<TaskCompletionAnalytics>): Double? {
        val errors = completions.mapNotNull { completion ->
            val actual = completion.actualDuration ?: return@mapNotNull null
            val estimated = completion.estimatedDuration?.takeIf { it > 0 } ?: return@mapNotNull null
            abs(actual - estimated) / estimated
        }
        if (errors.isEmpty()) return null
        return max(0.0, 1.0 - errors.average())
    }

    private fun improvementTrend(completions: List<TaskCompletionAnalytics>): ImprovementTrend {
        if (completions.size < 3) return ImprovementTrend.insufficient
        val ratings = completions.mapNotNull { it.qualityRating }
        if (ratings.size < 3) return ImprovementTrend.insufficient
        val half = ratings.size / 2
        val improvement = ratings.takeLast(half).average() - ratings.take(half).average()
        return when {
            improvement > 0.5 -> ImprovementTrend.improving
            improvement < -0.5 -> ImprovementTrend.declining
            else -> ImprovementTrend.stable
        }
    }

    /** Same sources as the donut (completed tasks' duration + tracked sessions), split by day and by task. */
    fun categoryDetail(categoryId: UUID): CategoryDetail {
        val current = data
        val start = current.periodStart
        val end = current.periodEnd
        val until = end.addingDays(1)
        val perDay = HashMap<Date, Double>()
        data class Share(val name: String, val icon: String, var hours: Double, var completions: Int)
        val perTask = LinkedHashMap<UUID, Share>()
        var completions = 0
        statTasks().filter { it.category?.id == categoryId }.forEach { task ->
            task.completions.forEach { (date, completion) ->
                if (completion.isCompleted && date >= start && date < until) {
                    val hours = completionHours(task, completion)
                    val dayKey = date.startOfDay()
                    perDay[dayKey] = (perDay[dayKey] ?: 0.0) + hours
                    val icon = if (task.icon.isEmpty() || task.icon == "circle") task.category?.icon ?: "checkmark.circle" else task.icon
                    val entry = perTask.getOrPut(task.id) { Share(task.name, icon, 0.0, 0) }
                    entry.hours += hours
                    entry.completions++
                    completions++
                }
            }
        }
        var sessionHours = 0.0
        val key = "category_${categoryId.uuidString}"
        for ((dateKey, day) in TimeTrackingStore.load()) {
            val date = dateFromKey(dateKey) ?: continue
            val hours = day[key]?.takeIf { it > 0 } ?: continue
            if (date < start || date >= until) continue
            val dayKey = date.startOfDay()
            perDay[dayKey] = (perDay[dayKey] ?: 0.0) + hours
            sessionHours += hours
        }
        val unit = bucketUnit(current.range, false)
        var cursor = if (unit == CalUnit.day) start else unit.start(start)
        val buckets = ArrayList<Pair<Date, Double>>()
        while (cursor <= end) {
            val next = unit.add(cursor, 1)
            buckets += cursor to perDay.filterKeys { it >= cursor && it < next }.values.sum()
            cursor = next
        }
        val byWeekday = HashMap<Int, Double>()
        perDay.forEach { (date, hours) -> byWeekday[date.weekday] = (byWeekday[date.weekday] ?: 0.0) + hours }
        val name = CategoryManager.categories.firstOrNull { it.id == categoryId }?.name
        return CategoryDetail(
            perDay.values.sum(),
            if (current.hasPreviousPeriod) current.previousCategoryHours[name] ?: 0.0 else null,
            completions,
            sessionHours,
            buckets,
            perTask.map { (id, share) -> CategoryTaskShare(id, share.name, share.icon, share.hours, share.completions) }.sortedByDescending { it.hours },
            weekdayOrder().map { it to (byWeekday[it] ?: 0.0) },
        )
    }

}
