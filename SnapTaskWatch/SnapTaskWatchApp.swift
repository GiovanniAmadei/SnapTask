import SwiftUI
import WatchConnectivity
import WatchKit

@main
struct SnapTaskWatchApp: App {
    @StateObject private var syncManager = WatchSyncManager.shared
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(syncManager)
                .tint(.orange)
        }
    }
}
