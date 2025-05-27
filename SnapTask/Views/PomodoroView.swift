import SwiftUI

struct PomodoroView: View {
    let task: TodoTask
    @StateObject private var viewModel = PomodoroViewModel.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingCompletionSheet = false
    @State private var completedFocusTime: TimeInterval = 0
    @AppStorage("pomodoroFocusColor") private var focusColorHex = "#4F46E5"
    @AppStorage("pomodoroBreakColor") private var breakColorHex = "#059669"
    
    private var focusColor: Color { Color(hex: focusColorHex) }
    private var breakColor: Color { Color(hex: breakColorHex) }
    
    init(task: TodoTask) {
        self.task = task
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Modern Header with gradient background
                VStack(spacing: 20) {
                    // Task Info Header with glassmorphism effect
                    HStack(spacing: 12) {
                        if let category = task.category {
                            Circle()
                                .fill(Color(hex: category.color))
                                .frame(width: 12, height: 12)
                        }
                        
                        Text(task.name)
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                            .lineLimit(1)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
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
                        
                        // Done button always visible
                        Button("Done") {
                            handleDone()
                        }
                        .font(.body.weight(.medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.1))
                        )
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
        .navigationBarBackButtonHidden(false)
        .onAppear {
            viewModel.setActiveTask(task)
        }
        .onChange(of: viewModel.state) { oldState, newState in
            if newState == .completed {
                // Calculate total focus time completed
                completedFocusTime = Double(viewModel.currentSession) * viewModel.settings.workDuration
                showingCompletionSheet = true
            }
        }
        .sheet(isPresented: $showingCompletionSheet) {
            PomodoroCompletionView(
                task: task,
                focusTimeCompleted: completedFocusTime
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .pomodoroCompleted)) { _ in
            dismiss()
        }
    }
    
    private func handleStop() {
        viewModel.stop()
    }
    
    private func handleDone() {
        // Always show completion sheet when Done is pressed, regardless of state
        if viewModel.state == .working || viewModel.state == .onBreak || viewModel.state == .paused {
            // Calculate focus time completed based on current progress
            let sessionProgress = viewModel.state == .working ? viewModel.progress : 1.0
            let completedFullSessions = max(0, viewModel.currentSession - 1)
            let currentSessionTime = sessionProgress * viewModel.settings.workDuration
            completedFocusTime = Double(completedFullSessions) * viewModel.settings.workDuration + currentSessionTime
            showingCompletionSheet = true
        } else if viewModel.state == .completed {
            showingCompletionSheet = true
        } else {
            // If not started, just dismiss
            dismiss()
        }
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

// Mini Floating Pomodoro Widget
struct MiniPomodoroWidget: View {
    @ObservedObject var viewModel: PomodoroViewModel
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Status indicator with task type
                HStack(spacing: 4) {
                    Circle()
                        .fill(viewModel.state == .working ? Color(hex: "#4F46E5") : Color(hex: "#059669"))
                        .frame(width: 8, height: 8)
                        .opacity(viewModel.state == .paused ? 0.5 : 1.0)
                        .symbolEffect(.pulse, options: .repeating, isActive: viewModel.state == .working || viewModel.state == .onBreak)
                    
                    // Session type
                    Text(viewModel.state == .working ? "Focus" : "Break")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: true, vertical: false)
                }
                
                // Time remaining
                Text(timeString(from: viewModel.timeRemaining))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.primary)
                
                // Progress bar
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 4)
                    .overlay(
                        GeometryReader { geo in
                            Capsule()
                                .fill(viewModel.state == .working ? Color(hex: "#4F46E5") : Color(hex: "#059669"))
                                .frame(width: max(4, geo.size.width * viewModel.progress))
                        }
                    )
                    .frame(width: 36)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                    .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .frame(height: 32)
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
