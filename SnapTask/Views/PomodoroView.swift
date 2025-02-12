import SwiftUI

struct PomodoroView: View {
    let task: TodoTask
    @State private var timeRemaining: Int
    @State private var isRunning = false
    @State private var showSettings = false
    @State private var currentSession = 1
    @State private var isBreak = false
    
    private var settings: PomodoroSettings {
        task.pomodoroSettings ?? PomodoroSettings.defaultSettings
    }
    
    init(task: TodoTask) {
        self.task = task
        let initialDuration = Int(task.pomodoroSettings?.workDuration ?? PomodoroSettings.defaultSettings.workDuration)
        self._timeRemaining = State(initialValue: initialDuration)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(lineWidth: 20)
                    .opacity(0.3)
                    .foregroundColor(.gray)
                
                let totalDuration = Int(settings.workDuration)
                let progress = CGFloat(timeRemaining) / CGFloat(totalDuration)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(style: StrokeStyle(lineWidth: 20, lineCap: .round, lineJoin: .round))
                    .foregroundColor(isBreak ? .green : .blue)
                    .rotationEffect(Angle(degrees: -90))
                    .animation(.linear, value: timeRemaining)
                
                VStack {
                    Text(timeString(time: timeRemaining))
                        .font(.system(size: 50, weight: .bold, design: .rounded))
                    
                    Text(isBreak ? "Break Time" : "Focus Time")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("Session \(currentSession)/\(settings.sessionsUntilLongBreak)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(40)
            
            HStack(spacing: 30) {
                Button {
                    isRunning.toggle()
                } label: {
                    Image(systemName: isRunning ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 50))
                }
                
                Button {
                    resetTimer()
                } label: {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: 50))
                }
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle(task.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gear")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            PomodoroSettingsView(settings: .constant(settings))
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard isRunning else { return }
            
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                handleSessionEnd()
            }
        }
    }
    
    private func timeString(time: Int) -> String {
        let minutes = time / 60
        let seconds = time % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func resetTimer() {
        isRunning = false
        timeRemaining = Int(settings.workDuration)
        currentSession = 1
        isBreak = false
    }
    
    private func handleSessionEnd() {
        isRunning = false
        if isBreak {
            currentSession += 1
            if currentSession > settings.sessionsUntilLongBreak {
                // All sessions completed
                return
            }
        }
        isBreak.toggle()
        timeRemaining = isBreak ? Int(settings.breakDuration) * 60 : Int(settings.workDuration)
    }
} 
