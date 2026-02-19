import SwiftUI

struct ContentView: View {
    @EnvironmentObject var syncManager: WatchSyncManager
    
    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    WatchTaskListView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tasks")
                                .font(.system(.body, design: .rounded, weight: .medium))
                            Text("\(todayTasksCount) today")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "checklist")
                            .foregroundColor(.accentColor)
                    }
                }
                
                NavigationLink {
                    WatchTimerSelectionView()
                } label: {
                    Label {
                        Text("Timer")
                            .font(.system(.body, design: .rounded, weight: .medium))
                    } icon: {
                        Image(systemName: "timer")
                            .foregroundColor(.orange)
                    }
                }
                
                NavigationLink {
                    WatchRewardsListView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Rewards")
                                .font(.system(.body, design: .rounded, weight: .medium))
                            Text("\(syncManager.totalPoints) pts")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "gift.fill")
                            .foregroundColor(.yellow)
                    }
                }
                
                NavigationLink {
                    WatchStatisticsView()
                } label: {
                    Label {
                        Text("Statistics")
                            .font(.system(.body, design: .rounded, weight: .medium))
                    } icon: {
                        Image(systemName: "chart.pie.fill")
                            .foregroundColor(.green)
                    }
                }
                
                NavigationLink {
                    WatchSettingsView()
                } label: {
                    Label {
                        Text("Settings")
                            .font(.system(.body, design: .rounded, weight: .medium))
                    } icon: {
                        Image(systemName: "gear")
                            .foregroundColor(.gray)
                    }
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
