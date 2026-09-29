import SwiftUI

struct WatchPomodoroView: View {
    var task: TodoTask?
    let settings: PomodoroSettings
    @EnvironmentObject var syncManager: WatchSyncManager
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var timerEngine = WatchTimerEngine.shared

    // Local display state mirrors the shared engine so the UI stays responsive
    // while the engine persists and drives the timer in the background.
    @State private var currentSession: Int = 1
    @State private var isWorkPhase: Bool = true
    @State private var timeRemaining: TimeInterval = 0
    @State private var isRunning: Bool = false
    @State private var isPaused: Bool = false
    @State private var totalWorkTime: TimeInterval = 0
    @State private var showingCompletion: Bool = false
    @State private var completedSessionCount: Int = 0
    @State private var completedTotalWorkTime: TimeInterval = 0
    
    private var currentPhaseDuration: TimeInterval {
        if isWorkPhase {
            return settings.workDuration
        } else {
            // Long break after every N sessions
            if currentSession % settings.sessionsUntilLongBreak == 0 {
                return settings.longBreakDuration
            }
            return settings.breakDuration
        }
    }
    
    private var progress: CGFloat {
        guard currentPhaseDuration > 0 else { return 0 }
        return CGFloat(currentPhaseDuration - timeRemaining) / CGFloat(currentPhaseDuration)
    }
    
    private var phaseColor: Color {
        isWorkPhase ? .orange : .green
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Session indicator
            sessionIndicator
            
            // Timer display
            timerDisplay
            
            // Controls
            controlButtons
        }
        .padding(.horizontal, 8)
        .navigationTitle(isWorkPhase ? "Focus" : "Break")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isRunning || isPaused)
        .toolbar {
            if isRunning || isPaused {
                ToolbarItem(placement: .cancellationAction) {
                    Button("End") {
                        endSession()
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .onAppear {
            timerEngine.restorePersistedStateIfNeeded()
            syncLocalStateFromEngine()
        }
        .onChange(of: timerEngine.now) { _, _ in
            syncLocalStateFromEngine()
        }
        .onChange(of: timerEngine.completedPomodoroSession?.id) { _, _ in
            handleCompletionFromEngine()
        }
        .sheet(isPresented: $showingCompletion) {
            completionView
        }
    }
    
    private var sessionIndicator: some View {
        HStack(spacing: 4) {
            ForEach(1...settings.totalSessions, id: \.self) { session in
                Circle()
                    .fill(session < currentSession ? Color.orange :
                          session == currentSession ? phaseColor : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }
    
    private var timerDisplay: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 10)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: progress)
                .stroke(phaseColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: progress)
            
            // Center content
            VStack(spacing: 4) {
                Text(formatTime(timeRemaining))
                    .font(.system(.title2, design: .monospaced, weight: .bold))
                
                Text(isWorkPhase ? "Focus" : "Break")
                    .font(.caption2)
                    .foregroundColor(phaseColor)
                
                Text("Session \(currentSession)/\(settings.totalSessions)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 130, height: 130)
    }
    
    private var controlButtons: some View {
        HStack(spacing: 16) {
            // Skip button (only during break)
            if !isWorkPhase && (isRunning || isPaused) {
                Button {
                    skipBreak()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.gray)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            
            // Play/Pause button
            Button {
                if isRunning {
                    pauseTimer()
                } else {
                    startTimer()
                }
            } label: {
                Image(systemName: isRunning ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(isRunning ? Color.orange : Color.green)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            // Stop button
            if isRunning || isPaused {
                Button {
                    endSession()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.red)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var completionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.green)
            
            Text("Pomodoro Complete!")
                .font(.headline)
            
            VStack(spacing: 4) {
                Text("\(completedSessionCount) sessions")
                    .font(.caption)
                
                Text("Total focus: \(formatTime(completedTotalWorkTime))")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.orange)
            }
            
            if let task = task {
                Text(task.name)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Button("Done") {
                showingCompletion = false
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    // MARK: - Timer Control
    private func startTimer() {
        if isPaused {
            timerEngine.resumePomodoro()
        } else {
            timerEngine.startPomodoro(task: task, settings: settings)
            currentSession = 1
            isWorkPhase = true
            timeRemaining = settings.workDuration
            totalWorkTime = 0
        }

        syncLocalStateFromEngine()
        HapticService.shared.play(.start)
    }

    private func pauseTimer() {
        timerEngine.pausePomodoro()
        syncLocalStateFromEngine()
        HapticService.shared.play(.click)
    }

    private func skipBreak() {
        timerEngine.skipBreak()
        syncLocalStateFromEngine()
        HapticService.shared.play(.click)
    }

    private func endSession() {
        let result = timerEngine.endPomodoro()
        if let completedSession = result.session {
            syncManager.saveTrackingSession(completedSession)
            completedSessionCount = currentSession
            completedTotalWorkTime = result.totalWorkTime
            showingCompletion = true
            timerEngine.consumeCompletedPomodoroSession()
            HapticService.shared.play(.success)
        }
        resetLocalState()
    }

    private func handleCompletionFromEngine() {
        guard let completedSession = timerEngine.completedPomodoroSession else { return }
        syncManager.saveTrackingSession(completedSession)
        completedSessionCount = currentSession
        completedTotalWorkTime = completedSession.elapsedTime
        showingCompletion = true
        timerEngine.consumeCompletedPomodoroSession()
        resetLocalState()
        HapticService.shared.play(.success)
    }

    private func syncLocalStateFromEngine() {
        if timerEngine.pomodoroIsRunning || timerEngine.pomodoroIsPaused {
            currentSession = timerEngine.pomodoroCurrentSession
            isWorkPhase = timerEngine.pomodoroIsWorkPhase
            timeRemaining = timerEngine.pomodoroTimeRemaining
            isRunning = timerEngine.pomodoroIsRunning
            isPaused = timerEngine.pomodoroIsPaused
            totalWorkTime = timerEngine.pomodoroTotalWorkTime
        } else if currentSession == 1 && !isRunning && !isPaused && timeRemaining == 0 {
            resetLocalState()
        }
    }

    private func resetLocalState() {
        currentSession = 1
        isWorkPhase = true
        timeRemaining = settings.workDuration
        isRunning = false
        isPaused = false
        totalWorkTime = 0
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    NavigationStack {
        WatchPomodoroView(
            task: nil,
            settings: .defaultSettings
        )
        .environmentObject(WatchSyncManager.shared)
    }
}
