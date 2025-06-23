import SwiftUI
import Combine

struct WatchFocusView: View {
    @StateObject private var taskManager = TaskManager.shared
    @State private var selectedTask: TodoTask?
    @State private var showingTaskPicker = false
    @State private var showingTrackingModeSelection = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Task selection row
                Button(action: { showingTaskPicker = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "target")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Select Task")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text(selectedTask?.name ?? "Choose a task to focus on")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { showingTrackingModeSelection = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "play.circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Track")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                            
                            Text("Start focus session")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Additional info based on selected task
                if let task = selectedTask {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Task Info")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                        
                        VStack(spacing: 4) {
                            if let category = task.category {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color(hex: category.color))
                                        .frame(width: 6, height: 6)
                                    
                                    Text(category.name)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                            }
                            
                            HStack(spacing: 6) {
                                if task.pomodoroSettings != nil {
                                    Text("Pomodoro")
                                        .font(.system(size: 8))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.pink.opacity(0.2))
                                        .foregroundColor(.pink)
                                        .cornerRadius(3)
                                }
                                
                                Text("Timer")
                                    .font(.system(size: 8))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .cornerRadius(3)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                        }
                    }
                }
                
                // General Focus section
                VStack(alignment: .leading, spacing: 6) {
                    Text("Quick Start")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                    
                    Button(action: { 
                        selectedTask = nil
                        showingTrackingModeSelection = true 
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "timer")
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            
                            Text("General Focus")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.blue.opacity(0.1))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .sheet(isPresented: $showingTaskPicker) {
            WatchTaskPickerView(selectedTask: $selectedTask)
        }
        .sheet(isPresented: $showingTrackingModeSelection) {
            WatchTrackingModeSelectionView(task: selectedTask)
        }
    }
}

// MARK: - General Pomodoro View (without specific task)
struct WatchGeneralPomodoroView: View {
    @StateObject private var viewModel = WatchPomodoroViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingCompletion = false
    @State private var totalFocusTime: TimeInterval = 0
    
    var body: some View {
        NavigationStack {
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
                        
                        // Session counter and focus time
                        VStack(spacing: 2) {
                            Text("Session \(viewModel.currentSession)/\(viewModel.totalSessions)")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            
                            if totalFocusTime > 0 {
                                Text("Focus: \(formatFocusTime(totalFocusTime))")
                                    .font(.system(size: 9))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                .padding(.top, 10)
                
                // Controls
                VStack(spacing: 8) {
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
                            totalFocusTime = 0
                        }) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 20))
                        }
                        .buttonStyle(BorderedButtonStyle())
                        .disabled(viewModel.state == .notStarted)
                    }
                    
                    if totalFocusTime > 0 {
                        Button(action: {
                            viewModel.pause() // Stop current timer
                            showingCompletion = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10))
                                Text("Complete Session")
                                    .font(.system(size: 11, weight: .medium))
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
                .padding(.bottom, 10)
            }
            .navigationTitle("General Focus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .font(.system(size: 12))
                }
            }
            .onAppear {
                // Use default pomodoro settings
                viewModel.setup(workDuration: 25, 
                                breakDuration: 5,
                                longBreakDuration: 15,
                               sessionsUntilLongBreak: 4)
            }
            .onChange(of: viewModel.completedWorkSessions) { _, newValue in
                totalFocusTime = TimeInterval(newValue) * (25 * 60) // 25 minutes per session
            }
        }
        .sheet(isPresented: $showingCompletion) {
            WatchTimeTrackingCompletionView(
                task: nil,
                timeSpent: totalFocusTime,
                onSave: {
                    viewModel.reset()
                    totalFocusTime = 0
                    dismiss()
                },
                onDiscard: {
                    viewModel.reset()
                    totalFocusTime = 0
                    dismiss()
                }
            )
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func formatFocusTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct WatchTaskPickerView: View {
    @Binding var selectedTask: TodoTask?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var taskManager = TaskManager.shared
    
    var body: some View {
        NavigationStack { 
            List {
                // Clear selection option
                Button(action: { selectTask(nil) }) {
                    HStack {
                        Image(systemName: "clear")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 16)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("General Focus")
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            
                            Text("No specific task")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if selectedTask == nil {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                ForEach(availableTasks) { task in
                    Button(action: { selectTask(task) }) {
                        HStack {
                            if let category = task.category {
                                Circle()
                                    .fill(Color(hex: category.color))
                                    .frame(width: 6, height: 6)
                            } else {
                                Circle()
                                    .fill(Color.gray)
                                    .frame(width: 6, height: 6)
                            }
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(task.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                                
                                HStack(spacing: 6) {
                                    if task.pomodoroSettings != nil {
                                        Text("Pomodoro")
                                            .font(.system(size: 8))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.pink.opacity(0.2))
                                            .foregroundColor(.pink)
                                            .cornerRadius(3)
                                    }
                                    
                                    Text("Timer")
                                        .font(.system(size: 8))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.blue.opacity(0.2))
                                        .foregroundColor(.blue)
                                        .cornerRadius(3)
                                }
                            }
                            
                            Spacer()
                            
                            if selectedTask?.id == task.id {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 12))
                }
            }
        }
    }
    
    private func taskShouldAppearOn(date: Date, task: TodoTask) -> Bool {
        let calendar = Calendar.current
        
        guard let recurrence = task.recurrence else {
            return calendar.isDate(task.startTime, inSameDayAs: date)
        }

        if let endDate = recurrence.endDate, date > endDate {
            return false
        }

        if date < calendar.startOfDay(for: task.startTime) {
            return false
        }

        switch recurrence.type {
        case .daily:
            return true 
        case .weekly(let days):
            let weekday = calendar.component(.weekday, from: date) 
            return days.contains(weekday)
        case .monthly(let days):
            let dayOfMonth = calendar.component(.day, from: date)
            return days.contains(dayOfMonth)
        }
    }
    
    private var availableTasks: [TodoTask] {
        let today = Calendar.current.startOfDay(for: Date())
        return taskManager.tasks.filter { task in
            let isNotCompletedOnToday = !(task.completions[today]?.isCompleted ?? false)
            return taskShouldAppearOn(date: today, task: task) && isNotCompletedOnToday
        }
        .sorted { $0.startTime < $1.startTime }
    }
    
    private func selectTask(_ task: TodoTask?) {
        selectedTask = task
        dismiss()
    }
}
