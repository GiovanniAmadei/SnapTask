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
    
    override init() {
        super.init()
        center.delegate = self
        checkAuthorizationStatus()
        loadNotificationSettings()
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
                print("🗑️ Cancelled \(taskNotificationIdentifiers.count) task notifications")
            }
        }
    }
    
    // MARK: - Notification Management
    
    func scheduleNotification(for task: TodoTask) async -> String? {
        guard areTaskNotificationsEnabled,
              authorizationStatus == .authorized,
              task.hasSpecificTime,
              task.hasNotification else {
            return nil
        }
        
        let lead = TimeInterval(max(0, task.notificationLeadTimeMinutes) * 60)
        let fireDate = task.startTime.addingTimeInterval(-lead)
        
        guard fireDate > Date() else {
            return nil
        }
        
        let identifier = "task_\(task.id.uuidString)"
        
        let content = UNMutableNotificationContent()
        content.title = "task_notification_title".localized
        content.body = String(format: "task_notification_body".localized, task.name)
        content.sound = .default
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
        guard areTaskNotificationsEnabled,
              authorizationStatus == .authorized,
              task.hasSpecificTime,
              task.hasNotification,
              let recurrence = task.recurrence else {
            return []
        }
        
        var identifiers: [String] = []
        let calendar = Calendar.current
        let today = Date()

        let pendingNow = await center.pendingNotificationRequests()
        let remainingBudget = max(0, maxPendingNotificationsBudget - pendingNow.count)
        let perTaskBudget = min(maxRecurringNotificationsPerTask, remainingBudget)
        if perTaskBudget <= 0 {
            return []
        }

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
            if identifiers.count >= perTaskBudget {
                break
            }
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
                    let lead = TimeInterval(max(0, task.notificationLeadTimeMinutes) * 60)
                    let notificationDate = occurrenceDate.addingTimeInterval(-lead)
                    
                    if notificationDate > Date() {
                        if identifiers.count >= perTaskBudget {
                            break
                        }
                        let identifier = "task_\(task.id.uuidString)_\(notificationDate.timeIntervalSince1970)"
                        
                        let content = UNMutableNotificationContent()
                        content.title = "task_notification_title".localized
                        content.body = String(format: "task_notification_body".localized, task.name)
                        content.sound = .default
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

        guard areTaskNotificationsEnabled, authorizationStatus == .authorized else { return }

        for task in tasks {
            guard task.hasNotification, task.hasSpecificTime, task.recurrence != nil else { continue }
            cancelAllNotificationsForTask(task.id)
            _ = await scheduleRecurringNotifications(for: task)
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
    
    func cancelAllNotificationsForTask(_ taskId: UUID) {
        center.getPendingNotificationRequests { requests in
            let taskIdentifiers = requests
                .filter { $0.identifier.contains("task_\(taskId.uuidString)") }
                .map { $0.identifier }
            
            if !taskIdentifiers.isEmpty {
                self.center.removePendingNotificationRequests(withIdentifiers: taskIdentifiers)
                print("🗑️ Cancelled \(taskIdentifiers.count) notifications for task: \(taskId)")
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
}

// MARK: - UNUserNotificationCenterDelegate

extension TaskNotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
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
        
        // Extract task ID from notification identifier
        if identifier.hasPrefix("task_") {
            let components = identifier.components(separatedBy: "_")
            if components.count >= 2,
               let taskId = UUID(uuidString: components[1]) {
                
                // Post notification to open task details
                NotificationCenter.default.post(
                    name: .openTaskFromNotification,
                    object: taskId
                )
            }
        }
        
        completionHandler()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openTaskFromNotification = Notification.Name("openTaskFromNotification")
    static let openJournalFromNotification = Notification.Name("openJournalFromNotification")
}