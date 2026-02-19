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
            VStack(spacing: 6) {
                // MARK: - Header Card
                headerCard
                
                // MARK: - Details Card
                if hasDetails {
                    detailsCard
                }
                
                // MARK: - Subtasks Card
                if !task.subtasks.isEmpty {
                    subtasksCard
                }
                
                // MARK: - Actions
                actionsCard
            }
            .padding(.horizontal, 4)
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
    
    private var hasDetails: Bool {
        (task.description != nil && !task.description!.isEmpty)
        || task.hasSpecificTime
        || (task.hasDuration && task.duration > 0)
        || (task.hasRewardPoints && task.rewardPoints > 0)
    }
    
    // MARK: - Header Card
    private var headerCard: some View {
        VStack(spacing: 10) {
            // Icon + Name + Category
            HStack(spacing: 8) {
                Image(systemName: task.icon)
                    .font(.title3)
                    .foregroundColor(categoryColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.name)
                        .font(.system(.footnote, design: .rounded, weight: .semibold))
                        .lineLimit(2)
                    
                    if let category = task.category {
                        Text(category.name)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(categoryColor)
                    }
                }
                
                Spacer(minLength: 0)
                
                // Priority badge
                priorityBadge
            }
            
            // Completion toggle
            Button {
                syncManager.toggleTaskCompletion(task, on: selectedDate)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.body)
                    Text(isCompleted ? "Completed" : "Mark Complete")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .tint(isCompleted ? .green : .gray)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.gray.opacity(0.14))
        )
    }
    
    // MARK: - Priority Badge
    private var priorityBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: task.priority.icon)
                .font(.system(size: 9, weight: .bold))
            Text(task.priority.displayName)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
        }
        .foregroundColor(Color(hex: task.priority.color))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color(hex: task.priority.color).opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    // MARK: - Details Card
    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Description
            if let description = task.description, !description.isEmpty {
                Text(description)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            
            // Info row
            HStack(spacing: 8) {
                // Time
                if task.hasSpecificTime {
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text(task.startTime, style: .time)
                            .font(.system(size: 11, design: .rounded))
                    }
                    .foregroundColor(.secondary)
                }
                
                // Duration
                if task.hasDuration && task.duration > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 9))
                        Text(formatDuration(task.duration))
                            .font(.system(size: 11, design: .rounded))
                    }
                    .foregroundColor(.secondary)
                }
                
                // Points
                if task.hasRewardPoints && task.rewardPoints > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                        Text("\(task.rewardPoints)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.yellow)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.gray.opacity(0.14))
        )
    }
    
    // MARK: - Subtasks Card
    private var subtasksCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Subtasks")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.bottom, 2)
            
            ForEach(task.subtasks) { subtask in
                Button {
                    syncManager.toggleSubtaskCompletion(task, subtaskId: subtask.id, on: selectedDate)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 14))
                            .foregroundColor(subtask.isCompleted ? .green : .secondary)
                        
                        Text(subtask.name)
                            .font(.system(.caption2, design: .rounded))
                            .strikethrough(subtask.isCompleted)
                            .foregroundColor(subtask.isCompleted ? .secondary : .primary)
                        
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.gray.opacity(0.14))
        )
    }
    
    // MARK: - Actions Card
    private var actionsCard: some View {
        VStack(spacing: 6) {
            // Start Timer
            Button {
                showingTimerSelection = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11))
                    Text("Start Timer")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
            
            // Edit & Delete row
            HStack(spacing: 6) {
                Button {
                    showingEditSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 10))
                        Text("Edit")
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .tint(.gray)
                
                Button {
                    showingDeleteConfirmation = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                        Text("Delete")
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
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
