import SwiftUI

struct TaskFormView: View {
    @ObservedObject var viewModel: TaskFormViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var newSubtaskName = ""
    @State private var showingPomodoroSettings = false
    @State private var showDurationPicker = false
    @State private var showDayPicker = false
    var onSave: (TodoTask) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Task Details") {
                    TextField("Task Name", text: $viewModel.name)
                    TextField("Description", text: $viewModel.description, axis: .vertical)
                        .lineLimit(3...6)
                    NavigationLink {
                        IconPickerView(selectedIcon: $viewModel.icon)
                    } label: {
                        HStack {
                            Text("Icon")
                            Spacer()
                            Image(systemName: viewModel.icon)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Time") {
                    DatePicker("Start Time", selection: $viewModel.startDate)
                    HStack {
                        Text("Duration")
                        Spacer()
                        HStack(spacing: 8) {
                            if viewModel.hasDuration {
                                Button(action: { showDurationPicker = true }) {
                                    let hours = Int(viewModel.duration) / 3600
                                    let minutes = (Int(viewModel.duration) % 3600) / 60
                                    Text(hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m")
                                        .foregroundColor(.secondary)
                                }
                            }
                            Toggle("", isOn: $viewModel.hasDuration)
                        }
                    }
                }
                
                Section("Category & Priority") {
                    NavigationLink {
                        CategoryPickerView(selectedCategory: $viewModel.selectedCategory)
                    } label: {
                        HStack {
                            Text("Category")
                            Spacer()
                            if let category = viewModel.selectedCategory {
                                Circle()
                                    .fill(Color(hex: category.color))
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                                    )
                                Text(category.name)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Picker("Priority", selection: $viewModel.selectedPriority) {
                        ForEach(Priority.allCases, id: \.self) { priority in
                            Label(priority.rawValue.capitalized, systemImage: priority.icon)
                                .foregroundColor(Color(hex: priority.color))
                                .tag(priority)
                        }
                    }
                }
                
                Section("Recurrence") {
                    Toggle("Repeat Task", isOn: $viewModel.isRecurring)
                    if viewModel.isRecurring {
                        NavigationLink {
                            RecurrenceSettingsView(
                                isDailyRecurrence: $viewModel.isDailyRecurrence,
                                selectedDays: $viewModel.selectedDays
                            )
                        } label: {
                            HStack {
                                Text("Frequency")
                                Spacer()
                                Text(viewModel.isDailyRecurrence ? "Daily" : "\(viewModel.selectedDays.count) days")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section("Subtasks") {
                    HStack {
                        TextField("New Subtask", text: $newSubtaskName)
                        Button("Add") {
                            if !newSubtaskName.isEmpty {
                                viewModel.addSubtask(name: newSubtaskName)
                                newSubtaskName = ""
                            }
                        }
                    }
                    
                    ForEach(viewModel.subtasks) { subtask in
                        Text(subtask.name)
                    }
                    .onDelete { indexSet in
                        viewModel.removeSubtask(at: indexSet)
                    }
                }
                
                Section {
                    Toggle("Pomodoro Mode", isOn: $viewModel.isPomodoroEnabled)
                    
                    if viewModel.isPomodoroEnabled {
                        NavigationLink("Pomodoro Settings") {
                            PomodoroSettingsView(settings: $viewModel.pomodoroSettings)
                        }
                    }
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let task = viewModel.createTask()
                        if viewModel.taskId != nil {
                            TaskManager.shared.updateTask(task)
                        } else {
                            TaskManager.shared.addTask(task)
                        }
                        dismiss()
                    }
                    .disabled(!viewModel.isValid)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showDurationPicker) {
                DurationPickerView(duration: $viewModel.duration)
            }
        }
    }
    
    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
}

extension TaskFormView {
    init(initialTask: TodoTask) {
        let viewModel = TaskFormViewModel(initialDate: initialTask.startTime)
        viewModel.taskId = initialTask.id
        viewModel.name = initialTask.name
        viewModel.description = initialTask.description ?? ""
        viewModel.startDate = initialTask.startTime
        viewModel.hasDuration = initialTask.hasDuration
        viewModel.duration = initialTask.duration
        viewModel.selectedCategory = initialTask.category
        viewModel.selectedPriority = initialTask.priority
        viewModel.icon = initialTask.icon
        viewModel.subtasks = initialTask.subtasks
        viewModel.isRecurring = initialTask.recurrence != nil
        if let recurrence = initialTask.recurrence {
            switch recurrence.type {
            case .daily:
                viewModel.isDailyRecurrence = true
            case .weekly(let days):
                viewModel.isDailyRecurrence = false
                viewModel.selectedDays = Set(days)
            case .monthly:
                break // Gestire se necessario
            }
            viewModel.recurrenceEndDate = recurrence.endDate ?? Date().addingTimeInterval(86400 * 30)
        }
        viewModel.isPomodoroEnabled = initialTask.pomodoroSettings != nil
        if let pomodoroSettings = initialTask.pomodoroSettings {
            viewModel.pomodoroSettings = pomodoroSettings
        }
        
        self.init(
            viewModel: viewModel,
            onSave: { updatedTask in
                TaskManager.shared.updateTask(updatedTask)
            }
        )
    }
}

#Preview {
    TaskFormView(
        viewModel: TaskFormViewModel(initialDate: Date()),
        onSave: { _ in }
    )
} 
