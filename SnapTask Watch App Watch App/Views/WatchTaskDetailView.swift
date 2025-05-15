import SwiftUI

struct DetailRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 16)
            
            Text(text)
                .font(.subheadline)
        }
    }
}

struct WatchTaskDetailView: View {
    let task: TodoTask
    let date: Date
    @State private var isShowingEditTask = false
    @State private var isShowingPomodoro = false
    @State private var refreshUI = false
    @Environment(\.dismiss) private var dismiss
    @StateObject private var taskManager = TaskManager.shared
    @State private var hapticEngine = WKHapticType.click
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                // Header with task name and icon
                HStack {
                    ZStack {
                        Circle()
                            .fill(task.category != nil ? Color(hex: task.category!.color) : Color.gray)
                            .frame(width: 30, height: 30)
                        
                        Image(systemName: task.icon)
                            .foregroundColor(.white)
                            .font(.system(size: 14))
                    }
                    
                    Text(task.name)
                        .font(.headline)
                        .lineLimit(2)
                }
                .padding(.bottom, 4)
                
                // Task details
                if let category = task.category {
                    DetailRow(icon: "folder", text: category.name)
                }
                
                DetailRow(icon: "calendar", text: formattedDate(task.startTime))
                
                if task.hasDuration {
                    DetailRow(icon: "clock", text: "\(task.duration) min")
                }
                
                DetailRow(icon: "flag", text: task.priority.rawValue.capitalized)
                
                if let recurrence = task.recurrence {
                    DetailRow(icon: "repeat", text: recurrenceText(recurrence))
                }
                
                // Subtasks section with progress
                if !task.subtasks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Subtasks")
                                .font(.headline)
                            
                            Spacer()
                            
                            // Progress indicator
                            Text("\(completedSubtasksCount)/\(task.subtasks.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                        
                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 4)
                                    .cornerRadius(2)
                                
                                Rectangle()
                                    .fill(Color.green)
                                    .frame(width: geometry.size.width * CGFloat(completedSubtasksCount) / CGFloat(task.subtasks.count), height: 4)
                                    .cornerRadius(2)
                            }
                        }
                        .frame(height: 4)
                        .padding(.bottom, 4)
                        
                        ForEach(task.subtasks) { subtask in
                            Button(action: {
                                taskManager.toggleSubtask(taskId: task.id, subtaskId: subtask.id, on: date)
                                WKInterfaceDevice.current().play(hapticEngine)
                                refreshUI.toggle()
                            }) {
                                HStack {
                                    Image(systemName: isSubtaskCompleted(subtask) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(isSubtaskCompleted(subtask) ? .green : .gray)
                                        .font(.system(size: 18))
                                    
                                    Text(subtask.name)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.vertical, 6)
                        }
                    }
                }
                
                // Button actions
                Button(action: {
                    taskManager.toggleTaskCompletion(task.id, on: date)
                    WKInterfaceDevice.current().play(hapticEngine)
                }) {
                    Label(
                        isCompleted ? "Mark Incomplete" : "Mark Complete",
                        systemImage: isCompleted ? "circle" : "checkmark.circle"
                    )
                    .font(.system(size: 14))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.top, 8)
                
                if task.pomodoroSettings != nil {
                    Button(action: {
                        isShowingPomodoro = true
                    }) {
                        Label("Start Pomodoro", systemImage: "timer")
                            .font(.system(size: 14))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 4)
                }
                
                HStack {
                    Button(action: {
                        isShowingEditTask = true
                    }) {
                        Label("Edit", systemImage: "pencil")
                            .font(.system(size: 14))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(role: .destructive, action: {
                        taskManager.removeTask(task)
                        dismiss()
                    }) {
                        Label("Delete", systemImage: "trash")
                            .font(.system(size: 14))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 4)
            }
            .padding()
        }
        .navigationTitle("Task Details")
        .sheet(isPresented: $isShowingEditTask) {
            WatchTaskFormView(
                viewModel: TaskFormViewModel(task: task),
                isPresented: $isShowingEditTask
            )
        }
        .sheet(isPresented: $isShowingPomodoro) {
            WatchPomodoroView(task: task)
        }
    }
    
    private var isCompleted: Bool {
        if let completion = task.completions[date.startOfDay] {
            return completion.isCompleted
        }
        return false
    }
    
    private func isSubtaskCompleted(_ subtask: Subtask) -> Bool {
        if let completion = task.completions[date.startOfDay] {
            return completion.completedSubtasks.contains(subtask.id)
        }
        return false
    }
    
    private var completedSubtasksCount: Int {
        if let completion = task.completions[date.startOfDay] {
            return task.subtasks.filter { completion.completedSubtasks.contains($0.id) }.count
        }
        return 0
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func recurrenceText(_ recurrence: Recurrence) -> String {
        switch recurrence.type {
        case .daily:
            return "Daily"
        case .weekly(let days):
            if !days.isEmpty {
                let dayNames = days.sorted().map { dayOfWeekName($0) }.joined(separator: ", ")
                return "Weekly on \(dayNames)"
            }
            return "Weekly"
        case .monthly(let days):
            if !days.isEmpty {
                return "Monthly on day\(days.count > 1 ? "s" : "") \(days.sorted().map { "\($0)" }.joined(separator: ", "))"
            }
            return "Monthly"
        }
    }
    
    private func dayOfWeekName(_ day: Int) -> String {
        let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return days[day - 1]
    }
} 