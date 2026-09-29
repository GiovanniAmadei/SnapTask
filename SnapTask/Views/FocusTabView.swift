import SwiftUI

struct FocusTabView: View {
    @StateObject private var timeTrackerViewModel = TimeTrackerViewModel.shared
    @StateObject private var pomodoroViewModel = PomodoroViewModel.shared
    @State private var showingTimeTracker = false
    @State private var activeTrackingSessionId: UUID?
    @State private var selectedTrackingMode: TrackingMode = .simple
    @State private var showingPomodoro = false
    @State private var showingSessionConflict = false
    @State private var pendingSessionType: SessionType?
    @State private var showingAllSessions = false
    @State private var sessionToEdit: TrackingSession?
    @ObservedObject private var taskManager = TaskManager.shared

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
                                activeTrackingSessionId = nil
                                if timeTrackerViewModel.activeSessions.count >= 2 {
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
                        if let sessionId = activeTrackingSessionId, timeTrackerViewModel.getSession(id: sessionId) != nil {
                            TimeTrackerView(
                                sessionId: sessionId,
                                presentationStyle: .fullscreen,
                                allowExpand: false
                            )
                        } else {
                            TimeTrackerView(
                                task: nil,
                                mode: selectedTrackingMode,
                                taskManager: TaskManager.shared,
                                presentationStyle: .fullscreen,
                                allowExpand: false
                            )
                        }
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
            .onReceive(NotificationCenter.default.publisher(for: .openFocusTabTimeTracker)) { notification in
                if let sessionId = notification.object as? UUID {
                    activeTrackingSessionId = sessionId
                } else {
                    activeTrackingSessionId = nil
                }
                showingTimeTracker = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .openFocusTabPomodoro)) { notification in
                if let task = notification.object as? TodoTask {
                    pomodoroViewModel.setActiveTask(task)
                }
                showingPomodoro = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .expandActiveTimer)) { notification in
                if let sessionId = notification.object as? UUID {
                    activeTrackingSessionId = sessionId
                }
                showingTimeTracker = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .expandActivePomodoro)) { notification in
                if let task = notification.object as? TodoTask {
                    pomodoroViewModel.setActiveTask(task)
                }
                showingPomodoro = true
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
                    activeTrackingSessionId = session.id
                    showingTimeTracker = true
                }
            }

            // Show pomodoro session
            if pomodoroViewModel.hasActiveTask {
                ActivePomodoroSessionRow(
                    viewModel: pomodoroViewModel,
                    theme: theme
                ) {
                    if pomodoroViewModel.state == .notStarted {
                        pomodoroViewModel.initializeGeneralSession()
                    }
                    showingPomodoro = true
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
                let totalCount = taskManager.trackingSessions.count
                if totalCount > 3 {
                    Button {
                        showingAllSessions = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("view_all".localized + " (\(totalCount))")
                                .font(.caption.weight(.medium))
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                        }
                        .foregroundColor(theme.accentColor)
                    }
                }
            }

            let recentSessions = getRecentSessions().prefix(3)

            if recentSessions.isEmpty {
                Text("no_sessions_yet".localized)
                    .font(.subheadline)
                    .foregroundColor(theme.secondaryTextColor)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentSessions)) { session in
                        SessionRowWithActions(
                            session: session,
                            onEdit: { sessionToEdit = session },
                            onDelete: { taskManager.deleteTrackingSession(session) }
                        )
                        if session.id != recentSessions.last?.id {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(theme.surfaceColor)
        .cornerRadius(16)
        .shadow(color: theme.shadowColor, radius: 8, x: 0, y: 2)
        .sheet(isPresented: $showingAllSessions) {
            AllSessionsView(
                onEdit: { session in sessionToEdit = session }
            )
        }
        .sheet(item: $sessionToEdit) { session in
            SessionEditView(session: session)
        }
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
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: "stopwatch.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("simple_timer".localized)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundColor(theme.textColor)

                    Text(session.taskName ?? "focus_session".localized)
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(theme.secondaryTextColor)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(timeTracker.formattedElapsedTime(for: session.id))
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .foregroundColor(.orange)

                    HStack(spacing: 4) {
                        Circle()
                            .fill(session.isPaused ? Color.orange : Color.green)
                            .frame(width: 6, height: 6)

                        Text(session.isPaused ? "paused".localized : "running".localized)
                            .font(.system(.caption2, design: .rounded).weight(.semibold))
                            .foregroundColor(session.isPaused ? .orange : .green)
                    }
                }
            }
            .padding(14)
            .background(sessionBackground(.orange))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func sessionBackground(_ color: Color) -> some View {
        let isDark = isDarkTheme
        return RoundedRectangle(cornerRadius: 14)
            .fill(color.opacity(isDark ? 0.15 : 0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(color.opacity(isDark ? 0.35 : 0.25), lineWidth: 1)
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

    private var phaseColor: Color {
        switch viewModel.effectivePhase {
        case .working: return Color(hex: "#4F46E5")
        case .onBreak: return Color(hex: "#059669")
        default: return Color(hex: "#4F46E5")
        }
    }

    private var phaseIcon: String {
        switch viewModel.effectivePhase {
        case .working: return "brain.head.profile"
        case .onBreak: return "cup.and.saucer.fill"
        default: return "timer"
        }
    }

    private var statusLabel: String {
        if viewModel.state == .paused {
            return "paused".localized
        }
        return viewModel.effectivePhase == .working ? "focus".localized : "break".localized
    }

    private var statusColor: Color {
        if viewModel.state == .paused {
            return .orange
        }
        return viewModel.effectivePhase == .working ? .indigo : .green
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(phaseColor.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: phaseIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(phaseColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("pomodoro_timer".localized)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundColor(theme.textColor)

                    Text(viewModel.activeTask?.name ?? "focus_session".localized)
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(theme.secondaryTextColor)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(formatPomodoroTime(viewModel.timeRemaining))
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .foregroundColor(phaseColor)

                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 6, height: 6)

                        Text(statusLabel)
                            .font(.system(.caption2, design: .rounded).weight(.semibold))
                            .foregroundColor(statusColor)
                    }
                }
            }
            .padding(14)
            .background(sessionBackground(phaseColor))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func sessionBackground(_ color: Color) -> some View {
        let isDark = isDarkTheme
        return RoundedRectangle(cornerRadius: 14)
            .fill(color.opacity(isDark ? 0.15 : 0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(color.opacity(isDark ? 0.35 : 0.25), lineWidth: 1)
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
                RoundedRectangle(cornerRadius: 2)
                    .fill(categoryColor)
                    .frame(width: 3, height: 24)
                    .padding(.trailing, 8)
            } else {
                Color.clear
                    .frame(width: 3, height: 24)
                    .padding(.trailing, 8)
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

// MARK: - SessionRowWithActions

struct SessionRowWithActions: View {
    let session: TrackingSession
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.theme) private var theme
    @State private var dragOffset: CGFloat = 0
    @State private var showActions = false
    private let actionWidth: CGFloat = 140

    var body: some View {
        ZStack(alignment: .trailing) {
            // Row content
            SessionRow(session: session)
                .padding(.vertical, 8)
                .background(theme.surfaceColor)
                .offset(x: dragOffset)
                .gesture(
                    DragGesture(minimumDistance: 15)
                        .onChanged { v in
                            let w = v.translation.width
                            guard w < 0 else {
                                if showActions { dragOffset = min(0, -actionWidth + w) }
                                return
                            }
                            dragOffset = max(-actionWidth, w + (showActions ? -actionWidth : 0))
                        }
                        .onEnded { v in
                            let revealed = -dragOffset > actionWidth / 2
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                if revealed {
                                    dragOffset = -actionWidth
                                    showActions = true
                                } else {
                                    dragOffset = 0
                                    showActions = false
                                }
                            }
                        }
                )
                .onTapGesture {
                    if showActions {
                        withAnimation(.spring(response: 0.3)) { dragOffset = 0; showActions = false }
                    }
                }

            // Action buttons clipped to the vacated space
            HStack(spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.3)) { dragOffset = 0; showActions = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { onEdit() }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .semibold))
                        Text("edit".localized)
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .frame(width: 70, height: 56)
                    .background(Color.orange)
                }
                Button {
                    withAnimation(.spring(response: 0.3)) { dragOffset = 0; showActions = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { onDelete() }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .semibold))
                        Text("delete".localized)
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .frame(width: 70, height: 56)
                    .background(Color.red)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .frame(width: max(0, -dragOffset), alignment: .trailing)
            .clipped()
            .allowsHitTesting(dragOffset < -10)
        }
        .clipped()
    }
}

// MARK: - AllSessionsView

struct AllSessionsView: View {
    let onEdit: (TrackingSession) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @ObservedObject private var taskManager = TaskManager.shared
    @State private var sessionToEdit: TrackingSession?

    private var groupedSessions: [(String, [TrackingSession])] {
        let sorted = taskManager.trackingSessions.sorted { $0.startTime > $1.startTime }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        var groups: [(String, [TrackingSession])] = []
        var current: (String, [TrackingSession])? = nil
        for session in sorted {
            let key = formatter.string(from: session.startTime)
            if current?.0 == key {
                current!.1.append(session)
            } else {
                if let c = current { groups.append(c) }
                current = (key, [session])
            }
        }
        if let c = current { groups.append(c) }
        return groups
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedSessions, id: \.0) { day, sessions in
                    Section(header:
                        Text(day)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(theme.secondaryTextColor)
                    ) {
                        ForEach(sessions) { session in
                            SessionRow(session: session)
                                .listRowBackground(theme.surfaceColor)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        taskManager.deleteTrackingSession(session)
                                    } label: {
                                        Label("delete".localized, systemImage: "trash")
                                    }
                                    Button {
                                        sessionToEdit = session
                                    } label: {
                                        Label("edit".localized, systemImage: "pencil")
                                    }
                                    .tint(.orange)
                                }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.backgroundColor.ignoresSafeArea())
            .navigationTitle("all_sessions".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("done".localized) { dismiss() }
                        .foregroundColor(theme.accentColor)
                }
            }
            .sheet(item: $sessionToEdit) { session in
                SessionEditView(session: session)
            }
        }
    }
}

#Preview {
    FocusTabView()
}