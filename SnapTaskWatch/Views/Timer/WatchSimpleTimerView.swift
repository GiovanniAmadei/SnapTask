import SwiftUI

struct WatchSimpleTimerView: View {
    var task: TodoTask?
    @EnvironmentObject var syncManager: WatchSyncManager
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var timerEngine = WatchTimerEngine.shared

    @State private var showingCompletion: Bool = false
    @State private var completedElapsed: TimeInterval = 0
    
    var body: some View {
        VStack(spacing: 16) {
            // Task name if present
            if let task {
                Text(task.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            } else if let taskName = timerEngine.simpleTaskName {
                Text(taskName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            // Timer display
            timerDisplay
            
            // Controls
            controlButtons
        }
        .padding()
        .navigationTitle("Timer")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            timerEngine.restorePersistedStateIfNeeded()
            syncLocalStateFromEngine()
        }
        .onChange(of: timerEngine.now) { _, _ in
            syncLocalStateFromEngine()
        }
        .onChange(of: timerEngine.completedSimpleSession?.id) { _, _ in
            handleCompletionFromEngine()
        }
        .sheet(isPresented: $showingCompletion) {
            timerCompletionView
        }
    }
    
    private var timerDisplay: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 8)
            
            // Progress (infinite for simple timer)
            Circle()
                .trim(from: 0, to: timerEngine.simpleIsRunning ? 1 : 0)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: timerEngine.simpleIsRunning)
            
            // Time display
            VStack(spacing: 4) {
                Text(formatTime(timerEngine.simpleElapsedTime))
                    .font(.system(.title2, design: .monospaced, weight: .bold))
                
                Text(timerEngine.simpleIsRunning ? "Running" : (timerEngine.simpleIsPaused ? "Paused" : "Ready"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 120, height: 120)
    }
    
    private var controlButtons: some View {
        HStack(spacing: 20) {
            if timerEngine.simpleIsRunning || timerEngine.simpleIsPaused {
                // Stop button
                Button {
                    completeTimer()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.red)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            
            // Play/Pause button
            Button {
                if timerEngine.simpleIsRunning {
                    pauseTimer()
                } else {
                    startOrResumeTimer()
                }
            } label: {
                Image(systemName: timerEngine.simpleIsRunning ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(timerEngine.simpleIsRunning ? Color.orange : Color.green)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            if timerEngine.simpleIsPaused {
                // Reset button
                Button {
                    resetTimer()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.gray)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var timerCompletionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.green)
            
            Text("Session Complete!")
                .font(.headline)
            
            Text(formatTime(completedElapsed))
                .font(.system(.title3, design: .monospaced, weight: .bold))
            
            if let task = task {
                Text(task.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button("Done") {
                showingCompletion = false
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    // MARK: - Timer Control
    private func startOrResumeTimer() {
        if timerEngine.simpleIsPaused {
            timerEngine.resumeSimpleTimer()
        } else {
            timerEngine.startSimpleTimer(task: task)
        }

        HapticService.shared.play(.start)
    }
    
    private func pauseTimer() {
        timerEngine.pauseSimpleTimer()
        HapticService.shared.play(.click)
    }
    
    private func resetTimer() {
        timerEngine.resetSimpleTimer()
    }

    private func completeTimer() {
        let result = timerEngine.completeSimpleTimer()

        if let session = result.session {
            syncManager.saveTrackingSession(session)
            completedElapsed = result.elapsed
            showingCompletion = true
            timerEngine.consumeCompletedSimpleSession()
            HapticService.shared.play(.success)
        }
    }

    private func handleCompletionFromEngine() {
        guard let session = timerEngine.completedSimpleSession else { return }
        syncManager.saveTrackingSession(session)
        completedElapsed = session.elapsedTime
        showingCompletion = true
        timerEngine.consumeCompletedSimpleSession()
    }

    private func syncLocalStateFromEngine() {
        if timerEngine.simpleIsRunning || timerEngine.simpleIsPaused {
            completedElapsed = timerEngine.simpleElapsedTime
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

#Preview {
    WatchSimpleTimerView(task: nil)
        .environmentObject(WatchSyncManager.shared)
}
