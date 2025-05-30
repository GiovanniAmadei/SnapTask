import SwiftUI

struct WatchTaskFormView: View {
    let task: TodoTask?
    let initialDate: Date
    @Binding var isPresented: Bool
    
    @State private var name = ""
    @State private var description = ""
    @State private var startTime = Date()
    @State private var duration: TimeInterval = 1800
    @State private var hasDuration = false
    @State private var category: Category?
    @State private var priority = Priority.medium
    @State private var subtasks: [Subtask] = []
    @State private var pomodoroSettings: PomodoroSettings?
    @State private var isRecurring = false
    @State private var recurrenceType = "daily"
    
    @State private var showCategoryPicker = false
    @State private var showPriorityPicker = false
    @State private var showRecurrencePicker = false
    @State private var showDatePicker = false
    @State private var showDurationPicker = false
    @State private var showPomodoroPicker = false
    @State private var newSubtaskName = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Task Name
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Task Name")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        TextField("Enter task name", text: $name)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.gray.opacity(0.2))
                            )
                    }
                    
                    // Date & Time
                    FormRow(
                        icon: "calendar",
                        label: "Date & Time",
                        value: formatDateTime(startTime),
                        action: { showDatePicker = true }
                    )
                    
                    // Duration
                    FormRow(
                        icon: "clock",
                        label: "Duration",
                        value: hasDuration ? formatDuration(duration) : "No duration",
                        action: { showDurationPicker = true }
                    )
                    
                    // Category
                    FormRow(
                        icon: "folder",
                        label: "Category",
                        value: category?.name ?? "None",
                        color: category != nil ? Color(hex: category!.color) : nil,
                        action: { showCategoryPicker = true }
                    )
                    
                    // Priority
                    FormRow(
                        icon: "flag",
                        label: "Priority",
                        value: priority.rawValue.capitalized,
                        color: Color(hex: priority.color),
                        action: { showPriorityPicker = true }
                    )
                    
                    // Recurrence
                    FormRow(
                        icon: "repeat",
                        label: "Recurrence",
                        value: isRecurring ? recurrenceText : "None",
                        action: { showRecurrencePicker = true }
                    )
                    
                    // Pomodoro
                    FormRow(
                        icon: "timer",
                        label: "Pomodoro",
                        value: pomodoroSettings != nil ? pomodoroText : "None",
                        action: { showPomodoroPicker = true }
                    )
                    
                    // Subtasks
                    if !subtasks.isEmpty || !newSubtaskName.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Subtasks")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            // Add Subtask Field
                            TextField("Add subtask", text: $newSubtaskName)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.gray.opacity(0.2))
                                )
                                .onSubmit { addSubtask() }
                            
                            // Existing Subtasks
                            ForEach(subtasks) { subtask in
                                HStack {
                                    Text(subtask.name)
                                        .font(.system(size: 12))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    Button(action: { deleteSubtask(subtask) }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.gray.opacity(0.1))
                                )
                            }
                        }
                    } else {
                        // Add Subtask Button
                        Button(action: { newSubtaskName = " " }) {
                            HStack {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 14))
                                Text("Add Subtasks")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
            .navigationTitle(task == nil ? "New Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTask()
                        isPresented = false
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .onAppear {
            setupInitialValues()
        }
        .sheet(isPresented: $showCategoryPicker) {
            WatchCategoryPickerView(selectedCategory: $category)
        }
        .sheet(isPresented: $showPriorityPicker) {
            WatchPriorityPickerView(selectedPriority: $priority)
        }
        .sheet(isPresented: $showRecurrencePicker) {
            WatchRecurrencePickerView(isRecurring: $isRecurring, recurrenceType: $recurrenceType)
        }
        .sheet(isPresented: $showDatePicker) {
            WatchDateTimePickerView(selectedDate: $startTime)
        }
        .sheet(isPresented: $showDurationPicker) {
            WatchDurationPickerView(hasDuration: $hasDuration, duration: $duration)
        }
        .sheet(isPresented: $showPomodoroPicker) {
            WatchPomodoroPickerView(pomodoroSettings: $pomodoroSettings)
        }
    }
    
    private func setupInitialValues() {
        if let task = task {
            name = task.name
            description = task.description ?? ""
            startTime = task.startTime
            duration = task.duration
            hasDuration = task.hasDuration
            category = task.category
            priority = task.priority
            subtasks = task.subtasks
            pomodoroSettings = task.pomodoroSettings
            
            if let recurrence = task.recurrence {
                isRecurring = true
                switch recurrence.type {
                case .daily:
                    recurrenceType = "daily"
                case .weekly:
                    recurrenceType = "weekly"
                case .monthly:
                    recurrenceType = "monthly"
                }
            }
        } else {
            startTime = initialDate
        }
    }
    
    private func saveTask() {
        let taskManager = TaskManager.shared
        
        if let existingTask = task {
            // Update existing task
            var updatedTask = existingTask
            updatedTask.name = name
            updatedTask.description = description.isEmpty ? nil : description
            updatedTask.startTime = startTime
            updatedTask.duration = duration
            updatedTask.hasDuration = hasDuration
            updatedTask.category = category
            updatedTask.priority = priority
            updatedTask.subtasks = subtasks
            updatedTask.pomodoroSettings = pomodoroSettings
            
            if isRecurring {
                let recurrenceTypeEnum: Recurrence.RecurrenceType
                switch recurrenceType {
                case "daily":
                    recurrenceTypeEnum = .daily
                case "weekly":
                    recurrenceTypeEnum = .weekly(days: [Calendar.current.component(.weekday, from: startTime)])
                case "monthly":
                    recurrenceTypeEnum = .monthly(days: [Calendar.current.component(.day, from: startTime)])
                default:
                    recurrenceTypeEnum = .daily
                }
                updatedTask.recurrence = Recurrence(type: recurrenceTypeEnum, startDate: startTime, endDate: nil)
            } else {
                updatedTask.recurrence = nil
            }
            
            taskManager.updateTask(updatedTask)
        } else {
            // Create new task
            var newTask = TodoTask(
                name: name,
                startTime: startTime,
                category: category,
                priority: priority
            )
            
            newTask.description = description.isEmpty ? nil : description
            newTask.duration = duration
            newTask.hasDuration = hasDuration
            newTask.subtasks = subtasks
            newTask.pomodoroSettings = pomodoroSettings
            
            if isRecurring {
                let recurrenceTypeEnum: Recurrence.RecurrenceType
                switch recurrenceType {
                case "daily":
                    recurrenceTypeEnum = .daily
                case "weekly":
                    recurrenceTypeEnum = .weekly(days: [Calendar.current.component(.weekday, from: startTime)])
                case "monthly":
                    recurrenceTypeEnum = .monthly(days: [Calendar.current.component(.day, from: startTime)])
                default:
                    recurrenceTypeEnum = .daily
                }
                newTask.recurrence = Recurrence(type: recurrenceTypeEnum, startDate: startTime, endDate: nil)
            }
            
            taskManager.addTask(newTask)
        }
    }
    
    private func addSubtask() {
        if !newSubtaskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let subtask = Subtask(name: newSubtaskName.trimmingCharacters(in: .whitespacesAndNewlines))
            subtasks.append(subtask)
            newSubtaskName = ""
        }
    }
    
    private func deleteSubtask(_ subtask: Subtask) {
        subtasks.removeAll { $0.id == subtask.id }
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        return "\(minutes) min"
    }
    
    private var recurrenceText: String {
        switch recurrenceType {
        case "daily": return "Daily"
        case "weekly": return "Weekly"
        case "monthly": return "Monthly"
        default: return "Custom"
        }
    }
    
    private var pomodoroText: String {
        if let settings = pomodoroSettings {
            return "\(Int(settings.workDuration / 60))m work"
        }
        return "None"
    }
}

struct FormRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color?
    let action: () -> Void
    
    init(icon: String, label: String, value: String, color: Color? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.label = label
        self.value = value
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color ?? .secondary)
                    .frame(width: 20)
                
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if let color = color, label == "Category" {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                }
                
                Text(value)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Picker Views

struct WatchCategoryPickerView: View {
    @Binding var selectedCategory: Category?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var categoryManager = CategoryManager.shared
    
    var body: some View {
        NavigationStack {
            List {
                Button(action: { selectCategory(nil) }) {
                    HStack {
                        Text("None")
                        Spacer()
                        if selectedCategory == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                ForEach(categoryManager.categories) { category in
                    Button(action: { selectCategory(category) }) {
                        HStack {
                            Circle()
                                .fill(Color(hex: category.color))
                                .frame(width: 12, height: 12)
                            
                            Text(category.name)
                            
                            Spacer()
                            
                            if selectedCategory?.id == category.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func selectCategory(_ category: Category?) {
        selectedCategory = category
        dismiss()
    }
}

struct WatchPriorityPickerView: View {
    @Binding var selectedPriority: Priority
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(Priority.allCases, id: \.self) { priority in
                    Button(action: { selectPriority(priority) }) {
                        HStack {
                            Image(systemName: priority.icon)
                                .foregroundColor(Color(hex: priority.color))
                            
                            Text(priority.rawValue.capitalized)
                            
                            Spacer()
                            
                            if selectedPriority == priority {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Priority")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func selectPriority(_ priority: Priority) {
        selectedPriority = priority
        dismiss()
    }
}

struct WatchRecurrencePickerView: View {
    @Binding var isRecurring: Bool
    @Binding var recurrenceType: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Toggle("Recurring Task", isOn: $isRecurring)
                    .padding(.horizontal)
                
                if isRecurring {
                    Picker("Type", selection: $recurrenceType) {
                        Text("Daily").tag("daily")
                        Text("Weekly").tag("weekly")
                        Text("Monthly").tag("monthly")
                    }
                    .pickerStyle(.wheel)
                }
                
                Spacer()
            }
            .navigationTitle("Recurrence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct WatchDateTimePickerView: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                DatePicker("Date & Time", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.wheel)
                    .labelsHidden()
            }
            .navigationTitle("Date & Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct WatchDurationPickerView: View {
    @Binding var hasDuration: Bool
    @Binding var duration: TimeInterval
    @Environment(\.dismiss) private var dismiss
    
    private let durations = [5, 10, 15, 20, 25, 30, 45, 60, 90, 120]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Toggle("Has Duration", isOn: $hasDuration)
                    .padding(.horizontal)
                
                if hasDuration {
                    Picker("Duration", selection: Binding(
                        get: { Int(duration / 60) },
                        set: { duration = TimeInterval($0 * 60) }
                    )) {
                        ForEach(durations, id: \.self) { minutes in
                            Text("\(minutes) min").tag(minutes)
                        }
                    }
                    .pickerStyle(.wheel)
                }
                
                Spacer()
            }
            .navigationTitle("Duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct WatchPomodoroPickerView: View {
    @Binding var pomodoroSettings: PomodoroSettings?
    @Environment(\.dismiss) private var dismiss
    
    @State private var hasPomodoro = false
    @State private var workDuration = 25
    @State private var breakDuration = 5
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Toggle("Use Pomodoro", isOn: $hasPomodoro)
                    .padding(.horizontal)
                    .onChange(of: hasPomodoro) { _, newValue in
                        if newValue {
                            updateSettings()
                        } else {
                            pomodoroSettings = nil
                        }
                    }
                
                if hasPomodoro {
                    VStack(spacing: 12) {
                        Text("Work: \(workDuration) min")
                            .font(.system(size: 12))
                        
                        Picker("Work Duration", selection: $workDuration) {
                            ForEach([15, 20, 25, 30, 35, 40, 45, 50, 60], id: \.self) { minutes in
                                Text("\(minutes) min").tag(minutes)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 80)
                        .onChange(of: workDuration) { _, _ in updateSettings() }
                        
                        Text("Break: \(breakDuration) min")
                            .font(.system(size: 12))
                        
                        Picker("Break Duration", selection: $breakDuration) {
                            ForEach([3, 5, 7, 10, 15], id: \.self) { minutes in
                                Text("\(minutes) min").tag(minutes)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 80)
                        .onChange(of: breakDuration) { _, _ in updateSettings() }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Pomodoro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            if let settings = pomodoroSettings {
                hasPomodoro = true
                workDuration = Int(settings.workDuration / 60)
                breakDuration = Int(settings.breakDuration / 60)
            }
        }
    }
    
    private func updateSettings() {
        pomodoroSettings = PomodoroSettings(
            workDuration: TimeInterval(workDuration * 60),
            breakDuration: TimeInterval(breakDuration * 60),
            longBreakDuration: TimeInterval(breakDuration * 3 * 60),
            sessionsUntilLongBreak: 4
        )
    }
}
