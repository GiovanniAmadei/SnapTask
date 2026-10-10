import Foundation
import UserNotifications
import Combine

class TaskNotificationManager: NSObject, ObservableObject {
    static let shared = TaskNotificationManager()
    
    @Published var areTaskNotificationsEnabled = true
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    private let center = UNUserNotificationCenter.current()

    private let maxPendingNotificationsBudget: Int = 60
    private let recurringWindowDays: Int = 30
    private let maxRecurringNotificationsPerTask: Int = 30

    private static var lastRollingRescheduleTime: Date = .distantPast
    
    static let taskReminderCategoryIdentifier = "TASK_REMINDER_CATEGORY"
    static let actionMarkCompletedIdentifier = "TASK_ACTION_MARK_COMPLETED"
    static let actionSnooze1HIdentifier = "TASK_ACTION_SNOOZE_1H"
    static let actionSnoozeTomorrowIdentifier = "TASK_ACTION_SNOOZE_TOMORROW"
    
    override init() {
        super.init()
        center.delegate = self
        checkAuthorizationStatus()
        loadNotificationSettings()
        setupNotificationCategories()
    }
    
    private func setupNotificationCategories() {
        let markCompletedAction = UNNotificationAction(
            identifier: TaskNotificationManager.actionMarkCompletedIdentifier,
            title: "mark_as_completed".localized,
            options: [],
            icon: UNNotificationActionIcon(systemImageName: "checkmark.circle.fill")
        )
        
        let snooze1hAction = UNNotificationAction(
            identifier: TaskNotificationManager.actionSnooze1HIdentifier,
            title: "remind_me_in_1_hour".localized,
            options: [],
            icon: UNNotificationActionIcon(systemImageName: "clock.arrow.circlepath")
        )
        
        let snoozeTomorrowAction = UNNotificationAction(
            identifier: TaskNotificationManager.actionSnoozeTomorrowIdentifier,
            title: "tomorrow_morning_9am".localized,
            options: [],
            icon: UNNotificationActionIcon(systemImageName: "sun.max.fill")
        )
        
        let taskCategory = UNNotificationCategory(
            identifier: TaskNotificationManager.taskReminderCategoryIdentifier,
            actions: [markCompletedAction, snooze1hAction, snoozeTomorrowAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        center.setNotificationCategories([taskCategory])
        print("🔔 Registered Actionable Notification Category: \(TaskNotificationManager.taskReminderCategoryIdentifier)")
    }
    
    // MARK: - Authorization
    
    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            await MainActor.run {
                self.authorizationStatus = granted ? .authorized : .denied
            }
            return granted
        } catch {
            print("Error requesting notification permission: \(error)")
            return false
        }
    }
    
    func checkAuthorizationStatus() {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
            }
        }
    }

    func refreshAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        await MainActor.run {
            self.authorizationStatus = settings.authorizationStatus
        }
        return settings.authorizationStatus
    }
    
    // MARK: - Master Mute Management
    
    func setTaskNotificationsEnabled(_ enabled: Bool) {
        areTaskNotificationsEnabled = enabled
        saveNotificationSettings()
        
        if !enabled {
            // Quando disabilitato: cancella tutte le notifiche task pendenti
            cancelAllTaskNotifications()
            print("🔇 Master mute ON: cancelled all task notifications")
        } else {
            print("🔔 Master mute OFF: task notifications re-enabled")
            // Nota: non ripianifichiamo automaticamente qui.
            // Le notifiche verranno ripianificate quando le task vengono modificate/create
        }
    }
    
    private func cancelAllTaskNotifications() {
        center.getPendingNotificationRequests { requests in
            let taskNotificationIdentifiers = requests
                .filter { $0.identifier.hasPrefix("task_") }
                .map { $0.identifier }
            
            if !taskNotificationIdentifiers.isEmpty {
                self.center.removePendingNotificationRequests(withIdentifiers: taskNotificationIdentifiers)
                self.center.removeDeliveredNotifications(withIdentifiers: taskNotificationIdentifiers)
                print("🗑️ Cancelled \(taskNotificationIdentifiers.count) task notifications")
            }

            self.center.getDeliveredNotifications { delivered in
                let deliveredTaskIdentifiers = delivered
                    .map { $0.request.identifier }
                    .filter { $0.hasPrefix("task_") }

                if !deliveredTaskIdentifiers.isEmpty {
                    self.center.removeDeliveredNotifications(withIdentifiers: deliveredTaskIdentifiers)
                    print("🗑️ Removed \(deliveredTaskIdentifiers.count) delivered task notifications")
                }
            }
        }
    }
    
    // MARK: - Notification Management

    private static func taskIdFromTaskNotificationIdentifier(_ identifier: String) -> UUID? {
        guard identifier.hasPrefix("task_") else { return nil }
        let components = identifier.components(separatedBy: "_")
        guard components.count >= 2 else { return nil }
        return UUID(uuidString: components[1])
    }

    func cleanupOrphanedTaskNotifications(validTaskIds: Set<UUID>) async {
        let requests = await center.pendingNotificationRequests()
        let orphanPendingIdentifiers = requests
            .map { $0.identifier }
            .filter { id in
                guard id.hasPrefix("task_") else { return false }
                guard let taskId = Self.taskIdFromTaskNotificationIdentifier(id) else { return true }
                return !validTaskIds.contains(taskId)
            }

        if !orphanPendingIdentifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: orphanPendingIdentifiers)
        }

        let delivered = await deliveredNotifications()
        let orphanDeliveredIdentifiers = delivered
            .map { $0.request.identifier }
            .filter { id in
                guard id.hasPrefix("task_") else { return false }
                guard let taskId = Self.taskIdFromTaskNotificationIdentifier(id) else { return true }
                return !validTaskIds.contains(taskId)
            }

        if !orphanDeliveredIdentifiers.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: orphanDeliveredIdentifiers)
        }

        if !orphanPendingIdentifiers.isEmpty || !orphanDeliveredIdentifiers.isEmpty {
            print("🧹 Cleaned up \(orphanPendingIdentifiers.count) orphan pending and \(orphanDeliveredIdentifiers.count) orphan delivered task notifications")
        }
    }

    static func computeRecurringNotificationDates(
        for task: TodoTask,
        now: Date,
        windowDays: Int = 30,
        maxCount: Int = 30,
        calendar: Calendar = .current
    ) -> [Date] {
        guard task.hasSpecificTime,
              task.hasNotification,
              let recurrence = task.recurrence else {
            return []
        }

        var dates: [Date] = []
        let defaultEnd = calendar.date(byAdding: .day, value: windowDays, to: now) ?? now
        let endDate = recurrence.endDate.map { min($0, defaultEnd) } ?? defaultEnd
        var currentDate = now

        let overridesByWeekday: [Int: Recurrence.WeekdayTimeOverride] = {
            guard let overrides = recurrence.weekdayTimeOverrides else { return [:] }
            return Dictionary(uniqueKeysWithValues: overrides.map { ($0.weekday, $0) })
        }()

        let overridesByMonthDay: [Int: Recurrence.MonthDayTimeOverride] = {
            guard let overrides = recurrence.monthDayTimeOverrides else { return [:] }
            return Dictionary(uniqueKeysWithValues: overrides.map { ($0.day, $0) })
        }()

        let overridesByMonthOrdinalKey: [String: Recurrence.MonthOrdinalTimeOverride] = {
            guard let overrides = recurrence.monthOrdinalTimeOverrides else { return [:] }
            return Dictionary(uniqueKeysWithValues: overrides.map { ("\($0.ordinal)_\($0.weekday)", $0) })
        }()

        while currentDate <= endDate {
            if dates.count >= maxCount { break }

            if recurrence.shouldOccurOn(date: currentDate) {
                let timeComponents: DateComponents = {
                    switch recurrence.type {
                    case .weekly:
                        let weekday = calendar.component(.weekday, from: currentDate)
                        if let override = overridesByWeekday[weekday] {
                            var comps = DateComponents()
                            comps.hour = override.hour
                            comps.minute = override.minute
                            return comps
                        }
                    case .monthly:
                        let day = calendar.component(.day, from: currentDate)
                        if let override = overridesByMonthDay[day] {
                            var comps = DateComponents()
                            comps.hour = override.hour
                            comps.minute = override.minute
                            return comps
                        }
                    case .monthlyOrdinal(let patterns):
                        let weekday = calendar.component(.weekday, from: currentDate)
                        let day = calendar.component(.day, from: currentDate)
                        let ordinal: Int = {
                            let range = calendar.range(of: .day, in: .month, for: currentDate)!
                            let lastDayOfMonth = range.upperBound - 1
                            if patterns.contains(where: { $0.ordinal == -1 && $0.weekday == weekday }) {
                                for dayOffset in 0..<7 {
                                    let checkDay = lastDayOfMonth - dayOffset
                                    if checkDay < 1 { break }
                                    if let checkDate = calendar.date(bySetting: .day, value: checkDay, of: currentDate),
                                       calendar.component(.weekday, from: checkDate) == weekday {
                                        return day == checkDay ? -1 : ((day - 1) / 7 + 1)
                                    }
                                }
                            }
                            return (day - 1) / 7 + 1
                        }()
                        if let override = overridesByMonthOrdinalKey["\(ordinal)_\(weekday)"] {
                            var comps = DateComponents()
                            comps.hour = override.hour
                            comps.minute = override.minute
                            return comps
                        }
                    case .yearly:
                        if let override = recurrence.yearlyTimeOverride {
                            var comps = DateComponents()
                            comps.hour = override.hour
                            comps.minute = override.minute
                            return comps
                        }
                    case .daily:
                        break
                    }
                    return calendar.dateComponents([.hour, .minute], from: task.startTime)
                }()

                let dateComponents = calendar.dateComponents([.year, .month, .day], from: currentDate)
                var candidateComponents = DateComponents()
                candidateComponents.year = dateComponents.year
                candidateComponents.month = dateComponents.month
                candidateComponents.day = dateComponents.day
                candidateComponents.hour = timeComponents.hour
                candidateComponents.minute = timeComponents.minute

                if let occurrenceDate = calendar.date(from: candidateComponents) {
                    let offset = TimeInterval(task.notificationLeadTimeMinutes) * 60
                    let notificationDate = occurrenceDate.addingTimeInterval(-offset)
                    if notificationDate > now {
                        dates.append(notificationDate)
                    }
                }
            }

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }

        return dates.sorted()
    }
    
    func scheduleNotification(for task: TodoTask) async -> String? {
        let status = await refreshAuthorizationStatus()
        guard areTaskNotificationsEnabled,
              status == .authorized,
              task.hasSpecificTime,
              task.hasNotification else {
            if task.hasNotification {
                print("⚠️ Skip scheduling notification for task: \(task.name) | enabled=\(areTaskNotificationsEnabled) status=\(status.rawValue) hasSpecificTime=\(task.hasSpecificTime) hasNotification=\(task.hasNotification)")
            }
            return nil
        }

        let offset = TimeInterval(task.notificationLeadTimeMinutes) * 60
        let fireDate = task.startTime.addingTimeInterval(-offset)
        
        guard fireDate > Date() else {
            return nil
        }
        
        let identifier = "task_\(task.id.uuidString)"
        
        let content = UNMutableNotificationContent()
        // The task name is the title: it is the only bold line iOS shows.
        content.title = task.name
        content.body = "task_notification_title".localized
        content.sound = .default
        content.categoryIdentifier = TaskNotificationManager.taskReminderCategoryIdentifier
        if let category = task.category {
            content.subtitle = category.name
        }
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            print("✅ Scheduled notification for task: \(task.name) at \(fireDate) (lead \(task.notificationLeadTimeMinutes)m)")
            return identifier
        } catch {
            print("❌ Error scheduling notification: \(error)")
            return nil
        }
    }
    
    func scheduleRecurringNotifications(for task: TodoTask) async -> [String] {
        let requests = await center.pendingNotificationRequests()
        let taskPrefix = "task_\(task.id.uuidString)"
        let otherRequestsCount = requests.filter { !$0.identifier.hasPrefix(taskPrefix) }.count
        let remainingBudget = max(0, maxPendingNotificationsBudget - otherRequestsCount)
        let perTaskBudget = min(maxRecurringNotificationsPerTask, remainingBudget)
        return await scheduleRecurringNotifications(for: task, maxCount: perTaskBudget)
    }

    func scheduleRecurringNotifications(for task: TodoTask, maxCount: Int) async -> [String] {
        let status = await refreshAuthorizationStatus()
        guard areTaskNotificationsEnabled,
              status == .authorized,
              task.hasSpecificTime,
              task.hasNotification,
              let recurrence = task.recurrence,
              maxCount > 0 else {
            if task.hasNotification && (status != .authorized || !areTaskNotificationsEnabled) {
                print("⚠️ Skip scheduling recurring notifications for task: \(task.name) | enabled=\(areTaskNotificationsEnabled) status=\(status.rawValue) hasSpecificTime=\(task.hasSpecificTime) hasNotification=\(task.hasNotification) hasRecurrence=\(task.recurrence != nil)")
            }
            return []
        }

        var identifiers: [String] = []
        let calendar = Calendar.current
        let today = Date()
        let perTaskBudget = min(max(0, maxCount), maxRecurringNotificationsPerTask)

        let overridesByWeekday: [Int: Recurrence.WeekdayTimeOverride] = {
            guard let overrides = recurrence.weekdayTimeOverrides else { return [:] }
            return Dictionary(uniqueKeysWithValues: overrides.map { ($0.weekday, $0) })
        }()

        let overridesByMonthDay: [Int: Recurrence.MonthDayTimeOverride] = {
            guard let overrides = recurrence.monthDayTimeOverrides else { return [:] }
            return Dictionary(uniqueKeysWithValues: overrides.map { ($0.day, $0) })
        }()

        let overridesByMonthOrdinalKey: [String: Recurrence.MonthOrdinalTimeOverride] = {
            guard let overrides = recurrence.monthOrdinalTimeOverrides else { return [:] }
            return Dictionary(uniqueKeysWithValues: overrides.map { ("\($0.ordinal)_\($0.weekday)", $0) })
        }()

        let defaultEnd = calendar.date(byAdding: .day, value: recurringWindowDays, to: today) ?? today
        let endDate = recurrence.endDate.map { min($0, defaultEnd) } ?? defaultEnd
        var currentDate = today

        while currentDate <= endDate {
            if identifiers.count >= perTaskBudget { break }

            if recurrence.shouldOccurOn(date: currentDate) {
                let timeComponents: DateComponents = {
                    switch recurrence.type {
                    case .weekly:
                        let weekday = calendar.component(.weekday, from: currentDate)
                        if let override = overridesByWeekday[weekday] {
                            var comps = DateComponents()
                            comps.hour = override.hour
                            comps.minute = override.minute
                            return comps
                        }
                    case .monthly:
                        let day = calendar.component(.day, from: currentDate)
                        if let override = overridesByMonthDay[day] {
                            var comps = DateComponents()
                            comps.hour = override.hour
                            comps.minute = override.minute
                            return comps
                        }
                    case .monthlyOrdinal(let patterns):
                        let weekday = calendar.component(.weekday, from: currentDate)
                        let day = calendar.component(.day, from: currentDate)
                        let ordinal: Int = {
                            let range = calendar.range(of: .day, in: .month, for: currentDate)!
                            let lastDayOfMonth = range.upperBound - 1
                            if patterns.contains(where: { $0.ordinal == -1 && $0.weekday == weekday }) {
                                for dayOffset in 0..<7 {
                                    let checkDay = lastDayOfMonth - dayOffset
                                    if checkDay < 1 { break }
                                    if let checkDate = calendar.date(bySetting: .day, value: checkDay, of: currentDate),
                                       calendar.component(.weekday, from: checkDate) == weekday {
                                        return day == checkDay ? -1 : ((day - 1) / 7 + 1)
                                    }
                                }
                            }
                            return (day - 1) / 7 + 1
                        }()
                        if let override = overridesByMonthOrdinalKey["\(ordinal)_\(weekday)"] {
                            var comps = DateComponents()
                            comps.hour = override.hour
                            comps.minute = override.minute
                            return comps
                        }
                    case .yearly:
                        if let override = recurrence.yearlyTimeOverride {
                            var comps = DateComponents()
                            comps.hour = override.hour
                            comps.minute = override.minute
                            return comps
                        }
                    case .daily:
                        break
                    }
                    return calendar.dateComponents([.hour, .minute], from: task.startTime)
                }()

                let dateComponents = calendar.dateComponents([.year, .month, .day], from: currentDate)
                var candidateComponents = DateComponents()
                candidateComponents.year = dateComponents.year
                candidateComponents.month = dateComponents.month
                candidateComponents.day = dateComponents.day
                candidateComponents.hour = timeComponents.hour
                candidateComponents.minute = timeComponents.minute

                if let occurrenceDate = calendar.date(from: candidateComponents) {
                    let offset = TimeInterval(task.notificationLeadTimeMinutes) * 60
                    let notificationDate = occurrenceDate.addingTimeInterval(-offset)

                    if notificationDate > Date() {
                        if identifiers.count >= perTaskBudget { break }

                        let identifier = "task_\(task.id.uuidString)_\(notificationDate.timeIntervalSince1970)"

                        let content = UNMutableNotificationContent()
                        // The task name is the title: it is the only bold line iOS shows.
                        content.title = task.name
                        content.body = "task_notification_title".localized
                        content.sound = .default
                        content.categoryIdentifier = TaskNotificationManager.taskReminderCategoryIdentifier
                        if let category = task.category {
                            content.subtitle = category.name
                        }

                        let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: notificationDate)
                        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)

                        let request = UNNotificationRequest(
                            identifier: identifier,
                            content: content,
                            trigger: trigger
                        )

                        do {
                            try await center.add(request)
                            identifiers.append(identifier)
                            print("✅ Scheduled recurring notification for task: \(task.name) at \(notificationDate) (lead \(task.notificationLeadTimeMinutes)m)")
                        } catch {
                            print("❌ Error scheduling recurring notification: \(error)")
                        }
                    }
                }
            }

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }

        return identifiers
    }

    func rescheduleRecurringNotificationsRollingWindow(tasks: [TodoTask]) async {
        let now = Date()
        if now.timeIntervalSince(Self.lastRollingRescheduleTime) < 30 {
            return
        }
        Self.lastRollingRescheduleTime = now

        let status = await refreshAuthorizationStatus()
        guard areTaskNotificationsEnabled, status == .authorized else {
            print("⚠️ Skip rolling reschedule | enabled=\(areTaskNotificationsEnabled) status=\(status.rawValue)")
            return
        }

        let eligibleTasks = tasks.filter { $0.hasNotification && $0.hasSpecificTime && $0.recurrence != nil }
        guard !eligibleTasks.isEmpty else { return }

        for task in eligibleTasks {
            await cancelAllNotificationsForTask(task.id)
        }

        let eligiblePrefixes = Set(eligibleTasks.map { "task_\($0.id.uuidString)" })
        let allPending = await center.pendingNotificationRequests()
        let nonEligiblePendingCount = allPending.filter { req in
            !eligiblePrefixes.contains(where: { req.identifier.hasPrefix($0) })
        }.count

        let remainingBudget = max(0, maxPendingNotificationsBudget - nonEligiblePendingCount)
        let fairPerTask = max(1, remainingBudget / eligibleTasks.count)
        let perTaskCap = min(maxRecurringNotificationsPerTask, fairPerTask)
        print("🧮 Rolling reschedule budget | eligible=\(eligibleTasks.count) otherPending=\(nonEligiblePendingCount) remaining=\(remainingBudget) perTask=\(perTaskCap)")

        for task in eligibleTasks {
            _ = await scheduleRecurringNotifications(for: task, maxCount: perTaskCap)
        }
    }
    
    func cancelNotification(withIdentifier identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        print("🗑️ Cancelled notification with identifier: \(identifier)")
    }
    
    func cancelNotifications(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        print("🗑️ Cancelled \(identifiers.count) notifications")
    }
    
    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        print("🗑️ Cancelled all pending and delivered notifications")
    }
    
    func cancelAllNotificationsForTask(_ taskId: UUID) async {
        let prefix = "task_\(taskId.uuidString)"

        let requests = await center.pendingNotificationRequests()
        let pendingTaskIdentifiers = requests
            .map { $0.identifier }
            .filter { $0.hasPrefix(prefix) }

        if !pendingTaskIdentifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: pendingTaskIdentifiers)
        }

        let delivered = await deliveredNotifications()
        let deliveredTaskIdentifiers = delivered
            .map { $0.request.identifier }
            .filter { $0.hasPrefix(prefix) }

        if !deliveredTaskIdentifiers.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: deliveredTaskIdentifiers)
        }

        if !pendingTaskIdentifiers.isEmpty || !deliveredTaskIdentifiers.isEmpty {
            print("🗑️ Cancelled \(pendingTaskIdentifiers.count) pending and \(deliveredTaskIdentifiers.count) delivered notifications for task: \(taskId)")
        }
    }

    private func deliveredNotifications() async -> [UNNotification] {
        await withCheckedContinuation { continuation in
            center.getDeliveredNotifications { notifications in
                continuation.resume(returning: notifications)
            }
        }
    }
    
    // MARK: - Settings Management
    
    private func loadNotificationSettings() {
        areTaskNotificationsEnabled = UserDefaults.standard.object(forKey: "masterTaskNotificationsEnabled") as? Bool ?? true
    }
    
    private func saveNotificationSettings() {
        UserDefaults.standard.set(areTaskNotificationsEnabled, forKey: "masterTaskNotificationsEnabled")
    }
    
    // MARK: - Utility Methods
    
    func getPendingNotificationsCount() async -> Int {
        let requests = await center.pendingNotificationRequests()
        return requests.filter { $0.identifier.contains("task_") }.count
    }
    
    func getScheduledNotifications() async -> [UNNotificationRequest] {
        let requests = await center.pendingNotificationRequests()
        return requests.filter { $0.identifier.contains("task_") }
    }

    func debugDumpPendingTaskNotifications(taskId: UUID? = nil) async {
        let requests = await center.pendingNotificationRequests()
        let filtered = requests.filter { req in
            guard req.identifier.hasPrefix("task_") else { return false }
            guard let taskId else { return true }
            return req.identifier.contains(taskId.uuidString)
        }

        let sorted = filtered.sorted { a, b in
            let da = (a.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? .distantFuture
            let db = (b.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? .distantFuture
            return da < db
        }

        print("🔎 Pending task notifications: \(sorted.count)")
        for req in sorted {
            let next = (req.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
            print("🔎 \(req.identifier) -> \(next?.description ?? "nil")")
        }
    }

    func debugDiagnoseScheduling(for task: TodoTask) async {
        let status = await refreshAuthorizationStatus()
        print("🧪 Diagnose scheduling | task=\(task.name) id=\(task.id)")
        print("🧪 enabled=\(areTaskNotificationsEnabled) status=\(status.rawValue) hasSpecificTime=\(task.hasSpecificTime) hasNotification=\(task.hasNotification) isRecurring=\(task.recurrence != nil)")
        print("🧪 startTime=\(task.startTime) leadMinutes=\(task.notificationLeadTimeMinutes)")

        let pending = await center.pendingNotificationRequests()
        let matching = pending.filter { $0.identifier.contains("task_\(task.id.uuidString)") }
        print("🧪 pendingTotal=\(pending.count) pendingForTask=\(matching.count)")
    }
    
    func scheduleCustomSnoozeNotification(for task: TodoTask, at fireDate: Date) async {
        let content = UNMutableNotificationContent()
        // The task name is the title: it is the only bold line iOS shows.
        content.title = task.name
        content.body = "task_notification_title".localized
        content.sound = .default
        content.categoryIdentifier = TaskNotificationManager.taskReminderCategoryIdentifier
        if let category = task.category {
            content.subtitle = category.name
        }
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let identifier = "task_\(task.id.uuidString)_\(Int(fireDate.timeIntervalSince1970))"
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        do {
            try await center.add(request)
            print("⏰ Snoozed notification scheduled for task '\(task.name)' at \(fireDate)")
        } catch {
            print("❌ Failed to schedule snoozed notification: \(error)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension TaskNotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if FeedbackReplyNotifier.isFeedbackReply(notification.request.content.userInfo) {
            FeedbackReplyNotifier.handleWillPresent(userInfo: notification.request.content.userInfo)
            completionHandler([.banner, .list, .sound])
            return
        }
        if notification.request.identifier == "dailyQuote" || notification.request.identifier.hasPrefix("dailyQuote_") {
            completionHandler([.banner, .sound])
            return
        }
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        let actionIdentifier = response.actionIdentifier
        
        // completionHandler MUST be called synchronously - async work continues independently
        defer { completionHandler() }
        
        let userInfo = response.notification.request.content.userInfo
        if FeedbackReplyNotifier.isFeedbackReply(userInfo) {
            if actionIdentifier == UNNotificationDefaultActionIdentifier {
                FeedbackReplyNotifier.handleTap(userInfo: userInfo)
            }
            return
        }
        
        // identifier format: "task_<UUID>" or "task_<UUID>_<timestamp>"
        // Extract the UUID portion (always at index 1 when split by "_", but UUID itself has hyphens not underscores)
        guard identifier.hasPrefix("task_") else { return }
        
        // Drop the leading "task_" prefix, then take up to the first underscore that follows the UUID (36 chars)
        let withoutPrefix = String(identifier.dropFirst("task_".count))
        // A UUID string is always 36 characters
        let uuidString = String(withoutPrefix.prefix(36))
        guard let taskId = UUID(uuidString: uuidString) else { return }
        
        // Only handle our custom actions here; default tap opens the task
        guard actionIdentifier != UNNotificationDefaultActionIdentifier else {
            NotificationCenter.default.post(name: .openTaskFromNotification, object: taskId)
            return
        }
        guard actionIdentifier != UNNotificationDismissActionIdentifier else { return }
        
        Task { @MainActor in
            switch actionIdentifier {
            case TaskNotificationManager.actionMarkCompletedIdentifier:
                _ = TaskManager.shared.toggleTaskCompletion(taskId, on: Date())
                NotificationCenter.default.post(name: Notification.Name("tasksDidUpdate"), object: nil)
                print("✅ Task marked completed via notification action: \(taskId)")
                
            case TaskNotificationManager.actionSnooze1HIdentifier:
                if var task = TaskManager.shared.tasks.first(where: { $0.id == taskId }) {
                    let snoozeDate = Date().addingTimeInterval(3600)
                    await self.scheduleCustomSnoozeNotification(for: task, at: snoozeDate)
                    if var recurrence = task.recurrence {
                        recurrence.postponeOccurrence(from: Date(), to: snoozeDate)
                        task.recurrence = recurrence
                    } else {
                        task.startTime = snoozeDate
                    }
                    await TaskManager.shared.updateTask(task)
                    NotificationCenter.default.post(name: Notification.Name("tasksDidUpdate"), object: nil)
                    print("⏰ Task snoozed for 1 hour via notification action: \(task.name)")
                }
                
            case TaskNotificationManager.actionSnoozeTomorrowIdentifier:
                if var task = TaskManager.shared.tasks.first(where: { $0.id == taskId }) {
                    let calendar = Calendar.current
                    if let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()),
                       let tomorrow9AM = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) {
                        await self.scheduleCustomSnoozeNotification(for: task, at: tomorrow9AM)
                        if var recurrence = task.recurrence {
                            recurrence.postponeOccurrence(from: Date(), to: tomorrow9AM)
                            task.recurrence = recurrence
                        } else {
                            task.startTime = tomorrow9AM
                        }
                        await TaskManager.shared.updateTask(task)
                        NotificationCenter.default.post(name: Notification.Name("tasksDidUpdate"), object: nil)
                        print("☀️ Task postponed to tomorrow 9 AM via notification action: \(task.name)")
                    }
                }
                
            default:
                break
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openTaskFromNotification = Notification.Name("openTaskFromNotification")
    static let openJournalFromNotification = Notification.Name("openJournalFromNotification")
}