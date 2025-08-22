import Foundation
import UserNotifications
import Combine

class TaskNotificationManager: NSObject, ObservableObject {
    static let shared = TaskNotificationManager()
    
    @Published var areNotificationsEnabled = false
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
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await MainActor.run {
                self.authorizationStatus = granted ? .authorized : .denied
                self.areNotificationsEnabled = granted
                self.saveNotificationSettings()
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
                self.areNotificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Notification Management
    
    func scheduleNotification(for task: TodoTask) async -> String? {
        guard areNotificationsEnabled,
              task.hasSpecificTime,
              task.hasNotification else {
            return nil
        }
        
        // Check if notification is in the future
        guard task.startTime > Date() else {
            return nil
        }
        
        let identifier = "task_\(task.id.uuidString)"
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "task_notification_title".localized
        content.body = String(format: "task_notification_body".localized, task.name)
        content.sound = .default
        content.badge = 1
        
        // Add category for context
        if let category = task.category {
            content.subtitle = category.name
        }
        
        // Create trigger for specific time
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: task.startTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        // Create request
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            print("✅ Scheduled notification for task: \(task.name) at \(task.startTime)")
            return identifier
        } catch {
            print("❌ Error scheduling notification: \(error)")
            return nil
        }
    }
    
    func scheduleRecurringNotifications(for task: TodoTask) async -> [String] {
        guard areNotificationsEnabled,
              task.hasSpecificTime,
              task.hasNotification,
              let recurrence = task.recurrence else {
            return []
        }
        
        var identifiers: [String] = []
        let calendar = Calendar.current
        let today = Date()
        
        // Schedule notifications for the next 30 days (or until end date)
        let endDate = recurrence.endDate ?? calendar.date(byAdding: .day, value: 30, to: today) ?? today
        var currentDate = today
        
        while currentDate <= endDate {
            if recurrence.shouldOccurOn(date: currentDate) {
                // Calculate notification time for this occurrence
                let timeComponents = calendar.dateComponents([.hour, .minute], from: task.startTime)
                let dateComponents = calendar.dateComponents([.year, .month, .day], from: currentDate)
                
                var notificationComponents = DateComponents()
                notificationComponents.year = dateComponents.year
                notificationComponents.month = dateComponents.month
                notificationComponents.day = dateComponents.day
                notificationComponents.hour = timeComponents.hour
                notificationComponents.minute = timeComponents.minute
                
                if let notificationDate = calendar.date(from: notificationComponents),
                   notificationDate > Date() {
                    
                    let identifier = "task_\(task.id.uuidString)_\(currentDate.timeIntervalSince1970)"
                    
                    // Create notification content
                    let content = UNMutableNotificationContent()
                    content.title = "task_notification_title".localized
                    content.body = String(format: "task_notification_body".localized, task.name)
                    content.sound = .default
                    content.badge = 1
                    
                    if let category = task.category {
                        content.subtitle = category.name
                    }
                    
                    // Create trigger
                    let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: notificationDate)
                    let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
                    
                    // Create request
                    let request = UNNotificationRequest(
                        identifier: identifier,
                        content: content,
                        trigger: trigger
                    )
                    
                    do {
                        try await center.add(request)
                        identifiers.append(identifier)
                        print("✅ Scheduled recurring notification for task: \(task.name) at \(notificationDate)")
                    } catch {
                        print("❌ Error scheduling recurring notification: \(error)")
                    }
                }
            }
            
            // Move to next day
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
        areNotificationsEnabled = UserDefaults.standard.bool(forKey: "taskNotificationsEnabled")
    }
    
    private func saveNotificationSettings() {
        UserDefaults.standard.set(areNotificationsEnabled, forKey: "taskNotificationsEnabled")
    }
    
    func toggleNotifications() {
        areNotificationsEnabled.toggle()
        saveNotificationSettings()
        
        if !areNotificationsEnabled {
            // Cancel all pending notifications
            center.removeAllPendingNotificationRequests()
        }
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
        if notification.request.identifier == "dailyQuote" {
            completionHandler([.banner, .sound])
            return
        }
        // Show notification even when app is in foreground
        completionHandler([.banner, .badge, .sound])
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