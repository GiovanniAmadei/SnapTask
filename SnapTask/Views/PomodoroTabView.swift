import SwiftUI

struct PomodoroTabView: View {
    @StateObject private var viewModel = PomodoroViewModel.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingCompletionSheet = false
    @State private var completedFocusTime: TimeInterval = 0
    @AppStorage("pomodoroFocusColor") private var focusColorHex = "#4F46E5"
    @AppStorage("pomodoroBreakColor") private var breakColorHex = "#059669"
    
    private var focusColor: Color { Color(hex: focusColorHex) }
    private var breakColor: Color { Color(hex: breakColorHex) }
    
    // Create a placeholder task for general pomodoro sessions
    private var generalPomodoroTask: TodoTask {
        TodoTask(
            name: "General Focus Session",
            description: "General pomodoro session",
            startTime: Date(),
            category: nil,
            priority: .medium,
            icon: "brain.head.profile"
        )
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Modern Header with gradient background
                    VStack(spacing: 20) {
                        // Session indicator and Done button
                        HStack {
                            // Session indicator
                            HStack(spacing: 4) {
                                Text("Session")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(viewModel.currentSession)/\(viewModel.totalSessions)")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color(.systemGray6))
                            )
                            
                            Spacer()
                            
                            // Settings button
                            NavigationLink {
                                PomodoroSettingsView(settings: $viewModel.settings)
                            } label: {
                                Image(systemName: "gear")
                                    .font(.body.weight(.medium))
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(Color.blue.opacity(0.1))
                                    )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        
                        // Large Timer Display with modern design
                        ZStack {
                            // Outer progress ring - subtle background
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            (viewModel.state == .working ? focusColor : breakColor).opacity(0.1),
                                            (viewModel.state == .working ? focusColor : breakColor).opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 8
                                )
                                .frame(width: 280, height: 280)
                            
                            // Progress ring with gradient
                            Circle()
                                .trim(from: 0.0, to: viewModel.progress)
                                .stroke(
                                    LinearGradient(
                                        colors: viewModel.state == .working ? 
                                            [focusColor, focusColor.opacity(0.7)] : [breakColor, breakColor.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(
                                        lineWidth: 8,
                                        lineCap: .round
                                    )
                                )
                                .frame(width: 280, height: 280)
                                .rotationEffect(Angle(degrees: -90))
                                .animation(.easeInOut(duration: 0.3), value: viewModel.progress)
                            
                            // Inner content
                            VStack(spacing: 12) {
                                // Session state with icon
                                HStack(spacing: 6) {
                                    Image(systemName: viewModel.state == .working ? "brain.head.profile" : "cup.and.saucer.fill")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(viewModel.state == .working ? focusColor : breakColor)
                                    
                                    Text(viewModel.state == .working ? "Focus Time" : "Break Time")
                                        .font(.system(.headline, design: .rounded))
                                        .foregroundColor(.secondary)
                                }
                                
                                // Large time display
                                Text(timeString(from: viewModel.timeRemaining))
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: viewModel.state == .working ? 
                                                [focusColor, focusColor.opacity(0.7)] : [breakColor, breakColor.opacity(0.7)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .contentTransition(.numericText())
                                
                                // Progress percentage
                                Text("\(Int(viewModel.progress * 100))%")
                                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 20)
                    }
                    .background(
                        LinearGradient(
                            colors: [
                                Color(.systemBackground),
                                Color(.systemGray6).opacity(0.3)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    // Session Timeline - Redesigned
                    VStack(spacing: 16) {
                        HStack {
                            Text("Session Overview")
                                .font(.headline.weight(.semibold))
                            Spacer()
                            Text("\(formatTime(viewModel.timeRemaining)) left")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        
                        ModernSessionTimeline(viewModel: viewModel)
                            .padding(.horizontal, 24)
                    }
                    
                    Spacer()
                    
                    // Modern Control Buttons
                    VStack(spacing: 20) {
                        // Primary Control Row
                        HStack(spacing: 24) {
                            // Stop Button
                            ControlButton(
                                icon: "stop.fill",
                                size: .medium,
                                color: .red,
                                isDisabled: viewModel.state == .notStarted || viewModel.state == .completed
                            ) {
                                handleStop()
                            }
                            
                            // Main Play/Pause Button
                            ControlButton(
                                icon: viewModel.state == .working || viewModel.state == .onBreak ? 
                                    "pause.fill" : "play.fill",
                                size: .large,
                                color: viewModel.state == .working ? focusColor : 
                                       viewModel.state == .onBreak ? breakColor : .primary,
                                isPulsing: viewModel.state == .working || viewModel.state == .onBreak
                            ) {
                                if viewModel.state == .notStarted || viewModel.state == .paused {
                                    viewModel.start()
                                } else {
                                    viewModel.pause()
                                }
                            }
                            
                            // Skip Button
                            ControlButton(
                                icon: "forward.fill",
                                size: .medium,
                                color: viewModel.state == .working ? focusColor : 
                                       viewModel.state == .onBreak ? breakColor : .primary,
                                isDisabled: viewModel.state == .notStarted || viewModel.state == .completed
                            ) {
                                viewModel.skip()
                            }
                        }
                        
                        // Additional info
                        if viewModel.state != .notStarted {
                            let completionTime = Date().addingTimeInterval(viewModel.timeRemaining)
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Finishes at \(formatTimeOnly(completionTime))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Pomodoro")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: viewModel.state) { oldState, newState in
                if newState == .completed {
                    // Calculate total focus time completed
                    completedFocusTime = Double(viewModel.currentSession) * viewModel.settings.workDuration
                    showingCompletionSheet = true
                }
            }
            .sheet(isPresented: $showingCompletionSheet) {
                PomodoroCompletionView(
                    task: generalPomodoroTask, 
                    focusTimeCompleted: completedFocusTime
                )
            }
        }
    }
    
    private func handleStop() {
        viewModel.stop()
    }
    
    private func formatTimeOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        return "\(minutes) min"
    }
}
