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
                return mode == .simple ? "simple_timer".localized : "advanced_timer".localized
            case .pomodoro:
                return "pomodoro_session".localized
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        HStack {
                            Text("focus_mode".localized)
                                .font(.largeTitle.bold())
                            Spacer()
                        }
                        
                        // Show timer widgets for all active sessions
                        if !timeTrackerViewModel.activeSessions.isEmpty || pomodoroViewModel.hasActiveTask {
                            HStack {
                                Spacer()
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        // FIXED: Show only sessions that have been actually started
                                        ForEach(timeTrackerViewModel.activeSessions.filter { session in
                                            session.isRunning || session.elapsedTime > 0 || session.isPaused
                                        }) { session in
                                            MiniTimerWidget(
                                                sessionId: session.id,
                                                viewModel: timeTrackerViewModel,
                                                onTap: {
                                                    // FIXED: Verifica che la sessione esista prima di aprire la vista
                                                    if timeTrackerViewModel.getSession(id: session.id) != nil {
                                                        selectedSessionId = session.id
                                                        showingWidgetTimer = true
                                                    }
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
                            title: "simple_timer".localized,
                            description: "freeform_focus_session".localized,
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
                            title: "pomodoro_technique".localized,
                            description: "25min_work_sessions_5min_breaks".localized,
                            icon: "timer",
                            color: .red,
                            gradient: [.red, .pink]
                        ) {
                            // Only check for Pomodoro conflicts
                            checkAndStartPomodoroSession()
                        }
                        
                        FocusModeCard(
                            title: "coming_soon".localized,
                            description: "more_focus_methods".localized,
                            icon: "sparkles",
                            color: .gray,
                            gradient: [.gray, .secondary],
                            action: {
                                // No action for now
                            },
                            isDisabled: true
                        )
                    }
                    
                    let activeSessionsCount = timeTrackerViewModel.activeSessions.filter { session in
                        session.isRunning || session.elapsedTime > 0 || session.isPaused
                    }.count
                    
                    if activeSessionsCount > 0 || pomodoroViewModel.hasActiveTask {
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
            return "pomodoro_session".localized
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
                Text("active_sessions".localized)
                    .font(.headline)
                Spacer()
                
                // FIXED: Count only sessions that have been actually started
                let activeSessionsCount = timeTrackerViewModel.activeSessions.filter { session in
                    session.isRunning || session.elapsedTime > 0 || session.isPaused
                }.count
                
                if activeSessionsCount > 0 || pomodoroViewModel.hasActiveTask {
                    Text("\(activeSessionsCount) " + "timers".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(spacing: 12) {
                // FIXED: Show only sessions that have been actually started
                ForEach(timeTrackerViewModel.activeSessions.filter { session in
                    session.isRunning || session.elapsedTime > 0 || session.isPaused
                }) { session in
                    Button(action: {
                        selectedSessionId = session.id
                        showingWidgetTimer = true
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("simple_timer".localized)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.primary)
                                
                                Text(session.taskName ?? "focus_session".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(timeTrackerViewModel.formattedElapsedTime(for: session.id))
                                    .font(.headline.weight(.bold))
                                    .foregroundColor(.yellow)
                                
                                Text(session.isPaused ? "paused".localized : "running".localized)
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
                                Text("pomodoro_timer".localized)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.primary)
                                
                                Text(pomodoroViewModel.activeTask?.name ?? "focus_session".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(formatPomodoroTime(pomodoroViewModel.timeRemaining))
                                    .font(.headline.weight(.bold))
                                    .foregroundColor(.red)
                                
                                Text(pomodoroViewModel.state == .working ? "focus".localized : "break".localized)
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
                Text("todays_focus".localized)
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 24) {
                StatItem(
                    title: "total_time".localized,
                    value: formatDuration(TaskManager.shared.getTodaysTrackedTime()),
                    color: .green
                )
                
                StatItem(
                    title: "sessions".localized,
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
                Text("recent_sessions".localized)
                    .font(.headline)
                Spacer()
            }
            
            let recentSessions = getRecentSessions()
            
            if recentSessions.isEmpty {
                Text("no_sessions_yet".localized)
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
                Text(session.taskName ?? "general_focus".localized)
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