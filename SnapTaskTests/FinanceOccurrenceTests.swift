import XCTest
@testable import SnapTask_Pro

/// Recurring finance entries must be expanded into one dated movement per repetition, so balance,
/// monthly figures, charts and budgets all agree with each other.
@MainActor
final class FinanceOccurrenceTests: XCTestCase {
    private let calendar = Calendar.current
    private var manager: FinanceManager { FinanceManager.shared }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func interval(_ start: Date, _ end: Date) -> DateInterval {
        DateInterval(start: start, end: end)
    }

    private func recurring(_ frequency: SubscriptionFrequency, from start: Date, until end: Date? = nil) -> FinanceEntry {
        FinanceEntry(
            name: "Test",
            amount: 10,
            type: .subscription,
            date: start,
            isRecurring: true,
            recurringFrequency: frequency,
            recurringEndDate: end
        )
    }

    func testOneOffEntryHappensOnlyInsideItsPeriod() {
        let entry = FinanceEntry(name: "Lunch", amount: 12, type: .expense, date: date(2026, 3, 10))

        XCTAssertEqual(manager.occurrenceDates(of: entry, in: interval(date(2026, 3, 1), date(2026, 4, 1))).count, 1)
        XCTAssertTrue(manager.occurrenceDates(of: entry, in: interval(date(2026, 4, 1), date(2026, 5, 1))).isEmpty)
    }

    func testPeriodEndIsExcluded() {
        let boundary = date(2026, 4, 1)
        let entry = FinanceEntry(name: "Edge", amount: 1, type: .expense, date: boundary)

        XCTAssertTrue(manager.occurrenceDates(of: entry, in: interval(date(2026, 3, 1), boundary)).isEmpty)
        XCTAssertEqual(manager.occurrenceDates(of: entry, in: interval(boundary, date(2026, 5, 1))).count, 1)
    }

    func testMonthlyEntryRepeatsEveryMonthOfThePeriod() {
        let entry = recurring(.monthly, from: date(2026, 1, 15))
        let dates = manager.occurrenceDates(of: entry, in: interval(date(2026, 3, 1), date(2026, 6, 1)))

        XCTAssertEqual(dates.map { calendar.component(.month, from: $0) }, [3, 4, 5])
        XCTAssertTrue(dates.allSatisfy { calendar.component(.day, from: $0) == 15 })
    }

    func testNothingHappensBeforeTheStartDate() {
        let entry = recurring(.monthly, from: date(2026, 6, 15))

        XCTAssertTrue(manager.occurrenceDates(of: entry, in: interval(date(2026, 1, 1), date(2026, 6, 1))).isEmpty)
    }

    func testRecurringEntryStopsAfterItsEndDate() {
        let entry = recurring(.monthly, from: date(2026, 1, 10), until: date(2026, 3, 10))
        let dates = manager.occurrenceDates(of: entry, in: interval(date(2026, 1, 1), date(2027, 1, 1)))

        // Jan 10, Feb 10 and Mar 10 (the end day itself is included).
        XCTAssertEqual(dates.count, 3)
    }

    func testMonthEndDayIsClampedWithoutDrifting() {
        let entry = recurring(.monthly, from: date(2026, 1, 31))
        let dates = manager.occurrenceDates(of: entry, in: interval(date(2026, 1, 1), date(2026, 5, 1)))
        let days = dates.map { calendar.component(.day, from: $0) }

        XCTAssertEqual(days, [31, 28, 31, 30])
    }

    func testWeeklyEntryHappensEverySevenDays() {
        let entry = recurring(.weekly, from: date(2026, 3, 2))
        let dates = manager.occurrenceDates(of: entry, in: interval(date(2026, 3, 1), date(2026, 4, 1)))

        XCTAssertEqual(dates.count, 5) // Mar 2, 9, 16, 23, 30
        for (previous, next) in zip(dates, dates.dropFirst()) {
            XCTAssertEqual(calendar.dateComponents([.day], from: previous, to: next).day, 7)
        }
    }

    func testQuarterlyAndYearlyEntries() {
        let quarterly = recurring(.quarterly, from: date(2025, 1, 5))
        XCTAssertEqual(manager.occurrenceDates(of: quarterly, in: interval(date(2026, 1, 1), date(2027, 1, 1))).count, 4)

        let yearly = recurring(.yearly, from: date(2020, 6, 20))
        XCTAssertEqual(manager.occurrenceDates(of: yearly, in: interval(date(2026, 1, 1), date(2027, 1, 1))).count, 1)
    }

    func testNextOccurrenceIsTheFirstFutureRepetition() {
        let now = Date()
        let start = calendar.date(byAdding: .day, value: -45, to: now)!
        let entry = recurring(.monthly, from: start)

        let next = manager.nextOccurrence(of: entry, after: now)

        XCTAssertNotNil(next)
        XCTAssertGreaterThanOrEqual(next!, now)
        XCTAssertLessThan(next!, calendar.date(byAdding: .day, value: 32, to: now)!)
    }

    func testEndedSubscriptionHasNoNextOccurrence() {
        let now = Date()
        let start = calendar.date(byAdding: .month, value: -6, to: now)!
        let end = calendar.date(byAdding: .month, value: -1, to: now)!

        XCTAssertNil(manager.nextOccurrence(of: recurring(.monthly, from: start, until: end), after: now))
    }

    func testAmountParsingAcceptsBothDecimalSeparators() {
        XCTAssertEqual(FinanceNumber.parse("12,50"), 12.5)
        XCTAssertEqual(FinanceNumber.parse("12.50"), 12.5)
        XCTAssertEqual(FinanceNumber.parse(" 3 "), 3)
        XCTAssertNil(FinanceNumber.parse(""))
        XCTAssertNil(FinanceNumber.parse("abc"))
    }
    
    // MARK: - Card layout
    
    func testEmptyLayoutIsTheDefaultOrder() {
        let layout = FinanceCardLayout(rawValue: "")
        XCTAssertEqual(layout, .default)
        XCTAssertEqual(layout.visibleCards, FinanceDashboardCard.allCases)
    }
    
    func testLayoutKeepsOrderAndHiddenCardsThroughItsRawValue() {
        var layout = FinanceCardLayout.default
        layout.order.move(fromOffsets: IndexSet(integer: layout.order.firstIndex(of: .budget)!), toOffset: 0)
        layout.hidden = [.summary]
        
        let restored = FinanceCardLayout(rawValue: layout.rawValue)
        
        XCTAssertEqual(restored, layout)
        XCTAssertEqual(restored.visibleCards.first, .budget)
        XCTAssertFalse(restored.visibleCards.contains(.summary))
    }
    
    func testLayoutAddsCardsMissingFromAnOlderSavedOrder() {
        // Saved by a version that only knew two cards, plus an unknown one that must be ignored.
        let layout = FinanceCardLayout(rawValue: "trend,-recentEntries,legacyCard")
        
        XCTAssertEqual(Set(layout.order), Set(FinanceDashboardCard.allCases))
        XCTAssertEqual(layout.order.count, FinanceDashboardCard.allCases.count)
        XCTAssertEqual(layout.order.first, .trend)
        XCTAssertEqual(layout.hidden, [.recentEntries])
    }
}
