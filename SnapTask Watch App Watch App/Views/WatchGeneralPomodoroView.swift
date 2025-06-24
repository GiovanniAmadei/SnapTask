import SwiftUI

struct WatchGeneralPomodoroView: View {
    @StateObject private var viewModel = WatchPomodoroViewModel()
    @Environment(\.dismiss) private var dismiss
    
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
        .navigationTitle("Pomodoro")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear {
            // Setup with default settings
            viewModel.setup(workDuration: 25, 
                            breakDuration: 5,
                            longBreakDuration: 15,
                           sessionsUntilLongBreak: 4)
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}