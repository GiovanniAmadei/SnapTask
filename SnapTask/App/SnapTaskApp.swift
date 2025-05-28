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
    // @StateObject private var cloudKitService = CloudKitService.shared
    @StateObject private var firebaseService = FirebaseService.shared
    @Environment(\.scenePhase) var scenePhase
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    init() {
        // Inizializza Firebase il prima possibile
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
                    Task {
                        await quoteManager.checkAndUpdateQuote()
                    }
                    
                    registerForRemoteNotifications()
                    // cloudKitService.syncInBackground()
                    // taskManager.startRegularSync()
                    connectivityManager.updateWatchContext()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task {
                            await quoteManager.checkAndUpdateQuote()
                        }
                        // cloudKitService.syncInBackground()
                        connectivityManager.updateWatchContext()
                    }
                }
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
        // COMMENTIAMO TEMPORANEAMENTE CLOUDKIT
        // CloudKitSyncProxy.shared.setupCloudKit()
        // CloudKitSyncProxy.shared.syncTasks()
    }
}

// MARK: - UIApplicationDelegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Backup Firebase configuration
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("🔥 Firebase configured in AppDelegate")
        }
        return true
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if let cloudKitDict = userInfo as? [String: NSObject],
           let cloudKitNotification = CKNotification(fromRemoteNotificationDictionary: cloudKitDict) {
            if cloudKitNotification.subscriptionID == "SnapTaskZone" {
                // COMMENTIAMO TEMPORANEAMENTE CLOUDKIT
                // CloudKitSyncProxy.shared.syncTasks()
                completionHandler(.newData)
                return
            }
        }
        completionHandler(.noData)
    }
}
