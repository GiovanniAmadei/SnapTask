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
    @FocusState private var focusedField: FocusedField?
    var onSave: (TodoTask) -> Void
    
    enum FocusedField: Hashable {
        case taskName
        case taskDescription
        case subtaskName
        case customPoints
    }
    
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
                    ModernCard(title: "task_details".localized, icon: "doc.text") {
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("task_name".localized)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.primary)
                                
                                TextField("enter_task_name".localized, text: $viewModel.name)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.gray.opacity(0.1))
                                    )
                                    .autocorrectionDisabled(true)
                                    .textInputAutocapitalization(.sentences)
                                    .focused($focusedField, equals: .taskName)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("task_description".localized)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.primary)
                                
                                TextField("add_description".localized, text: $viewModel.description, axis: .vertical)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .lineLimit(3...6)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.gray.opacity(0.1))
                                    )
                                    .autocorrectionDisabled(true)
                                    .textInputAutocapitalization(.sentences)
                                    .focused($focusedField, equals: .taskDescription)
                            }
                            
                            NavigationLink {
                                LocationPickerView(selectedLocation: $viewModel.location)
                            } label: {
                                HStack {
                                    Text("Location".localized)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if let location = viewModel.location {
                                        Text(location.shortDisplayName)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    } else {
                                        Text("Add Location".localized)
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
                                    title: "Icon".localized,
                                    value: viewModel.icon,
                                    isSystemImage: true
                                )
                            }
                        }
                    }
                    
                    // Time Card
                    ModernCard(title: "Time".localized, icon: "clock") {
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Specific Time".localized)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.primary)
                                    Text("Set Exact Time".localized)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                ModernToggle(isOn: $viewModel.hasSpecificTime)
                            }
                            
                            if viewModel.hasSpecificTime {
                                HStack {
                                    Text("Start Time".localized)
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
                                    Text("Duration".localized)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.primary)
                                    Text("Add Duration".localized)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                ModernToggle(isOn: $viewModel.hasDuration)
                            }
                            
                            if viewModel.hasDuration {
                                HStack {
                                    Text("Duration Value".localized)
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
                    ModernCard(title: "Category & Priority".localized, icon: "folder") {
                        VStack(spacing: 16) {
                            NavigationLink {
                                CategoryPickerView(selectedCategory: $viewModel.selectedCategory)
                            } label: {
                                HStack {
                                    Text("Category".localized)
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
                                        Text("Select Category".localized)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            HStack {
                                Text("Priority".localized)
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
                    ModernCard(title: "Recurrence".localized, icon: "repeat") {
                        VStack(spacing: 16) {
                            HStack {
                                Text("Repeat Task".localized)
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
                                            Text("Frequency".localized)
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
                                        Text("Track in Consistency".localized)
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
                    ModernCard(title: "Subtasks".localized, icon: "checklist") {
                        VStack(spacing: 16) {
                            HStack(spacing: 12) {
                                TextField("Add Subtask".localized, text: $newSubtaskName)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.gray.opacity(0.1))
                                    )
                                    .focused($focusedField, equals: .subtaskName)
                                
                                Button(action: {
                                    if !newSubtaskName.isEmpty {
                                        viewModel.addSubtask(name: newSubtaskName)
                                        newSubtaskName = ""
                                    }
                                }) {
                                    Text("Add".localized)
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
                    ModernCard(title: "Pomodoro Mode".localized, icon: "timer") {
                        VStack(spacing: 16) {
                            HStack {
                                Text("Enable Pomodoro".localized)
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
                                        Text("Pomodoro Settings".localized)
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
                    ModernCard(title: "Reward Points".localized, icon: "star") {
                        VStack(spacing: 16) {
                            HStack {
                                Text("Earn Reward Points".localized)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.primary)
                                Spacer()
                                ModernToggle(isOn: $viewModel.hasRewardPoints)
                            }
                            
                            if viewModel.hasRewardPoints {
                                VStack(spacing: 16) {
                                    HStack {
                                        Text("Custom Points".localized)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        ModernToggle(isOn: $viewModel.useCustomPoints)
                                    }
                                    
                                    HStack(alignment: .center) {
                                        Text("Points".localized)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        
                                        Group {
                                            if viewModel.useCustomPoints {
                                                HStack {
                                                    TextField("Points".localized, text: $viewModel.customPointsText)
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
                                                        .focused($focusedField, equals: .customPoints)
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
                                                Picker("Points".localized, selection: $viewModel.rewardPoints) {
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
                                        Text("Point Guidelines".localized)
                                            .font(.caption.weight(.medium))
                                            .foregroundColor(.secondary)
                                        Text("Quick Tasks (5-15 min)".localized)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("Regular Tasks (30-90 min)".localized)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("Complex Tasks (2-4 hours)".localized)
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
                            Text("Save Task".localized)
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
            .simultaneousGesture(
                TapGesture()
                    .onEnded { _ in
                        focusedField = nil
                    }
            )
            .contentShape(Rectangle())
            .navigationTitle("New Task".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel".localized) {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save".localized) {
                        let task = viewModel.createTask()
                        onSave(task)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.pink)
                    .disabled(!viewModel.isValid)
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done".localized) {
                        focusedField = nil
                    }
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
