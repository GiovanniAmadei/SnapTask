import SwiftUI

struct TimeTrackerView: View {
    @ObservedObject private var viewModel: TimeTrackerViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    
    let task: TodoTask?
    let mode: TrackingMode
    let presentationStyle: PresentationStyle
    let allowExpand: Bool
    
    @State private var sessionId: UUID?
    
    enum PresentationStyle {
        case fullscreen
        case sheet
    }
    
    init(task: TodoTask?, mode: TrackingMode, taskManager: TaskManager, presentationStyle: PresentationStyle = .sheet, allowExpand: Bool = true) {
        self.task = task
        self.mode = mode
        self.presentationStyle = presentationStyle
        self.allowExpand = allowExpand
        self.viewModel = TimeTrackerViewModel.shared
        
        // Connect to existing active session for this task if one already exists
        if let task = task,
           let existing = TimeTrackerViewModel.shared.activeSessions.first(where: { $0.taskId == task.id }) {
            self._sessionId = State(initialValue: existing.id)
        } else if task == nil,
                  let existing = TimeTrackerViewModel.shared.activeSessions.first(where: { $0.taskId == nil }) {
            self._sessionId = State(initialValue: existing.id)
        } else {
            self._sessionId = State(initialValue: nil)
        }
    }
    
    init(sessionId: UUID, presentationStyle: PresentationStyle = .sheet, allowExpand: Bool = true) {
        self.viewModel = TimeTrackerViewModel.shared
        self.presentationStyle = presentationStyle
        self.allowExpand = allowExpand
        self._sessionId = State(initialValue: sessionId)
        
        // Get task and mode from the existing session
        if let session = TimeTrackerViewModel.shared.getSession(id: sessionId) {
            if let taskId = session.taskId {
                self.task = TaskManager.shared.tasks.first(where: { $0.id == taskId })
            } else {
                self.task = nil
            }
            self.mode = session.mode
        } else {
            self.task = nil
            self.mode = .simple
        }
    }
    
    private var session: TrackingSession? {
        guard let sessionId = sessionId else { return nil }
        return viewModel.getSession(id: sessionId)
    }
    
    private var isCompactMode: Bool {
        presentationStyle == .sheet
    }
    
    var body: some View {
        Group {
            if viewModel.showingCompletion, let completedSession = viewModel.completedSession {
                TimeTrackingCompletionView(
                    task: task,
                    session: completedSession,
                    onSave: {
                        if let sessionId = sessionId {
                            viewModel.saveSession(id: sessionId)
                        }
                        dismiss()
                    },
                    onDiscard: {
                        if let sessionId = sessionId {
                            viewModel.discardSession(id: sessionId)
                        }
                        dismiss()
                    },
                    onContinue: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            viewModel.completedSession = nil
                            viewModel.showingCompletion = false
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.96)),
                    removal: .opacity
                ))
            } else {
                mainTimerContent
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: viewModel.showingCompletion)
        .presentationDetents(viewModel.showingCompletion ? [.large] : [.height(410), .medium, .large])
    }
    
    private var mainTimerContent: some View {
        ZStack {
            theme.backgroundColor
                .ignoresSafeArea()
            
            if isCompactMode {
                compactLayout
            } else {
                fullscreenLayout
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarHidden(true)
    }
    
    // MARK: - Compact Sheet Layout
    private var compactLayout: some View {
        VStack(spacing: 0) {
            // Custom integrated header row with minus, pill, expand/close
            ZStack {
                // Center: Category or Timer Badge Pill
                if let task = task {
                    HStack(spacing: 5) {
                        if let category = task.category {
                            Circle()
                                .fill(Color(hex: category.color))
                                .frame(width: 7, height: 7)
                            Text(category.name.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: category.color))
                        } else {
                            Circle()
                                .fill(theme.accentColor)
                                .frame(width: 7, height: 7)
                            Text("TIMER".localized)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(theme.accentColor)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill((task.category.map { Color(hex: $0.color) } ?? theme.accentColor).opacity(0.14))
                    )
                } else {
                    HStack(spacing: 5) {
                        Image(systemName: "stopwatch.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(theme.accentColor)
                        Text("TIMER".localized)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(theme.accentColor)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(theme.accentColor.opacity(0.14))
                    )
                }
                
                HStack(alignment: .center) {
                    // Leading: Collapse button
                    Button(action: { 
                        dismiss() 
                    }) {
                        Image(systemName: "minus")
                            .font(.system(size: 15, weight: .bold))
                            .themedPrimaryText()
                            .frame(width: 34, height: 34)
                            .background(
                                Circle()
                                    .fill(theme.surfaceColor)
                                    .shadow(color: theme.shadowColor.opacity(0.4), radius: 4, x: 0, y: 1)
                            )
                    }
                    
                    Spacer()
                    
                    // Trailing: Expand + Close buttons
                    HStack(spacing: 8) {
                        if allowExpand {
                            Button(action: {
                                expandToFullscreen()
                            }) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(theme.accentColor)
                                    .frame(width: 34, height: 34)
                                    .background(
                                        Circle()
                                            .fill(theme.accentColor.opacity(0.12))
                                    )
                            }
                        }
                        
                        Button(action: { 
                            if let sessionId = sessionId {
                                viewModel.removeSession(id: sessionId)
                            }
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.red)
                                .frame(width: 34, height: 34)
                                .background(
                                    Circle()
                                        .fill(Color.red.opacity(0.12))
                                )
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            
            // Task Title (bold, centered, beautiful)
            if let task = task {
                Text(task.name)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .themedPrimaryText()
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            } else {
                Text("simple_timer".localized)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .themedPrimaryText()
                    .padding(.top, 8)
            }
            
            Spacer(minLength: 8)
            
            // Hero Timer Ring
            ZStack {
                // Ambient soft glow
                Circle()
                    .fill(theme.accentColor.opacity(0.14))
                    .frame(width: 170, height: 170)
                    .blur(radius: 16)
                    .opacity(session?.isRunning == true ? 1.0 : 0.3)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: session?.isRunning)
                
                // Soft inner surface plate
                Circle()
                    .fill(theme.surfaceColor)
                    .frame(width: 142, height: 142)
                    .shadow(color: theme.shadowColor.opacity(0.6), radius: 8, x: 0, y: 3)
                
                // Background Track
                Circle()
                    .stroke(theme.borderColor.opacity(0.35), lineWidth: 6)
                    .frame(width: 142, height: 142)
                
                // Active gradient ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: session?.isRunning == true ? 
                            [theme.accentColor, theme.primaryColor] :
                            [theme.borderColor.opacity(0.4), theme.borderColor.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 142, height: 142)
                    .animation(.easeInOut(duration: 0.4), value: session?.isRunning)
                
                VStack(spacing: 5) {
                    Text(formattedElapsedTime)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .themedPrimaryText()
                        .contentTransition(.numericText())
                    
                    // State indicator pill
                    if session?.isPaused == true {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 5, height: 5)
                            
                            Text("paused".localized.uppercased())
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.orange.opacity(0.12))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.orange.opacity(0.3), lineWidth: 0.8)
                                )
                        )
                    } else if session?.isRunning == true {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 5, height: 5)
                            
                            Text("running".localized.uppercased())
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.12))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.green.opacity(0.3), lineWidth: 0.8)
                                )
                        )
                    } else {
                        Text("ready_to_start".localized)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .themedSecondaryText()
                    }
                }
            }
            
            Spacer(minLength: 8)
            
            // Action controls (Play/Pause LEFT, Checkmark RIGHT)
            HStack(spacing: 24) {
                // Play/Pause Hero Button
                Button(action: {
                    if sessionId == nil {
                        if let task = task {
                            sessionId = viewModel.startSession(for: task, mode: mode)
                        } else {
                            sessionId = viewModel.startGeneralSession(mode: mode)
                        }
                    }
                    
                    guard let sessionId = sessionId else { return }
                    
                    if session?.isRunning != true {
                        HapticManager.shared.impact(.medium)
                        viewModel.startTimer(for: sessionId)
                    } else if session?.isPaused == true {
                        HapticManager.shared.impact(.medium)
                        viewModel.resumeSession(id: sessionId)
                    } else {
                        HapticManager.shared.impact(.light)
                        viewModel.pauseSession(id: sessionId)
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [theme.accentColor, theme.primaryColor],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 64, height: 64)
                        
                        Image(systemName: session?.isRunning == true ? (session?.isPaused == true ? "play.fill" : "pause.fill") : "play.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .shadow(color: theme.accentColor.opacity(0.38), radius: 8, x: 0, y: 4)
                }
                
                // Complete Button (Checkmark) on the RIGHT
                Button(action: {
                    HapticManager.shared.impact(.medium)
                    if let sessionId = sessionId {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            viewModel.stopSession(id: sessionId)
                        }
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.14))
                            .frame(width: 52, height: 52)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.green)
                    }
                    .overlay(
                        Circle()
                            .stroke(Color.green.opacity(0.35), lineWidth: 1.5)
                    )
                    .shadow(color: Color.green.opacity(0.22), radius: 5, x: 0, y: 2)
                }
                .disabled(session?.isRunning != true && session?.isPaused != true)
                .opacity((session?.isRunning == true || session?.isPaused == true) ? 1.0 : 0.4)
                .scaleEffect((session?.isRunning == true || session?.isPaused == true) ? 1.0 : 0.95)
                .animation(.easeInOut(duration: 0.2), value: session?.isRunning == true || session?.isPaused == true)
            }
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.backgroundColor.ignoresSafeArea())
    }
    
    // MARK: - Fullscreen Layout
    private var fullscreenLayout: some View {
        VStack(spacing: 40) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "minus")
                        .font(.system(size: 15, weight: .bold))
                        .themedPrimaryText()
                        .frame(width: 34, height: 34)
                        .background(
                            Circle()
                                .fill(theme.surfaceColor)
                                .shadow(color: theme.shadowColor.opacity(0.3), radius: 3, x: 0, y: 1)
                        )
                }
                
                Spacer()
                
                Button(action: {
                    if let sessionId = sessionId {
                        viewModel.removeSession(id: sessionId)
                    }
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.red)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle()
                                .fill(Color.red.opacity(0.12))
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            VStack(spacing: 16) {
                if let task = task {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            if let category = task.category {
                                Circle()
                                    .fill(Color(hex: category.color))
                                    .frame(width: 8, height: 8)
                            }
                            
                            Text(task.name)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .themedPrimaryText()
                        }
                        
                        Text("focus_session".localized)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .themedSecondaryText()
                    }
                } else {
                    Text("simple_timer".localized)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .themedPrimaryText()
                }
            }
            
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    theme.accentColor.opacity(0.12),
                                    theme.accentColor.opacity(0.04),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 80,
                                endRadius: 130
                            )
                        )
                        .frame(width: 250, height: 250)
                        .blur(radius: 12)
                        .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: session?.isRunning)
                    
                    Circle()
                        .fill(theme.surfaceColor.opacity(0.6))
                        .frame(width: 210, height: 210)
                        .shadow(color: theme.shadowColor.opacity(0.5), radius: 10, x: 0, y: 4)

                    Circle()
                        .stroke(theme.borderColor.opacity(0.3), lineWidth: 8)
                        .frame(width: 210, height: 210)
                    
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: session?.isRunning == true ? 
                                [theme.accentColor, theme.primaryColor] :
                                [theme.borderColor.opacity(0.4), theme.borderColor.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 210, height: 210)
                        .shadow(color: session?.isRunning == true ? theme.accentColor.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 0)
                        .animation(.easeInOut(duration: 0.3), value: session?.isRunning)
                    
                    VStack(spacing: 8) {
                        Text(formattedElapsedTime)
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .themedPrimaryText()
                            .contentTransition(.numericText())
                        
                        if session?.isPaused == true {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 6, height: 6)
                                    .shadow(color: Color.orange.opacity(0.8), radius: 2)
                                
                                Text("paused".localized.uppercased())
                                    .font(.system(.caption2, design: .rounded).weight(.bold))
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.orange.opacity(0.12))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        } else if session?.isRunning == true {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                                    .shadow(color: Color.green.opacity(0.8), radius: 2)
                                
                                Text("running".localized.uppercased())
                                    .font(.system(.caption2, design: .rounded).weight(.bold))
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.green.opacity(0.12))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                    }
                }
                
                if session?.isRunning == true {
                    Text(session?.isPaused == true ? "tap_play_to_resume".localized : "session_in_progress".localized)
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .themedSecondaryText()
                } else {
                    Text("ready_to_start".localized)
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .themedSecondaryText()
                }
            }
            
            Spacer()
            
            TrackingControlButtons(
                isRunning: session?.isRunning == true,
                isPaused: session?.isPaused == true,
                onPlayPause: {
                    if sessionId == nil {
                        if let task = task {
                            sessionId = viewModel.startSession(for: task, mode: mode)
                        } else {
                            sessionId = viewModel.startGeneralSession(mode: mode)
                        }
                    }
                    
                    guard let sessionId = sessionId else { return }
                    
                    if session?.isRunning != true {
                        viewModel.startTimer(for: sessionId)
                    } else if session?.isPaused == true {
                        viewModel.resumeSession(id: sessionId)
                    } else {
                        viewModel.pauseSession(id: sessionId)
                    }
                },
                onComplete: {
                    if let sessionId = sessionId {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            viewModel.stopSession(id: sessionId)
                        }
                    }
                }
            )
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.backgroundColor.ignoresSafeArea())
    }
    
    private var formattedElapsedTime: String {
        guard let sessionId = sessionId else { return "00:00" }
        return viewModel.formattedElapsedTime(for: sessionId)
    }
    
    private func expandToFullscreen() {
        let currentSessionId = sessionId
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: .expandActiveTimer, object: currentSessionId)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(name: .openFocusTabTimeTracker, object: currentSessionId)
        }
    }
}