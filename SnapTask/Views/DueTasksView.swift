import SwiftUI

struct DueTasksView: View {
    @StateObject private var viewModel = TimelineViewModel()
    @State private var currentDate = Date()
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.dueTasks) { task in
                    TaskView(
                        task: task,
                        onToggleComplete: { viewModel.toggleTaskCompletion(task.id) },
                        onToggleSubtask: { subtaskId in
                            viewModel.toggleSubtask(taskId: task.id, subtaskId: subtaskId)
                        }
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Due Tasks")
            .overlay(
                Group {
                    if viewModel.dueTasks.isEmpty {
                        ContentUnavailableView(
                            "No Tasks Due",
                            systemImage: "checkmark.circle",
                            description: Text("All caught up!")
                        )
                    }
                }
            )
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
                currentDate = Date()
                // The tasks will update automatically through TaskManager
            }
        }
    }
} 