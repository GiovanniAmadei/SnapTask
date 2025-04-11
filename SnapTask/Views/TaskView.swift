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
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(.leading, 8)
                    
                    if let description = task.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                if task.hasDuration && task.duration > 0 {
                    Text(formatDuration(task.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if task.pomodoroSettings != nil {
                    Button(action: { 
                        PomodoroViewModel.shared.setActiveTask(task)
                        showingPomodoro = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.15))
                                .frame(width: 36, height: 36)
                                
                            Image(systemName: "timer")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(task.category.map { Color(hex: $0.color) } ?? .accentColor)
                        }
                        .overlay(
                            Circle()
                                .strokeBorder(Color.accentColor.opacity(0.5), lineWidth: 1)
                        )
                        .shadow(color: Color.accentColor.opacity(0.2), radius: 2, x: 0, y: 1)
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
                    .tint(task.category.map { Color(hex: $0.color) } ?? .gray)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: task.completionProgress)
                
                ForEach(task.subtasks) { subtask in
                    HStack {
                        Button(action: { onToggleSubtask(subtask.id) }) {
                            SubtaskCheckmark(isCompleted: subtask.isCompleted)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        
                        Text(subtask.name)
                            .font(.subheadline)
                            .foregroundColor(isCompleted ? .secondary : .primary)
                            .strikethrough(isCompleted)
                        
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, minHeight: 50)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(colorScheme == .dark ? Color(.systemGray6) : .white)
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
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
