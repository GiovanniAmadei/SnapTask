import SwiftUI

struct TrackingModeSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    let task: TodoTask?
    let onModeSelected: (TrackingMode) -> Void
    
    @StateObject private var timeTrackerViewModel = TimeTrackerViewModel.shared
    @StateObject private var pomodoroViewModel = PomodoroViewModel.shared
    @State private var showingSessionConflict = false
    @State private var pendingMode: TrackingMode?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    if let task = task {
                        Text(String(format: "track_task_format".localized, task.name))
                            .font(.title2)
                            .fontWeight(.semibold)
                    } else {
                        Text("start_focus_session".localized)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    Text("choose_tracking_mode".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                // Mode Selection Cards
                VStack(spacing: 16) {
                    // Simple Mode Card
                    TrackingModeCard(
                        mode: .simple,
                        isSelected: false
                    ) {
                        checkAndStartMode(.simple)
                    }
                    
                    // Pomodoro Mode Card - this should start PomodoroView, not TimeTrackerView
                    Button(action: {
                        checkAndStartMode(.pomodoro)
                    }) {
                        HStack(spacing: 16) {
                            // Icon
                            Image(systemName: TrackingMode.pomodoro.icon)
                                .font(.title2)
                                .foregroundColor(.red)
                                .frame(width: 40, height: 40)
                                .background(Color.red.opacity(0.1))
                                .clipShape(Circle())
                            
                            // Content
                            VStack(alignment: .leading, spacing: 4) {
                                Text(TrackingMode.pomodoro.displayName)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(TrackingMode.pomodoro.description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Arrow
                            Image(systemName: "chevron.right")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("select_mode".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingSessionConflict) {
                SessionConflictView(
                    currentSession: getCurrentSessionName(),
                    newSession: pendingMode?.displayName ?? "",
                    onReplace: {
                        handleSessionReplacement()
                    },
                    onCancel: {
                        pendingMode = nil
                    },
                    onSaveAndReplace: {
                        handleSaveAndReplace()
                    },
                    onDiscardAndReplace: {
                        handleDiscardAndReplace()
                    },
                    onKeepBoth: {
                        handleKeepBoth()
                    }
                )
            }
        }
    }
    
    private func checkAndStartMode(_ mode: TrackingMode) {
        if hasActiveSession() {
            pendingMode = mode
            showingSessionConflict = true
        } else {
            startMode(mode)
        }
    }
    
    private func startMode(_ mode: TrackingMode) {
        onModeSelected(mode)
        dismiss()
    }
    
    private func hasActiveSession() -> Bool {
        return timeTrackerViewModel.hasActiveSession || pomodoroViewModel.hasActiveTask
    }
    
    private func getCurrentSessionName() -> String {
        if timeTrackerViewModel.hasActiveSession {
            if let taskName = timeTrackerViewModel.currentSession?.taskName {
                return "simple_timer".localized + ": \(taskName)"
            } else {
                return "simple_timer_session".localized
            }
        } else if pomodoroViewModel.hasActiveTask {
            if let taskName = pomodoroViewModel.activeTask?.name {
                return "pomodoro".localized + ": \(taskName)"
            } else {
                return "pomodoro_session".localized
            }
        }
        return ""
    }
    
    private func handleSaveAndReplace() {
        if timeTrackerViewModel.hasActiveSession {
            timeTrackerViewModel.saveSession()
        }
        if pomodoroViewModel.hasActiveTask {
            pomodoroViewModel.stop()
        }
        
        guard let mode = pendingMode else { return }
        startMode(mode)
        pendingMode = nil
    }
    
    private func handleDiscardAndReplace() {
        if timeTrackerViewModel.hasActiveSession {
            timeTrackerViewModel.discardSession()
        }
        if pomodoroViewModel.hasActiveTask {
            pomodoroViewModel.stop()
        }
        
        guard let mode = pendingMode else { return }
        startMode(mode)
        pendingMode = nil
    }
    
    private func handleKeepBoth() {
        guard let mode = pendingMode else { return }
        startMode(mode)
        pendingMode = nil
    }
    
    private func handleSessionReplacement() {
        handleDiscardAndReplace()
    }
}

struct TrackingModeCard: View {
    let mode: TrackingMode
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: mode.icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                    .frame(width: 40, height: 40)
                    .background(iconColor.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(mode.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var iconColor: Color {
        switch mode {
        case .simple:
            return .yellow
        case .pomodoro:
            return .red
        }
    }
}

extension Notification.Name {
    static let startPomodoroFromTracking = Notification.Name("startPomodoroFromTracking")
}

#Preview {
    TrackingModeSelectionView(
        task: TodoTask(name: "Sample Task", startTime: Date())
    ) { mode in
        print("Selected: \(mode)")
    }
}