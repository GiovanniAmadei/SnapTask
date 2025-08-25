import SwiftUI
import Foundation

struct TaskCard: View {
    let task: TodoTask
    let onToggleComplete: () -> Void
    let onToggleSubtask: (UUID) -> Void
    @ObservedObject var viewModel: TimelineViewModel
    @State private var isExpanded = false
    @State private var showingPomodoro = false
    @State private var showingDetailView = false
    
    // Calcola se la task è completata per la data corrente
    private var isCompleted: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if let completion = task.completions[today] {
            return completion.isCompleted
        }
        return false
    }
    
    // Calcola le subtask completate per la data corrente
    private var completedSubtasks: Set<UUID> {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if let completion = task.completions[today] {
            return completion.completedSubtasks
        }
        return []
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header della task
            HStack(alignment: .center) {
                // Checkmark
                Button(action: onToggleComplete) {
                    TaskCheckmark(isCompleted: isCompleted)
                }
                .buttonStyle(BorderlessButtonStyle())
                .contentShape(Rectangle())
                .frame(width: 24, height: 24)
                
                // Titolo e categoria
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.name)
                        .font(.headline)
                        .foregroundColor(isCompleted ? .secondary : .primary)
                        .strikethrough(isCompleted)
                    
                    if let category = task.category {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: category.color))
                                .frame(width: 8, height: 8)
                            Text(category.name)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Info button per aprire i dettagli
                Button(action: {
                    showingDetailView = true
                }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                        )
                }
                .buttonStyle(BorderlessButtonStyle())
                
                // Pulsante Pomodoro (se disponibile)
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
                                .foregroundColor(.accentColor)
                        }
                        .overlay(
                            Circle()
                                .strokeBorder(Color.accentColor.opacity(0.5), lineWidth: 1)
                        )
                        .shadow(color: Color.accentColor.opacity(0.2), radius: 2, x: 0, y: 1)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                
                // Pulsante espandi (se ci sono subtask)
                if !task.subtasks.isEmpty {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: "chevron.down")
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .foregroundColor(.secondary)
                            .padding(8)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .padding(.leading, -8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            // Subtasks (se espanso)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            showingDetailView = true
        }
        .fullScreenCover(isPresented: $showingPomodoro) {
            NavigationStack {
                PomodoroTabView()
            }
        }
        .navigationDestination(isPresented: $showingDetailView) {
            TaskDetailView(taskId: task.id, targetDate: nil)
        }
    }
}

// MARK: - TaskCheckmark
struct TaskCheckmark: View {
    let isCompleted: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(isCompleted ? Color.accentColor : Color.gray.opacity(0.5), lineWidth: 1.5)
                .frame(width: 22, height: 22)
            
            if isCompleted {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 22, height: 22)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - SubtaskRow
struct SubtaskRow: View {
    let subtask: Subtask
    let isCompleted: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onToggle) {
                SubtaskCheckmark(isCompleted: isCompleted)
            }
            .buttonStyle(BorderlessButtonStyle())
            .contentShape(Rectangle())
            .frame(width: 20, height: 20)
            
            Text(subtask.name)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

// MARK: - SubtaskCheckmark
struct SubtaskCheckmark: View {
    let isCompleted: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(isCompleted ? Color.accentColor : Color.gray.opacity(0.5), lineWidth: 1.5)
                .frame(width: 18, height: 18)
            
            if isCompleted {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 18, height: 18)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
}