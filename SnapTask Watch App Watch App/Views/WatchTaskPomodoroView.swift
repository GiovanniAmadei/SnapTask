import SwiftUI

struct WatchTaskPomodoroView: View {
    let task: TodoTask
    @Environment(\.dismiss) private var dismiss
    @StateObject private var pomodoroViewModel: WatchPomodoroViewModel
    
    init(task: TodoTask) {
        self.task = task
        self._pomodoroViewModel = StateObject(wrappedValue: WatchPomodoroViewModel())
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Task Info
                VStack(spacing: 4) {
                    Text(task.name)
                        .font(.system(size: 14, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    if let category = task.category {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: category.color))
                                .frame(width: 6, height: 6)
                            
                            Text(category.name)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Timer Display
                VStack(spacing: 8) {
                    ZStack {
                        // Background Circle
                        Circle()
                            .stroke(lineWidth: 6)
                            .opacity(0.2)
                            .foregroundColor(.gray)
                        
                        // Progress Circle
                        Circle()
                            .trim(from: 0.0, to: pomodoroViewModel.progress)
                            .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .foregroundColor(pomodoroViewModel.state == .working ? .blue : .green)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.5), value: pomodoroViewModel.progress)
                        
                        // Time Text
                        VStack(spacing: 2) {
                            Text(formatTime(pomodoroViewModel.timeRemaining))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text(stateText)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(height: 100)
                    
                    // Session Info
                    Text("Session \(pomodoroViewModel.currentSession)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                // Control Buttons
                HStack(spacing: 12) {
                    if pomodoroViewModel.state == .notStarted {
                        Button(action: { pomodoroViewModel.start() }) {
                            Text("Start")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.blue)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else if pomodoroViewModel.state == .paused {
                        Button(action: { pomodoroViewModel.start() }) {
                            Text("Resume")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.green)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else if pomodoroViewModel.state == .working || pomodoroViewModel.state == .onBreak {
                        Button(action: { pomodoroViewModel.pause() }) {
                            Text("Pause")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.orange)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Button(action: { pomodoroViewModel.reset() }) {
                        Text("Reset")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.red, lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Pomodoro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear {
            setupPomodoro()
        }
    }
    
    private func setupPomodoro() {
        if let settings = task.pomodoroSettings {
            pomodoroViewModel.setup(
                workDuration: Int(settings.workDuration / 60),
                breakDuration: Int(settings.breakDuration / 60),
                longBreakDuration: Int(settings.longBreakDuration / 60),
                sessionsUntilLongBreak: settings.sessionsUntilLongBreak
            )
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private var stateText: String {
        switch pomodoroViewModel.state {
        case .notStarted: return "Ready to start"
        case .working: return "Focus time"
        case .onBreak: return "Break time"
        case .paused: return "Paused"
        case .completed: return "Completed"
        }
    }
}
