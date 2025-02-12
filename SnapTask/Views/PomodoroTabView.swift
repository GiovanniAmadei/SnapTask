import SwiftUI

struct PomodoroTabView: View {
    @State private var selectedDate = Date()
    @StateObject private var viewModel: PomodoroViewModel
    
    init() {
        // Initialize with default settings
        let settings = PomodoroSettings.defaultSettings
        _viewModel = StateObject(wrappedValue: PomodoroViewModel(settings: settings))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Timer Display
                ZStack {
                    // Progress Circle
                    Circle()
                        .stroke(lineWidth: 20)
                        .opacity(0.3)
                        .foregroundColor(viewModel.state == .working ? .blue : .green)
                    
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
                    VStack {
                        Text(timeString(from: viewModel.timeRemaining))
                            .font(.system(size: 50, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        
                        Text(viewModel.state == .working ? "Work" : "Break")
                            .font(.title3)
                            .foregroundColor(viewModel.state == .working ? .blue : .green)
                        
                        if viewModel.state != .notStarted {
                            Text("Session \(viewModel.currentSession) of \(viewModel.totalSessions)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(40)
                
                // Controls
                HStack(spacing: 30) {
                    if viewModel.state == .paused {
                        Button(action: viewModel.resume) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 50))
                        }
                    } else if viewModel.state != .notStarted {
                        Button(action: viewModel.pause) {
                            Image(systemName: "pause.circle.fill")
                                .font(.system(size: 50))
                        }
                    }
                    
                    Button(action: viewModel.start) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 50))
                    }
                    .disabled(viewModel.state == .working || viewModel.state == .onBreak)
                    
                    Button(action: viewModel.skip) {
                        Image(systemName: "forward.end.circle.fill")
                            .font(.system(size: 50))
                    }
                    .disabled(viewModel.state == .notStarted)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Pomodoro")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        PomodoroSettingsView(settings: $viewModel.settings)
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
} 