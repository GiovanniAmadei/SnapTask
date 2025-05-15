import SwiftUI

struct PomodoroListView: View {
    @ObservedObject private var taskManager = TaskManager.shared
    
    var body: some View {
        List {
            if pomodoroTasks.isEmpty {
                Text("No Pomodoro tasks")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(pomodoroTasks) { task in
                    NavigationLink(destination: WatchPomodoroView(task: task)) {
                        WatchPomodoroRow(task: task)
                    }
                }
            }
        }
        .listStyle(CarouselListStyle())
        .navigationTitle("Pomodoro")
    }
    
    private var pomodoroTasks: [TodoTask] {
        taskManager.tasks.filter { $0.pomodoroSettings != nil }
            .sorted { $0.name < $1.name }
    }
}

struct WatchPomodoroRow: View {
    let task: TodoTask
    
    var body: some View {
        HStack {
            // Task icon with colored background
            ZStack {
                Circle()
                    .fill(task.category != nil ? Color(hex: task.category!.color) : Color.gray)
                    .frame(width: 30, height: 30)
                
                Image(systemName: task.icon)
                    .foregroundColor(.white)
                    .font(.system(size: 14))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let settings = task.pomodoroSettings {
                    Text("\(settings.workDuration)m focus / \(settings.breakDuration)m break")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
} 