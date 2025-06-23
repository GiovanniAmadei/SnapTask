import SwiftUI

struct WatchTaskDetailView: View {
    let task: TodoTask
    let selectedDate: Date
    @Environment(\.dismiss) private var dismiss
    @StateObject private var taskManager = TaskManager.shared
    @State private var showingEditForm = false
    @State private var showingTrackingModeSelection = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Task Header
                    VStack(spacing: 8) {
                        Text(task.name)
                            .font(.system(size: 16, weight: .semibold))
                            .multilineTextAlignment(.center)
                        
                        if let category = task.category {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color(hex: category.color))
                                    .frame(width: 8, height: 8)
                                
                                Text(category.name)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Task Details
                    VStack(spacing: 8) {
                        if task.hasDuration {
                            DetailRow(
                                icon: "clock",
                                label: "Time",
                                value: formatDateTime(task.startTime, duration: task.duration)
                            )
                        }
                        
                        DetailRow(
                            icon: "flag",
                            label: "Priority",
                            value: task.priority.rawValue.capitalized,
                            color: Color(hex: task.priority.color)
                        )
                        
                        if let description = task.description, !description.isEmpty {
                            DetailRow(
                                icon: "text.alignleft",
                                label: "Description",
                                value: description
                            )
                        }
                        
                        if task.recurrence != nil {
                            DetailRow(
                                icon: "repeat",
                                label: "Recurrence",
                                value: recurrenceText
                            )
                        }
                        
                        if task.pomodoroSettings != nil {
                            DetailRow(
                                icon: "timer",
                                label: "Pomodoro",
                                value: pomodoroText
                            )
                        }
                    }
                    
                    // Subtasks
                    if !task.subtasks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Subtasks")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            ForEach(task.subtasks) { subtask in
                                HStack(spacing: 8) {
                                    Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 12))
                                        .foregroundColor(subtask.isCompleted ? .green : .gray)
                                    
                                    Text(subtask.name)
                                        .font(.system(size: 12))
                                        .strikethrough(subtask.isCompleted)
                                        .foregroundColor(subtask.isCompleted ? .secondary : .primary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    
                    // Action Buttons
                    VStack(spacing: 8) {
                        // Complete/Incomplete Button
                        Button(action: toggleCompletion) {
                            HStack {
                                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 14))
                                
                                Text(isCompleted ? "Mark Incomplete" : "Mark Complete")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isCompleted ? Color.orange : Color.green)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Single Track button instead of two separate buttons
                        Button(action: { showingTrackingModeSelection = true }) {
                            HStack {
                                Image(systemName: "play.circle")
                                    .font(.system(size: 14))
                                
                                Text("Track")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Edit Button
                        Button(action: { showingEditForm = true }) {
                            HStack {
                                Image(systemName: "pencil")
                                    .font(.system(size: 14))
                                
                                Text("Edit Task")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showingEditForm) {
            WatchTaskFormView(task: task, initialDate: selectedDate, isPresented: $showingEditForm)
        }
        .sheet(isPresented: $showingTrackingModeSelection) {
            WatchTrackingModeSelectionView(task: task)
        }
    }
    
    private var isCompleted: Bool {
        if let completion = task.completions[selectedDate.startOfDay] {
            return completion.isCompleted
        }
        return false
    }
    
    private func toggleCompletion() {
        taskManager.toggleTaskCompletion(task.id, on: selectedDate)
    }
    
    private func formatDateTime(_ date: Date, duration: TimeInterval) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let startTime = formatter.string(from: date)
        
        if duration > 0 {
            let endTime = formatter.string(from: date.addingTimeInterval(duration))
            return "\(startTime) - \(endTime)"
        }
        
        return startTime
    }
    
    private var recurrenceText: String {
        guard let recurrence = task.recurrence else { return "None" }
        
        switch recurrence.type {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }
    
    private var pomodoroText: String {
        guard let settings = task.pomodoroSettings else { return "None" }
        
        let workMin = Int(settings.workDuration / 60)
        let breakMin = Int(settings.breakDuration / 60)
        return "\(workMin)m work, \(breakMin)m break"
    }
}

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color?
    
    init(icon: String, label: String, value: String, color: Color? = nil) {
        self.icon = icon
        self.label = label
        self.value = value
        self.color = color
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color ?? .secondary)
                .frame(width: 16)
            
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            
            Text(value)
                .font(.system(size: 11))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.1))
        )
    }
}
