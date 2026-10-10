import Testing
import Foundation
import UserNotifications
@testable import SnapTask_Pro

/// Runs against the real notification center of the test host, so it needs notification
/// permission on the simulator; without it the tests return early.
@MainActor
@Suite(.serialized)
struct TaskReminderSyncTests {
    let center = UNUserNotificationCenter.current()
    let manager = TaskNotificationManager.shared

    private func authorized() async -> Bool {
        await center.notificationSettings().authorizationStatus == .authorized
    }

    private func taskReminders() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix("task_") }
    }

    private func daily(_ name: String, hourFromNow: Double = 1) -> TodoTask {
        let now = Date()
        return TodoTask(
            id: UUID(),
            name: name,
            startTime: now.addingTimeInterval(hourFromNow * 3600),
            hasSpecificTime: true,
            recurrence: Recurrence(type: .daily, startDate: Calendar.current.startOfDay(for: now), endDate: nil),
            hasNotification: true,
            notificationLeadTimeMinutes: 0
        )
    }

    private func oneOff(_ name: String, hoursFromNow: Double) -> TodoTask {
        TodoTask(
            id: UUID(),
            name: name,
            startTime: Date().addingTimeInterval(hoursFromNow * 3600),
            hasSpecificTime: true,
            hasNotification: true,
            notificationLeadTimeMinutes: 0
        )
    }

    /// The test host app syncs its own tasks at launch: let that finish first.
    private func reset() async {
        await manager.waitForReminderSync()
        center.removeAllPendingNotificationRequests()
        manager.areTaskNotificationsEnabled = true
    }

    /// Fails instead of silently skipping, so a run without permission can't pass by accident.
    @Test func hasNotificationPermission() async {
        #expect(await authorized(), "Allow SnapTask notifications on the simulator to run these tests")
    }

    @Test func schedulesRecurringAndOneOffTasks() async {
        guard await authorized() else { return }
        await reset()
        let tasks = [daily("Daily A"), oneOff("Once", hoursFromNow: 5)]

        await manager.syncTaskReminders(tasks: tasks)

        let pending = await taskReminders()
        #expect(pending.contains { $0.identifier == "task_\(tasks[1].id.uuidString)" })
        #expect(pending.filter { $0.identifier.hasPrefix("task_\(tasks[0].id.uuidString)_") }.count >= 25)
        #expect(pending.allSatisfy { $0.content.title == "Daily A" || $0.content.title == "Once" })
    }

    @Test func secondRunChangesNothing() async {
        guard await authorized() else { return }
        await reset()
        let tasks = [daily("Daily A"), daily("Daily B", hourFromNow: 2)]
        await manager.syncTaskReminders(tasks: tasks)
        let first = Set(await taskReminders().map(\.identifier))

        await manager.syncTaskReminders(tasks: tasks)

        #expect(Set(await taskReminders().map(\.identifier)) == first)
    }

    /// The bug of 1.8: an interrupted reschedule left no reminders. Now a run only fills gaps.
    @Test func refillsWhatIsMissingWithoutClearingTheRest() async {
        guard await authorized() else { return }
        await reset()
        let tasks = [daily("Daily A")]
        await manager.syncTaskReminders(tasks: tasks)
        let all = await taskReminders().map(\.identifier).sorted()
        center.removePendingNotificationRequests(withIdentifiers: Array(all.prefix(10)))

        await manager.syncTaskReminders(tasks: tasks)

        #expect(await taskReminders().map(\.identifier).sorted() == all)
    }

    @Test func movesReminderWhenTimeChangesAndDropsDeletedTasks() async {
        guard await authorized() else { return }
        await reset()
        var once = oneOff("Once", hoursFromNow: 5)
        let gone = daily("Gone")
        await manager.syncTaskReminders(tasks: [once, gone])

        once.startTime = Date().addingTimeInterval(8 * 3600)
        await manager.syncTaskReminders(tasks: [once])

        let pending = await taskReminders()
        #expect(!pending.contains { $0.identifier.contains(gone.id.uuidString) })
        let trigger = pending.first { $0.identifier == "task_\(once.id.uuidString)" }?.trigger as? UNCalendarNotificationTrigger
        let expected = Calendar.current.dateComponents([.hour, .minute], from: once.startTime)
        #expect(trigger?.dateComponents.hour == expected.hour)
        #expect(trigger?.dateComponents.minute == expected.minute)
    }

    @Test func staysWithinTheIOSLimitKeepingTheSoonest() async {
        guard await authorized() else { return }
        await reset()
        let tasks = (0..<10).map { daily("Daily \($0)", hourFromNow: 1 + Double($0) / 10) }

        await manager.syncTaskReminders(tasks: tasks)

        let pending = await taskReminders()
        #expect(pending.count <= 60)
        #expect(pending.count >= 50)
        // Every task gets its next days, none is left without reminders.
        for task in tasks {
            #expect(pending.contains { $0.identifier.hasPrefix("task_\(task.id.uuidString)_") })
        }
    }

    @Test func keepsSnoozedReminders() async {
        guard await authorized() else { return }
        await reset()
        let task = oneOff("Snoozed", hoursFromNow: 5)
        await manager.scheduleCustomSnoozeNotification(for: task, at: Date().addingTimeInterval(3600))

        await manager.syncTaskReminders(tasks: [])

        #expect(await taskReminders().contains { $0.identifier.hasPrefix("task_\(task.id.uuidString)_") })
    }

    @Test func mutedLeavesEverythingAsIs() async {
        guard await authorized() else { return }
        await reset()
        let tasks = [daily("Daily A")]
        await manager.syncTaskReminders(tasks: tasks)
        let before = await taskReminders().count

        manager.areTaskNotificationsEnabled = false
        await manager.syncTaskReminders(tasks: [])
        manager.areTaskNotificationsEnabled = true

        #expect(await taskReminders().count == before)
    }
}
