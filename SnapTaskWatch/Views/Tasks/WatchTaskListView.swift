import SwiftUI

struct WatchTaskListView: View {
    @EnvironmentObject var syncManager: WatchSyncManager
    @State private var showingAddTask = false
    @State private var showingMenu = false
    @State private var selectedDate = Date()
    
    private var todaysTasks: [TodoTask] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        
        return syncManager.tasks.filter { task in
            // Check if task should appear on this date
            if let recurrence = task.recurrence {
                return recurrence.shouldOccurOn(date: selectedDate)
            } else {
                return calendar.isDate(task.startTime, inSameDayAs: selectedDate)
            }
        }.sorted { $0.startTime < $1.startTime }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                // Header with date
                headerView
                
                if todaysTasks.isEmpty {
                    emptyStateView
                } else {
                    ForEach(todaysTasks) { task in
                        NavigationLink(destination: WatchTaskDetailView(task: task)) {
                            WatchTaskRowView(task: task, date: selectedDate)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Today")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showingMenu = true
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddTask = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
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
    
    private var headerView: some View {
        HStack(spacing: 6) {
            Text(selectedDate, format: .dateTime.weekday(.wide).month().day())
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.vertical, 2)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            Text("No tasks")
                .font(.headline)
            
            Text("Tap + to add a task")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 20)
    }
}

#Preview {
    WatchTaskListView()
        .environmentObject(WatchSyncManager.shared)
}

// Inline fallback for the menu to ensure availability in this target
struct WatchMenuView: View {
    @EnvironmentObject var syncManager: WatchSyncManager
    
    var body: some View {
        List {
            Section(footer: EmptyView()) {
                MenuCard(icon: "checklist", iconColor: .blue, title: "Tasks", subtitle: "\(todayTasksCount) today") {
                    WatchTaskListView()
                }
                MenuCard(icon: "timer", iconColor: .orange, title: "Timer", subtitle: "") {
                    WatchTimerSelectionView()
                }
                MenuCard(icon: "gift.fill", iconColor: .purple, title: "Rewards", subtitle: "\(syncManager.totalPoints) pts") {
                    WatchRewardsListView()
                }
                MenuCard(icon: "chart.pie.fill", iconColor: .green, title: "Statistics", subtitle: "") {
                    WatchStatisticsView()
                }
                MenuCard(icon: "gear", iconColor: .gray, title: "Settings", subtitle: "") {
                    WatchSettingsView()
                }
            }
        }
        .listStyle(.carousel)
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

private struct MenuCard<Destination: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @ViewBuilder var destination: Destination
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .frame(height: 44)
            .contentShape(Rectangle())
        }
    }
}
