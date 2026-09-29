import SwiftUI
import CloudKit
import UserNotifications
import Firebase
import BackgroundTasks
import WatchConnectivity
import AppIntents

@main
struct SnapTaskApp: App {
    @StateObject private var quoteManager = QuoteManager.shared
    @StateObject private var taskManager = TaskManager.shared
    @StateObject private var taskNotificationManager = TaskNotificationManager.shared
    @StateObject private var cloudKitService = CloudKitService.shared
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var settingsManager = CloudKitSettingsManager.shared
    @StateObject private var moodManager = MoodManager.shared // Add mood manager initialization
    @StateObject private var watchConnectivityHandler = WatchConnectivityHandler.shared
    @StateObject private var confettiManager = ConfettiManager.shared
    @Environment(\.scenePhase) var scenePhase
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    /// Computed color scheme based on appearanceMode setting
    private var computedColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil // "system" - follows device setting
        }
    }
    
    init() {
        // Initialize Firebase as early as possible
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("🔥 Firebase configured in app init")
        }

        SnapTaskAppShortcuts.updateAppShortcutParameters()
        
        // Initialize Watch Connectivity
        _ = WatchConnectivityHandler.shared
        print("⌚ Watch Connectivity initialized")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .overlay(
                    Group {
                        if confettiManager.triggerCounter > 0 {
                            ConfettiView()
                                .id(confettiManager.triggerCounter)
                        }
                    }
                )
                .preferredColorScheme(
                    // Solo i temi premium sovrascrivono la dark mode
                    ThemeManager.shared.currentTheme.overridesSystemColors ? 
                    (ThemeManager.shared.isDarkTheme ? .dark : .light) : 
                    computedColorScheme
                )
                .onAppear {
                    setupNotifications()
                    Task {
                        await quoteManager.checkAndUpdateQuote()
                    }
                    
                    registerForRemoteNotifications()
                    
                    initializeAppData()
                }
                .onOpenURL { url in
                    // Deep links used by the Control Center / Action Button
                    // "Quick Add Task" control (`OpenQuickAddIntent`).
                    // URL format: snaptask://quickadd
                    handleDeepLink(url)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        SnapTaskAppShortcuts.updateAppShortcutParameters()
                        Task {
                            await quoteManager.checkAndUpdateQuote()
                        }
                        cloudKitService.syncNow()
                        
                        // Sync settings when app becomes active
                        if cloudKitService.isCloudKitEnabled {
                            settingsManager.syncSettings()
                        }

                        // Reload tasks from App Group if modified by the widget
                        TaskManager.shared.reloadFromSharedIfAvailable()
                        
                        // Sync data to Watch
                        watchConnectivityHandler.sendFullSyncToWatch()

                        Task {
                            taskNotificationManager.checkAuthorizationStatus()
                            await taskNotificationManager.cleanupOrphanedTaskNotifications(
                                validTaskIds: Set(taskManager.tasks.map { $0.id })
                            )
                            await taskNotificationManager.rescheduleRecurringNotificationsRollingWindow(tasks: taskManager.tasks)
                        }
                        
                        requestBackgroundAppRefresh()
                        UIApplication.shared.applicationIconBadgeNumber = 0
                    }
                    else if newPhase == .background {
                        scheduleBackgroundAppRefresh()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .openTaskFromNotification)) { notification in
                    if let taskId = notification.object as? UUID {
                        // Handle opening task from notification
                        NotificationCenter.default.post(
                            name: .openTaskDetail,
                            object: taskId
                        )
                    }
                }
        }
    }
    
    /// Handles `snaptask://` deep links. Currently supports:
    /// - `snaptask://quickadd` → switch to Timeline + show new-task sheet.
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "snaptask" else { return }
        switch url.host {
        case "quickadd":
            // Persist the flag so it survives across cold/warm start.
            if let suite = UserDefaults(suiteName: "group.com.snapTask.shared") {
                suite.set(Date().timeIntervalSince1970, forKey: "pendingQuickAddOpen")
                suite.synchronize()
            }
            // Also set the in-memory flag so TimelineView.onAppear can
            // pick it up even if the notification fires too early.
            Task { @MainActor in
                QuickAddTrigger.pending = true
            }
            // Give the view hierarchy time to mount on cold start before
            // posting the notification.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                NotificationCenter.default.post(name: .checkPendingQuickAdd, object: nil)
            }
        default:
            break
        }
    }
    
    private func requestBackgroundAppRefresh() {
        Task {
            let status = await UIApplication.shared.backgroundRefreshStatus
            if status == .denied {
                print("⚠️ Background App Refresh is disabled. Timer accuracy may be affected.")
            } else if status == .available {
                print("✅ Background App Refresh is available")
            }
        }
    }
    
    private func scheduleBackgroundAppRefresh() {
        // This will help maintain timer accuracy when the app is backgrounded
        let identifier = "com.snaptask.timer-update"
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30) // 30 seconds from now
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("⏰ Background refresh scheduled for timer continuity")
        } catch {
            print("❌ Could not schedule background refresh: \(error)")
        }
    }
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().delegate = appDelegate
        
        // Request notification permissions for timer notifications
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("✅ Notification permissions granted")
            } else {
                print("❌ Notification permissions denied: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    private func initializeAppData() {
        // Ensure categories exist before starting sync
        let categoryManager = CategoryManager.shared
        print("📱 App initialized with \(categoryManager.categories.count) categories")
        
        // Start CloudKit sync
        cloudKitService.syncNow()
        taskManager.startRegularSync()
        
        // Initialize settings sync
        if cloudKitService.isCloudKitEnabled {
            settingsManager.syncSettings()
        }
    }
    
    func registerForRemoteNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    func initializeCloudKit() throws {
        CloudKitService.shared.syncNow()
    }
}

// MARK: - UIApplicationDelegate
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private static let pendingJournalDateKey = "pendingJournalDateFromNotification"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Set up notification center delegate
        UNUserNotificationCenter.current().delegate = self

        UserDefaults.standard.removeObject(forKey: Self.pendingJournalDateKey)
        
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.snaptask.timer-update", using: nil) { task in
            self.handleBackgroundTimerUpdate(task: task as! BGAppRefreshTask)
        }
        
        // Backup Firebase configuration
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("🔥 Firebase configured in AppDelegate")
        }
        return true
    }
    
    private func handleBackgroundTimerUpdate(task: BGAppRefreshTask) {
        // Schedule next background refresh
        let identifier = "com.snaptask.timer-update"
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30)
        
        try? BGTaskScheduler.shared.submit(request)
        
        // Mark task as completed
        task.setTaskCompleted(success: true)
    }
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show all notifications even when app is in foreground
        if notification.request.identifier.hasPrefix("pomodoro-") {
            completionHandler([.banner, .sound])
        } else if notification.request.identifier.hasPrefix("task_") {
            completionHandler([.banner, .sound])
        } else if notification.request.identifier == "dailyQuote" || notification.request.identifier.hasPrefix("dailyQuote_") {
            completionHandler([.banner, .sound])
        } else if notification.request.identifier.hasPrefix("diary_") {
            completionHandler([.banner, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let identifier = response.notification.request.identifier
        let actionIdentifier = response.actionIdentifier
        
        if identifier == "dailyQuote" || identifier.hasPrefix("dailyQuote_") {
            Task {
                await QuoteManager.shared.forceUpdateQuote()
            }
        } else if identifier.hasPrefix("pomodoro-") {
            print("📱 Pomodoro notification tapped: \(identifier)")
        } else if identifier.hasPrefix("task_") {
            // Extract UUID: identifier is "task_<36-char-UUID>" or "task_<36-char-UUID>_<timestamp>"
            let withoutPrefix = String(identifier.dropFirst("task_".count))
            let uuidString = String(withoutPrefix.prefix(36))
            
            if let taskId = UUID(uuidString: uuidString) {
                switch actionIdentifier {
                case TaskNotificationManager.actionMarkCompletedIdentifier:
                    Task { @MainActor in
                        _ = TaskManager.shared.toggleTaskCompletion(taskId, on: Date())
                        NotificationCenter.default.post(name: Notification.Name("tasksDidUpdate"), object: nil)
                        print("✅ Task marked completed via notification: \(taskId)")
                    }
                    
                case TaskNotificationManager.actionSnooze1HIdentifier:
                    Task { @MainActor in
                        let taskMgr = TaskManager.shared
                        // Load tasks if not yet loaded
                        if taskMgr.tasks.isEmpty {
                            try? await Task.sleep(nanoseconds: 500_000_000)
                        }
                        if var task = taskMgr.tasks.first(where: { $0.id == taskId }) {
                            let snoozeDate = Date().addingTimeInterval(3600)
                            if var recurrence = task.recurrence {
                                recurrence.postponeOccurrence(from: Date(), to: snoozeDate)
                                task.recurrence = recurrence
                            } else {
                                task.startTime = snoozeDate
                            }
                            await taskMgr.updateTask(task)
                            await TaskNotificationManager.shared.scheduleNotification(for: task)
                            NotificationCenter.default.post(name: Notification.Name("tasksDidUpdate"), object: nil)
                            print("⏰ Task snoozed 1h via notification: \(task.name)")
                        }
                    }
                    
                case TaskNotificationManager.actionSnoozeTomorrowIdentifier:
                    Task { @MainActor in
                        let taskMgr = TaskManager.shared
                        if taskMgr.tasks.isEmpty {
                            try? await Task.sleep(nanoseconds: 500_000_000)
                        }
                        if var task = taskMgr.tasks.first(where: { $0.id == taskId }) {
                            let calendar = Calendar.current
                            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()),
                               let tomorrow9AM = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) {
                                if var recurrence = task.recurrence {
                                    recurrence.postponeOccurrence(from: Date(), to: tomorrow9AM)
                                    task.recurrence = recurrence
                                } else {
                                    task.startTime = tomorrow9AM
                                }
                                await taskMgr.updateTask(task)
                                await TaskNotificationManager.shared.scheduleNotification(for: task)
                                NotificationCenter.default.post(name: Notification.Name("tasksDidUpdate"), object: nil)
                                print("☀️ Task postponed to tomorrow 9AM via notification: \(task.name)")
                            }
                        }
                    }
                    
                default:
                    // Default tap: open task details
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .openTaskFromNotification, object: taskId)
                    }
                }
            }
        } else if identifier.hasPrefix("diary_") {
            let components = identifier.components(separatedBy: "_")
            if components.count >= 2 {
                let dateString = components[1]
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                if let date = formatter.date(from: dateString) {
                    if UIApplication.shared.applicationState != .active {
                        UserDefaults.standard.set(dateString, forKey: Self.pendingJournalDateKey)
                    }
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .openJournalFromNotification, object: date)
                    }
                }
            }
        }

        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }

        completionHandler()
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Handle CloudKit notifications
        CloudKitService.shared.processRemoteNotification(userInfo)
        
        if let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) {
            if notification.subscriptionID == "SnapTaskZone-changes" {
                print("📱 Received CloudKit sync notification")
                completionHandler(.newData)
                return
            }
        }
        
        completionHandler(.noData)
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("📱 Successfully registered for remote notifications")
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error)")
    }
}

// MARK: - Quick Add Trigger

/// In-memory flag consumed by `TimelineView` to present the new-task sheet.
/// This survives the cold-start race where notifications might fire before
/// subscriber views have mounted.
enum QuickAddTrigger {
    @MainActor static var pending = false
}

// MARK: - Notification Names

extension Notification.Name {
    static let openTaskDetail = Notification.Name("openTaskDetail")
    /// Posted when the app is opened via the Control Center / Action Button
    /// "Quick Add Task" control and should immediately present the new-task sheet.
    static let openQuickAdd = Notification.Name("openQuickAdd")
    /// Posted from `SnapTaskApp.onOpenURL` to ask `ContentView` to re-run
    /// `checkPendingQuickAdd()` when the app receives a `snaptask://quickadd`
    /// deep link while it's already in foreground.
    static let checkPendingQuickAdd = Notification.Name("checkPendingQuickAdd")
}