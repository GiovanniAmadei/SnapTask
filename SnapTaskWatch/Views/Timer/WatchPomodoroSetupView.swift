import SwiftUI

struct WatchPomodoroSetupView: View {
    var task: TodoTask?
    @EnvironmentObject var syncManager: WatchSyncManager
    @Environment(\.dismiss) private var dismiss
    
    // Settings - configurable each time
    @State private var workDuration: Int = 25 // minutes
    @State private var breakDuration: Int = 5 // minutes
    @State private var longBreakDuration: Int = 15 // minutes
    @State private var totalSessions: Int = 4
    @State private var sessionsUntilLongBreak: Int = 4
    
    @State private var showingTimer = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Task info
                if let task = task {
                    taskHeader(task)
                }
                
                // Work duration
                settingRow(
                    title: "Focus",
                    value: $workDuration,
                    range: 1...60,
                    unit: "min",
                    color: .orange
                )
                
                // Break duration
                settingRow(
                    title: "Break",
                    value: $breakDuration,
                    range: 1...30,
                    unit: "min",
                    color: .green
                )
                
                // Long break duration
                settingRow(
                    title: "Long Break",
                    value: $longBreakDuration,
                    range: 5...60,
                    unit: "min",
                    color: .blue
                )
                
                // Sessions
                settingRow(
                    title: "Sessions",
                    value: $totalSessions,
                    range: 1...12,
                    unit: "",
                    color: .purple
                )
                
                // Estimated time
                estimatedTimeView
                
                // Start button
                startButton
            }
            .padding(.horizontal, 8)
        }
        .navigationTitle("Setup")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showingTimer) {
            WatchPomodoroView(
                task: task,
                settings: createSettings()
            )
        }
        .onAppear {
            loadTaskSettings()
        }
    }
    
    private func taskHeader(_ task: TodoTask) -> some View {
        HStack(spacing: 8) {
            Image(systemName: task.icon)
                .font(.caption)
                .foregroundColor(task.category != nil ? Color(hex: task.category!.color) : .gray)
            
            Text(task.name)
                .font(.caption)
                .lineLimit(1)
            
            Spacer()
        }
        .padding(8)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
    
    private func settingRow(title: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 2) {
                    Text("\(value.wrappedValue)")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundColor(color)
                    
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Stepper using buttons for Watch
            HStack(spacing: 12) {
                Button {
                    if value.wrappedValue > range.lowerBound {
                        value.wrappedValue -= 1
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundColor(value.wrappedValue > range.lowerBound ? color : .gray)
                }
                .buttonStyle(.plain)
                
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 4)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color)
                            .frame(width: geo.size.width * progressValue(value.wrappedValue, in: range), height: 4)
                    }
                }
                .frame(height: 4)
                
                Button {
                    if value.wrappedValue < range.upperBound {
                        value.wrappedValue += 1
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(value.wrappedValue < range.upperBound ? color : .gray)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(8)
    }
    
    private func progressValue(_ value: Int, in range: ClosedRange<Int>) -> CGFloat {
        let total = CGFloat(range.upperBound - range.lowerBound)
        let current = CGFloat(value - range.lowerBound)
        return current / total
    }
    
    private var estimatedTimeView: some View {
        let totalMinutes = estimatedTotalTime()
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        return HStack {
            Image(systemName: "clock")
                .font(.caption2)
            
            Text("Est. time:")
                .font(.caption2)
            
            if hours > 0 {
                Text("\(hours)h \(minutes)m")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
            } else {
                Text("\(minutes)m")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
            }
        }
        .foregroundColor(.secondary)
        .padding(.vertical, 4)
    }
    
    private var startButton: some View {
        Button {
            showingTimer = true
        } label: {
            HStack {
                Image(systemName: "play.fill")
                Text("Start")
            }
            .font(.system(.caption, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.orange)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
    
    private func loadTaskSettings() {
        // If task has pomodoro settings, use those as defaults
        if let settings = task?.pomodoroSettings {
            workDuration = Int(settings.workDuration / 60)
            breakDuration = Int(settings.breakDuration / 60)
            longBreakDuration = Int(settings.longBreakDuration / 60)
            totalSessions = settings.totalSessions
            sessionsUntilLongBreak = settings.sessionsUntilLongBreak
        }
    }
    
    private func createSettings() -> PomodoroSettings {
        PomodoroSettings(
            workDuration: Double(workDuration * 60),
            breakDuration: Double(breakDuration * 60),
            longBreakDuration: Double(longBreakDuration * 60),
            sessionsUntilLongBreak: sessionsUntilLongBreak,
            totalSessions: totalSessions,
            totalDuration: Double(estimatedTotalTime())
        )
    }
    
    private func estimatedTotalTime() -> Int {
        let workTime = workDuration * totalSessions
        let shortBreaks = max(0, totalSessions - 1 - (totalSessions / sessionsUntilLongBreak))
        let longBreaks = totalSessions / sessionsUntilLongBreak
        let breakTime = (shortBreaks * breakDuration) + (longBreaks * longBreakDuration)
        return workTime + breakTime
    }
}

#Preview {
    NavigationStack {
        WatchPomodoroSetupView(task: nil)
            .environmentObject(WatchSyncManager.shared)
    }
}
