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
        ScrollView {
            VStack(spacing: 20) {
                // Top section with task info
                TaskInfoHeader(task: task)
                
                // Timer Display
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(lineWidth: 24)
                        .opacity(0.08)
                        .foregroundColor(viewModel.state == .working ? .blue : .green)
                    
                    // Progress circle
                    Circle()
                        .trim(from: 0.0, to: viewModel.progress)
                        .stroke(style: StrokeStyle(
                            lineWidth: 24,
                            lineCap: .round
                        ))
                        .foregroundColor(viewModel.state == .working ? .blue : .green)
                        .rotationEffect(Angle(degrees: -90))
                        .animation(.linear(duration: 0.1), value: viewModel.progress)
                    
                    // Time and Session Display
                    VStack(spacing: 10) {
                        // Session state
                        Text(viewModel.state == .working ? "Focus Time" : "Break Time")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        // Time remaining
                        Text(timeString(from: viewModel.timeRemaining))
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(viewModel.state == .working ? .blue : .green)
                        
                        // Session progress
                        Text("Session \(viewModel.currentSession) of \(viewModel.totalSessions)")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(height: 260)
                
                // Task details
                taskDetailsView
                
                // Session Timeline Visualization
                SessionTimelineView(viewModel: viewModel)
                    .padding(.horizontal, 4)
                
                Spacer(minLength: 30)
                
                // Controls - moved lower
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
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 20)
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
    
    private var taskDetailsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let description = task.description, !description.isEmpty {
                Text(description)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.05))
                    )
            }
            
            HStack(spacing: 12) {
                if let category = task.category {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: category.color))
                            .frame(width: 8, height: 8)
                        
                        Text(category.name)
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.05))
                    )
                }
                
                if task.hasDuration && task.duration > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(formatDuration(task.duration))
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.05))
                    )
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, 4)
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
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }
}

// Session Timeline Visualization
struct SessionTimelineView: View {
    @ObservedObject var viewModel: PomodoroViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            // Segment labels
            HStack {
                Text("Timeline")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(formatTime(viewModel.timeRemaining)) remaining")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
            
            // Continuous timeline with proportional segments and segment boundaries
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track with segment divisions
                    HStack(spacing: 0) {
                        ForEach(1...viewModel.totalSessions, id: \.self) { session in
                            // Work segment
                            Capsule()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: calculateSegmentWidth(geo.size.width, isWork: true, session: session))
                            
                            // Break segment (except after last session)
                            if session < viewModel.totalSessions {
                                Capsule()
                                    .fill(Color.green.opacity(0.1))
                                    .frame(width: calculateSegmentWidth(geo.size.width, isWork: false, session: session))
                            }
                        }
                    }
                    .frame(height: 16)
                    
                    // Progress fill
                    HStack(spacing: 0) {
                        // Completed segments
                        ForEach(1..<viewModel.currentSession, id: \.self) { session in
                            // Completed work segment
                            Capsule()
                                .fill(Color.blue.opacity(0.7))
                                .frame(width: calculateSegmentWidth(geo.size.width, isWork: true, session: session))
                            
                            // Completed break segment
                            if session < viewModel.totalSessions {
                                Capsule()
                                    .fill(Color.green.opacity(0.7))
                                    .frame(width: calculateSegmentWidth(geo.size.width, isWork: false, session: session))
                            }
                        }
                        
                        // Current active segment
                        if viewModel.currentSession <= viewModel.totalSessions {
                            if viewModel.state == .working {
                                Capsule()
                                    .fill(Color.blue)
                                    .frame(width: calculateSegmentWidth(geo.size.width, isWork: true, session: viewModel.currentSession) * viewModel.progress)
                            } else if viewModel.state == .onBreak && viewModel.currentSession < viewModel.totalSessions {
                                // Work segment for current session (completed)
                                Capsule()
                                    .fill(Color.blue.opacity(0.7))
                                    .frame(width: calculateSegmentWidth(geo.size.width, isWork: true, session: viewModel.currentSession))
                                
                                // Break segment in progress
                                Capsule()
                                    .fill(Color.green)
                                    .frame(width: calculateSegmentWidth(geo.size.width, isWork: false, session: viewModel.currentSession) * viewModel.progress)
                            }
                        }
                    }
                    .frame(height: 16)
                    .mask(
                        Capsule()
                            .frame(height: 16)
                    )
                }
            }
            .frame(height: 16)
            
            // Compact session chips
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                ForEach(1...viewModel.totalSessions, id: \.self) { session in
                    // Work session
                    SessionProgressView(
                        label: "Focus \(session)",
                        duration: viewModel.settings.workDuration,
                        isActive: session == viewModel.currentSession && viewModel.state == .working,
                        isCompleted: session < viewModel.currentSession,
                        progress: session == viewModel.currentSession && viewModel.state == .working ? viewModel.progress : (session < viewModel.currentSession ? 1.0 : 0.0),
                        color: .blue
                    )
                    
                    // Break session (except after last session)
                    if session < viewModel.totalSessions {
                        SessionProgressView(
                            label: "Break \(session)",
                            duration: breakDuration(for: session, viewModel: viewModel),
                            isActive: session == viewModel.currentSession && viewModel.state == .onBreak,
                            isCompleted: session < viewModel.currentSession,
                            progress: session == viewModel.currentSession && viewModel.state == .onBreak ? viewModel.progress : (session < viewModel.currentSession ? 1.0 : 0.0),
                            color: .green
                        )
                    } else {
                        // Empty cell for grid alignment
                        Color.clear
                            .frame(height: 0)
                    }
                }
            }
        }
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

struct SessionProgressView: View {
    let label: String
    let duration: TimeInterval
    let isActive: Bool
    let isCompleted: Bool
    let progress: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Label with duration
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isActive ? color : .primary)
                
                Spacer()
                
                // Show check for completed, time for others
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(color)
                } else {
                    Text("\(Int(duration / 60))m")
                        .font(.system(size: 12))
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
                    .frame(width: max(0, progress) * UIScreen.main.bounds.width * 0.4, height: 6)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isActive ? color.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
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
