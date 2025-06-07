import SwiftUI

struct FocusTabView: View {
    @StateObject private var timeTrackerViewModel = TimeTrackerViewModel.shared
    @StateObject private var pomodoroViewModel = PomodoroViewModel.shared
    @State private var showingTimeTracker = false
    @State private var selectedTrackingMode: TrackingMode = .simple
    @State private var showingPomodoro = false
    @State private var showingTaskPomodoro = false
    @State private var showingSessionConflict = false
    @State private var pendingSessionType: SessionType?
    @State private var showingWidgetTimer = false
    @State private var showingWidgetPomodoro = false
    @State private var selectedSessionId: UUID?

    private enum SessionType {
        case timer(TrackingMode)
        case pomodoro
        
        var displayName: String {
            switch self {
            case .timer(let mode):
                return mode == .simple ? "Simple Timer" : "Advanced Timer"
            case .pomodoro:
                return "Pomodoro Session"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        HStack {
                            Text("Focus Mode")
                                .font(.largeTitle.bold())
                            Spacer()
                        }
                        
                        // Show timer widgets for all active sessions
                        if !timeTrackerViewModel.activeSessions.isEmpty || pomodoroViewModel.hasActiveTask {
                            HStack {
                                Spacer()
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        // Show all active timer sessions
                                        ForEach(timeTrackerViewModel.activeSessions) { session in
                                            MiniTimerWidget(
                                                sessionId: session.id,
                                                viewModel: timeTrackerViewModel,
                                                onTap: {
                                                    selectedSessionId = session.id
                                                    showingWidgetTimer = true
                                                }
                                            )
                                        }
                                        
                                        // Show pomodoro if active
                                        if pomodoroViewModel.hasActiveTask {
                                            MiniPomodoroWidget(viewModel: pomodoroViewModel) {
                                                showingWidgetPomodoro = true
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                                
                                Spacer()
                            }
                        }
                    }
                    .padding(.top)
                    
                    VStack(spacing: 16) {
                        FocusModeCard(
                            title: "Simple Timer",
                            description: "Free-form focus session with manual timing",
                            icon: "stopwatch",
                            color: .yellow,
                            gradient: [.yellow, .orange]
                        ) {
                            selectedTrackingMode = .simple
                            if timeTrackerViewModel.activeSessions.count >= 2 {
                                // Show alert or do nothing
                                return
                            }
                            showingTimeTracker = true
                        }
                        
                        FocusModeCard(
                            title: "Pomodoro Technique",
                            description: "25min work sessions with 5min breaks",
                            icon: "timer",
                            color: .red,
                            gradient: [.red, .pink]
                        ) {
                            // Only check for Pomodoro conflicts
                            checkAndStartPomodoroSession()
                        }
                        
                        FocusModeCard(
                            title: "Coming Soon",
                            description: "More focus methods will be added",
                            icon: "sparkles",
                            color: .gray,
                            gradient: [.gray, .secondary],
                            action: {
                                // No action for now
                            },
                            isDisabled: true
                        )
                    }
                    
                    // Enhanced active sessions display
                    if timeTrackerViewModel.hasActiveSession || pomodoroViewModel.hasActiveTask {
                        activeSessionsCard
                    }
                    
                    todaysStatsCard
                    
                    recentSessionsCard
                    
                    Spacer()
                }
                .padding(.horizontal)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingTimeTracker) {
                NavigationStack {
                    TimeTrackerView(
                        task: nil,
                        mode: selectedTrackingMode,
                        taskManager: TaskManager.shared,
                        presentationStyle: .fullscreen
                    )
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingPomodoro) {
                NavigationStack {
                    PomodoroTabView()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingTaskPomodoro) {
                if let activeTask = pomodoroViewModel.activeTask {
                    NavigationStack {
                        PomodoroView(task: activeTask, presentationStyle: .fullscreen)
                    }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showingWidgetTimer) {
                if let sessionId = selectedSessionId {
                    NavigationStack {
                        SessionTimeTrackerView(
                            sessionId: sessionId,
                            viewModel: timeTrackerViewModel,
                            presentationStyle: .sheet
                        )
                    }
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showingWidgetPomodoro) {
                if let activeTask = pomodoroViewModel.activeTask {
                    NavigationStack {
                        PomodoroView(task: activeTask, presentationStyle: .sheet)
                    }
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showingSessionConflict) {
                SessionConflictView(
                    currentSession: getCurrentSessionName(),
                    newSession: pendingSessionType?.displayName ?? "",
                    onReplace: {
                        handleSessionReplacement()
                    },
                    onCancel: {
                        pendingSessionType = nil
                    },
                    onSaveAndReplace: {
                        handleSaveAndReplace()
                    },
                    onDiscardAndReplace: {
                        handleDiscardAndReplace()
                    },
                    onKeepBoth: nil // No keep both for Pomodoro
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFocusTabTimeTracker)) { _ in
            showingTimeTracker = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFocusTabPomodoro)) { notification in
            if let task = notification.object as? TodoTask {
                pomodoroViewModel.setActiveTask(task)
                showingTaskPomodoro = true
            } else {
                showingPomodoro = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .expandActiveTimer)) { notification in
            // Non serve gestire questa notifica perché il MiniTimerWidget usa onTap diretto
        }
        .onReceive(NotificationCenter.default.publisher(for: .expandActivePomodoro)) { notification in
            if let task = notification.object as? TodoTask {
                showingTaskPomodoro = true
            } else if pomodoroViewModel.hasActiveTask {
                showingTaskPomodoro = true
            }
        }
    }
    
    // Only check for Pomodoro conflicts
    private func checkAndStartPomodoroSession() {
        if pomodoroViewModel.hasActiveTask {
            pendingSessionType = .pomodoro
            showingSessionConflict = true
        } else {
            showingPomodoro = true
        }
    }
    
    private func getCurrentSessionName() -> String {
        if pomodoroViewModel.hasActiveTask {
            return "Pomodoro Session"
        }
        return ""
    }
    
    private func handleSaveAndReplace() {
        if pomodoroViewModel.hasActiveTask {
            pomodoroViewModel.stop()
        }
        
        startPendingSession()
    }
    
    private func handleDiscardAndReplace() {
        if pomodoroViewModel.hasActiveTask {
            pomodoroViewModel.stop()
        }
        
        startPendingSession()
    }
    
    private func handleSessionReplacement() {
        handleDiscardAndReplace()
    }
    
    private func startPendingSession() {
        guard let sessionType = pendingSessionType else { return }
        
        switch sessionType {
        case .timer(let mode):
            selectedTrackingMode = mode
            showingTimeTracker = true
        case .pomodoro:
            showingPomodoro = true
        }
        
        pendingSessionType = nil
    }
    
    // Enhanced active sessions display
    private var activeSessionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "play.circle.fill")
                    .foregroundColor(.blue)
                Text("Active Sessions")
                    .font(.headline)
                Spacer()
                
                if timeTrackerViewModel.activeSessions.count > 1 {
                    Text("\(timeTrackerViewModel.activeSessions.count) timers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(spacing: 12) {
                // Show all timer sessions
                ForEach(timeTrackerViewModel.activeSessions) { session in
                    Button(action: {
                        selectedSessionId = session.id
                        showingWidgetTimer = true
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Simple Timer")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.primary)
                                
                                Text(session.taskName ?? "Focus Session")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(timeTrackerViewModel.formattedElapsedTime(for: session.id))
                                    .font(.headline.weight(.bold))
                                    .foregroundColor(.yellow)
                                
                                Text(session.isPaused ? "Paused" : "Running")
                                    .font(.caption)
                                    .foregroundColor(session.isPaused ? .orange : .green)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.yellow.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.yellow.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Show pomodoro session
                if pomodoroViewModel.hasActiveTask {
                    Button(action: {
                        showingWidgetPomodoro = true
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Pomodoro Timer")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.primary)
                                
                                Text(pomodoroViewModel.activeTask?.name ?? "Focus Session")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(formatPomodoroTime(pomodoroViewModel.timeRemaining))
                                    .font(.headline.weight(.bold))
                                    .foregroundColor(.red)
                                
                                Text(pomodoroViewModel.state == .working ? "Focus" : "Break")
                                    .font(.caption)
                                    .foregroundColor(pomodoroViewModel.state == .working ? .green : .blue)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
    }
    
    private func formatPomodoroTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
    
    private var todaysStatsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.green)
                Text("Today's Focus")
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 24) {
                StatItem(
                    title: "Total Time",
                    value: formatDuration(TaskManager.shared.getTodaysTrackedTime()),
                    color: .green
                )
                
                StatItem(
                    title: "Sessions",
                    value: "\(getTodaysSessions().count)",
                    color: .blue
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
    }
    
    private var recentSessionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
                Text("Recent Sessions")
                    .font(.headline)
                Spacer()
            }
            
            let recentSessions = getRecentSessions()
            
            if recentSessions.isEmpty {
                Text("No sessions yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(recentSessions.prefix(5)) { session in
                        SessionRow(session: session)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
    }
    
    private func getTodaysSessions() -> [TrackingSession] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        return TaskManager.shared.trackingSessions
            .filter { session in
                session.startTime >= today && session.startTime < tomorrow
            }
    }
    
    private func getRecentSessions() -> [TrackingSession] {
        return TaskManager.shared.trackingSessions
            .sorted { $0.startTime > $1.startTime }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2.bold())
                .foregroundColor(color)
        }
    }
}

struct SessionRow: View {
    let session: TrackingSession
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.taskName ?? "General Focus")
                    .font(.subheadline.weight(.medium))
                
                Text(session.startTime.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatSessionDuration(session.effectiveWorkTime))
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                
                Text(session.mode.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatSessionDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

#Preview {
    FocusTabView()
}
