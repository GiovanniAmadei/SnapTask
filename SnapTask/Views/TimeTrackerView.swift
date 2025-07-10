import SwiftUI

struct TimeTrackerView: View {
    @ObservedObject private var viewModel: TimeTrackerViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    
    let task: TodoTask?
    let mode: TrackingMode
    let presentationStyle: PresentationStyle
    
    @State private var sessionId: UUID?
    
    enum PresentationStyle {
        case fullscreen
        case sheet
    }
    
    init(task: TodoTask?, mode: TrackingMode, taskManager: TaskManager, presentationStyle: PresentationStyle = .sheet) {
        self.task = task
        self.mode = mode
        self.presentationStyle = presentationStyle
        self.viewModel = TimeTrackerViewModel.shared
    }
    
    private var session: TrackingSession? {
        guard let sessionId = sessionId else { return nil }
        return viewModel.getSession(id: sessionId)
    }
    
    private var isCompactMode: Bool {
        presentationStyle == .sheet
    }
    
    var body: some View {
        ZStack {
            if !isCompactMode {
                LinearGradient(
                    colors: [
                        theme.backgroundColor,
                        theme.surfaceColor,
                        theme.backgroundColor
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
            
            if isCompactMode {
                compactLayout
            } else {
                fullscreenLayout
            }
        }
        .themedBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { 
                    dismiss() 
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .medium))
                        .themedPrimaryText()
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(theme.surfaceColor)
                        )
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 8) {
                    if isCompactMode {
                        Button(action: {
                            expandToFullscreen()
                        }) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(theme.accentColor)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(theme.accentColor.opacity(0.1))
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
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.red)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color.red.opacity(0.1))
                            )
                    }
                }
            }
        }
        .onAppear {
            // FIXED: Non creare automaticamente la sessione - sarà creata quando l'utente preme play
            // Questo previene la comparsa di timer widget a 00:00 che non sono mai stati avviati
        }
        .sheet(isPresented: $viewModel.showingCompletion) {
            if let completedSession = viewModel.completedSession {
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
                        viewModel.showingCompletion = false
                    }
                )
            }
        }
    }
    
    private var compactLayout: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                if let task = task {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(theme.accentColor)
                            .frame(width: 8, height: 8)
                        
                        Text(task.name)
                            .font(.system(size: 18, weight: .semibold))
                            .themedPrimaryText()
                            .lineLimit(1)
                        
                        Spacer()
                    }
                    
                    Text("Focus Session")
                        .font(.system(size: 14, weight: .medium))
                        .themedSecondaryText()
                } else {
                    Text("Timer Session")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .themedPrimaryText()
                }
            }
            .padding(.top, 8)
            
            ZStack {
                Circle()
                    .stroke(theme.borderColor, lineWidth: 4)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: session?.isRunning == true ? 
                            [theme.accentColor, theme.primaryColor] :
                            [theme.borderColor, theme.borderColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .animation(.easeInOut(duration: 0.5), value: session?.isRunning)
                
                VStack(spacing: 4) {
                    Text(formattedElapsedTime)
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .themedPrimaryText()
                    
                    if session?.isPaused == true {
                        Text("PAUSED")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.orange.opacity(0.1))
                            )
                    }
                }
            }
            
            Text(session?.isRunning == true ? 
                 (session?.isPaused == true ? "Tap play to resume" : "Session in progress") : 
                 "Ready to start tracking")
                .font(.system(size: 12, weight: .medium))
                .themedSecondaryText()
                .multilineTextAlignment(.center)
            
            Spacer()
            
            HStack(spacing: 20) {
                Button(action: {
                    if let sessionId = sessionId {
                        viewModel.stopSession(id: sessionId)
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "stop.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .shadow(color: Color.red.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .disabled(session?.isRunning != true)
                .opacity(session?.isRunning == true ? 1.0 : 0.5)
                
                Button(action: {
                    // FIXED: Crea la sessione solo quando l'utente preme play per la prima volta
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
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [theme.accentColor, theme.accentColor.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: session?.isRunning == true ? (session?.isPaused == true ? "play.fill" : "pause.fill") : "play.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .shadow(color: theme.accentColor.opacity(0.3), radius: 6, x: 0, y: 3)
                }
                
                if isCompactMode {
                    Button(action: {
                        if let sessionId = sessionId {
                            viewModel.stopSession(id: sessionId)
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .shadow(color: Color.green.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .disabled(session?.isRunning != true)
                    .opacity(session?.isRunning == true ? 1.0 : 0.5)
                }
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
    }
    
    private var fullscreenLayout: some View {
        VStack(spacing: 40) {
            VStack(spacing: 16) {
                if let task = task {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: task.icon)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(theme.accentColor)
                            
                            Text(task.name)
                                .font(.system(size: 18, weight: .semibold))
                                .themedPrimaryText()
                        }
                        
                        Text("Focus Session")
                            .font(.system(size: 14, weight: .medium))
                            .themedSecondaryText()
                    }
                } else {
                    Text("Timer Session")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .themedPrimaryText()
                }
            }
            .padding(.top, 20)
            
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    theme.accentColor.opacity(0.1),
                                    theme.accentColor.opacity(0.05),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 80,
                                endRadius: 120
                            )
                        )
                        .frame(width: 240, height: 240)
                        .blur(radius: 8)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: session?.isRunning)
                    
                    Circle()
                        .stroke(theme.borderColor, lineWidth: 8)
                        .frame(width: 200, height: 200)
                    
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: session?.isRunning == true ? 
                                [theme.accentColor, theme.primaryColor] :
                                [theme.borderColor, theme.borderColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 200, height: 200)
                        .animation(.easeInOut(duration: 0.5), value: session?.isRunning)
                    
                    VStack(spacing: 8) {
                        Text(formattedElapsedTime)
                            .font(.system(size: 36, weight: .medium, design: .monospaced))
                            .themedPrimaryText()
                            .shadow(color: theme.shadowColor, radius: 2, x: 0, y: 1)
                        
                        if session?.isPaused == true {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 6, height: 6)
                                
                                Text("PAUSED")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.orange.opacity(0.1))
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                    }
                }
                
                if session?.isRunning == true {
                    Text(session?.isPaused == true ? "Tap play to resume" : "Session in progress")
                        .font(.system(size: 16, weight: .medium))
                        .themedSecondaryText()
                } else {
                    Text("Ready to start tracking")
                        .font(.system(size: 16, weight: .medium))
                        .themedSecondaryText()
                }
            }
            
            Spacer()
            
            VStack(spacing: 20) {
                TrackingControlButtons(
                    isRunning: session?.isRunning == true,
                    isPaused: session?.isPaused == true,
                    onPlayPause: {
                        // FIXED: Crea la sessione solo quando l'utente preme play per la prima volta
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
                    onStop: {
                        if let sessionId = sessionId {
                            viewModel.stopSession(id: sessionId)
                        }
                    }
                )
            }
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 20)
    }
    
    private var formattedElapsedTime: String {
        guard let sessionId = sessionId else { return "00:00" }
        return viewModel.formattedElapsedTime(for: sessionId)
    }
    
    private func expandToFullscreen() {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: .expandActiveTimer, object: nil)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(name: .openFocusTabTimeTracker, object: nil)
        }
    }
}

extension Notification.Name {
    static let openFocusTabTimeTracker = Notification.Name("openFocusTabTimeTracker")
    static let openFocusTabPomodoro = Notification.Name("openFocusTabPomodoro")
    static let expandActiveTimer = Notification.Name("expandActiveTimer")
    static let expandActivePomodoro = Notification.Name("expandActivePomodoro")
}

#Preview {
    TimeTrackerView(
        task: TodoTask(name: "Sample Task", startTime: Date()),
        mode: .simple,
        taskManager: TaskManager(),
        presentationStyle: .sheet
    )
}