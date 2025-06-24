import SwiftUI

struct WatchTrackingModeSelectionView: View {
    let task: TodoTask?
    @Environment(\.dismiss) private var dismiss
    @State private var showingSimpleTimer = false
    @State private var showingPomodoro = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom header with cancel button
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Text("Select Mode")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Empty space to balance the layout
                    Color.clear
                        .frame(width: 40)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        // Header
                        VStack(spacing: 6) {
                            if let task = task {
                                Text(task.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }
                            
                            Text("Choose tracking mode")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                        
                        // Mode Cards
                        VStack(spacing: 8) {
                            // Simple Timer Card
                            Button(action: { showingSimpleTimer = true }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "timer")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                        .frame(width: 32, height: 32)
                                        .background(Color.blue)
                                        .clipShape(Circle())
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Simple Timer")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.primary)
                                        
                                        Text("Track time continuously")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.secondary.opacity(0.1))
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Pomodoro Card (only if task has pomodoro settings or no task)
                            if task == nil || task?.pomodoroSettings != nil {
                                Button(action: { showingPomodoro = true }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "clock.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.white)
                                            .frame(width: 32, height: 32)
                                            .background(Color.pink)
                                            .clipShape(Circle())
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Pomodoro")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.primary)
                                            
                                            Text("Work in focused intervals")
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.secondary.opacity(0.1))
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            } else {
                                // Info message for tasks without pomodoro
                                VStack(spacing: 4) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "info.circle")
                                            .font(.system(size: 12))
                                            .foregroundColor(.orange)
                                        
                                        Text("No Pomodoro settings")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.orange.opacity(0.1))
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
        }
        .sheet(isPresented: $showingSimpleTimer) {
            WatchSimpleTimerView(task: task)
        }
        .sheet(isPresented: $showingPomodoro) {
            if let task = task {
                WatchTaskPomodoroView(task: task)
            } else {
                WatchGeneralPomodoroView()
            }
        }
    }
}

#Preview {
    WatchTrackingModeSelectionView(task: nil)
}
