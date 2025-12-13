import SwiftUI

struct ContentView: View {
    @EnvironmentObject var syncManager: WatchSyncManager
    
    var body: some View {
        NavigationStack {
            List {
                // Tasks Section - Main feature
                NavigationLink {
                    WatchTaskListView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tasks")
                                .font(.headline)
                            Text("\(todayTasksCount) today")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "checklist")
                            .foregroundColor(.blue)
                    }
                }
                
                // Timer
                NavigationLink {
                    WatchTimerSelectionView()
                } label: {
                    Label("Timer", systemImage: "timer")
                        .foregroundColor(.orange)
                }
                
                // Rewards
                NavigationLink {
                    WatchRewardsListView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Rewards")
                            Text("\(syncManager.totalPoints) pts")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                        }
                    } icon: {
                        Image(systemName: "gift.fill")
                            .foregroundColor(.purple)
                    }
                }
                
                // Stats
                NavigationLink {
                    WatchStatisticsView()
                } label: {
                    Label("Statistics", systemImage: "chart.pie.fill")
                        .foregroundColor(.green)
                }
                
                // Settings
                NavigationLink {
                    WatchSettingsView()
                } label: {
                    Label("Settings", systemImage: "gear")
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("SnapTask")
        }
    }
    
    private var todayTasksCount: Int {
        let calendar = Calendar.current
        let today = Date()
        return syncManager.tasks.filter { task in
            if let recurrence = task.recurrence {
                return recurrence.shouldOccurOn(date: today)
            } else {
                return calendar.isDate(task.startTime, inSameDayAs: today)
            }
        }.count
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchSyncManager.shared)
}
