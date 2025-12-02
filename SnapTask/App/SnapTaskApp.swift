import SwiftUI
import CloudKit
import UserNotifications
import Firebase
import BackgroundTasks

@main
struct SnapTaskApp: App {
    @StateObject private var quoteManager = QuoteManager.shared
    @StateObject private var taskManager = TaskManager.shared
    @StateObject private var taskNotificationManager = TaskNotificationManager.shared
    @StateObject private var cloudKitService = CloudKitService.shared
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var settingsManager = CloudKitSettingsManager.shared
    @StateObject private var moodManager = MoodManager.shared // Add mood manager initialization
    @Environment(\.scenePhase) var scenePhase
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Initialize Firebase as early as possible
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("🔥 Firebase configured in app init")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(
                    // Solo i temi premium sovrascrivono la dark mode
                    ThemeManager.shared.currentTheme.overridesSystemColors ? 
                    (ThemeManager.shared.isDarkTheme ? .dark : .light) : 
                    (isDarkMode ? .dark : .light)
                )
                .onAppear {
                    setupNotifications()
                    Task {
                        await quoteManager.checkAndUpdateQuote()
                    }
                    
                    registerForRemoteNotifications()
                    
                    initializeAppData()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
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
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Set up notification center delegate
        UNUserNotificationCenter.current().delegate = self
        
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
        } else {
            completionHandler([.alert, .sound])
        }
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let identifier = response.notification.request.identifier
        
        if identifier == "dailyQuote" || identifier.hasPrefix("dailyQuote_") {
            // User tapped daily quote notification
            Task {
                await QuoteManager.shared.forceUpdateQuote()
            }
        } else if identifier.hasPrefix("pomodoro-") {
            // User tapped Pomodoro notification - open the app to the Focus tab
            print("📱 Pomodoro notification tapped: \(identifier)")
            // You could implement navigation to Focus tab here
        } else if identifier.hasPrefix("task_") {
            // User tapped task notification - extract task ID and open task details
            let components = identifier.components(separatedBy: "_")
            if components.count >= 2,
               let taskId = UUID(uuidString: components[1]) {
                
                print("📱 Task notification tapped for task: \(taskId)")
                
                // Post notification to open task details
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .openTaskFromNotification,
                        object: taskId
                    )
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

// MARK: - Notification Names

extension Notification.Name {
    static let openTaskDetail = Notification.Name("openTaskDetail")
}