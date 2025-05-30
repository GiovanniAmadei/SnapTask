import SwiftUI

struct WatchTimelineView: View {
    @ObservedObject var viewModel: TimelineViewModel // Now passed from ContentView
    var onEditTaskFromRow: (TodoTask) -> Void   // Closure to request editing a task

    @StateObject private var taskManager = TaskManager.shared // Can remain for local operations like delete
    @State private var selectedTask: TodoTask? // For showing detail view locally

    var body: some View {
        ScrollView {
            VStack(spacing: 8) { 
                if viewModel.tasksForSelectedDate().isEmpty {
                    VStack(spacing: 12) {
                        WatchEmptyState()
                    }
                    .padding(.top, 20) 
                } else {
                    LazyVStack(spacing: 4) {
                        ForEach(viewModel.tasksForSelectedDate()) { task in
                            WatchTimelineTaskRow(
                                task: task,
                                selectedDate: viewModel.selectedDate,
                                onTap: { selectedTask = task }, 
                                onEdit: { onEditTaskFromRow(task) }, 
                                onDelete: { taskManager.removeTask(task) }, 
                                onToggleComplete: { 
                                    taskManager.toggleTaskCompletion(task.id, on: viewModel.selectedDate)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 6) 
                }
                Spacer(minLength: 10) 
            }
            .padding(.top, 8) 
        }
        .sheet(item: $selectedTask) { task in 
            WatchTaskDetailView(task: task, selectedDate: viewModel.selectedDate)
                .environmentObject(taskManager)
        }
    }
}

struct WatchTimelineTaskRow: View {
    let task: TodoTask
    let selectedDate: Date
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleComplete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Button(action: onToggleComplete) {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundColor(isCompleted ? .green : .gray)
                }
                .buttonStyle(PlainButtonStyle())
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(task.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isCompleted ? .secondary : .primary)
                            .strikethrough(isCompleted)
                            .lineLimit(2)
                        
                        Spacer()
                        
                        if task.priority != .medium {
                            Image(systemName: task.priority.icon)
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: task.priority.color))
                        }
                    }
                    
                    HStack {
                        if let category = task.category {
                            Text(category.name)
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: category.color))
                        }
                        
                        Spacer()
                        
                        if task.hasDuration {
                            Text(formatTime(task.startTime))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(task.category != nil ? Color(hex: task.category!.color).opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private var isCompleted: Bool {
        if let completion = task.completions[selectedDate.startOfDay] {
            return completion.isCompleted
        }
        return false
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct WatchEmptyState: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            
            Text("No tasks")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
            
            Text("Tap to add your first task")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 16)
    }
}

struct WatchDatePickerView: View {
    @Binding var selectedDate: Date
    @Binding var selectedDayOffset: Int
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(-7...7, id: \.self) { offset in
                        WatchDateButton(
                            offset: offset,
                            isSelected: offset == selectedDayOffset,
                            onTap: {
                                let newDate = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
                                selectedDate = newDate
                                selectedDayOffset = offset
                                dismiss()
                            }
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .navigationTitle("Select Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15))
                }
            }
        }
    }
}

struct WatchDateButton: View {
    let offset: Int
    let isSelected: Bool
    let onTap: () -> Void
    
    private var date: Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dayText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isSelected ? .white : .secondary)
                    
                    Text(dateText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .primary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue : Color.secondary.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var dayText: String {
        if offset == 0 {
            return "Today"
        } else if offset == -1 {
            return "Yesterday"
        } else if offset == 1 {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        }
    }
    
    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
