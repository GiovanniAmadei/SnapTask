import SwiftUI

struct WatchSimpleTimerView: View {
    let task: TodoTask?
    @StateObject private var viewModel = WatchSimpleTimerViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingCompletion = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // Task name if provided, otherwise show "Timer"
                VStack(spacing: 4) {
                    if let task = task {
                        Text(task.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        
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
                    } else {
                        Text("General Timer")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.top, 4)
                
                // Timer Display
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(lineWidth: 8)
                        .opacity(0.2)
                        .foregroundColor(.blue)
                    
                    // Time Display
                    VStack(spacing: 2) {
                        Text(timeString(from: viewModel.elapsedTime))
                            .font(.system(size: 24, weight: .bold))
                            .monospacedDigit()
                            .foregroundColor(.blue)
                        
                        Text(viewModel.isRunning ? "Running" : viewModel.isPaused ? "Paused" : "Stopped")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(height: 100)
                
                // Controls
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        // Play/Pause Button
                        Button(action: {
                            if viewModel.isRunning {
                                viewModel.pause()
                            } else {
                                viewModel.start()
                            }
                        }) {
                            Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(BorderedButtonStyle(tint: .blue))
                        
                        // Stop Button
                        Button(action: {
                            viewModel.stop()
                        }) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(BorderedButtonStyle(tint: .red))
                        .disabled(!viewModel.isRunning && !viewModel.isPaused)
                    }
                    
                    // Complete Button
                    if viewModel.elapsedTime > 0 {
                        Button(action: {
                            viewModel.pause() // Stop timer
                            showingCompletion = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12))
                                Text("Complete")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.green)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .font(.system(size: 12))
                }
            }
        }
        .onAppear {
            if let task = task {
                viewModel.setup(for: task)
            } else {
                viewModel.setup(for: nil)
            }
        }
        .sheet(isPresented: $showingCompletion) {
            WatchTimeTrackingCompletionView(
                task: task,
                timeSpent: viewModel.elapsedTime,
                onSave: {
                    dismiss()
                },
                onDiscard: {
                    dismiss()
                }
            )
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

class WatchSimpleTimerViewModel: ObservableObject {
    @Published var elapsedTime: TimeInterval = 0
    @Published var isRunning: Bool = false
    @Published var isPaused: Bool = false
    
    private var timer: Timer?
    private var startTime: Date?
    private var pauseTime: Date?
    private var totalPausedTime: TimeInterval = 0
    
    private var task: TodoTask?
    
    func setup(for task: TodoTask?) {
        self.task = task
        reset()
    }
    
    func start() {
        if isPaused {
            // Resume from pause
            if let pauseTime = pauseTime {
                totalPausedTime += Date().timeIntervalSince(pauseTime)
            }
            isPaused = false
        } else {
            // Fresh start
            startTime = Date()
            totalPausedTime = 0
        }
        
        isRunning = true
        pauseTime = nil
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
    }
    
    func pause() {
        guard isRunning else { return }
        
        timer?.invalidate()
        timer = nil
        isRunning = false
        isPaused = true
        pauseTime = Date()
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        isPaused = false
        startTime = nil
        pauseTime = nil
        totalPausedTime = 0
    }
    
    func complete() {
        stop()
        // Timer completed, could save statistics here
    }
    
    private func reset() {
        stop()
        elapsedTime = 0
    }
    
    private func updateTimer() {
        guard let startTime = startTime, isRunning else { return }
        
        let currentTime = Date()
        let totalElapsed = currentTime.timeIntervalSince(startTime)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.elapsedTime = totalElapsed - self.totalPausedTime
        }
    }
}
