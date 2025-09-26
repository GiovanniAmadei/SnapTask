import Foundation
import UserNotifications
import Combine

class TaskNotificationManager: NSObject, ObservableObject {
    static let shared = TaskNotificationManager()
    
    @Published var areTaskNotificationsEnabled = true
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    private let center = UNUserNotificationCenter.current()
    
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
        
        let endDate = recurrence.endDate ?? calendar.date(byAdding: .day, value: 30, to: today) ?? today
        var currentDate = today
        
        while currentDate <= endDate {
            if recurrence.shouldOccurOn(date: currentDate) {
                let timeComponents = calendar.dateComponents([.hour, .minute], from: task.startTime)
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
}