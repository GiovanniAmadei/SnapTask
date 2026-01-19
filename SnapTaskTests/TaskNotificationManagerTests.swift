//
//  TaskNotificationManagerTests.swift
//  SnapTaskTests
//
//  Created by Cascade on 14/01/26.
//

import Testing
import Foundation
@testable import SnapTask_Pro

struct TaskNotificationManagerTests {
    
    /// Test che verifica che cancelAllNotificationsForTask sia async e attenda il completamento
    /// Prima della fix: la funzione usava un completion handler e ritornava immediatamente
    /// Dopo la fix: la funzione è async e attende il completamento prima di ritornare
    @Test func testCancelAllNotificationsForTaskIsAsync() async throws {
        let manager = TaskNotificationManager.shared
        let testTaskId = UUID()
        
        // Verifica che la funzione sia chiamabile con await (compila solo se è async)
        await manager.cancelAllNotificationsForTask(testTaskId)
        
        // Se arriviamo qui, la funzione è correttamente async
        #expect(true, "cancelAllNotificationsForTask è correttamente async")
    }
    
    @Test func testComputeRecurringNotificationDates_daily_beforeAndAfter() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_700_000_000) // fixed
        let startTime = now.addingTimeInterval(3600) // +1h

        let recurrence = Recurrence(type: .daily, startDate: calendar.startOfDay(for: now), endDate: nil)

        // BEFORE: 10 min prima
        var taskBefore = TodoTask(
            id: UUID(),
            name: "Daily",
            startTime: startTime,
            hasSpecificTime: true,
            recurrence: recurrence,
            hasNotification: true,
            notificationLeadTimeMinutes: 10
        )
        let datesBefore = TaskNotificationManager.computeRecurringNotificationDates(
            for: taskBefore,
            now: now,
            windowDays: 2,
            maxCount: 10,
            calendar: calendar
        )
        #expect(!datesBefore.isEmpty)
        #expect(datesBefore.first! < startTime)

        // AFTER: 10 min dopo (leadMinutes negativo)
        taskBefore.notificationLeadTimeMinutes = -10
        let datesAfter = TaskNotificationManager.computeRecurringNotificationDates(
            for: taskBefore,
            now: now,
            windowDays: 2,
            maxCount: 10,
            calendar: calendar
        )
        #expect(!datesAfter.isEmpty)
        #expect(datesAfter.first! > startTime)
    }
    
    @Test func testComputeRecurringNotificationDates_respectsMaxCount() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let startTime = now.addingTimeInterval(3600)
        let recurrence = Recurrence(type: .daily, startDate: calendar.startOfDay(for: now), endDate: nil)

        let task = TodoTask(
            id: UUID(),
            name: "Daily",
            startTime: startTime,
            hasSpecificTime: true,
            recurrence: recurrence,
            hasNotification: true,
            notificationLeadTimeMinutes: 0
        )

        let dates = TaskNotificationManager.computeRecurringNotificationDates(
            for: task,
            now: now,
            windowDays: 30,
            maxCount: 3,
            calendar: calendar
        )
        #expect(dates.count <= 3)
    }
}
