import SwiftUI

struct SessionTimeTrackerView: View {
    let sessionId: UUID
    @ObservedObject private var viewModel: TimeTrackerViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    let presentationStyle: PresentationStyle
    
    enum PresentationStyle {
        case fullscreen
        case sheet
    }
    
    init(sessionId: UUID, viewModel: TimeTrackerViewModel, presentationStyle: PresentationStyle = .sheet) {
        self.sessionId = sessionId
        self.viewModel = viewModel
        self.presentationStyle = presentationStyle
    }
    
    private var session: TrackingSession? {
        viewModel.getSession(id: sessionId)
    }
    
    private var isCompactMode: Bool {
        presentationStyle == .sheet
    }
    
    private var backgroundColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(hex: "1a1a1a"),
                Color(hex: "2d2d2d"),
                Color(hex: "1a1a1a")
            ]
        } else {
            return [
                Color(hex: "f8f9fa"),
                Color(hex: "e9ecef"),
                Color(hex: "f8f9fa")
            ]
        }
    }
    
    private var textColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.7)
    }
    
    private var glowColor: Color {
        colorScheme == .dark ? Color(hex: "5E5CE6").opacity(0.3) : Color(hex: "5E5CE6").opacity(0.1)
    }
    
    private var trackColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)
    }
    
    var body: some View {
        Group {
            if let session = session {
                if isCompactMode {
                    compactLayout
                        .background(Color(.systemBackground))
                } else {
                    fullscreenLayout
                }
            } else {
                Text("Session not available.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(isCompactMode ? Color(.systemBackground) : Color.clear)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                        )
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 8) {
                    if isCompactMode {
                        Button(action: {
                            // Expansion logic if re-enabled
                        }) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(Color.blue.opacity(0.1))
                                )
                        }
                    }
                    
                    Button(action: {
                        viewModel.removeSession(id: sessionId)
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
            if let sessionOnAppear = self.session {
                if !sessionOnAppear.isRunning && !sessionOnAppear.isPaused {
                    viewModel.startTimer(for: sessionId)
                }
            } else {
                dismiss()
            }
        }
        .sheet(isPresented: $viewModel.showingCompletion) {
            if let completedSession = viewModel.completedSession {
                TimeTrackingCompletionView(
                    task: nil,
                    session: completedSession,
                    onSave: {
                        viewModel.saveSession(id: sessionId)
                        dismiss()
                    },
                    onDiscard: {
                        viewModel.discardSession(id: sessionId)
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
                if let taskName = session?.taskName {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(hex: "5E5CE6"))
                            .frame(width: 8, height: 8)
                        
                        Text(taskName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                    }
                    
                    Text("Focus Session")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                } else {
                    Text("Timer Session")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                }
            }
            .padding(.top, 8)
            
            ZStack {
                Circle()
                    .stroke(trackColor, lineWidth: 4)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: session?.isRunning == true ?
                            [Color(hex: "5E5CE6"), Color(hex: "9747FF")] :
                            [trackColor, trackColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .animation(.easeInOut(duration: 0.5), value: session?.isRunning)
                
                VStack(spacing: 4) {
                    Text(viewModel.formattedElapsedTime(for: sessionId))
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                    
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
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            HStack(spacing: 20) {
                Button(action: {
                    viewModel.stopSession(id: sessionId)
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
                                    colors: [Color(hex: "5E5CE6"), Color(hex: "5E5CE6").opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: session?.isRunning == true ? (session?.isPaused == true ? "play.fill" : "pause.fill") : "play.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .shadow(color: Color(hex: "5E5CE6").opacity(0.3), radius: 6, x: 0, y: 3)
                }
                
                if isCompactMode {
                    Button(action: {
                        viewModel.stopSession(id: sessionId)
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
        ZStack {
            LinearGradient(
                colors: backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                VStack(spacing: 16) {
                    if let taskName = session?.taskName {
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "stopwatch")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color(hex: "5E5CE6"))
                                
                                Text(taskName)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(textColor)
                            }
                            
                            Text("Focus Session")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(secondaryTextColor)
                        }
                    } else {
                        Text("Timer Session")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundColor(textColor)
                    }
                }
                .padding(.top, 20)
                
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        glowColor,
                                        glowColor.opacity(0.5),
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
                            .stroke(trackColor, lineWidth: 8)
                            .frame(width: 200, height: 200)
                        
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: session?.isRunning == true ?
                                    [Color(hex: "5E5CE6"), Color(hex: "9747FF")] :
                                    [trackColor, trackColor],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 200, height: 200)
                            .animation(.easeInOut(duration: 0.5), value: session?.isRunning)
                        
                        VStack(spacing: 8) {
                            Text(viewModel.formattedElapsedTime(for: sessionId))
                                .font(.system(size: 36, weight: .medium, design: .monospaced))
                                .foregroundColor(textColor)
                                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 2, x: 0, y: 1)
                            
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
                            .foregroundColor(secondaryTextColor)
                    } else {
                        Text("Ready to start tracking")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(secondaryTextColor)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 20) {
                    TrackingControlButtons(
                        isRunning: session?.isRunning == true,
                        isPaused: session?.isPaused == true,
                        onPlayPause: {
                            if session?.isRunning != true {
                                viewModel.startTimer(for: sessionId)
                            } else if session?.isPaused == true {
                                viewModel.resumeSession(id: sessionId)
                            } else {
                                viewModel.pauseSession(id: sessionId)
                            }
                        },
                        onStop: {
                            viewModel.stopSession(id: sessionId)
                        }
                    )
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 20)
        }
    }
}

#Preview {
    SessionTimeTrackerView(
        sessionId: UUID(),
        viewModel: TimeTrackerViewModel.shared,
        presentationStyle: .sheet
    )
}
