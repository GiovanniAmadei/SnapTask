import SwiftUI

struct PomodoroView: View {
    let task: TodoTask
    @StateObject private var viewModel = PomodoroViewModel.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    init(task: TodoTask) {
        self.task = task
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Top section with task info
            TaskInfoHeader(task: task)
            
            // Timer Display
            ZStack {
                // Background circle
                Circle()
                    .stroke(lineWidth: 20)
                    .opacity(0.08)
                    .foregroundColor(viewModel.state == .working ? .blue : .green)
                
                // Progress circle
                Circle()
                    .trim(from: 0.0, to: viewModel.progress)
                    .stroke(style: StrokeStyle(
                        lineWidth: 20,
                        lineCap: .round
                    ))
                    .foregroundColor(viewModel.state == .working ? .blue : .green)
                    .rotationEffect(Angle(degrees: -90))
                    .animation(.linear(duration: 0.1), value: viewModel.progress)
                
                // Time and Session Display
                VStack(spacing: 6) {
                    // Session state
                    Text(viewModel.state == .working ? "Focus Time" : "Break Time")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    // Time remaining
                    Text(timeString(from: viewModel.timeRemaining))
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(viewModel.state == .working ? .blue : .green)
                    
                    // Session progress
                    Text("Session \(viewModel.currentSession) of \(viewModel.totalSessions)")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 220)
            
            // Compact info below time
            HStack(spacing: 16) {
                if let category = task.category {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: category.color))
                            .frame(width: 8, height: 8)
                        
                        Text(category.name)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                if task.hasDuration && task.duration > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(formatDuration(task.duration))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Show expected completion time
                if viewModel.state != .notStarted {
                    let completionTime = Date().addingTimeInterval(viewModel.timeRemaining)
                    HStack(spacing: 4) {
                        Image(systemName: "flag.checkered")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(formatTimeOnly(completionTime))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            
            // Session Timeline Visualization
            SessionTimelineView(viewModel: viewModel)
                .padding(.horizontal, 16)
            
            Spacer()
            
            // Controls
            HStack(spacing: 30) {
                // Stop Button
                Button(action: {
                    viewModel.stop()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.12))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "stop.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.red)
                    }
                }
                .disabled(viewModel.state == .notStarted || viewModel.state == .completed)
                
                // Play/Pause Button (Larger)
                Button(action: {
                    if viewModel.state == .notStarted || viewModel.state == .paused {
                        viewModel.start()
                    } else {
                        viewModel.pause()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(viewModel.state == .working ? Color.blue.opacity(0.12) : 
                                  viewModel.state == .onBreak ? Color.green.opacity(0.12) : 
                                  Color.primary.opacity(0.08))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: viewModel.state == .working || viewModel.state == .onBreak ? 
                              "pause.fill" : "play.fill")
                            .font(.system(size: 30))
                            .foregroundColor(viewModel.state == .working ? .blue : 
                                             viewModel.state == .onBreak ? .green : .primary)
                    }
                    .shadow(color: colorScheme == .dark ? Color.clear : 
                                (viewModel.state == .working ? Color.blue.opacity(0.3) : 
                                 viewModel.state == .onBreak ? Color.green.opacity(0.3) : 
                                 Color.primary.opacity(0.1)),
                            radius: 10, x: 0, y: 5)
                }
                .symbolEffect(.pulse, options: .repeating, isActive: viewModel.state == .working || viewModel.state == .onBreak)
                
                // Skip Button
                Button(action: {
                    viewModel.skip()
                }) {
                    ZStack {
                        Circle()
                            .fill(viewModel.state == .working ? Color.blue.opacity(0.12) : 
                                  viewModel.state == .onBreak ? Color.green.opacity(0.12) : 
                                  Color.primary.opacity(0.08))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "forward.fill")
                            .font(.system(size: 24))
                            .foregroundColor(viewModel.state == .working ? .blue : 
                                             viewModel.state == .onBreak ? .green : .primary)
                    }
                }
                .disabled(viewModel.state == .notStarted || viewModel.state == .completed)
            }
            .padding(.bottom, 30)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .fontWeight(.medium)
                }
            }
        }
        .onAppear {
            viewModel.setActiveTask(task)
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
    
    private func formatDuration(_ minutes: TimeInterval) -> String {
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
}

// Task information header
struct TaskInfoHeader: View {
    let task: TodoTask
    
    var body: some View {
        HStack(spacing: 12) {
            // Category color indicator
            if let category = task.category {
                Circle()
                    .fill(Color(hex: category.color))
                    .frame(width: 12, height: 12)
            }
            
            // Task name
            Text(task.name)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

// Session Timeline Visualization
struct SessionTimelineView: View {
    @ObservedObject var viewModel: PomodoroViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Segment label with time remaining
            Text("\(formatTime(viewModel.timeRemaining)) remaining")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom, 4)
            
            // Continuous timeline with proportional segments
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track - single continuous bar with visually distinct segments
                    Capsule()
                        .fill(Color.secondary.opacity(0.1))
                        .frame(height: 8)
                    
                    // Progress fill - a single continuous progress bar
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .green, .blue, .green],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: calculateTotalProgress(width: geo.size.width), height: 8)
                }
            }
            .frame(height: 8)
            
            // Unified list of segments with connected progress bars
            VStack(spacing: 0) {
                ForEach(0..<viewModel.totalSessions, id: \.self) { sessionIndex in
                    let session = sessionIndex + 1
                                    
                    VStack(spacing: 0) {
                        // Work session
                        UnifiedSessionRow(
                            label: "Focus \(session)",
                            duration: viewModel.settings.workDuration,
                            isActive: session == viewModel.currentSession && viewModel.state == .working,
                            isCompleted: session < viewModel.currentSession || (session == viewModel.currentSession && viewModel.state == .onBreak),
                            progress: session == viewModel.currentSession && viewModel.state == .working ? viewModel.progress : (session < viewModel.currentSession || (session == viewModel.currentSession && viewModel.state == .onBreak) ? 1.0 : 0.0),
                            color: .blue,
                            showConnector: session < viewModel.totalSessions
                        )
                        
                        // Break session (except after last session)
                        if session < viewModel.totalSessions {
                            UnifiedSessionRow(
                                label: "Break \(session)",
                                duration: breakDuration(for: session, viewModel: viewModel),
                                isActive: session == viewModel.currentSession && viewModel.state == .onBreak,
                                isCompleted: session < viewModel.currentSession,
                                progress: session == viewModel.currentSession && viewModel.state == .onBreak ? viewModel.progress : (session < viewModel.currentSession ? 1.0 : 0.0),
                                color: .green,
                                showConnector: true
                            )
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.03))
            )
        }
    }
    
    private func calculateTotalProgress(width: CGFloat) -> CGFloat {
        // Calculate completed segments
        var progress: CGFloat = 0
        
        // Add completed work sessions
        for session in 1..<viewModel.currentSession {
            progress += calculateSegmentWidth(width, isWork: true, session: session)
            
            if session < viewModel.totalSessions {
                progress += calculateSegmentWidth(width, isWork: false, session: session)
            }
        }
        
        // Add current session progress
        if viewModel.currentSession <= viewModel.totalSessions {
            if viewModel.state == .working {
                progress += calculateSegmentWidth(width, isWork: true, session: viewModel.currentSession) * CGFloat(viewModel.progress)
            } else if viewModel.state == .onBreak {
                // Work segment for current session is completed
                progress += calculateSegmentWidth(width, isWork: true, session: viewModel.currentSession)
                
                // Add break progress
                progress += calculateSegmentWidth(width, isWork: false, session: viewModel.currentSession) * CGFloat(viewModel.progress)
            }
        }
        
        return progress
    }
    
    private func calculateSegmentWidth(_ totalWidth: CGFloat, isWork: Bool, session: Int) -> CGFloat {
        let totalDuration = calculateTotalSessionsDuration()
        let segmentDuration = isWork ? viewModel.settings.workDuration : 
                              (session % viewModel.settings.sessionsUntilLongBreak == 0 ? 
                               viewModel.settings.longBreakDuration : 
                               viewModel.settings.breakDuration)
        
        return totalWidth * (segmentDuration / totalDuration)
    }
    
    private func calculateTotalSessionsDuration() -> TimeInterval {
        var total: TimeInterval = 0
        
        // Add all work segments
        total += viewModel.settings.workDuration * Double(viewModel.totalSessions)
        
        // Add all break segments (one less than total sessions)
        for session in 1..<viewModel.totalSessions {
            total += breakDuration(for: session, viewModel: viewModel)
        }
        
        return total
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        return "\(minutes) min"
    }
}

// Unified session row with connecting lines
struct UnifiedSessionRow: View {
    let label: String
    let duration: TimeInterval
    let isActive: Bool
    let isCompleted: Bool
    let progress: Double
    let color: Color
    let showConnector: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            // Left connector column
            ZStack {
                if showConnector {
                    Rectangle()
                        .fill(isCompleted ? color : Color.secondary.opacity(0.2))
                        .frame(width: 2)
                }
                
                Circle()
                    .fill(isCompleted ? color : (isActive ? color : Color.secondary.opacity(0.2)))
                    .frame(width: 12, height: 12)
            }
            .frame(width: 20)
            
            // Main content
            VStack(alignment: .leading, spacing: 6) {
                // Label row with progress indicator
                HStack {
                    // Label
                    Text(label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isActive ? color : .primary)
                    
                    Spacer()
                    
                    // Time indicator or checkmark
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(color)
                    } else {
                        Text("\(Int(duration / 60))m")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Progress bar
                ZStack(alignment: .leading) {
                    // Background
                    Capsule()
                        .fill(color.opacity(0.1))
                        .frame(height: 6)
                    
                    // Progress fill
                    Capsule()
                        .fill(color.opacity(isActive ? 1.0 : 0.6))
                        .frame(width: max(0, CGFloat(progress) * UIScreen.main.bounds.width * 0.7), height: 6)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .padding(.leading, 4)
        }
    }
}

func breakDuration(for session: Int, viewModel: PomodoroViewModel) -> TimeInterval {
    return session % viewModel.settings.sessionsUntilLongBreak == 0 ?
        viewModel.settings.longBreakDuration :
        viewModel.settings.breakDuration
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
                        .fill(viewModel.state == .working ? Color.blue : Color.green)
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
                                .fill(viewModel.state == .working ? Color.blue : Color.green)
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
