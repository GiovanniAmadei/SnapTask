import SwiftUI

struct ContentView: View {
    @EnvironmentObject var syncManager: WatchSyncManager
    @State private var isSyncing = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        performSync()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: syncManager.syncStatus.icon)
                                .foregroundColor(syncStatusColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(syncManager.syncStatus.description)
                                    .font(.caption)
                                Text(syncManager.isPhoneReachable ? "iPhone" : "CloudKit")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if isSyncing || syncManager.syncStatus == .syncing {
                                ProgressView()
                                    .scaleEffect(0.75)
                            }
                        }
                    }
                    .disabled(isSyncing || syncManager.syncStatus == .syncing)
                }
                
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
    
    private var syncStatusColor: Color {
        switch syncManager.syncStatus {
        case .idle: return .gray
        case .syncing: return .accentColor
        case .success: return .green
        case .error: return .red
        }
    }
    
    private var todayTasksCount: Int {
        let calendar = Calendar.current
        let today = Date()
        return syncManager.tasks.filter { task in
            if let recurrence = task.recurrence {
                return recurrence.shouldOccurOn(date: today)
            } else {
                return task.timeScope != .inbox && calendar.isDate(task.startTime, inSameDayAs: today)
            }
        }.count
    }
    
    private func performSync() {
        isSyncing = true
        Task {
            await syncManager.forceSync()
            await MainActor.run {
                isSyncing = false
                HapticService.shared.play(.notification)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchSyncManager.shared)
}
