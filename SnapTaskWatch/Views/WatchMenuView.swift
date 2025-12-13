import SwiftUI

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

#Preview {
    NavigationStack { WatchMenuView() }
        .environmentObject(WatchSyncManager.shared)
}
