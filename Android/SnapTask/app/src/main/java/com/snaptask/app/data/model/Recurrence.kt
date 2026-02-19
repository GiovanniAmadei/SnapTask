package com.snaptask.app.data.model

import java.util.Calendar
import java.util.Date

/**
 * Recurrence pattern for tasks, matching iOS Recurrence struct.
 * Supports daily, weekly, monthly, monthlyOrdinal, and yearly patterns
 * with advanced interval/modulo scheduling.
 */
data class Recurrence(
    val type: RecurrenceType,
    val startDate: Date,
    val endDate: Date? = null,
    val trackInStatistics: Boolean = true,
    // Day-level
    val dayInterval: Int? = null,
    // Week-level
    val weekInterval: Int? = null,
    val weekModuloK: Int? = null,
    val weekModuloOffset: Int? = null,
    val weekSelectedOrdinals: Set<Int>? = null,
    val weekdayTimeOverrides: List<WeekdayTimeOverride>? = null,
    // Month-level
    val monthDayTimeOverrides: List<MonthDayTimeOverride>? = null,
    val monthOrdinalTimeOverrides: List<MonthOrdinalTimeOverride>? = null,
    val monthInterval: Int? = null,
    val monthSelectedMonths: Set<Int>? = null, // 1..12
    // Year-level
    val yearInterval: Int? = null,
    val yearModuloK: Int? = null,
    val yearModuloOffset: Int? = null,
    val yearlyTimeOverride: YearlyTimeOverride? = null,
) {
    /**
     * Check if this recurrence should occur on the given date.
     */
    fun shouldOccurOn(date: Date): Boolean {
        val calendar = Calendar.getInstance()
        val targetDay = startOfDay(date)
        val recurrenceStart = startOfDay(startDate)

        if (targetDay.before(recurrenceStart)) return false
        if (endDate != null && targetDay.after(startOfDay(endDate))) return false

        return when (type) {
            RecurrenceType.DAILY -> {
                if (dayInterval != null && dayInterval > 1) {
                    val daysBetween = daysBetween(recurrenceStart, targetDay)
                    daysBetween % dayInterval == 0
                } else {
                    true
                }
            }

            is RecurrenceType.WEEKLY -> {
                if (!passesWeekLevelGating(date)) return false
                calendar.time = date
                val weekday = calendar.get(Calendar.DAY_OF_WEEK)
                type.days.contains(weekday)
            }

            is RecurrenceType.MONTHLY -> {
                if (!passesMonthLevelGating(date)) return false
                calendar.time = date
                val day = calendar.get(Calendar.DAY_OF_MONTH)
                type.days.contains(day)
            }

            is RecurrenceType.MONTHLY_ORDINAL -> {
                if (!passesMonthLevelGating(date)) return false
                type.patterns.any { matchesOrdinalPattern(date, it) }
            }

            RecurrenceType.YEARLY -> {
                if (!passesYearLevelGating(date)) return false
                calendar.time = date
                val startCal = Calendar.getInstance().apply { time = startDate }
                calendar.get(Calendar.MONTH) == startCal.get(Calendar.MONTH) &&
                        calendar.get(Calendar.DAY_OF_MONTH) == startCal.get(Calendar.DAY_OF_MONTH)
            }
        }
    }

    private fun matchesOrdinalPattern(date: Date, pattern: OrdinalPattern): Boolean {
        val calendar = Calendar.getInstance().apply { time = date }
        val weekday = calendar.get(Calendar.DAY_OF_WEEK)
        if (weekday != pattern.weekday) return false

        val day = calendar.get(Calendar.DAY_OF_MONTH)

        if (pattern.ordinal == -1) {
            // Last occurrence in month
            val maxDay = calendar.getActualMaximum(Calendar.DAY_OF_MONTH)
            for (dayOffset in 0 until 7) {
                val checkDay = maxDay - dayOffset
                if (checkDay < 1) break
                val checkCal = Calendar.getInstance().apply {
                    time = date
                    set(Calendar.DAY_OF_MONTH, checkDay)
                }
                if (checkCal.get(Calendar.DAY_OF_WEEK) == weekday) {
                    return day == checkDay
                }
            }
            return false
        } else {
            val occurrence = (day - 1) / 7 + 1
            return occurrence == pattern.ordinal
        }
    }

    private fun passesWeekLevelGating(date: Date): Boolean {
        val calendar = Calendar.getInstance()
        val anchorWeek = startOfWeek(startDate)
        val targetWeek = startOfWeek(date)

        val weeksBetween = weeksBetween(anchorWeek, targetWeek)
        if (weeksBetween < 0) return false

        weekModuloK?.let { k ->
            if (k > 1) {
                val offset = weekModuloOffset ?: 0
                if (weeksBetween % k != offset) return false
            }
        }
        weekInterval?.let { interval ->
            if (interval > 1 && weeksBetween % interval != 0) return false
        }
        return true
    }

    private fun passesMonthLevelGating(date: Date): Boolean {
        val calendar = Calendar.getInstance()
        val anchorMonth = startOfMonth(startDate)
        val targetMonth = startOfMonth(date)

        val monthsBetween = monthsBetween(anchorMonth, targetMonth)
        if (monthsBetween < 0) return false

        monthInterval?.let { interval ->
            if (interval > 1 && monthsBetween % interval != 0) return false
        }
        monthSelectedMonths?.let { allowed ->
            if (allowed.isNotEmpty()) {
                calendar.time = date
                val m = calendar.get(Calendar.MONTH) + 1 // Calendar.MONTH is 0-based
                if (m !in allowed) return false
            }
        }
        return true
    }

    private fun passesYearLevelGating(date: Date): Boolean {
        val startCal = Calendar.getInstance().apply { time = startDate }
        val targetCal = Calendar.getInstance().apply { time = date }
        val years = targetCal.get(Calendar.YEAR) - startCal.get(Calendar.YEAR)
        if (years < 0) return false

        yearModuloK?.let { k ->
            if (k > 1) {
                val offset = yearModuloOffset ?: 0
                if (years % k != offset) return false
            }
        }
        yearInterval?.let { interval ->
            if (interval > 1 && years % interval != 0) return false
        }
        return true
    }

    companion object {
        fun startOfDay(date: Date): Date {
            val cal = Calendar.getInstance().apply { time = date }
            cal.set(Calendar.HOUR_OF_DAY, 0)
            cal.set(Calendar.MINUTE, 0)
            cal.set(Calendar.SECOND, 0)
            cal.set(Calendar.MILLISECOND, 0)
            return cal.time
        }

        fun startOfWeek(date: Date): Date {
            val cal = Calendar.getInstance().apply { time = date }
            cal.set(Calendar.DAY_OF_WEEK, cal.firstDayOfWeek)
            cal.set(Calendar.HOUR_OF_DAY, 0)
            cal.set(Calendar.MINUTE, 0)
            cal.set(Calendar.SECOND, 0)
            cal.set(Calendar.MILLISECOND, 0)
            return cal.time
        }

        fun startOfMonth(date: Date): Date {
            val cal = Calendar.getInstance().apply { time = date }
            cal.set(Calendar.DAY_OF_MONTH, 1)
            cal.set(Calendar.HOUR_OF_DAY, 0)
            cal.set(Calendar.MINUTE, 0)
            cal.set(Calendar.SECOND, 0)
            cal.set(Calendar.MILLISECOND, 0)
            return cal.time
        }

        fun daysBetween(start: Date, end: Date): Int {
            val diff = end.time - start.time
            return (diff / (1000 * 60 * 60 * 24)).toInt()
        }

        fun weeksBetween(start: Date, end: Date): Int {
            return daysBetween(start, end) / 7
        }

        fun monthsBetween(start: Date, end: Date): Int {
            val startCal = Calendar.getInstance().apply { time = start }
            val endCal = Calendar.getInstance().apply { time = end }
            return (endCal.get(Calendar.YEAR) - startCal.get(Calendar.YEAR)) * 12 +
                    (endCal.get(Calendar.MONTH) - startCal.get(Calendar.MONTH))
        }
    }
}

/**
 * Recurrence types, matching iOS Recurrence.RecurrenceType.
 */
sealed class RecurrenceType {
    data object DAILY : RecurrenceType()
    data class WEEKLY(val days: Set<Int>) : RecurrenceType() // 1=Sun, 7=Sat
    data class MONTHLY(val days: Set<Int>) : RecurrenceType() // Day of month
    data class MONTHLY_ORDINAL(val patterns: Set<OrdinalPattern>) : RecurrenceType()
    data object YEARLY : RecurrenceType()
}

/**
 * Ordinal pattern for monthly recurrence (e.g., "first Monday", "last Friday").
 */
data class OrdinalPattern(
    val ordinal: Int, // 1=first, 2=second, 3=third, 4=fourth, -1=last
    val weekday: Int, // 1=Sunday, 7=Saturday
)

// Time override data classes
data class WeekdayTimeOverride(val weekday: Int, val hour: Int, val minute: Int)
data class MonthDayTimeOverride(val day: Int, val hour: Int, val minute: Int)
data class MonthOrdinalTimeOverride(val weekday: Int, val ordinal: Int, val hour: Int, val minute: Int)
data class YearlyTimeOverride(val hour: Int, val minute: Int)
