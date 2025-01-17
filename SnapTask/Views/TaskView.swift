import SwiftUI

struct TaskView: View {
    let task: TodoTask
    let onToggleComplete: () -> Void
    let onToggleSubtask: (UUID) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingPomodoro = false
    @StateObject private var taskManager = TaskManager.shared
    
    private var isCompleted: Bool {
        if let completion = task.completions[Date().startOfDay] {
            return completion.isCompleted
        }
        return false
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let description = task.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                if task.hasDuration && task.duration > 0 {
                    Text(formatDuration(task.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if task.pomodoroSettings != nil {
                    Button(action: { showingPomodoro = true }) {
                        Image(systemName: "timer")
                            .foregroundColor(Color(hex: task.category.color))
                    }
                }
                
                Button(action: onToggleComplete) {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isCompleted ? .green : .gray)
                        .font(.title2)
                }
                .buttonStyle(BorderlessButtonStyle())
                .contentShape(Rectangle())
                .frame(width: 44, height: 44)
            }
            
            if !task.subtasks.isEmpty {
                ProgressView(value: task.completionProgress, total: 1.0)
                    .tint(Color(hex: task.category.color))
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: task.completionProgress)
                
                ForEach(task.subtasks) { subtask in
                    HStack {
                        Button(action: { onToggleSubtask(subtask.id) }) {
                            Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(subtask.isCompleted ? .green : .gray)
                                .animation(.spring(response: 0.3), value: subtask.isCompleted)
                        }
                        
                        Text(subtask.name)
                            .font(.subheadline)
                            .foregroundColor(isCompleted ? .secondary : .primary)
                            .strikethrough(isCompleted)
                        
                        Spacer()
                    }
                }
            }
        }
        .sheet(isPresented: $showingPomodoro) {
            PomodoroView(task: task)
        }
        .onChange(of: task.completions) { oldValue, newValue in
            taskManager.updateTask(task)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

#Preview {
    TaskView(
        task: TodoTask(
            name: "Sample Task",
            startTime: Date(),
            duration: 3600,
            category: Category(id: UUID(), name: "Work", color: "#FF0000")
        ),
        onToggleComplete: {},
        onToggleSubtask: { _ in }
    )
    .padding()
} 