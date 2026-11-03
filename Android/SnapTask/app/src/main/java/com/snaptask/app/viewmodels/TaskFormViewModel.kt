package com.snaptask.app

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import java.text.DateFormatSymbols
import java.time.format.FormatStyle
import java.util.UUID
import kotlin.math.max
import kotlin.math.min

enum class FormRecurrenceType(val rawValue: String) {
    daily("daily_enum"), weekly("weekly_enum"), monthly("monthly_enum"), yearly("yearly_enum");
    val localizedString: String get() = rawValue.localized
}

enum class MonthlySelectionType(val rawValue: String) {
    days("days_enum"), patterns("patterns_enum");
    val localizedString: String get() = rawValue.localized
}

enum class WeekRecurrenceMode { everyNWeeks, specificWeeksOfMonth, moduloPattern }
enum class MonthRecurrenceMode { everyNMonths, specificMonths }
enum class YearRecurrenceMode { everyNYears, moduloPattern }
enum class EditScopeMode { entireSeries, singleInstance }

fun monthSymbol(month: Int): String =
    DateFormatSymbols.getInstance(appLocale).months[month - 1].replaceFirstChar { it.titlecase(appLocale) }

fun ordinalText(value: Int): String {
    val language = appLocale.language
    return when (language) {
        "en" -> value.toString() + when {
            value % 100 in 11..13 -> "th"
            value % 10 == 1 -> "st"
            value % 10 == 2 -> "nd"
            value % 10 == 3 -> "rd"
            else -> "th"
        }
        "it", "es", "pt" -> "$value" + "º"
        "fr" -> if (value == 1) "1er" else "${value}e"
        "de" -> "$value."
        "ja" -> "第$value"
        else -> value.toString()
    }
}

class TaskFormViewModel(initialDate: Date, val preserveTime: Boolean = false) {
    var name by mutableStateOf("")
    var description by mutableStateOf("")
    var location by mutableStateOf<TaskLocation?>(null)
    var startDate by mutableStateOf(if (preserveTime) initialDate else initialDate.withTime(9, 0))
    var hasSpecificDay by mutableStateOf(true)
    var hasSpecificTime by mutableStateOf(preserveTime)
    var hasDuration by mutableStateOf(false)
    private var _duration by mutableStateOf(3600.0)
    var duration: Double
        get() = _duration
        set(value) { _duration = if (value.isNaN() || value <= 0) 3600.0 else value }
    var icon by mutableStateOf("circle.fill")
    var selectedCategory by mutableStateOf<Category?>(null)
    var selectedPriority by mutableStateOf(Priority.medium)
    var subtasks by mutableStateOf<List<Subtask>>(emptyList())
    var hasNotification by mutableStateOf(false)
    var notificationLeadTimeMinutes by mutableStateOf(0)
    var isRecurring by mutableStateOf(false)
    var recurrenceType by mutableStateOf(FormRecurrenceType.daily)
    var selectedDays by mutableStateOf<Set<Int>>(emptySet())
    var selectedMonthlyDays by mutableStateOf<Set<Int>>(emptySet())
    var monthlySelectionType by mutableStateOf(MonthlySelectionType.days)
    var selectedOrdinalPatterns by mutableStateOf<Set<OrdinalPattern>>(emptySet())
    var yearlyDate by mutableStateOf(startDate)
    var weeklyTimes by mutableStateOf<Map<Int, Date>>(emptyMap())
    var monthlyTimes by mutableStateOf<Map<Int, Date>>(emptyMap())
    var monthlyOrdinalTimes by mutableStateOf<Map<OrdinalPattern, Date>>(emptyMap())
    var yearlyTime by mutableStateOf(startDate)
    var dayInterval by mutableStateOf(1)
    var hasRecurrenceEndDate by mutableStateOf(false)
    var recurrenceEndDate by mutableStateOf(now().addingDays(30))
    var trackInStatistics by mutableStateOf(true)
    var hasRewardPoints by mutableStateOf(false)
    private var _rewardPoints by mutableStateOf(5)
    var rewardPoints: Int
        get() = _rewardPoints
        set(value) { _rewardPoints = value.coerceIn(1, 999) }
    var useCustomPoints by mutableStateOf(false)
    var customPointsText by mutableStateOf("5")
    var autoCarryOver by mutableStateOf(false)

    private var _selectedTimeScope by mutableStateOf(TaskTimeScope.today)
    var selectedTimeScope: TaskTimeScope
        get() = _selectedTimeScope
        set(value) {
            _selectedTimeScope = value
            updateDefaultSpecificTime(value)
        }
    var selectedWeekDate by mutableStateOf(now())
    var selectedMonthDate by mutableStateOf(now())
    var selectedYearDate by mutableStateOf(now())
    var selectedMonth by mutableStateOf(now().month)
    var selectedYear by mutableStateOf(now().yearNumber)

    var weekRecurrenceMode by mutableStateOf(WeekRecurrenceMode.everyNWeeks)
    var weekInterval by mutableStateOf(1)
    var weekSelectedOrdinals by mutableStateOf<Set<Int>>(emptySet())
    var weekModuloK by mutableStateOf(2)
    var weekModuloOffset by mutableStateOf(0)
    var monthRecurrenceMode by mutableStateOf(MonthRecurrenceMode.everyNMonths)
    var monthInterval by mutableStateOf(1)
    var monthSelectedMonths by mutableStateOf<Set<Int>>(emptySet())
    var yearRecurrenceMode by mutableStateOf(YearRecurrenceMode.everyNYears)
    var yearInterval by mutableStateOf(1)
    var yearModuloK by mutableStateOf(2)
    var yearModuloOffset by mutableStateOf(0)
    var editScopeMode by mutableStateOf(EditScopeMode.entireSeries)

    var taskId: UUID? = null
    var initialTask: TodoTask? = null
    val isEditing: Boolean get() = taskId != null
    val categories: List<Category> get() = CategoryManager.categories

    /** Selects without the defaults a change of scope applies: used when loading an existing task. */
    fun loadScope(scope: TaskTimeScope) { _selectedTimeScope = scope }

    /** If the chosen time is out of the current period, the period follows it. */
    fun syncPeriodWithStartDate() {
        if (!hasSpecificTime) return
        when (selectedTimeScope) {
            TaskTimeScope.week -> selectedWeekDate = startDate.startOfWeek()
            TaskTimeScope.month -> {
                selectedMonth = startDate.month
                selectedYear = startDate.yearNumber
            }
            TaskTimeScope.year -> selectedYear = startDate.yearNumber
            else -> Unit
        }
    }

    private fun updateDefaultSpecificTime(scope: TaskTimeScope) {
        if (!preserveTime) hasSpecificTime = false
        hasSpecificDay = scope == TaskTimeScope.today
        when (scope) {
            TaskTimeScope.week -> selectedWeekDate = startDate.startOfWeek()
            TaskTimeScope.month -> {
                selectedMonth = startDate.month
                selectedYear = startDate.yearNumber
                selectedMonthDate = startDate.startOfMonth()
            }
            TaskTimeScope.year -> {
                selectedYear = startDate.yearNumber
                selectedYearDate = startDate.startOfYear()
            }
            else -> Unit
        }
    }

    val isValid: Boolean get() = name.isNotEmpty()

    val selectedPeriodDisplayText: String
        get() = when (selectedTimeScope) {
            TaskTimeScope.today -> startDate.dateStyle(FormatStyle.MEDIUM)
            TaskTimeScope.week -> selectedWeekRangeText
            TaskTimeScope.month -> "${monthSymbol(selectedMonth)} $selectedYear"
            TaskTimeScope.year -> selectedYear.toString()
            TaskTimeScope.longTerm -> "long_term_goal".localized
            TaskTimeScope.inbox -> "scope_inbox".localized
            TaskTimeScope.all -> ""
        }

    val timeScopeTitle: String
        get() = if (selectedTimeScope == TaskTimeScope.today && !startDate.isToday()) startDate.skeleton("dMMMyyyy") else selectedTimeScope.displayName

    val selectedWeekRangeText: String
        get() {
            val start = selectedWeekDate.startOfWeek()
            return "${start.dateStyle(FormatStyle.SHORT)} - ${start.addingDays(6).dateStyle(FormatStyle.SHORT)}"
        }

    val availableYears: List<Int> get() = (now().yearNumber..now().yearNumber + 10).toList()

    val recurrenceDisplayText: String
        get() = if (selectedTimeScope == TaskTimeScope.longTerm) "no_recurrence_long_term".localized else contextualRecurrenceSummary

    val contextualRecurrenceSummary: String
        get() = when (selectedTimeScope) {
            TaskTimeScope.today -> "every_day".localized
            TaskTimeScope.week -> when (weekRecurrenceMode) {
                WeekRecurrenceMode.everyNWeeks -> if (weekInterval == 1) "every_week".localized else "every_n_weeks_format".localized(weekInterval)
                WeekRecurrenceMode.specificWeeksOfMonth -> if (weekSelectedOrdinals.isEmpty()) "select_weeks_of_month".localized else {
                    "weeks_of_month_prefix".localized(
                        weekSelectedOrdinals.sortedBy { if (it == -1) 6 else it }
                            .joinToString(", ") { if (it == -1) "last_ordinal".localized.lowercase(appLocale) else ordinalText(it) }
                    )
                }
                WeekRecurrenceMode.moduloPattern -> if (weekModuloK == 2) {
                    if (weekModuloOffset == 0) "even_weeks".localized else "odd_weeks".localized
                } else "every_kth_week_offset_format".localized(weekModuloK, weekModuloOffset + 1)
            }
            TaskTimeScope.month -> when (monthRecurrenceMode) {
                MonthRecurrenceMode.everyNMonths -> if (monthInterval == 1) "every_month".localized else "every_n_months_format".localized(monthInterval)
                MonthRecurrenceMode.specificMonths -> if (monthSelectedMonths.isEmpty()) "select_specific_months".localized
                else "months_prefix".localized(monthSelectedMonths.sorted().joinToString(", ") { monthSymbol(it) })
            }
            TaskTimeScope.year -> when (yearRecurrenceMode) {
                YearRecurrenceMode.everyNYears -> if (yearInterval == 1) "every_year".localized else "every_n_years_format".localized(yearInterval)
                YearRecurrenceMode.moduloPattern -> if (yearModuloK == 2) {
                    if (yearModuloOffset == 0) "even_years".localized else "odd_years".localized
                } else "every_k_years_offset_format".localized(yearModuloK, yearModuloOffset + 1)
            }
            TaskTimeScope.longTerm, TaskTimeScope.inbox -> "no_recurrence".localized
            TaskTimeScope.all -> ""
        }

    val shouldShowRecurrenceOption: Boolean get() = selectedTimeScope != TaskTimeScope.longTerm

    fun createTask(): TodoTask {
        val id = taskId ?: UUID.randomUUID()
        val taskStartTime: Date
        var scopeStart: Date? = null
        var scopeEnd: Date? = null
        when (selectedTimeScope) {
            TaskTimeScope.today, TaskTimeScope.all -> taskStartTime = if (hasSpecificTime) startDate else startDate.startOfDay()
            TaskTimeScope.week -> {
                val weekStart = selectedWeekDate.startOfWeek()
                val weekEnd = weekStart.addingDays(6)
                taskStartTime = if (hasSpecificDay) {
                    if (hasSpecificTime) {
                        val clamped = maxOf(weekStart, minOf(weekEnd, startDate))
                        clamped.withTime(startDate.hour, startDate.minute)
                    } else maxOf(weekStart, minOf(weekEnd, startDate.startOfDay())).startOfDay()
                } else weekStart
                scopeStart = weekStart
                scopeEnd = weekEnd
            }
            TaskTimeScope.month -> {
                val monthStart = java.time.LocalDate.of(selectedYear, selectedMonth, 1).instant()
                val monthEnd = monthStart.endOfMonth()
                taskStartTime = if (hasSpecificDay) {
                    val day = startDate.dayOfMonth.coerceIn(1, monthStart.daysInMonth)
                    val base = monthStart.withDayOfMonth(day)
                    if (hasSpecificTime) maxOf(monthStart, minOf(monthEnd, base.withTime(startDate.hour, startDate.minute)))
                    else maxOf(monthStart, minOf(monthEnd, base)).startOfDay()
                } else monthStart
                scopeStart = monthStart
                scopeEnd = monthEnd
            }
            TaskTimeScope.year -> {
                val yearStart = java.time.LocalDate.of(selectedYear, 1, 1).instant()
                val yearEnd = java.time.LocalDate.of(selectedYear, 12, 31).instant()
                taskStartTime = if (hasSpecificDay) {
                    if (hasSpecificTime) {
                        val day = runCatching { java.time.LocalDate.of(selectedYear, startDate.month, startDate.dayOfMonth) }
                            .getOrDefault(java.time.LocalDate.of(selectedYear, startDate.month, 28))
                        maxOf(yearStart, minOf(yearEnd, day.instant().withTime(startDate.hour, startDate.minute)))
                    } else maxOf(yearStart, minOf(yearEnd, startDate.startOfDay())).startOfDay()
                } else yearStart
                scopeStart = yearStart
                scopeEnd = yearEnd
            }
            TaskTimeScope.longTerm -> taskStartTime = if (hasSpecificDay) {
                if (hasSpecificTime) startDate else startDate.startOfDay()
            } else now().startOfDay()
            // Undated: keep the original creation time (it anchors the completion key).
            TaskTimeScope.inbox -> taskStartTime = if (initialTask?.timeScope == TaskTimeScope.inbox) initialTask!!.startTime else now()
        }

        val existingRecurrence = initialTask?.recurrence
        val recurrence: Recurrence? = when {
            isEditing && editScopeMode == EditScopeMode.singleInstance && existingRecurrence != null ->
                existingRecurrence.postponingOccurrence(initialTask?.startTime ?: now(), taskStartTime)
            isRecurring -> if (selectedTimeScope == TaskTimeScope.today) createEnhancedRecurrence(taskStartTime) else createContextualRecurrence(taskStartTime)
            else -> null
        }
        val finalStart = if (isEditing && editScopeMode == EditScopeMode.singleInstance) initialTask?.startTime ?: taskStartTime else taskStartTime
        val base = initialTask ?: TodoTask(id = id)
        return base.copy(
            id = id,
            name = name,
            description = description.ifEmpty { null },
            location = location,
            startTime = finalStart,
            hasSpecificDay = if (selectedTimeScope == TaskTimeScope.today) true else hasSpecificDay,
            hasSpecificTime = hasSpecificTime,
            duration = duration,
            hasDuration = hasDuration,
            category = selectedCategory,
            priority = selectedPriority,
            icon = icon,
            recurrence = recurrence,
            subtasks = subtasks,
            hasRewardPoints = hasRewardPoints,
            rewardPoints = rewardPoints,
            hasNotification = hasNotification,
            timeScope = if (selectedTimeScope == TaskTimeScope.all) TaskTimeScope.today else selectedTimeScope,
            scopeStartDate = scopeStart,
            scopeEndDate = scopeEnd,
            notificationLeadTimeMinutes = notificationLeadTimeMinutes,
            autoCarryOver = autoCarryOver && selectedTimeScope in listOf(TaskTimeScope.today, TaskTimeScope.week, TaskTimeScope.month, TaskTimeScope.year),
        )
    }

    private fun createEnhancedRecurrence(start: Date): Recurrence {
        val startDay = start.startOfDay()
        val end = if (hasRecurrenceEndDate) recurrenceEndDate.startOfDay() else null
        return when (recurrenceType) {
            FormRecurrenceType.daily -> Recurrence(RecurrenceType.Daily, startDay, end, trackInStatistics, dayInterval = dayInterval.takeIf { it > 1 })
            FormRecurrenceType.weekly -> {
                val days = selectedDays.ifEmpty { setOf(startDay.weekday) }
                val overrides = days.mapNotNull { weekday -> weeklyTimes[weekday]?.let { WeekdayTimeOverride(weekday, it.hour, it.minute) } }
                Recurrence(RecurrenceType.Weekly(days), startDay, end, trackInStatistics, weekdayTimeOverrides = overrides.ifEmpty { null })
            }
            FormRecurrenceType.monthly -> if (monthlySelectionType == MonthlySelectionType.days) {
                val days = selectedMonthlyDays.ifEmpty { setOf(startDay.dayOfMonth) }
                monthlyTimes = days.associateWith { monthlyTimes[it] ?: start }
                val overrides = days.mapNotNull { day -> monthlyTimes[day]?.let { MonthDayTimeOverride(day, it.hour, it.minute) } }
                Recurrence(RecurrenceType.Monthly(days), startDay, end, trackInStatistics, monthDayTimeOverrides = overrides.ifEmpty { null })
            } else {
                val patterns = selectedOrdinalPatterns.ifEmpty { setOf(OrdinalPattern(1, startDay.weekday)) }
                monthlyOrdinalTimes = patterns.associateWith { monthlyOrdinalTimes[it] ?: start }
                val overrides = patterns.mapNotNull { pattern -> monthlyOrdinalTimes[pattern]?.let { MonthOrdinalTimeOverride(pattern.ordinal, pattern.weekday, it.hour, it.minute) } }
                Recurrence(RecurrenceType.MonthlyOrdinal(patterns), startDay, end, trackInStatistics, monthOrdinalTimeOverrides = overrides.ifEmpty { null })
            }
            FormRecurrenceType.yearly -> Recurrence(
                RecurrenceType.Yearly, yearlyDate.startOfDay(), end, trackInStatistics,
                yearlyTimeOverride = YearlyTimeOverride(yearlyTime.hour, yearlyTime.minute),
            )
        }
    }

    private fun createContextualRecurrence(start: Date): Recurrence? {
        val startDay = start.startOfDay()
        val end = if (hasRecurrenceEndDate) recurrenceEndDate.startOfDay() else null
        return when (selectedTimeScope) {
            TaskTimeScope.week -> {
                val weekday = startDay.weekday
                var recurrence = Recurrence(RecurrenceType.Weekly(setOf(weekday)), startDay, end, trackInStatistics)
                weeklyTimes[weekday]?.let { recurrence = recurrence.copy(weekdayTimeOverrides = listOf(WeekdayTimeOverride(weekday, it.hour, it.minute))) }
                when (weekRecurrenceMode) {
                    WeekRecurrenceMode.everyNWeeks -> recurrence.copy(weekInterval = max(1, weekInterval))
                    WeekRecurrenceMode.specificWeeksOfMonth -> recurrence.copy(
                        weekSelectedOrdinals = weekSelectedOrdinals.ifEmpty { setOf(weekOrdinalInMonth(startDay)) },
                        monthInterval = 1,
                    )
                    WeekRecurrenceMode.moduloPattern -> recurrence.copy(
                        weekModuloK = max(2, weekModuloK),
                        weekModuloOffset = max(0, min(weekModuloK - 1, weekModuloOffset)),
                    )
                }
            }
            TaskTimeScope.month -> {
                val recurrence = Recurrence(RecurrenceType.Monthly(setOf(startDay.dayOfMonth)), startDay, end, trackInStatistics)
                when (monthRecurrenceMode) {
                    MonthRecurrenceMode.everyNMonths -> recurrence.copy(monthInterval = max(1, monthInterval))
                    MonthRecurrenceMode.specificMonths -> recurrence.copy(monthSelectedMonths = monthSelectedMonths.ifEmpty { setOf(startDay.month) })
                }
            }
            TaskTimeScope.year -> {
                val recurrence = Recurrence(RecurrenceType.Yearly, startDay, end, trackInStatistics)
                when (yearRecurrenceMode) {
                    YearRecurrenceMode.everyNYears -> recurrence.copy(yearInterval = max(1, yearInterval))
                    YearRecurrenceMode.moduloPattern -> recurrence.copy(
                        yearModuloK = max(2, yearModuloK),
                        yearModuloOffset = max(0, min(yearModuloK - 1, yearModuloOffset)),
                    )
                }
            }
            TaskTimeScope.today -> createEnhancedRecurrence(startDay)
            else -> null
        }
    }

    private fun weekOrdinalInMonth(date: Date): Int =
        if (date.startOfWeek().addingDays(7).month != date.month) -1 else date.weekOfMonth

    fun addSubtask(name: String) { subtasks = subtasks + Subtask(name = name) }
    fun removeSubtask(id: UUID) { subtasks = subtasks.filter { it.id != id } }

    companion object {
        /** A form filled from an existing task (`TaskFormView.init(initialTask:)`). */
        fun from(task: TodoTask, editScope: EditScopeMode = EditScopeMode.entireSeries, preserveTime: Boolean = false): TaskFormViewModel {
            val preserve = preserveTime || task.hasSpecificTime
            val vm = TaskFormViewModel(task.startTime, preserve)
            vm.taskId = task.id
            vm.initialTask = task
            vm.editScopeMode = editScope
            vm.name = task.name
            vm.description = task.description ?: ""
            vm.location = task.location
            vm.startDate = task.startTime
            vm.hasDuration = task.hasDuration
            vm.duration = task.duration
            vm.selectedCategory = task.category
            vm.selectedPriority = task.priority
            vm.icon = task.icon
            vm.subtasks = task.subtasks
            vm.hasNotification = task.hasNotification
            vm.selectedTimeScope = task.timeScope
            vm.hasSpecificDay = task.hasSpecificDay
            vm.hasSpecificTime = preserve
            vm.notificationLeadTimeMinutes = task.notificationLeadTimeMinutes
            vm.autoCarryOver = task.autoCarryOver
            task.scopeStartDate?.let { start ->
                when (task.timeScope) {
                    TaskTimeScope.week -> vm.selectedWeekDate = start
                    TaskTimeScope.month -> {
                        vm.selectedMonth = start.month
                        vm.selectedYear = start.yearNumber
                        vm.selectedMonthDate = start
                    }
                    TaskTimeScope.year -> {
                        vm.selectedYear = start.yearNumber
                        vm.selectedYearDate = start
                    }
                    else -> Unit
                }
            }
            vm.isRecurring = task.recurrence != null
            task.recurrence?.let { recurrence ->
                vm.hasRecurrenceEndDate = recurrence.endDate != null
                fun time(hour: Int, minute: Int) = task.startTime.withTime(hour, minute)
                when (val type = recurrence.type) {
                    RecurrenceType.Daily -> {
                        vm.recurrenceType = FormRecurrenceType.daily
                        vm.dayInterval = recurrence.dayInterval ?: 1
                    }
                    is RecurrenceType.Weekly -> {
                        vm.recurrenceType = FormRecurrenceType.weekly
                        vm.selectedDays = type.days
                        vm.weeklyTimes = recurrence.weekdayTimeOverrides?.associate { it.weekday to time(it.hour, it.minute) } ?: emptyMap()
                    }
                    is RecurrenceType.Monthly -> {
                        vm.recurrenceType = FormRecurrenceType.monthly
                        vm.monthlySelectionType = MonthlySelectionType.days
                        vm.selectedMonthlyDays = type.days
                        val overrides = recurrence.monthDayTimeOverrides?.associate { it.day to time(it.hour, it.minute) } ?: emptyMap()
                        vm.monthlyTimes = type.days.associateWith { overrides[it] ?: task.startTime }
                    }
                    is RecurrenceType.MonthlyOrdinal -> {
                        vm.recurrenceType = FormRecurrenceType.monthly
                        vm.monthlySelectionType = MonthlySelectionType.patterns
                        vm.selectedOrdinalPatterns = type.patterns
                        val overrides = recurrence.monthOrdinalTimeOverrides?.associate { OrdinalPattern(it.ordinal, it.weekday) to time(it.hour, it.minute) } ?: emptyMap()
                        vm.monthlyOrdinalTimes = type.patterns.associateWith { overrides[it] ?: task.startTime }
                    }
                    RecurrenceType.Yearly -> {
                        vm.recurrenceType = FormRecurrenceType.yearly
                        vm.yearlyDate = recurrence.startDate
                        vm.yearlyTime = recurrence.yearlyTimeOverride?.let { time(it.hour, it.minute) } ?: task.startTime
                    }
                }
                recurrence.weekInterval?.let { vm.weekInterval = it }
                recurrence.weekSelectedOrdinals?.let {
                    vm.weekSelectedOrdinals = it
                    vm.weekRecurrenceMode = WeekRecurrenceMode.specificWeeksOfMonth
                }
                recurrence.weekModuloK?.let {
                    vm.weekModuloK = it
                    vm.weekModuloOffset = recurrence.weekModuloOffset ?: 0
                    vm.weekRecurrenceMode = WeekRecurrenceMode.moduloPattern
                }
                recurrence.monthInterval?.let { vm.monthInterval = it }
                recurrence.monthSelectedMonths?.takeIf { it.isNotEmpty() }?.let {
                    vm.monthSelectedMonths = it
                    vm.monthRecurrenceMode = MonthRecurrenceMode.specificMonths
                }
                recurrence.yearInterval?.let { vm.yearInterval = it }
                recurrence.yearModuloK?.let {
                    vm.yearModuloK = it
                    vm.yearModuloOffset = recurrence.yearModuloOffset ?: 0
                    vm.yearRecurrenceMode = YearRecurrenceMode.moduloPattern
                }
                vm.recurrenceEndDate = recurrence.endDate ?: now().addingDays(30)
                vm.trackInStatistics = recurrence.trackInStatistics
            }
            vm.hasRewardPoints = task.hasRewardPoints
            vm.rewardPoints = task.rewardPoints.coerceAtLeast(1)
            return vm
        }
    }
}
