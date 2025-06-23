import SwiftUI

struct WatchPomodoroView: View {
    let task: TodoTask
    @StateObject private var viewModel = WatchPomodoroViewModel()
    
    var body: some View {
        VStack(spacing: 8) {
            // Timer Display
            ZStack {
                // Background circle
                Circle()
                    .stroke(lineWidth: 10)
                    .opacity(0.2)
                    .foregroundColor(viewModel.state == .working ? .blue : .green)
                
                // Progress circle
                Circle()
                    .trim(from: 0.0, to: viewModel.progress)
                    .stroke(style: StrokeStyle(
                        lineWidth: 10,
                        lineCap: .round
                    ))
                    .foregroundColor(viewModel.state == .working ? .blue : .green)
                    .rotationEffect(Angle(degrees: -90))
                    .animation(.linear(duration: 0.1), value: viewModel.progress)
                
                // Time and Session Display
                VStack(spacing: 4) {
                    // Session state
                    Text(viewModel.state == .working ? "Focus" : "Break")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    // Time remaining
                    Text(timeString(from: viewModel.timeRemaining))
                        .font(.system(size: 28, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(viewModel.state == .working ? .blue : .green)
                }
            }
            .padding(.top, 10)
            
            // Controls
            HStack(spacing: 20) {
                // Play/Pause Button
                Button(action: {
                    if viewModel.state == .notStarted || viewModel.state == .paused {
                        viewModel.start()
                    } else {
                        viewModel.pause()
                    }
                }) {
                    Image(systemName: viewModel.state == .working || viewModel.state == .onBreak ? 
                          "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .foregroundColor(viewModel.state == .working ? .blue : 
                                         viewModel.state == .onBreak ? .green : .primary)
                }
                .buttonStyle(BorderedButtonStyle(tint: viewModel.state == .working ? .blue : 
                                                viewModel.state == .onBreak ? .green : .gray))
                
                // Reset Button
                Button(action: {
                    viewModel.reset()
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 20))
                }
                .buttonStyle(BorderedButtonStyle())
                .disabled(viewModel.state == .notStarted)
            }
            .padding(.bottom, 10)
        }
        .navigationTitle(task.name)
        .onAppear {
            if let settings = task.pomodoroSettings {
                viewModel.setup(workDuration: Int(settings.workDuration), 
                                breakDuration: Int(settings.breakDuration),
                                longBreakDuration: Int(settings.longBreakDuration),
                               sessionsUntilLongBreak: settings.sessionsUntilLongBreak)
            }
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

enum PomodoroState: Equatable {
    case notStarted
    case working
    case onBreak
    case paused
    case completed
}

class WatchPomodoroViewModel: ObservableObject {
    @Published var timeRemaining: TimeInterval = 0
    @Published var state: PomodoroState = .notStarted
    @Published var currentSession: Int = 1
    @Published var totalSessions: Int = 4
    @Published var completedWorkSessions: Int = 0
    
    private var workDuration: TimeInterval = 25 * 60
    private var breakDuration: TimeInterval = 5 * 60
    private var longBreakDuration: TimeInterval = 15 * 60
    private var sessionsUntilLongBreak: Int = 4
    
    private var timer: Timer?
    private var startTime: Date?
    private var pauseTime: TimeInterval = 0
    
    var progress: Double {
        if state == .notStarted {
            return 0.0
        }
        
        let totalDuration = state == .working ? workDuration : 
                            (currentSession % sessionsUntilLongBreak == 0 ? longBreakDuration : breakDuration)
        
        return 1.0 - (timeRemaining / totalDuration)
    }
    
    func setup(workDuration: Int, breakDuration: Int, longBreakDuration: Int, sessionsUntilLongBreak: Int) {
        self.workDuration = TimeInterval(workDuration * 60)
        self.breakDuration = TimeInterval(breakDuration * 60)
        self.longBreakDuration = TimeInterval(longBreakDuration * 60)
        self.sessionsUntilLongBreak = sessionsUntilLongBreak
        self.totalSessions = sessionsUntilLongBreak
        
        timeRemaining = self.workDuration
        state = .notStarted
        currentSession = 1
        completedWorkSessions = 0
    }
    
    func start() {
        if state == .notStarted {
            state = .working
            timeRemaining = workDuration
        } else if state == .paused {
            state = pauseTime >= workDuration ? .onBreak : .working
        }
        
        startTime = Date()
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
    }
    
    func pause() {
        timer?.invalidate()
        timer = nil
        state = .paused
        pauseTime = timeRemaining
    }
    
    func reset() {
        timer?.invalidate()
        timer = nil
        timeRemaining = workDuration
        state = .notStarted
        currentSession = 1
        completedWorkSessions = 0
    }
    
    private func updateTimer() {
        guard let startTime = startTime else { return }
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        let newTimeRemaining = max(pauseTime - elapsedTime, 0)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.timeRemaining = newTimeRemaining
            
            if self.timeRemaining <= 0 {
                self.timer?.invalidate()
                self.timer = nil
                
                // Logic to switch between working and breaks
                if self.state == .working {
                    self.completedWorkSessions += 1
                    
                    self.state = .onBreak
                    
                    // Check if it's time for a long break
                    if self.currentSession % self.sessionsUntilLongBreak == 0 {
                        self.timeRemaining = self.longBreakDuration
                    } else {
                        self.timeRemaining = self.breakDuration
                    }
                    
                    self.pauseTime = self.timeRemaining
                    self.start()
                } else if self.state == .onBreak {
                    // End of break, prepare for next work session
                    if self.currentSession >= self.totalSessions {
                        self.state = .completed
                    } else {
                        self.currentSession += 1
                        self.state = .working
                        self.timeRemaining = self.workDuration
                        self.pauseTime = self.timeRemaining
                        self.start()
                    }
                }
            }
        }
    }
}
