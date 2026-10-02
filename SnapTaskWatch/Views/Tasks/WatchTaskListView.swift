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
                return task.timeScope != .inbox && calendar.isDate(task.startTime, inSameDayAs: selectedDate)
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
