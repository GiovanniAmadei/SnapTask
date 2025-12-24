import SwiftUI

struct FocusTabView: View {
    @StateObject private var timeTrackerViewModel = TimeTrackerViewModel.shared
    @StateObject private var pomodoroViewModel = PomodoroViewModel.shared
    @State private var showingTimeTracker = false
    @State private var selectedTrackingMode: TrackingMode = .simple
    @State private var showingPomodoro = false
    @State private var showingTaskPomodoro = false
    @State private var showingPomodoroFullScreen = false // used when reopening from widget in general mode
    @State private var showingSessionConflict = false
    @State private var pendingSessionType: SessionType?
    @State private var showingWidgetTimer = false
    // Removed dedicated widget sheet for Pomodoro; reuse existing sheets
    @State private var selectedSessionId: UUID?

    @Environment(\.theme) private var theme

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
            ZStack {
                theme.backgroundColor
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 16) {
                            HStack {
                                Text("focus_mode".localized)
                                    .font(.largeTitle.bold())
                                    .foregroundColor(theme.textColor)
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
                                                    // Present on next run loop to stabilize sheet presentation
                                                    DispatchQueue.main.async {
                                                        if pomodoroViewModel.activeTask != nil {
                                                            showingTaskPomodoro = true
                                                        } else {
                                                            // Ensure a general session is initialized before presenting
                                                            if pomodoroViewModel.state == .notStarted {
                                                                pomodoroViewModel.initializeGeneralSession()
                                                            }
                                                            // Use fullScreenCover to avoid sheet rendering glitches
                                                            showingPomodoroFullScreen = true
                                                        }
                                                    }
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
                .fullScreenCover(isPresented: $showingPomodoroFullScreen) {
                    NavigationStack {
                        PomodoroTabView()
                    }
                }
                .sheet(isPresented: $showingPomodoro) {
                    NavigationStack {
                        PomodoroTabView()
                    }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
                .fullScreenCover(isPresented: $showingTaskPomodoro) {
                    if pomodoroViewModel.activeTask != nil {
                        NavigationStack {
                            PomodoroTabView()
                        }
                    }
                }
                .sheet(isPresented: $showingWidgetTimer) {
                    if let sessionId = selectedSessionId {
                        NavigationStack {
                            TimeTrackerView(
                                sessionId: sessionId,
                                presentationStyle: .sheet
                            )
                        }
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
                    }
                }
                // Removed separate widget sheet; handled by showingPomodoro/showingTaskPomodoro
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
            activeSessionsHeader
            activeSessionsList
        }
        .padding(20)
        .background(theme.surfaceColor)
        .cornerRadius(16)
        .shadow(
            color: theme.shadowColor,
            radius: 8,
            x: 0,
            y: 2
        )
    }

    private var activeSessionsHeader: some View {
        HStack {
            Image(systemName: "play.circle.fill")
                .foregroundColor(theme.accentColor)
            Text("active_sessions".localized)
                .font(.headline)
                .foregroundColor(theme.textColor)
            Spacer()

            // FIXED: Count only sessions that have been actually started
            let activeSessionsCount = timeTrackerViewModel.activeSessions.filter { session in
                session.isRunning || session.elapsedTime > 0 || session.isPaused
            }.count

            if activeSessionsCount > 0 || pomodoroViewModel.hasActiveTask {
                Text("\(activeSessionsCount) " + "timers".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryTextColor)
            }
        }
    }

    private var activeSessionsList: some View {
        VStack(spacing: 12) {
            // Show timer sessions
            let activeSessions = timeTrackerViewModel.activeSessions.filter { session in
                session.isRunning || session.elapsedTime > 0 || session.isPaused
            }

            ForEach(activeSessions) { session in
                ActiveTimerSessionRow(
                    session: session,
                    timeTracker: timeTrackerViewModel,
                    theme: theme
                ) {
                    selectedSessionId = session.id
                    showingWidgetTimer = true
                }
            }

            // Show pomodoro session
            if pomodoroViewModel.hasActiveTask {
                ActivePomodoroSessionRow(
                    viewModel: pomodoroViewModel,
                    theme: theme
                ) {
                    // Present on next run loop to stabilize presentation
                    DispatchQueue.main.async {
                        if pomodoroViewModel.activeTask != nil {
                            showingTaskPomodoro = true
                        } else {
                            if pomodoroViewModel.state == .notStarted {
                                pomodoroViewModel.initializeGeneralSession()
                            }
                            showingPomodoroFullScreen = true
                        }
                    }
                }
            }
        }
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
                    .foregroundColor(theme.textColor)
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
                    color: theme.accentColor
                )
            }
        }
        .padding(20)
        .background(theme.surfaceColor)
        .cornerRadius(16)
        .shadow(
            color: theme.shadowColor,
            radius: 8,
            x: 0,
            y: 2
        )
    }

    private var recentSessionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
                Text("recent_sessions".localized)
                    .font(.headline)
                    .foregroundColor(theme.textColor)
                Spacer()
            }

            let recentSessions = getRecentSessions()

            if recentSessions.isEmpty {
                Text("no_sessions_yet".localized)
                    .font(.subheadline)
                    .foregroundColor(theme.secondaryTextColor)
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
        .background(theme.surfaceColor)
        .cornerRadius(16)
        .shadow(
            color: theme.shadowColor,
            radius: 8,
            x: 0,
            y: 2
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

// MARK: - Supporting Views

struct ActiveTimerSessionRow: View {
    let session: TrackingSession
    let timeTracker: TimeTrackerViewModel
    let theme: Theme
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("simple_timer".localized)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(theme.textColor)

                    Text(session.taskName ?? "focus_session".localized)
                        .font(.caption)
                        .foregroundColor(theme.secondaryTextColor)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(timeTracker.formattedElapsedTime(for: session.id))
                        .font(.headline.weight(.bold))
                        .foregroundColor(.yellow)

                    Text(session.isPaused ? "paused".localized : "running".localized)
                        .font(.caption)
                        .foregroundColor(session.isPaused ? .orange : .green)
                }
            }
            .padding()
            .background(sessionBackground(.yellow))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func sessionBackground(_ color: Color) -> some View {
        let isDark = isDarkTheme
        return RoundedRectangle(cornerRadius: 12)
            .fill(color.opacity(isDark ? 0.15 : 0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(color.opacity(isDark ? 0.4 : 0.3), lineWidth: 1)
            )
    }

    private var isDarkTheme: Bool {
        let uiColor = UIColor(theme.backgroundColor)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return luminance < 0.5
    }
}

struct ActivePomodoroSessionRow: View {
    let viewModel: PomodoroViewModel
    let theme: Theme
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("pomodoro_timer".localized)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(theme.textColor)

                    Text(viewModel.activeTask?.name ?? "focus_session".localized)
                        .font(.caption)
                        .foregroundColor(theme.secondaryTextColor)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatPomodoroTime(viewModel.timeRemaining))
                        .font(.headline.weight(.bold))
                        .foregroundColor(.red)

                    Text(viewModel.state == .working ? "focus".localized : "break".localized)
                        .font(.caption)
                        .foregroundColor(viewModel.state == .working ? .green : .blue)
                }
            }
            .padding()
            .background(sessionBackground(.red))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func sessionBackground(_ color: Color) -> some View {
        let isDark = isDarkTheme
        return RoundedRectangle(cornerRadius: 12)
            .fill(color.opacity(isDark ? 0.15 : 0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(color.opacity(isDark ? 0.4 : 0.3), lineWidth: 1)
            )
    }

    private var isDarkTheme: Bool {
        let uiColor = UIColor(theme.backgroundColor)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return luminance < 0.5
    }

    private func formatPomodoroTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let color: Color
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(theme.secondaryTextColor)

            Text(value)
                .font(.title2.bold())
                .foregroundColor(color)
        }
    }
}

struct SessionRow: View {
    let session: TrackingSession
    @Environment(\.theme) private var theme
    @ObservedObject private var categoryManager = CategoryManager.shared

    var body: some View {
        HStack {
            if let categoryColor {
                Circle()
                    .fill(categoryColor)
                    .frame(width: 10, height: 10)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(session.taskName ?? "general_focus".localized)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(theme.textColor)

                Text(session.startTime.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(theme.secondaryTextColor)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatSessionDuration(session.effectiveWorkTime))
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(theme.textColor)

                Text(session.mode.displayName)
                    .font(.caption)
                    .foregroundColor(theme.secondaryTextColor)
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

    private var categoryColor: Color? {
        guard let categoryId = session.categoryId else { return nil }

        if let category = categoryManager.categories.first(where: { $0.id == categoryId }) {
            return Color(hex: category.color)
        }

        if let taskId = session.taskId,
           let task = TaskManager.shared.tasks.first(where: { $0.id == taskId }),
           let hex = task.category?.color {
            return Color(hex: hex)
        }

        return nil
    }
}

#Preview {
    FocusTabView()
}