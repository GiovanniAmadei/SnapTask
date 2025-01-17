import SwiftUI

struct PomodoroView: View {
    @StateObject private var viewModel: PomodoroViewModel
    @Environment(\.dismiss) private var dismiss
    let task: TodoTask
    
    private let workColor: Color
    private let breakColor: Color
    
    init(task: TodoTask) {
        self.task = task
        self._viewModel = StateObject(
            wrappedValue: PomodoroViewModel(
                settings: task.pomodoroSettings ?? PomodoroSettings()
            )
        )
        self.workColor = Color(hex: task.category!.color)
        self.breakColor = .green
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text(task.name)
                .font(.title2)
                .bold()
            
            // Timer Display
            ZStack {
                // Progress Circle
                Circle()
                    .stroke(lineWidth: 20)
                    .opacity(0.3)
                    .foregroundColor(viewModel.state == .working ? workColor : breakColor)
                
                Circle()
                    .trim(from: 0.0, to: viewModel.progress)
                    .stroke(style: StrokeStyle(
                        lineWidth: 20,
                        lineCap: .round
                    ))
                    .foregroundColor(viewModel.state == .working ? workColor : breakColor)
                    .rotationEffect(Angle(degrees: -90))
                    .animation(.linear(duration: 0.1), value: viewModel.progress)
                
                // Time and Session Display
                VStack {
                    Text(timeString(from: viewModel.timeRemaining))
                        .font(.system(size: 50, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    
                    Text(stateText)
                        .font(.title3)
                        .foregroundColor(viewModel.state == .working ? workColor : breakColor)
                    
                    if viewModel.state != .notStarted {
                        Text("Session \(viewModel.currentSession) of \(viewModel.totalSessions)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(40)
            
            // Session Progress Bars
            VStack(spacing: 2) {
                // Work sessions
                GeometryReader { geometry in
                    HStack(spacing: 2) {
                        ForEach(0..<viewModel.totalSessions, id: \.self) { session in
                            let width = sessionWidth(for: geometry, isWork: true, session: session)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(workColor)
                                .frame(width: width)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(workColor)
                                        .frame(width: width * sessionProgress(session: session, isWork: true))
                                )
                                .opacity(0.3)
                        }
                    }
                }
                .frame(height: 8)
                
                // Break sessions
                GeometryReader { geometry in
                    HStack(spacing: 2) {
                        ForEach(0..<viewModel.totalSessions, id: \.self) { session in
                            let width = sessionWidth(for: geometry, isWork: false, session: session)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(breakColor)
                                .frame(width: width)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(breakColor)
                                        .frame(width: width * sessionProgress(session: session, isWork: false))
                                )
                                .opacity(0.3)
                        }
                    }
                }
                .frame(height: 8)
            }
            .padding(.horizontal)
            .animation(.linear(duration: 0.1), value: viewModel.progress)
            
            // Controls
            HStack(spacing: 30) {
                // Stop Button
                Button(action: viewModel.stop) {
                    Image(systemName: "stop.fill")
                        .font(.title)
                        .foregroundColor(.red)
                }
                .opacity(viewModel.state == .notStarted ? 0 : 1)
                
                // Play/Pause Button
                Button(action: {
                    switch viewModel.state {
                    case .notStarted:
                        viewModel.start()
                    case .working, .onBreak:
                        viewModel.pause()
                    case .paused:
                        viewModel.resume()
                    case .completed:
                        break
                    }
                }) {
                    Image(systemName: playPauseIcon)
                        .font(.title)
                        .foregroundColor(.primary)
                }
                
                // Skip Button
                Button(action: viewModel.skip) {
                    Image(systemName: "forward.fill")
                        .font(.title)
                        .foregroundColor(.primary)
                }
                .opacity(viewModel.state == .notStarted ? 0 : 1)
            }
            .padding()
        }
        .padding()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
    
    private var stateText: String {
        switch viewModel.state {
        case .notStarted:
            return "Ready to start"
        case .working:
            return "Working"
        case .onBreak:
            return "Break Time"
        case .paused:
            return "Paused"
        case .completed:
            return "Completed!"
        }
    }
    
    private var playPauseIcon: String {
        switch viewModel.state {
        case .notStarted:
            return "play.fill"
        case .working, .onBreak:
            return "pause.fill"
        case .paused:
            return "play.fill"
        case .completed:
            return "checkmark.circle.fill"
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func sessionWidth(for geometry: GeometryProxy, isWork: Bool, session: Int) -> CGFloat {
        let totalTime = viewModel.settings.workDuration * Double(viewModel.totalSessions) +
            (0..<viewModel.totalSessions).reduce(0.0) { total, sessionIndex in
                total + (sessionIndex % viewModel.settings.sessionsUntilLongBreak == 0 ?
                    viewModel.settings.longBreakDuration : viewModel.settings.breakDuration)
            }
        
        let sessionTime = isWork ? viewModel.settings.workDuration :
            (session % viewModel.settings.sessionsUntilLongBreak == 0 ?
                viewModel.settings.longBreakDuration : viewModel.settings.breakDuration)
        
        return geometry.size.width * (sessionTime / totalTime)
    }
    
    private func sessionProgress(session: Int, isWork: Bool) -> Double {
        guard session == viewModel.currentSession - 1 else {
            return viewModel.isSessionCompleted(session: session, isWork: isWork) ? 1 : 0
        }
        
        if isWork && viewModel.state == .working {
            return viewModel.progress
        } else if !isWork && viewModel.state == .onBreak {
            return viewModel.progress
        }
        return viewModel.isSessionCompleted(session: session, isWork: isWork) ? 1 : 0
    }
} 
