import SwiftUI

struct WatchFocusView: View {
    @StateObject private var taskManager = TaskManager.shared
    @State private var selectedTask: TodoTask?
    @State private var showingTaskPicker = false
    @State private var showingPomodoro = false
    
    var body: some View {
        // COPIO ESATTAMENTE la struttura del WatchMenuView!
        ScrollView {
            VStack(spacing: 6) {
                // Task selection row - IDENTICO al menu
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
                
                // Start Pomodoro button se task selezionato
                if let task = selectedTask, task.pomodoroSettings != nil {
                    Button(action: { showingPomodoro = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 24)
                            
                            Text("Start Pomodoro")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                            
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
                } else {
                    // Info message
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 24)
                        
                        Text(selectedTask == nil ? "Select a task to enable Pomodoro" : "Selected task has no Pomodoro settings")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.05))
                    )
                }
            }
            .padding(.horizontal, 8) // IDENTICO al menu
            .padding(.vertical, 8)   // IDENTICO al menu
        }
        .sheet(isPresented: $showingTaskPicker) {
            WatchTaskPickerView(selectedTask: $selectedTask)
        }
        .sheet(isPresented: $showingPomodoro) {
            if let task = selectedTask {
                WatchTaskPomodoroView(task: task)
            }
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
                ForEach(availableTasks) { task in
                    Button(action: { selectTask(task) }) {
                        HStack {
                            if let category = task.category {
                                Circle()
                                    .fill(Color(hex: category.color))
                                    .frame(width: 6, height: 6)
                            }
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(task.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                                
                                if task.pomodoroSettings != nil {
                                    Text("Pomodoro enabled")
                                        .font(.system(size: 9))
                                        .foregroundColor(.blue)
                                } else {
                                    Text("No Pomodoro settings")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
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
    
    private func selectTask(_ task: TodoTask) {
        selectedTask = task
        dismiss()
    }
}
