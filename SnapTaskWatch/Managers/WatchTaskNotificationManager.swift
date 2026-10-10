import Foundation
import Combine
import UserNotifications

@MainActor
final class WatchTaskNotificationManager: NSObject, ObservableObject {
    static let shared = WatchTaskNotificationManager()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()
    private var preferencesCancellable: AnyCancellable?
    private var cachedTasks: [TodoTask] = []

    private let recurringWindowDays = 30
    private let maxRecurringNotificationsPerTask = 30

    private override init() {
        super.init()
        center.delegate = self
        bindPreferences()

        Task {
            await refreshAuthorizationStatus()
        }
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            await refreshAuthorizationStatus()
            return granted
        } catch {
            print("⌚️ Error requesting notification permission: \(error)")
            return false
        }
    }

    @discardableResult
    func refreshAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        return settings.authorizationStatus
    }

    func syncNotifications(for tasks: [TodoTask]) async {
        cachedTasks = tasks

        let status = await refreshAuthorizationStatus()
        guard WatchPreferences.shared.notificationsEnabled else {
            await cancelAllTaskNotifications()
            return
        }

        guard status == .authorized else {
            return
        }

        await cancelAllTaskNotifications()

        for task in tasks {
            guard task.hasNotification, task.hasSpecificTime else { continue }
            if task.recurrence != nil {
                _ = await scheduleRecurringNotifications(for: task)
            } else {
                _ = await scheduleNotification(for: task)
            }
        }
    }

    func resyncCachedNotifications() async {
        await syncNotifications(for: cachedTasks)
    }

    private func bindPreferences() {
        preferencesCancellable = WatchPreferences.shared.$notificationsEnabled
            .removeDuplicates()
            .sink { [weak self] enabled in
                guard let self else { return }
                Task { @MainActor in
                    if enabled {
                        await self.resyncCachedNotifications()
                    } else {
                        await self.cancelAllTaskNotifications()
                    }
                }
            }
    }

    private func notificationContent(for task: TodoTask) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        // The task name is the title: it is the only bold line iOS shows.
        content.title = task.name
        content.body = "task_notification_title".localized
        content.sound = .default
        if let category = task.category {
            content.subtitle = category.name
        }
        return content
    }

    private func triggerDate(for task: TodoTask, occurrenceDate: Date) -> Date? {
        let offset = TimeInterval(task.notificationLeadTimeMinutes) * 60
        let date = occurrenceDate.addingTimeInterval(-offset)
        return date > Date() ? date : nil
    }

    private func scheduleNotification(for task: TodoTask) async -> String? {
        guard task.hasNotification,
              task.hasSpecificTime,
              authorizationStatus == .authorized else {
            return nil
        }

        guard let fireDate = triggerDate(for: task, occurrenceDate: task.startTime) else {
            return nil
        }

        let identifier = "task_\(task.id.uuidString)"
        let content = notificationContent(for: task)
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
            print("⌚️ Scheduled task notification: \(task.name) at \(fireDate)")
            return identifier
        } catch {
            print("⌚️ Failed scheduling task notification for \(task.name): \(error)")
            return nil
        }
    }

    private func scheduleRecurringNotifications(for task: TodoTask) async -> [String] {
        guard task.hasNotification,
              task.hasSpecificTime,
              let recurrence = task.recurrence,
              authorizationStatus == .authorized else {
            return []
        }

        let calendar = Calendar.current
        let today = Date()
        let endDate = calendar.date(byAdding: .day, value: recurringWindowDays, to: today) ?? today
        let maxCount = maxRecurringNotificationsPerTask
        var identifiers: [String] = []
        var currentDate = today

        while currentDate <= endDate, identifiers.count < maxCount {
            guard recurrence.shouldOccurOn(date: currentDate) else {
                guard let next = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
                currentDate = next
                continue
            }

            let occurrenceTime = calendar.dateComponents([.hour, .minute], from: task.startTime)
            var candidateComponents = calendar.dateComponents([.year, .month, .day], from: currentDate)
            candidateComponents.hour = occurrenceTime.hour
            candidateComponents.minute = occurrenceTime.minute

            guard let occurrenceDate = calendar.date(from: candidateComponents),
                  let fireDate = triggerDate(for: task, occurrenceDate: occurrenceDate) else {
                guard let next = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
                currentDate = next
                continue
            }

            let identifier = "task_\(task.id.uuidString)_\(Int(fireDate.timeIntervalSince1970))"
            let content = notificationContent(for: task)
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            do {
                try await center.add(request)
                identifiers.append(identifier)
                print("⌚️ Scheduled recurring task notification: \(task.name) at \(fireDate)")
            } catch {
                print("⌚️ Failed scheduling recurring task notification for \(task.name): \(error)")
            }

            guard let next = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = next
        }

        return identifiers
    }

    private func cancelAllTaskNotifications() async {
        let requests = await pendingRequests()
        let pendingTaskIdentifiers = requests
            .map { $0.identifier }
            .filter { $0.hasPrefix("task_") }

        if !pendingTaskIdentifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: pendingTaskIdentifiers)
        }

        let delivered = await deliveredNotifications()
        let deliveredTaskIdentifiers = delivered
            .map { $0.request.identifier }
            .filter { $0.hasPrefix("task_") }

        if !deliveredTaskIdentifiers.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: deliveredTaskIdentifiers)
        }

        if !pendingTaskIdentifiers.isEmpty || !deliveredTaskIdentifiers.isEmpty {
            print("⌚️ Cancelled \(pendingTaskIdentifiers.count) pending and \(deliveredTaskIdentifiers.count) delivered task notifications")
        }
    }

    private func pendingRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }

    private func deliveredNotifications() async -> [UNNotification] {
        await withCheckedContinuation { continuation in
            center.getDeliveredNotifications { notifications in
                continuation.resume(returning: notifications)
            }
        }
    }
}

extension WatchTaskNotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}
