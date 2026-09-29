import Foundation
import WatchKit

final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    private let refreshIdentifier = "com.snaptask.watch.background-refresh"

    func applicationDidFinishLaunching() {
        scheduleBackgroundRefresh()
    }

    func applicationDidBecomeActive() {
        WatchTimerEngine.shared.restorePersistedStateIfNeeded()
        Task {
            await WatchSyncManager.shared.syncNow()
        }
        scheduleBackgroundRefresh()
    }

    func applicationWillResignActive() {
        scheduleBackgroundRefresh()
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            switch task {
            case let appRefreshTask as WKApplicationRefreshBackgroundTask:
                Task {
                    await handleAppRefresh(task: appRefreshTask)
                }
            default:
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }

    private func handleAppRefresh(task: WKApplicationRefreshBackgroundTask) async {
        defer {
            task.setTaskCompletedWithSnapshot(false)
            scheduleBackgroundRefresh()
        }

        await WatchSyncManager.shared.syncNow()
        await WatchTaskNotificationManager.shared.resyncCachedNotifications()
    }

    private func scheduleBackgroundRefresh() {
        let preferredDate = Date(timeIntervalSinceNow: 30 * 60)

        WKExtension.shared().scheduleBackgroundRefresh(
            withPreferredDate: preferredDate,
            userInfo: nil,
            scheduledCompletion: { error in
                if let error {
                    print("⌚️ Failed to schedule background refresh: \(error)")
                } else {
                    print("⌚️ Scheduled background refresh for \(preferredDate)")
                }
            }
        )
    }
}
