import SwiftUI

struct WatchTaskFormView: View {
    @ObservedObject var viewModel: TaskFormViewModel
    @Binding var isPresented: Bool
    @State private var showCategoryPicker = false
    @State private var showPriorityPicker = false
    @State private var showRecurrencePicker = false
    @State private var showDatePicker = false
    @State private var showDurationPicker = false
    @State private var showPomodoroPicker = false
    @State private var newSubtaskName = ""
    @State private var editingSubtaskId: UUID?
    @State private var hapticEngine = WKHapticType.click
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                // Form header
                Text(viewModel.editingTask == nil ? "New Task" : "Edit Task")
                    .font(.headline)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .center)

                // Task Name
                TextField("Task Name", text: $viewModel.name)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(8)
                    .padding(.horizontal, -4)  // Compensate for the parent padding

                // Date selection
                formRowButton(icon: "calendar", label: "Date", value: formattedDate, action: { showDatePicker = true })
                
                // Duration
                formRowButton(icon: "clock", label: "Duration", value: viewModel.hasDuration ? "\(Int(viewModel.duration / 60.0)) min" : "Not set", action: { showDurationPicker = true })
                
                // Category
                formRowButton(icon: "folder", label: "Category", value: viewModel.category?.name ?? "Not set", color: viewModel.category != nil ? Color(hex: viewModel.category!.color) : nil, action: { showCategoryPicker = true })
                
                // Priority
                formRowButton(icon: "flag", label: "Priority", value: viewModel.priority.rawValue.capitalized, action: { showPriorityPicker = true })
                
                // Recurrence
                formRowButton(icon: "repeat", label: "Recurrence", value: viewModel.isRecurring ? recurrenceTypeText : "Not set", action: { showRecurrencePicker = true })
                
                // Pomodoro Settings
                formRowButton(icon: "timer", label: "Pomodoro", value: viewModel.pomodoroSettings != nil ? "\(Int(viewModel.pomodoroSettings!.workDuration / 60.0))m work" : "Not set", action: { showPomodoroPicker = true })
                
                // Subtasks section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Subtasks")
                        .font(.headline)
                        .padding(.top, 8)
                    
                    // Subtask input field
                    HStack {
                        TextField("Add subtask", text: $newSubtaskName)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(8)
                            .submitLabel(.done)
                            .onSubmit {
                                addSubtask()
                            }
                    }
                    
                    // Existing subtasks
                    if !viewModel.subtasks.isEmpty {
                        ForEach(viewModel.subtasks) { subtask in
                            HStack {
                                if editingSubtaskId == subtask.id {
                                    TextField("Edit subtask", text: Binding(
                                        get: { subtask.name },
                                        set: { newName in
                                            if let index = viewModel.subtasks.firstIndex(where: { $0.id == subtask.id }) {
                                                viewModel.subtasks[index].name = newName
                                            }
                                        }
                                    ))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.gray.opacity(0.15))
                                    .cornerRadius(8)
                                    .submitLabel(.done)
                                    .onSubmit {
                                        editingSubtaskId = nil
                                        WKInterfaceDevice.current().play(hapticEngine)
                                    }
                                } else {
                                    Text(subtask.name)
                                        .font(.subheadline)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            editingSubtaskId = subtask.id
                                            WKInterfaceDevice.current().play(hapticEngine)
                                        }
                                    
                                    Button(action: {
                                        deleteSubtask(subtask)
                                        WKInterfaceDevice.current().play(hapticEngine)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                            .font(.system(size: 16))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                Spacer(minLength: 16)

                // Save button
                Button(action: {
                    let _ = viewModel.saveTask()
                    isPresented = false
                }) {
                    Text("Save")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 16)
                .disabled(viewModel.name.isEmpty)
            }
            .padding(.horizontal)
        }
        .navigationTitle(viewModel.editingTask == nil ? "New Task" : "Edit Task")
        .sheet(isPresented: $showCategoryPicker) {
            WatchCategoryPicker(selectedCategory: $viewModel.category)
        }
        .sheet(isPresented: $showPriorityPicker) {
            WatchPriorityPicker(selectedPriority: $viewModel.priority)
        }
        .sheet(isPresented: $showRecurrencePicker) {
            WatchRecurrencePicker(
                isRecurring: $viewModel.isRecurring,
                recurrenceType: $viewModel.recurrenceType,
                selectedDaysOfWeek: $viewModel.selectedDaysOfWeek,
                selectedDaysOfMonth: $viewModel.selectedDaysOfMonth
            )
        }
        .sheet(isPresented: $showDatePicker) {
            VStack {
                Text("Select Date & Time")
                    .font(.headline)
                    .padding(.top)

                DatePicker("", selection: $viewModel.startTime, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .padding(.horizontal)
                    .frame(maxHeight: 160)

                Button("Done") {
                    showDatePicker = false
                }
                .padding(.top)
                .padding(.bottom)
            }
            .padding()
            .presentationDetents([.height(230), .medium])
        }
        .sheet(isPresented: $showDurationPicker) {
            WatchDurationPicker(
                hasDuration: $viewModel.hasDuration,
                duration: $viewModel.duration
            )
        }
        .sheet(isPresented: $showPomodoroPicker) {
            WatchPomodoroSettingsPicker(viewModel: viewModel)
        }
    }
    
    private func addSubtask() {
        if !newSubtaskName.isEmpty {
            viewModel.addSubtask(newSubtaskName)
            newSubtaskName = ""
            WKInterfaceDevice.current().play(hapticEngine)
        }
    }
    
    private func deleteSubtask(_ subtask: Subtask) {
        if let index = viewModel.subtasks.firstIndex(where: { $0.id == subtask.id }) {
            viewModel.subtasks.remove(at: index)
        }
    }
    
    @ViewBuilder
    private func formRowButton(icon: String, label: String, value: String, color: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.body)
                    .frame(width: 24, alignment: .center)
                    .foregroundColor(color ?? .secondary)
                
                Text(label)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if let categoryColor = color, label == "Category" {
                     Circle()
                        .fill(categoryColor)
                        .frame(width: 10, height: 10)
                        .padding(.trailing, 4)
                }

                Text(value)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.15))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: viewModel.startTime)
    }
    
    private var recurrenceTypeText: String {
        if !viewModel.isRecurring { return "Not set" }
        switch viewModel.recurrenceType {
        case "daily": return "Daily"
        case "weekly":
            return viewModel.selectedDaysOfWeek.isEmpty ? "Weekly" : "Weekly (\(viewModel.selectedDaysOfWeek.count) day\(viewModel.selectedDaysOfWeek.count == 1 ? "" : "s"))"
        case "monthly":
            return viewModel.selectedDaysOfMonth.isEmpty ? "Monthly" : "Monthly (\(viewModel.selectedDaysOfMonth.count) day\(viewModel.selectedDaysOfMonth.count == 1 ? "" : "s"))"
        default: return "Custom"
        }
    }
}

struct WatchCategoryPicker: View {
    @Binding var selectedCategory: Category?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SettingsViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("Select Category")
                    .font(.headline)
                    .padding(.vertical, 8)
                
                ForEach(viewModel.categories) { category in
                    Button(action: {
                        selectedCategory = category
                        dismiss()
                    }) {
                        HStack {
                            Circle()
                                .fill(Color(hex: category.color))
                                .frame(width: 16, height: 16)
                            
                            Text(category.name)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if selectedCategory?.id == category.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.1))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Button(action: {
                    selectedCategory = nil
                    dismiss()
                }) {
                    HStack {
                        Text("None")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if selectedCategory == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
        }
        .onAppear {
            viewModel.loadCategories() // Force load categories when view appears
        }
    }
}

struct WatchPriorityPicker: View {
    @Binding var selectedPriority: Priority
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("Select Priority")
                    .font(.headline)
                    .padding(.vertical, 8)
                
                ForEach(Priority.allCases, id: \.self) { priority in
                    Button(action: {
                        selectedPriority = priority
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: priority.icon)
                                .foregroundColor(Color(hex: priority.color))
                            
                            Text(priority.rawValue.capitalized)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if selectedPriority == priority {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.1))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
    }
}

struct WatchRecurrencePicker: View {
    @Binding var isRecurring: Bool
    @Binding var recurrenceType: String
    @Binding var selectedDaysOfWeek: Set<Int>
    @Binding var selectedDaysOfMonth: Set<Int>
    @Environment(\.dismiss) private var dismiss
    @State private var selectionStep = 0
    
    var body: some View {
        VStack {
            if selectionStep == 0 {
                // Recurring toggle
                Toggle("Recurring", isOn: $isRecurring)
                    .padding()
                
                // Recurrence type picker
                if isRecurring {
                    Picker("Recurrence", selection: $recurrenceType) {
                        Text("Daily").tag("daily")
                        Text("Weekly").tag("weekly")
                        Text("Monthly").tag("monthly")
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 100)
                    
                    Button("Next") {
                        if recurrenceType == "weekly" || recurrenceType == "monthly" {
                            selectionStep = 1
                        } else {
                            dismiss()
                        }
                    }
                    .buttonStyle(.bordered)
                    .padding()
                } else {
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .padding()
                }
            } else if selectionStep == 1 {
                if recurrenceType == "weekly" {
                    weekdayPicker
                } else if recurrenceType == "monthly" {
                    monthDayPicker
                }
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .padding()
            }
        }
    }
    
    private var weekdayPicker: some View {
        VStack(spacing: 12) {
            Text("Select Days of Week")
                .font(.headline)
            
            ForEach(1...7, id: \.self) { day in
                Button(action: {
                    if selectedDaysOfWeek.contains(day) {
                        selectedDaysOfWeek.remove(day)
                    } else {
                        selectedDaysOfWeek.insert(day)
                    }
                }) {
                    HStack {
                        Text(weekdayName(day))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if selectedDaysOfWeek.contains(day) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
    }
    
    private var monthDayPicker: some View {
        VStack(spacing: 12) {
            Text("Select Days of Month")
                .font(.headline)
            
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(1...31, id: \.self) { day in
                        Button(action: {
                            if selectedDaysOfMonth.contains(day) {
                                selectedDaysOfMonth.remove(day)
                            } else {
                                selectedDaysOfMonth.insert(day)
                            }
                        }) {
                            Text("\(day)")
                                .frame(width: 24, height: 24)
                                .foregroundColor(selectedDaysOfMonth.contains(day) ? .white : .primary)
                                .background(
                                    Circle()
                                        .fill(selectedDaysOfMonth.contains(day) ? Color.blue : Color.clear)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .padding()
    }
    
    private func weekdayName(_ day: Int) -> String {
        let days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return days[day - 1]
    }
}

struct WatchDurationPicker: View {
    @Binding var hasDuration: Bool
    @Binding var duration: TimeInterval
    @Environment(\.dismiss) private var dismiss
    
    // Durations in minutes, spaced out for better picking
    private let durations = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 75, 90, 105, 120, 150, 180]
    
    var body: some View {
        NavigationView { // Use NavigationView for a title and cleaner Done button placement
            VStack(spacing: 15) {
                Toggle("Enable Duration", isOn: $hasDuration)
                    .padding(.horizontal)
                
                if hasDuration {
                    Picker("Select Duration", selection: Binding(
                        get: { Int(duration / 60.0) },
                        set: { duration = TimeInterval($0) * 60.0 }
                    )) {
                        ForEach(durations, id: \.self) { mins in
                            Text("\(mins) min").tag(mins)
                        }
                    }
                    .labelsHidden() // Hide the "Select Duration" label from picker, title is enough
                    .pickerStyle(WheelPickerStyle())
                    .frame(maxWidth: .infinity) // Allow picker to use available width
                    .padding(.horizontal)
                    
                    Text("Selected: \(Int(duration / 60.0)) minutes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Spacer()
                    Text("Duration is disabled.")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .padding(.vertical)
            .navigationTitle("Task Duration")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { // Standard placement for Done
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct WatchPomodoroSettingsPicker: View {
    @ObservedObject var viewModel: TaskFormViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var hasPomodoro = false
    @State private var workDuration = 25
    @State private var breakDuration = 5
    @State private var longBreakDuration = 15
    @State private var sessionsUntilLongBreak = 4
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Toggle("Use Pomodoro", isOn: $hasPomodoro)
                    .onChange(of: hasPomodoro) { _, newValue in
                        if newValue {
                            updateSettings()
                        } else {
                            viewModel.removePomodoroSettings()
                        }
                    }
                
                if hasPomodoro {
                    Group {
                        HStack {
                            Text("Work Duration")
                            Spacer()
                            Text("\(workDuration) min")
                        }
                        
                        Slider(value: Binding(
                            get: { Double(workDuration) },
                            set: { workDuration = Int($0) }
                        ), in: 5...60, step: 5)
                        
                        HStack {
                            Text("Break Duration")
                            Spacer()
                            Text("\(breakDuration) min")
                        }
                        
                        Slider(value: Binding(
                            get: { Double(breakDuration) },
                            set: { breakDuration = Int($0) }
                        ), in: 1...30, step: 1)
                        
                        HStack {
                            Text("Long Break")
                            Spacer()
                            Text("\(longBreakDuration) min")
                        }
                        
                        Slider(value: Binding(
                            get: { Double(longBreakDuration) },
                            set: { longBreakDuration = Int($0) }
                        ), in: 5...45, step: 5)
                        
                        HStack {
                            Text("Sessions")
                            Spacer()
                            Text("\(sessionsUntilLongBreak)")
                        }
                        
                        Slider(value: Binding(
                            get: { Double(sessionsUntilLongBreak) },
                            set: { sessionsUntilLongBreak = Int($0) }
                        ), in: 2...6, step: 1)
                    }
                    .onChange(of: workDuration) { _, _ in updateSettings() }
                    .onChange(of: breakDuration) { _, _ in updateSettings() }
                    .onChange(of: longBreakDuration) { _, _ in updateSettings() }
                    .onChange(of: sessionsUntilLongBreak) { _, _ in updateSettings() }
                }
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .padding(.top, 8)
            }
            .padding()
        }
        .onAppear {
            if let settings = viewModel.pomodoroSettings {
                hasPomodoro = true
                workDuration = Int(settings.workDuration / 60.0)
                breakDuration = Int(settings.breakDuration / 60.0)
                longBreakDuration = Int(settings.longBreakDuration / 60.0)
                sessionsUntilLongBreak = settings.sessionsUntilLongBreak
            } else {
                hasPomodoro = false
            }
        }
    }
    
    private func updateSettings() {
        viewModel.configurePomodoroSettings(
            workDuration: workDuration,
            breakDuration: breakDuration,
            longBreakDuration: longBreakDuration,
            sessionsUntilLongBreak: sessionsUntilLongBreak
        )
    }
} 