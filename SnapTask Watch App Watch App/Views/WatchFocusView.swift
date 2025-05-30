import SwiftUI

struct WatchFocusView: View {
    @StateObject private var taskManager = TaskManager.shared
    @State private var selectedTask: TodoTask?
    @State private var showingTaskPicker = false
    @State private var showingPomodoro = false
    
    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 6) {
                Text("Select Task to Focus On")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                
                Button(action: { showingTaskPicker = true }) {
                    HStack {
                        if let task = selectedTask {
                            if let category = task.category {
                                Circle()
                                    .fill(Color(hex: category.color))
                                    .frame(width: 8, height: 8)
                            }
                            
                            Text(task.name)
                                .font(.system(size: 11))
                                .lineLimit(1)
                        } else {
                            Text("Choose a task")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.2))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            if let task = selectedTask, task.pomodoroSettings != nil {
                Button(action: { showingPomodoro = true }) {
                    HStack {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12))
                        
                        Text("Start Pomodoro")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                VStack(spacing: 3) {
                    Text(selectedTask == nil ? "Select a task to enable Pomodoro" : "Selected task has no Pomodoro settings")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 8)
                .padding(.top, 10)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
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
                                    .frame(width: 8, height: 8)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
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
                                    .font(.system(size: 12))
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
