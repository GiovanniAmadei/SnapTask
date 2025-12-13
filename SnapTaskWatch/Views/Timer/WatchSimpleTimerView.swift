import SwiftUI
import WatchKit

struct WatchSimpleTimerView: View {
    var task: TodoTask?
    @EnvironmentObject var syncManager: WatchSyncManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var elapsedTime: TimeInterval = 0
    @State private var isRunning: Bool = false
    @State private var isPaused: Bool = false
    @State private var timer: Timer?
    @State private var startTime: Date?
    @State private var showingCompletion: Bool = false
    @State private var session: TrackingSession?
    
    var body: some View {
        VStack(spacing: 16) {
            // Task name if present
            if let task = task {
                Text(task.name)
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
        .onDisappear {
            stopTimer()
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
                .trim(from: 0, to: isRunning ? 1 : 0)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isRunning)
            
            // Time display
            VStack(spacing: 4) {
                Text(formatTime(elapsedTime))
                    .font(.system(.title2, design: .monospaced, weight: .bold))
                
                Text(isRunning ? "Running" : (isPaused ? "Paused" : "Ready"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 120, height: 120)
    }
    
    private var controlButtons: some View {
        HStack(spacing: 20) {
            if isRunning || isPaused {
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
                if isRunning {
                    pauseTimer()
                } else {
                    startTimer()
                }
            } label: {
                Image(systemName: isRunning ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(isRunning ? Color.orange : Color.green)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            if isPaused {
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
            
            Text(formatTime(elapsedTime))
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
    private func startTimer() {
        if !isPaused {
            startTime = Date()
            session = TrackingSession(
                taskId: task?.id,
                taskName: task?.name,
                mode: .simple,
                categoryId: task?.category?.id,
                categoryName: task?.category?.name
            )
        }
        
        isRunning = true
        isPaused = false
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedTime += 1
        }
        
        // Haptic feedback
        WKInterfaceDevice.current().play(.start)
    }
    
    private func pauseTimer() {
        isRunning = false
        isPaused = true
        timer?.invalidate()
        timer = nil
        
        WKInterfaceDevice.current().play(.click)
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        isPaused = false
    }
    
    private func resetTimer() {
        stopTimer()
        elapsedTime = 0
        session = nil
        startTime = nil
    }
    
    private func completeTimer() {
        stopTimer()
        
        // Save tracking session
        if var completedSession = session {
            completedSession.elapsedTime = elapsedTime
            completedSession.totalDuration = elapsedTime
            completedSession.isCompleted = true
            completedSession.endTime = Date()
            
            syncManager.saveTrackingSession(completedSession)
        }
        
        WKInterfaceDevice.current().play(.success)
        showingCompletion = true
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
