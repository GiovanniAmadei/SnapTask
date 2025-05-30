import SwiftUI
import WatchConnectivity
import CloudKit
import UserNotifications
import Firebase

@main
struct SnapTaskApp: App {
    @StateObject private var quoteManager = QuoteManager.shared
    @StateObject private var taskManager = TaskManager.shared
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    @StateObject private var cloudKitService = CloudKitService.shared
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var settingsManager = CloudKitSettingsManager.shared
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
                .preferredColorScheme(isDarkMode ? .dark : .light)
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
                        connectivityManager.updateWatchContext()
                        
                        // Sync settings when app becomes active
                        if cloudKitService.isCloudKitEnabled {
                            settingsManager.syncSettings()
                        }
                    }
                }
        }
    }
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().delegate = appDelegate
    }
    
    private func initializeAppData() {
        // Ensure categories exist before starting sync
        let categoryManager = CategoryManager.shared
        print("📱 App initialized with \(categoryManager.categories.count) categories")
        
        // Start CloudKit sync
        cloudKitService.syncNow()
        taskManager.startRegularSync()
        connectivityManager.updateWatchContext()
        
        // Initialize settings sync
        if cloudKitService.isCloudKitEnabled {
            settingsManager.syncSettings()
        }
    }
    
    func registerForRemoteNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
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
        
        // Backup Firebase configuration
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("🔥 Firebase configured in AppDelegate")
        }
        return true
    }
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .badge, .sound])
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.notification.request.identifier == "dailyQuote" {
            // User tapped daily quote notification
            Task {
                await QuoteManager.shared.forceUpdateQuote()
            }
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
