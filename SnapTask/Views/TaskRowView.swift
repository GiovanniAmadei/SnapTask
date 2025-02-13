import SwiftUI

struct TaskRowView: View {
    @Binding var task: TodoTask
    @StateObject private var viewModel = TaskViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingEditSheet = false
    let date: Date
    @State private var offset: CGFloat = 0
    
    var body: some View {
        List {
            VStack(spacing: 8) {
                HStack {
                    // Task completion indicator
                    Button(action: {
                        viewModel.toggleCompletion(for: task, on: date)
                    }) {
                        Image(systemName: task.completions[date.startOfDay]?.isCompleted == true ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(task.completions[date.startOfDay]?.isCompleted == true ? .green : .gray)
                            .font(.title2)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        // Task name and category
                        HStack {
                            Text(task.name)
                                .font(.headline)
                            
                            if let category = task.category {
                                Circle()
                                    .fill(Color(hex: category.color))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        
                        if ((task.description?.isNilOrEmpty) == nil) {
                            Text(task.description ?? "")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        // Task details
                        if task.hasDuration {
                            Text(formatDuration(task.duration))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Streak indicator
                    if task.recurrence != nil {
                        let streak = task.streakForDate(date)
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                            Text("\(streak)")
                                .font(.system(.caption, design: .rounded).bold())
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.15))
                        )
                    }
                    
                    // Priority indicator
                    Circle()
                        .fill(priorityColor(task.priority))
                        .frame(width: 8, height: 8)
                        .padding(.leading, 4)
                }
                
                // Subtasks section
                if !task.subtasks.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(task.subtasks) { subtask in
                            HStack {
                                Image(systemName: task.completions[date.startOfDay]?.completedSubtasks.contains(subtask.id) == true ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(task.completions[date.startOfDay]?.completedSubtasks.contains(subtask.id) == true ? .green : .gray)
                                    .font(.subheadline)
                                Text(subtask.name)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.leading)
                }
            }
            .frame(minHeight: 250)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            .contentShape(Rectangle())
            .offset(x: offset)
            .gesture(DragGesture()
                .onChanged { gesture in
                    if gesture.translation.width < 0 {
                        offset = max(gesture.translation.width, -100)
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring()) {
                        if offset < -50 {
                            offset = -100
                        } else {
                            offset = 0
                        }
                    }
                }
            )
            .overlay(
                HStack(spacing: -8) {
                    Button {
                        withAnimation(.spring()) {
                            editTask()
                            offset = 0
                        }
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.blue)
                            .frame(width: 44, height: 44)
                    }
                    
                    Button {
                        withAnimation(.spring()) {
                            deleteTask()
                            offset = 0
                        }
                    } label: {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.red)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.trailing, 16)
                .opacity(offset < 0 ? 1 : 0)
                .frame(maxWidth: .infinity, alignment: .trailing)
                , alignment: .trailing
            )
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
        .listStyle(PlainListStyle())
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                TaskFormView(initialTask: task)
            }
        }
        .onAppear {
            viewModel.refreshTask(task, for: date)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                viewModel.refreshTask(task, for: date)
            }
        }
        .onChange(of: task) { oldTask, newTask in
            viewModel.refreshTask(newTask, for: date)
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
    
    private func priorityColor(_ priority: Priority) -> Color {
        switch priority {
        case .high:
            return .red
        case .medium:
            return .orange
        case .low:
            return .green
        }
    }
    
    private func deleteTask() {
        TaskManager.shared.removeTask(task)
    }
    
    private func editTask() {
        showingEditSheet = true
    }
}

extension String {
    var isNilOrEmpty: Bool {
        self.isEmpty
    }
} 
