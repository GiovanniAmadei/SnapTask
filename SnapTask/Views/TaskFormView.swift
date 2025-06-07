import SwiftUI
import Combine

struct TaskFormView: View {
    @StateObject private var viewModel: TaskFormViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var newSubtaskName = ""
    @State private var showingPomodoroSettings = false
    @State private var showDurationPicker = false
    @State private var showDayPicker = false
    @State private var hasAppeared = false
    var onSave: (TodoTask) -> Void
    
    init(initialDate: Date, onSave: @escaping (TodoTask) -> Void) {
        self._viewModel = StateObject(wrappedValue: {
            let vm = TaskFormViewModel(initialDate: initialDate)
            return vm
        }())
        self.onSave = onSave
    }
    
    init(initialTask: TodoTask, onSave: @escaping (TodoTask) -> Void) {
        self._viewModel = StateObject(wrappedValue: {
            let vm = TaskFormViewModel(initialDate: initialTask.startTime)
            vm.taskId = initialTask.id
            vm.name = initialTask.name
            vm.description = initialTask.description ?? ""
            vm.location = initialTask.location
            vm.startDate = initialTask.startTime
            vm.hasSpecificTime = initialTask.hasSpecificTime
            vm.hasDuration = initialTask.hasDuration
            vm.duration = initialTask.duration
            vm.selectedCategory = initialTask.category
            vm.selectedPriority = initialTask.priority
            vm.icon = initialTask.icon
            vm.subtasks = initialTask.subtasks
            vm.isRecurring = initialTask.recurrence != nil
            if let recurrence = initialTask.recurrence {
                vm.hasRecurrenceEndDate = recurrence.endDate != nil
                switch recurrence.type {
                case .daily:
                    vm.recurrenceType = .daily
                case .weekly(let days):
                    vm.recurrenceType = .weekly
                    vm.selectedDays = days
                case .monthly(let days):
                    vm.recurrenceType = .monthly
                    vm.monthlySelectionType = .days
                    vm.selectedMonthlyDays = days
                case .monthlyOrdinal(let patterns):
                    vm.recurrenceType = .monthly
                    vm.monthlySelectionType = .ordinal
                    vm.selectedOrdinalPatterns = patterns
                case .yearly:
                    vm.recurrenceType = .yearly
                    vm.yearlyDate = recurrence.startDate
                }
                vm.recurrenceEndDate = recurrence.endDate ?? Date().addingTimeInterval(86400 * 30)
                vm.trackInStatistics = recurrence.trackInStatistics
            }
            vm.isPomodoroEnabled = initialTask.pomodoroSettings != nil
            if let pomodoroSettings = initialTask.pomodoroSettings {
                vm.pomodoroSettings = pomodoroSettings
            }
            vm.hasRewardPoints = initialTask.hasRewardPoints
            vm.rewardPoints = initialTask.rewardPoints
            return vm
        }())
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Task Details Card
                    ModernCard(title: "Task Details", icon: "doc.text") {
                        VStack(spacing: 16) {
                            ModernTextField(
                                title: "Task Name",
                                text: $viewModel.name,
                                placeholder: "Enter task name..."
                            )
                            
                            ModernTextField(
                                title: "Description",
                                text: $viewModel.description,
                                placeholder: "Add description...",
                                axis: .vertical,
                                lineLimit: 3...6
                            )
                            
                            NavigationLink {
                                LocationPickerView(selectedLocation: $viewModel.location)
                            } label: {
                                HStack {
                                    Text("Location")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if let location = viewModel.location {
                                        Text(location.shortDisplayName)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    } else {
                                        Text("Add Location")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            NavigationLink {
                                IconPickerView(selectedIcon: $viewModel.icon)
                            } label: {
                                ModernNavigationRow(
                                    title: "Icon",
                                    value: viewModel.icon,
                                    isSystemImage: true
                                )
                            }
                        }
                    }
                    
                    // Time Card
                    ModernCard(title: "Time", icon: "clock") {
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Specific Time")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.primary)
                                    Text("Set exact time")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                ModernToggle(isOn: $viewModel.hasSpecificTime)
                            }
                            
                            if viewModel.hasSpecificTime {
                                HStack {
                                    Text("Start Time")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    DatePicker("", selection: $viewModel.startDate)
                                        .labelsHidden()
                                }
                                .transition(.asymmetric(
                                    insertion: .opacity,
                                    removal: .opacity.animation(.easeInOut(duration: 0.3))
                                ))
                            }
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Duration")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.primary)
                                    Text("Add duration")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                ModernToggle(isOn: $viewModel.hasDuration)
                            }
                            
                            if viewModel.hasDuration {
                                HStack {
                                    Text("Duration Value")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Button(action: { showDurationPicker = true }) {
                                        let hours = Int(viewModel.duration) / 3600
                                        let minutes = (Int(viewModel.duration) % 3600) / 60
                                        Text(hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.gray.opacity(0.1))
                                            )
                                    }
                                }
                                .transition(.asymmetric(
                                    insertion: .opacity,
                                    removal: .opacity.animation(.easeInOut(duration: 0.3))
                                ))
                            }
                        }
                        .animation(hasAppeared ? .easeInOut(duration: 0.2) : .none, value: viewModel.hasSpecificTime)
                        .animation(hasAppeared ? .easeInOut(duration: 0.2) : .none, value: viewModel.hasDuration)
                    }
                    .animation(hasAppeared ? .easeInOut(duration: 0.2) : .none, value: viewModel.hasSpecificTime)
                    .animation(hasAppeared ? .easeInOut(duration: 0.2) : .none, value: viewModel.hasDuration)
                    
                    // Category & Priority Card
                    ModernCard(title: "Category & Priority", icon: "folder") {
                        VStack(spacing: 16) {
                            NavigationLink {
                                CategoryPickerView(selectedCategory: $viewModel.selectedCategory)
                            } label: {
                                HStack {
                                    Text("Category")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if let category = viewModel.selectedCategory {
                                        HStack(spacing: 8) {
                                            Circle()
                                                .fill(Color(hex: category.color))
                                                .frame(width: 12, height: 12)
                                            Text(category.name)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                    } else {
                                        Text("Select Category")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            HStack {
                                Text("Priority")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.primary)
                                Spacer()
                                Menu {
                                    ForEach(Priority.allCases, id: \.self) { priority in
                                        Button(action: {
                                            viewModel.selectedPriority = priority
                                        }) {
                                            Label(priority.rawValue.capitalized, systemImage: priority.icon)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: viewModel.selectedPriority.icon)
                                            .font(.system(size: 12))
                                            .foregroundColor(Color(hex: viewModel.selectedPriority.color))
                                        Text(viewModel.selectedPriority.rawValue.capitalized)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Recurrence Card
                    ModernCard(title: "Recurrence", icon: "repeat") {
                        VStack(spacing: 16) {
                            HStack {
                                Text("Repeat Task")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.primary)
                                Spacer()
                                ModernToggle(isOn: $viewModel.isRecurring)
                            }
                            
                            if viewModel.isRecurring {
                                VStack(spacing: 16) {
                                    NavigationLink {
                                        EnhancedRecurrenceSettingsView(viewModel: viewModel)
                                    } label: {
                                        HStack {
                                            Text("Frequency")
                                                .font(.subheadline.weight(.medium))
                                                .foregroundColor(.primary)
                                            Spacer()
                                            Text(viewModel.recurrenceDisplayText)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    HStack {
                                        Text("track_in_consistency".localized)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        ModernToggle(isOn: $viewModel.trackInStatistics)
                                    }
                                }
                                .transition(.asymmetric(
                                    insertion: .opacity,
                                    removal: .opacity.animation(.easeInOut(duration: 0.3))
                                ))
                            }
                        }
                        .animation(hasAppeared ? .easeInOut(duration: 0.2) : .none, value: viewModel.isRecurring)
                    }
                    .animation(hasAppeared ? .easeInOut(duration: 0.2) : .none, value: viewModel.isRecurring)
                    
                    // Subtasks Card
                    ModernCard(title: "Subtasks", icon: "checklist") {
                        VStack(spacing: 16) {
                            HStack(spacing: 12) {
                                TextField("Add subtask...", text: $newSubtaskName)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.gray.opacity(0.1))
                                    )
                                
                                Button(action: {
                                    if !newSubtaskName.isEmpty {
                                        viewModel.addSubtask(name: newSubtaskName)
                                        newSubtaskName = ""
                                    }
                                }) {
                                    Text("Add")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color.pink)
                                        )
                                }
                                .disabled(newSubtaskName.isEmpty)
                            }
                            
                            if !viewModel.subtasks.isEmpty {
                                VStack(spacing: 8) {
                                    ForEach(viewModel.subtasks) { subtask in
                                        HStack {
                                            Image(systemName: "circle")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                            Text(subtask.name)
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                            Spacer()
                                        }
                                        .padding(.vertical, 4)
                                    }
                                    .onDelete { indexSet in
                                        viewModel.removeSubtask(at: indexSet)
                                    }
                                }
                                .transition(.asymmetric(
                                    insertion: .opacity,
                                    removal: .opacity.animation(.easeInOut(duration: 0.3))
                                ))
                            }
                        }
                        .animation(hasAppeared ? .easeInOut(duration: 0.2) : .none, value: viewModel.subtasks.count)
                    }
                    .animation(hasAppeared ? .easeInOut(duration: 0.2) : .none, value: viewModel.subtasks.count)
                    
                    // Pomodoro Card
                    ModernCard(title: "Pomodoro Mode", icon: "timer") {
                        VStack(spacing: 16) {
                            HStack {
                                Text("Enable Pomodoro")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.primary)
                                Spacer()
                                ModernToggle(isOn: $viewModel.isPomodoroEnabled)
                            }
                            
                            if viewModel.isPomodoroEnabled {
                                NavigationLink {
                                    PomodoroSettingsView(settings: $viewModel.pomodoroSettings)
                                } label: {
                                    HStack {
                                        Text("Pomodoro Settings")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .transition(.asymmetric(
                                    insertion: .opacity,
                                    removal: .opacity.animation(.easeInOut(duration: 0.3))
                                ))
                            }
                        }
                        .animation(hasAppeared ? .easeInOut(duration: 0.2) : .none, value: viewModel.isPomodoroEnabled)
                    }
                    .animation(hasAppeared ? .easeInOut(duration: 0.2) : .none, value: viewModel.isPomodoroEnabled)
                    
                    // Rewards Card
                    ModernCard(title: "Reward Points", icon: "star") {
                        VStack(spacing: 16) {
                            HStack {
                                Text("Earn reward points")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.primary)
                                Spacer()
                                ModernToggle(isOn: $viewModel.hasRewardPoints)
                            }
                            
                            if viewModel.hasRewardPoints {
                                VStack(spacing: 16) {
                                    HStack {
                                        Text("Custom Points")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        ModernToggle(isOn: $viewModel.useCustomPoints)
                                    }
                                    
                                    HStack(alignment: .center) {
                                        Text("Points")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        
                                        Group {
                                            if viewModel.useCustomPoints {
                                                HStack {
                                                    TextField("Points", text: $viewModel.customPointsText)
                                                        .keyboardType(.numberPad)
                                                        .textFieldStyle(PlainTextFieldStyle())
                                                        .multilineTextAlignment(.center)
                                                        .frame(width: 60)
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 8)
                                                        .background(
                                                            RoundedRectangle(cornerRadius: 8)
                                                                .fill(Color.gray.opacity(0.1))
                                                        )
                                                        .onChange(of: viewModel.customPointsText) { oldValue, newValue in
                                                            let filtered = String(newValue.filter { $0.isNumber })
                                                            if filtered != newValue {
                                                                viewModel.customPointsText = filtered
                                                            }
                                                            if let points = Int(filtered), points >= 1, points <= 999 {
                                                                viewModel.rewardPoints = points
                                                            }
                                                        }
                                                    
                                                    Text("(1-999)")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            } else {
                                                Picker("Points", selection: $viewModel.rewardPoints) {
                                                    ForEach([1, 2, 3, 5, 8, 10], id: \.self) { points in
                                                        Text("\(points)").tag(points)
                                                    }
                                                    ForEach([15, 20, 25, 30, 40, 50], id: \.self) { points in
                                                        Text("\(points)").tag(points)
                                                    }
                                                    ForEach([75, 100, 150, 200], id: \.self) { points in
                                                        Text("\(points)").tag(points)
                                                    }
                                                }
                                                .pickerStyle(WheelPickerStyle())
                                                .frame(width: 80, height: 100)
                                                .clipped()
                                                .onChange(of: viewModel.rewardPoints) { oldValue, newValue in
                                                    viewModel.customPointsText = "\(newValue)"
                                                }
                                            }
                                        }
                                        .frame(height: 100)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Point Guidelines:")
                                            .font(.caption.weight(.medium))
                                            .foregroundColor(.secondary)
                                        Text("• 1-10: Quick tasks (5-15 min)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("• 15-50: Regular tasks (30-90 min)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("• 75-200: Complex tasks (2-4 hours)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 4)
                                }
                                .transition(.asymmetric(
                                    insertion: .opacity,
                                    removal: .opacity.combined(with: .scale(scale: 0.01, anchor: .top))
                                ))
                            }
                        }
                        .animation(hasAppeared ? .easeInOut(duration: 0.2) : .none, value: viewModel.hasRewardPoints)
                        .animation(hasAppeared ? .easeInOut(duration: 0.2) : .none, value: viewModel.useCustomPoints)
                    }
                    .animation(hasAppeared ? .easeInOut(duration: 0.2) : .none, value: viewModel.hasRewardPoints)
                    .animation(hasAppeared ? .easeInOut(duration: 0.2) : .none, value: viewModel.useCustomPoints)
                    
                    // Save Button
                    Button(action: {
                        let task = viewModel.createTask()
                        onSave(task)
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .medium))
                            Text("Save Task")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: viewModel.isValid ? [.pink, .pink.opacity(0.8)] : [.gray, .gray.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: viewModel.isValid ? .pink.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                    }
                    .disabled(!viewModel.isValid)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let task = viewModel.createTask()
                        onSave(task)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.pink)
                    .disabled(!viewModel.isValid)
                }
            }
            .sheet(isPresented: $showDurationPicker) {
                DurationPickerView(duration: $viewModel.duration)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                hasAppeared = true
            }
        }
    }
}

// MARK: - Modern UI Components

struct ModernCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    @Environment(\.colorScheme) private var colorScheme
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.pink)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(
                    color: colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.08),
                    radius: colorScheme == .dark ? 0.5 : 8,
                    x: 0,
                    y: colorScheme == .dark ? 1 : 2
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            colorScheme == .dark ? .white.opacity(0.1) : .clear,
                            lineWidth: colorScheme == .dark ? 1 : 0
                        )
                )
        )
        .padding(.horizontal)
    }
}

struct ModernTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let axis: Axis
    let lineLimit: ClosedRange<Int>
    
    init(title: String, text: Binding<String>, placeholder: String, axis: Axis = .horizontal, lineLimit: ClosedRange<Int> = 1...1) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.axis = axis
        self.lineLimit = lineLimit
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
            
            TextField(placeholder, text: $text, axis: axis)
                .textFieldStyle(PlainTextFieldStyle())
                .lineLimit(lineLimit)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.1))
                )
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.sentences)
        }
    }
}

struct ModernToggle: View {
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle("", isOn: $isOn)
            .toggleStyle(SwitchToggleStyle(tint: .pink))
            .scaleEffect(0.9)
            .animation(.easeInOut(duration: 0.3), value: isOn)
    }
}

struct ModernNavigationRow: View {
    let title: String
    let value: String
    let isSystemImage: Bool
    
    init(title: String, value: String, isSystemImage: Bool = false) {
        self.title = title
        self.value = value
        self.isSystemImage = isSystemImage
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
            Spacer()
            if isSystemImage {
                Image(systemName: value)
                    .foregroundColor(.secondary)
            } else {
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    TaskFormView(
        initialDate: Date(),
        onSave: { _ in }
    )
}
