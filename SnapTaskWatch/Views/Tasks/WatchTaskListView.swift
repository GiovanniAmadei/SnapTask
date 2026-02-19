import SwiftUI

struct WatchTaskListView: View {
    @EnvironmentObject var syncManager: WatchSyncManager
    @State private var showingAddTask = false
    @State private var showingMenu = false
    @State private var selectedDate = Date()
    
    private var todaysTasks: [TodoTask] {
        let calendar = Calendar.current
        
        return syncManager.tasks.filter { task in
            if let recurrence = task.recurrence {
                return recurrence.shouldOccurOn(date: selectedDate)
            } else {
                return calendar.isDate(task.startTime, inSameDayAs: selectedDate)
            }
        }.sorted { $0.startTime < $1.startTime }
    }
    
    var body: some View {
        Group {
            if todaysTasks.isEmpty {
                emptyState
            } else {
                taskList
            }
        }
        .navigationTitle("Today")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showingMenu = true
                } label: {
                    Image(systemName: "line.3.horizontal")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddTask = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddTask) {
            WatchTaskFormView(mode: .create)
        }
        .sheet(isPresented: $showingMenu) {
            NavigationStack {
                WatchMenuView()
            }
        }
    }
    
    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 12) {
                Spacer().frame(height: 8)
                
                Text(selectedDate, format: .dateTime.weekday(.wide).day().month())
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
                
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 32))
                    .foregroundColor(.gray.opacity(0.5))
                
                Text("No tasks")
                    .font(.system(.headline, design: .rounded))
                
                Text("Tap + to add a task")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private var taskList: some View {
        List {
            Section {
                ForEach(todaysTasks) { task in
                    NavigationLink(destination: WatchTaskDetailView(task: task)) {
                        WatchTaskRowView(task: task, date: selectedDate)
                    }
                }
            } header: {
                Text(selectedDate, format: .dateTime.weekday(.wide).day().month())
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        WatchTaskListView()
            .environmentObject(WatchSyncManager.shared)
    }
}

// Inline fallback for the menu to ensure availability in this target
struct WatchMenuView: View {
    @EnvironmentObject var syncManager: WatchSyncManager
    
    var body: some View {
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
