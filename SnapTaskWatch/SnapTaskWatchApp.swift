import SwiftUI
import WatchConnectivity

@main
struct SnapTaskWatchApp: App {
    @StateObject private var syncManager = WatchSyncManager.shared
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchTaskListView()
            }
                .environmentObject(syncManager)
        }
    }
}
