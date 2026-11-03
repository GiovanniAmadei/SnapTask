package com.snaptask.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId
import java.util.UUID

private fun date(year: Int, month: Int, day: Int): Date =
    LocalDate.of(year, month, day).atTime(12, 0).atZone(ZoneId.systemDefault()).toInstant()

/** The same cases as `FinanceOccurrenceTests` on iOS. */
class FinanceOccurrenceTests {
    private val manager = FinanceManager

    private fun recurring(frequency: SubscriptionFrequency, from: Date, until: Date? = null) = FinanceEntry(
        name = "Test", amount = 10.0, type = FinanceEntryType.subscription, date = from,
        isRecurring = true, recurringFrequency = frequency, recurringEndDate = until,
    )

    @Test fun oneOffEntryHappensOnlyInsideItsPeriod() {
        val entry = FinanceEntry(name = "Lunch", amount = 12.0, type = FinanceEntryType.expense, date = date(2026, 3, 10))
        assertEquals(1, manager.occurrenceDates(entry, DatePeriod(date(2026, 3, 1), date(2026, 4, 1))).size)
        assertTrue(manager.occurrenceDates(entry, DatePeriod(date(2026, 4, 1), date(2026, 5, 1))).isEmpty())
    }

    @Test fun periodEndIsExcluded() {
        val boundary = date(2026, 4, 1)
        val entry = FinanceEntry(name = "Edge", amount = 1.0, type = FinanceEntryType.expense, date = boundary)
        assertTrue(manager.occurrenceDates(entry, DatePeriod(date(2026, 3, 1), boundary)).isEmpty())
        assertEquals(1, manager.occurrenceDates(entry, DatePeriod(boundary, date(2026, 5, 1))).size)
    }

    @Test fun monthlyEntryRepeatsEveryMonthOfThePeriod() {
        val dates = manager.occurrenceDates(recurring(SubscriptionFrequency.monthly, date(2026, 1, 15)), DatePeriod(date(2026, 3, 1), date(2026, 6, 1)))
        assertEquals(listOf(3, 4, 5), dates.map { it.month })
        assertTrue(dates.all { it.dayOfMonth == 15 })
    }

    @Test fun nothingHappensBeforeTheStartDate() {
        assertTrue(manager.occurrenceDates(recurring(SubscriptionFrequency.monthly, date(2026, 6, 15)), DatePeriod(date(2026, 1, 1), date(2026, 6, 1))).isEmpty())
    }

    @Test fun recurringEntryStopsAfterItsEndDate() {
        val entry = recurring(SubscriptionFrequency.monthly, date(2026, 1, 10), date(2026, 3, 10))
        assertEquals(3, manager.occurrenceDates(entry, DatePeriod(date(2026, 1, 1), date(2027, 1, 1))).size)
    }

    @Test fun monthEndDayIsClampedWithoutDrifting() {
        val dates = manager.occurrenceDates(recurring(SubscriptionFrequency.monthly, date(2026, 1, 31)), DatePeriod(date(2026, 1, 1), date(2026, 5, 1)))
        assertEquals(listOf(31, 28, 31, 30), dates.map { it.dayOfMonth })
    }

    @Test fun weeklyEntryHappensEverySevenDays() {
        val dates = manager.occurrenceDates(recurring(SubscriptionFrequency.weekly, date(2026, 3, 2)), DatePeriod(date(2026, 3, 1), date(2026, 4, 1)))
        assertEquals(5, dates.size)
        dates.zipWithNext().forEach { (previous, next) -> assertEquals(previous.addingDays(7), next) }
    }

    @Test fun quarterlyAndYearlyEntries() {
        val year = DatePeriod(date(2026, 1, 1), date(2027, 1, 1))
        assertEquals(4, manager.occurrenceDates(recurring(SubscriptionFrequency.quarterly, date(2025, 1, 5)), year).size)
        assertEquals(1, manager.occurrenceDates(recurring(SubscriptionFrequency.yearly, date(2020, 6, 20)), year).size)
    }

    @Test fun nextOccurrenceIsTheFirstFutureRepetition() {
        val time = now()
        val next = manager.nextOccurrence(recurring(SubscriptionFrequency.monthly, time.addingDays(-45)), time)
        assertNotNull(next)
        assertTrue(next!! >= time)
        assertTrue(next < time.addingDays(32))
    }

    @Test fun endedSubscriptionHasNoNextOccurrence() {
        val time = now()
        assertNull(manager.nextOccurrence(recurring(SubscriptionFrequency.monthly, time.addingMonths(-6), time.addingMonths(-1)), time))
    }

    @Test fun amountParsingAcceptsBothDecimalSeparators() {
        assertEquals(12.5, FinanceNumber.parse("12,50")!!, 0.0)
        assertEquals(12.5, FinanceNumber.parse("12.50")!!, 0.0)
        assertEquals(3.0, FinanceNumber.parse(" 3 ")!!, 0.0)
        assertNull(FinanceNumber.parse(""))
        assertNull(FinanceNumber.parse("abc"))
    }
}

class RecurrenceTests {
    private fun task(type: RecurrenceType, start: Date, configure: Recurrence.() -> Recurrence = { this }) = TodoTask(
        name = "Task", startTime = start, hasSpecificDay = true, recurrence = Recurrence(type = type, startDate = start).configure(),
    )

    @Test fun oneOffTaskOccursOnlyOnItsDay() {
        val task = TodoTask(name = "Task", startTime = date(2026, 3, 10), hasSpecificDay = true)
        assertTrue(task.occurs(date(2026, 3, 10)))
        assertFalse(task.occurs(date(2026, 3, 11)))
    }

    @Test fun inboxItemsNeverFallOnADay() {
        val task = TodoTask(name = "Idea", startTime = date(2026, 3, 10), timeScope = TaskTimeScope.inbox)
        assertFalse(task.occurs(date(2026, 3, 10)))
    }

    @Test fun dailyTaskStartsOnItsDateAndHonoursTheInterval() {
        val everyDay = task(RecurrenceType.Daily, date(2026, 3, 10))
        assertFalse(everyDay.occurs(date(2026, 3, 9)))
        assertTrue(everyDay.occurs(date(2026, 3, 10)))
        assertTrue(everyDay.occurs(date(2026, 4, 2)))
        val everyOther = task(RecurrenceType.Daily, date(2026, 3, 10)) { copy(dayInterval = 2) }
        assertTrue(everyOther.occurs(date(2026, 3, 12)))
        assertFalse(everyOther.occurs(date(2026, 3, 13)))
    }

    @Test fun weeklyTaskOccursOnItsWeekdaysOnly() {
        // 2026-03-09 is a Monday (2) and 2026-03-11 a Wednesday (4).
        val weekly = task(RecurrenceType.Weekly(setOf(2, 4)), date(2026, 3, 9))
        assertTrue(weekly.occurs(date(2026, 3, 9)))
        assertFalse(weekly.occurs(date(2026, 3, 10)))
        assertTrue(weekly.occurs(date(2026, 3, 11)))
    }

    @Test fun recurrenceEndsOnItsEndDate() {
        val ending = task(RecurrenceType.Daily, date(2026, 3, 10)) { copy(endDate = date(2026, 3, 12)) }
        assertTrue(ending.occurs(date(2026, 3, 12)))
        assertFalse(ending.occurs(date(2026, 3, 13)))
    }
}

/** What the file format promises: data moves between the iOS and the Android app. */
class CompatibilityTests {
    @Test fun taskSurvivesEncodingWithItsRecurrence() {
        val original = TodoTask(
            name = "Run", startTime = date(2026, 3, 10), hasSpecificDay = true, priority = Priority.high, icon = "figure.run",
            recurrence = Recurrence(type = RecurrenceType.Weekly(setOf(2, 4)), startDate = date(2026, 3, 10)),
            subtasks = listOf(Subtask(name = "Warm up")),
        )
        val decoded = AppJson.decodeFromString(TodoTask.serializer(), AppJson.encodeToString(TodoTask.serializer(), original))
        assertEquals(original.id, decoded.id)
        assertEquals(original.name, decoded.name)
        assertEquals(original.recurrence?.type, decoded.recurrence?.type)
        assertEquals(original.subtasks.map { it.name }, decoded.subtasks.map { it.name })
    }

    @Test fun datesAreWrittenAsIOSReadsThem() {
        val json = AppJson.encodeToString(DateSerializer, java.time.Instant.parse("2026-03-10T12:00:00.750Z"))
        assertEquals("\"2026-03-10T12:00:00Z\"", json)
    }

    @Test fun idsAreWrittenInCapitalsLikeIOS() {
        val id = UUID.fromString("0a1b2c3d-0000-4000-8000-00000000abcd")
        assertEquals("0A1B2C3D-0000-4000-8000-00000000ABCD", id.uuidString)
    }

    @Test fun replyKeyMatchesTheOneOfIOSAndTheReplyScript() {
        val id = UUID.fromString("00000000-0000-0000-0000-000000000001")
        assertEquals("6297c5cbd971b71bbb43f60e932868c2", FeedbackReplyNotifier.replyKey(id, "Hello"))
    }
}
