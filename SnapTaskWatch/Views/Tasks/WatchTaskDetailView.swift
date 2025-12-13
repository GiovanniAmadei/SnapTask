import SwiftUI

struct WatchTaskDetailView: View {
    let task: TodoTask
    @EnvironmentObject var syncManager: WatchSyncManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showingTimerSelection = false
    
    private var selectedDate: Date { Date() }
    
    private var isCompleted: Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        return task.completions[startOfDay]?.isCompleted == true
    }
    
    private var categoryColor: Color {
        if let colorHex = task.category?.color {
            return Color(hex: colorHex)
        }
        return .gray
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                headerSection
                
                Divider()
                
                // Details
                detailsSection
                
                // Subtasks
                if !task.subtasks.isEmpty {
                    Divider()
                    subtasksSection
                }
                
                Divider()
                
                // Actions
                actionsSection
            }
            .padding(.horizontal, 8)
        }
        .navigationTitle(task.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEditSheet) {
            WatchTaskFormView(mode: .edit(task))
        }
        .sheet(isPresented: $showingTimerSelection) {
            WatchTimerSelectionView(preselectedTask: task)
        }
        .confirmationDialog("Delete Task?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                syncManager.deleteTask(task)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            // Icon and category
            HStack {
                Image(systemName: task.icon)
                    .font(.title2)
                    .foregroundColor(categoryColor)
                
                Spacer()
                
                if let category = task.category {
                    Text(category.name)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(categoryColor.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            
            // Completion toggle
            Button {
                syncManager.toggleTaskCompletion(task, on: selectedDate)
            } label: {
                HStack {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isCompleted ? .green : .secondary)
                    Text(isCompleted ? "Completed" : "Mark Complete")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isCompleted ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Description
            if let description = task.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Time
            if task.hasSpecificTime {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(task.startTime, style: .time)
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            
            // Duration
            if task.hasDuration && task.duration > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "hourglass")
                        .font(.caption2)
                    Text(formatDuration(task.duration))
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            
            // Priority
            HStack(spacing: 4) {
                Image(systemName: task.priority.icon)
                    .font(.caption2)
                Text(task.priority.displayName)
                    .font(.caption)
            }
            .foregroundColor(Color(hex: task.priority.color))
            
            // Points
            if task.hasRewardPoints && task.rewardPoints > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                    Text("\(task.rewardPoints) points")
                        .font(.caption)
                }
                .foregroundColor(.yellow)
            }
        }
    }
    
    private var subtasksSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Subtasks")
                .font(.caption)
                .fontWeight(.semibold)
            
            ForEach(task.subtasks) { subtask in
                Button {
                    syncManager.toggleSubtaskCompletion(task, subtaskId: subtask.id, on: selectedDate)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: subtask.isCompleted ? "checkmark.square.fill" : "square")
                            .font(.caption)
                            .foregroundColor(subtask.isCompleted ? .green : .secondary)
                        
                        Text(subtask.name)
                            .font(.caption2)
                            .strikethrough(subtask.isCompleted)
                            .foregroundColor(subtask.isCompleted ? .secondary : .primary)
                        
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var actionsSection: some View {
        VStack(spacing: 8) {
            // Start Timer
            Button {
                showingTimerSelection = true
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Timer")
                }
                .font(.caption)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            
            // Edit
            Button {
                showingEditSheet = true
            } label: {
                HStack {
                    Image(systemName: "pencil")
                    Text("Edit")
                }
                .font(.caption)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.3))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            
            // Delete
            Button {
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete")
                }
                .font(.caption)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.2))
                .foregroundColor(.red)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

#Preview {
    NavigationStack {
        WatchTaskDetailView(
            task: TodoTask(
                name: "Test Task",
                description: "This is a test description",
                startTime: Date(),
                hasSpecificTime: true,
                duration: 3600,
                hasDuration: true,
                priority: .high,
                icon: "star.fill",
                subtasks: [
                    Subtask(name: "Subtask 1"),
                    Subtask(name: "Subtask 2", isCompleted: true)
                ],
                hasRewardPoints: true,
                rewardPoints: 10
            )
        )
        .environmentObject(WatchSyncManager.shared)
    }
}
