import SwiftUI
import Combine

struct TaskFormView: View {
    @StateObject private var viewModel: TaskFormViewModel
    @StateObject private var taskNotificationManager = TaskNotificationManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.theme) private var theme
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
    
    init(initialDate: Date, initialTimeScope: TaskTimeScope, onSave: @escaping (TodoTask) -> Void) {
        self._viewModel = StateObject(wrappedValue: {
            let vm = TaskFormViewModel(initialDate: initialDate)
            vm.selectedTimeScope = initialTimeScope
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
            vm.hasDuration = initialTask.hasDuration
            vm.duration = initialTask.duration
            vm.selectedCategory = initialTask.category
            vm.selectedPriority = initialTask.priority
            vm.icon = initialTask.icon
            vm.subtasks = initialTask.subtasks
            vm.hasNotification = initialTask.hasNotification
            vm.selectedTimeScope = initialTask.timeScope
            
            vm.hasSpecificTime = initialTask.hasSpecificTime
            
            // Set specific period dates based on existing task
            if let scopeStart = initialTask.scopeStartDate {
                let calendar = Calendar.current
                switch initialTask.timeScope {
                case .week:
                    vm.selectedWeekDate = scopeStart
                case .month:
                    vm.selectedMonth = calendar.component(.month, from: scopeStart)
                    vm.selectedYear = calendar.component(.year, from: scopeStart)
                    vm.selectedMonthDate = scopeStart
                case .year:
                    vm.selectedYear = calendar.component(.year, from: scopeStart)
                    vm.selectedYearDate = scopeStart
                default:
                    break
                }
            }
            
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
                                    .themedPrimaryText()
                                
                                TextField("enter_task_name".localized, text: $viewModel.name)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(theme.backgroundColor)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .strokeBorder(
                                                        focusedField == .taskName ? 
                                                        theme.primaryColor : 
                                                        theme.borderColor, 
                                                        lineWidth: focusedField == .taskName ? 2 : 1
                                                    )
                                            )
                                    )
                                    .themedPrimaryText()
                                    .accentColor(theme.primaryColor)
                                    .autocorrectionDisabled(true)
                                    .textInputAutocapitalization(.sentences)
                                    .focused($focusedField, equals: .taskName)
                                    .animation(.easeInOut(duration: 0.2), value: focusedField)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("task_description".localized)
                                    .font(.subheadline.weight(.medium))
                                    .themedPrimaryText()
                                
                                TextField("add_description".localized, text: $viewModel.description, axis: .vertical)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .lineLimit(3...6)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(theme.backgroundColor)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .strokeBorder(
                                                        focusedField == .taskDescription ? 
                                                        theme.primaryColor : 
                                                        theme.borderColor, 
                                                        lineWidth: focusedField == .taskDescription ? 2 : 1
                                                    )
                                            )
                                    )
                                    .themedPrimaryText()
                                    .accentColor(theme.primaryColor)
                                    .autocorrectionDisabled(true)
                                    .textInputAutocapitalization(.sentences)
                                    .focused($focusedField, equals: .taskDescription)
                                    .animation(.easeInOut(duration: 0.2), value: focusedField)
                            }
                            
                            NavigationLink {
                                LocationPickerView(selectedLocation: $viewModel.location)
                            } label: {
                                HStack {
                                    Text("location".localized)
                                        .font(.subheadline.weight(.medium))
                                        .themedPrimaryText()
                                    Spacer()
                                    if let location = viewModel.location {
                                        Text(location.shortDisplayName)
                                            .font(.subheadline)
                                            .themedSecondaryText()
                                            .lineLimit(1)
                                    } else {
                                        Text("add_location".localized)
                                            .font(.subheadline)
                                            .themedSecondaryText()
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .themedSecondaryText()
                                }
                            }
                            
                            NavigationLink {
                                IconPickerView(selectedIcon: $viewModel.icon)
                            } label: {
                                ModernNavigationRow(
                                    title: "icon".localized,
                                    value: viewModel.icon,
                                    isSystemImage: true
                                )
                            }
                        }
                    }
                    
                    // Time Card
                    ModernCard(title: "time".localized, icon: "clock") {
                        VStack(spacing: 16) {
                            // TimeScope Selection
                            HStack {
                                Text("time_scope".localized)
                                    .font(.subheadline.weight(.medium))
                                    .themedPrimaryText()
                                Spacer()
                                Menu {
                                    ForEach(TaskTimeScope.allCases, id: \.self) { scope in
                                        Button(action: {
                                            viewModel.selectedTimeScope = scope
                                        }) {
                                            Label(scope.displayName, systemImage: scope.icon)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: viewModel.selectedTimeScope.icon)
                                            .font(.system(size: 12))
                                            .foregroundColor(Color(viewModel.selectedTimeScope.color))
                                        Text(viewModel.selectedTimeScope.displayName)
                                            .font(.subheadline.weight(.semibold))
                                            .themedPrimaryText()
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 10))
                                            .themedSecondaryText()
                                    }
                                }
                            }
                            
                            // Date/Time Selection (for all scopes, but with different defaults)
                            if viewModel.selectedTimeScope == .today {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("specific_time".localized)
                                            .font(.subheadline.weight(.medium))
                                            .themedPrimaryText()
                                        Text("set_exact_time".localized)
                                            .font(.caption)
                                            .themedSecondaryText()
                                    }
                                    Spacer()
                                    ModernToggle(isOn: $viewModel.hasSpecificTime)
                                }
                                
                                if viewModel.hasSpecificTime {
                                    HStack {
                                        Text("start_time".localized)
                                            .font(.subheadline.weight(.medium))
                                            .themedPrimaryText()
                                        Spacer()
                                        DatePicker("", selection: $viewModel.startDate)
                                            .labelsHidden()
                                    }
                                    .transition(.asymmetric(
                                        insertion: .opacity,
                                        removal: .opacity.animation(.easeInOut(duration: 0.3))
                                    ))
                                    
                                    // Notification toggle (available for all tasks with specific time)
                                    if taskNotificationManager.areNotificationsEnabled {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("enable_notification".localized)
                                                    .font(.subheadline.weight(.medium))
                                                    .themedPrimaryText()
                                                Text("notification_scheduled".localized)
                                                    .font(.caption)
                                                    .themedSecondaryText()
                                            }
                                            Spacer()
                                            ModernToggle(isOn: $viewModel.hasNotification)
                                        }
                                        .transition(.asymmetric(
                                            insertion: .opacity,
                                            removal: .opacity.animation(.easeInOut(duration: 0.3))
                                        ))
                                    } else if viewModel.hasNotification {
                                        // Show notification disabled warning
                                        HStack {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(.orange)
                                                .font(.system(size: 14))
                                            
                                            Text("notifications_not_available".localized)
                                                .font(.caption)
                                                .themedSecondaryText()
                                            
                                            Spacer()
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(.orange.opacity(0.1))
                                        )
                                        .onAppear {
                                            // Auto-disable notification if not available
                                            viewModel.hasNotification = false
                                        }
                                        .transition(.asymmetric(
                                            insertion: .opacity,
                                            removal: .opacity.animation(.easeInOut(duration: 0.3))
                                        ))
                                    }
                                }
                            } else {
                                // For other time scopes, show period selector
                                VStack(spacing: 12) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("selected_period".localized)
                                                .font(.subheadline.weight(.medium))
                                                .themedPrimaryText()
                                            Text(viewModel.selectedPeriodDisplayText)
                                                .font(.caption)
                                                .themedSecondaryText()
                                        }
                                        Spacer()
                                        Image(systemName: viewModel.selectedTimeScope.icon)
                                            .font(.system(size: 16))
                                            .foregroundColor(Color(viewModel.selectedTimeScope.color))
                                    }
                                    
                                    // Period picker based on scope
                                    switch viewModel.selectedTimeScope {
                                    case .week:
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("select_week".localized)
                                                .font(.caption.weight(.medium))
                                                .themedSecondaryText()
                                            
                                            // Week picker - shows week range
                                            DatePicker(
                                                "",
                                                selection: $viewModel.selectedWeekDate,
                                                in: Date()...,
                                                displayedComponents: [.date]
                                            )
                                            .datePickerStyle(.compact)
                                            .labelsHidden()
                                            
                                            // Show selected week range
                                            Text("week_range".localized + ": " + viewModel.selectedWeekRangeText)
                                                .font(.caption2)
                                                .themedSecondaryText()
                                                .padding(.top, 4)
                                        }
                                        
                                    case .month:
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("select_month".localized)
                                                .font(.caption.weight(.medium))
                                                .themedSecondaryText()
                                            
                                            // Month/Year picker only
                                            HStack {
                                                // Month picker
                                                Picker("month".localized, selection: $viewModel.selectedMonth) {
                                                    ForEach(1...12, id: \.self) { month in
                                                        Text(Calendar.current.monthSymbols[month - 1])
                                                            .tag(month)
                                                    }
                                                }
                                                .pickerStyle(.wheel)
                                                .frame(height: 120)
                                                
                                                // Year picker
                                                Picker("year".localized, selection: $viewModel.selectedYear) {
                                                    ForEach(viewModel.availableYears, id: \.self) { year in
                                                        Text(String(year))
                                                            .tag(year)
                                                    }
                                                }
                                                .pickerStyle(.wheel)
                                                .frame(height: 120)
                                            }
                                        }
                                        
                                    case .year:
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("select_year".localized)
                                                .font(.caption.weight(.medium))
                                                .themedSecondaryText()
                                            
                                            // Year only picker
                                            Picker("year".localized, selection: $viewModel.selectedYear) {
                                                ForEach(viewModel.availableYears, id: \.self) { year in
                                                    Text(String(year))
                                                        .tag(year)
                                                }
                                            }
                                            .pickerStyle(.wheel)
                                            .frame(height: 120)
                                            .labelsHidden()
                                        }
                                        
                                    case .longTerm:
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("long_term_info".localized)
                                                .font(.caption)
                                                .themedSecondaryText()
                                        }
                                        
                                    default:
                                        EmptyView()
                                    }
                                    
                                    // Optional: Allow specific time for other scopes
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("specific_time".localized)
                                                .font(.subheadline.weight(.medium))
                                                .themedPrimaryText()
                                            Text("optional_specific_time".localized)
                                                .font(.caption)
                                                .themedSecondaryText()
                                        }
                                        Spacer()
                                        ModernToggle(isOn: $viewModel.hasSpecificTime)
                                    }
                                    
                                    if viewModel.hasSpecificTime {
                                        HStack {
                                            Text("start_time".localized)
                                                .font(.subheadline.weight(.medium))
                                                .themedPrimaryText()
                                            Spacer()
                                            DatePicker("", selection: $viewModel.startDate)
                                                .labelsHidden()
                                        }
                                        .transition(.asymmetric(
                                            insertion: .opacity,
                                            removal: .opacity.animation(.easeInOut(duration: 0.3))
                                        ))
                                        
                                        // Notification toggle (available for all tasks with specific time)
                                        if taskNotificationManager.areNotificationsEnabled {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("enable_notification".localized)
                                                        .font(.subheadline.weight(.medium))
                                                        .themedPrimaryText()
                                                    Text("notification_scheduled".localized)
                                                        .font(.caption)
                                                        .themedSecondaryText()
                                                }
                                                Spacer()
                                                ModernToggle(isOn: $viewModel.hasNotification)
                                            }
                                            .transition(.asymmetric(
                                                insertion: .opacity,
                                                removal: .opacity.animation(.easeInOut(duration: 0.3))
                                            ))
                                        } else if viewModel.hasNotification {
                                            // Show notification disabled warning
                                            HStack {
                                                Image(systemName: "exclamationmark.triangle.fill")
                                                    .foregroundColor(.orange)
                                                    .font(.system(size: 14))
                                                
                                                Text("notifications_not_available".localized)
                                                    .font(.caption)
                                                    .themedSecondaryText()
                                                
                                                Spacer()
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(.orange.opacity(0.1))
                                            )
                                            .onAppear {
                                                // Auto-disable notification if not available
                                                viewModel.hasNotification = false
                                            }
                                            .transition(.asymmetric(
                                                insertion: .opacity,
                                                removal: .opacity.animation(.easeInOut(duration: 0.3))
                                            ))
                                        }
                                    }
                                }
                                .transition(.asymmetric(
                                    insertion: .opacity,
                                    removal: .opacity.animation(.easeInOut(duration: 0.3))
                                ))
                            }
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("duration".localized)
                                        .font(.subheadline.weight(.medium))
                                        .themedPrimaryText()
                                    Text("add_duration".localized)
                                        .font(.caption)
                                        .themedSecondaryText()
                                }
                                Spacer()
                                ModernToggle(isOn: $viewModel.hasDuration)
                            }
                            
                            if viewModel.hasDuration {
                                HStack {
                                    Text("duration_value".localized)
                                        .font(.subheadline.weight(.medium))
                                        .themedPrimaryText()
                                    
                                    Spacer()
                                    
                                    Button(action: { showDurationPicker = true }) {
                                        let hours = Int(viewModel.duration) / 3600
                                        let minutes = (Int(viewModel.duration) % 3600) / 60
                                        Text(hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m")
                                            .font(.subheadline)
                                            .themedSecondaryText()
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(theme.surfaceColor)
                                            )
                                    }
                                }
                                .transition(.asymmetric(
                                    insertion: .opacity,
                                    removal: .opacity.animation(.easeInOut(duration: 0.3))
                                ))
                            }
                        }
                    }
                    
                    // Category & Priority Card
                    ModernCard(title: "category_priority".localized, icon: "folder") {
                        VStack(spacing: 16) {
                            NavigationLink {
                                CategoryPickerView(selectedCategory: $viewModel.selectedCategory)
                            } label: {
                                HStack {
                                    Text("category".localized)
                                        .font(.subheadline.weight(.medium))
                                        .themedPrimaryText()
                                    Spacer()
                                    if let category = viewModel.selectedCategory {
                                        HStack(spacing: 8) {
                                            Circle()
                                                .fill(Color(hex: category.color))
                                                .frame(width: 12, height: 12)
                                            Text(category.name)
                                                .font(.subheadline)
                                                .themedSecondaryText()
                                        }
                                    } else {
                                        Text("select_category".localized)
                                            .font(.subheadline)
                                            .themedSecondaryText()
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .themedSecondaryText()
                                }
                            }
                            
                            HStack {
                                Text("priority".localized)
                                    .font(.subheadline.weight(.medium))
                                    .themedPrimaryText()
                                Spacer()
                                Menu {
                                    ForEach(Priority.allCases, id: \.self) { priority in
                                        Button(action: {
                                            viewModel.selectedPriority = priority
                                        }) {
                                            Label(priority.displayName, systemImage: priority.icon)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: viewModel.selectedPriority.icon)
                                            .font(.system(size: 12))
                                            .foregroundColor(Color(hex: viewModel.selectedPriority.color))
                                        Text(viewModel.selectedPriority.displayName)
                                            .font(.subheadline)
                                            .themedSecondaryText()
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 10))
                                            .themedSecondaryText()
                                    }
                                }
                            }
                        }
                    }
                    
                    // Recurrence Card
                    if viewModel.shouldShowRecurrenceOption {
                        ModernCard(title: "recurrence".localized, icon: "repeat") {
                            VStack(spacing: 16) {
                                HStack {
                                    Text("repeat_task".localized)
                                        .font(.subheadline.weight(.medium))
                                        .themedPrimaryText()
                                    Spacer()
                                    ModernToggle(isOn: $viewModel.isRecurring)
                                }
                                
                                if viewModel.isRecurring {
                                    VStack(spacing: 16) {
                                        // Use the ORIGINAL EnhancedRecurrenceSettingsView for today tasks
                                        if viewModel.selectedTimeScope == .today {
                                            NavigationLink {
                                                EnhancedRecurrenceSettingsView(viewModel: viewModel)
                                            } label: {
                                                HStack {
                                                    Text("frequency".localized)
                                                        .font(.subheadline.weight(.medium))
                                                        .themedPrimaryText()
                                                    Spacer()
                                                    Text(viewModel.recurrenceType.localizedString)
                                                        .font(.subheadline)
                                                        .themedSecondaryText()
                                                    Image(systemName: "chevron.right")
                                                        .font(.system(size: 12))
                                                        .themedSecondaryText()
                                                }
                                            }
                                        } else {
                                            // Use new ContextualRecurrenceSettingsView for other time scopes
                                            NavigationLink {
                                                ContextualRecurrenceSettingsView(viewModel: viewModel)
                                            } label: {
                                                HStack {
                                                    Text("frequency".localized)
                                                        .font(.subheadline.weight(.medium))
                                                        .themedPrimaryText()
                                                    Spacer()
                                                    VStack(alignment: .trailing, spacing: 4) {
                                                        Text(viewModel.recurrenceDisplayText)
                                                            .font(.subheadline)
                                                            .themedSecondaryText()
                                                        Text("contextual_to_scope".localized)
                                                            .font(.caption)
                                                            .themedSecondaryText()
                                                            .opacity(0.7)
                                                    }
                                                    Image(systemName: "chevron.right")
                                                        .font(.system(size: 12))
                                                        .themedSecondaryText()
                                                }
                                            }
                                        }
                                        
                                        HStack {
                                            Text("track_in_consistency".localized)
                                                .font(.subheadline.weight(.medium))
                                                .themedPrimaryText()
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
                        }
                    }

                    // Subtasks Card
                    ModernCard(title: "subtasks".localized, icon: "checklist") {
                        VStack(spacing: 16) {
                            HStack(spacing: 12) {
                                TextField("add_subtask".localized, text: $newSubtaskName)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(theme.backgroundColor)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .strokeBorder(
                                                        focusedField == .subtaskName ? 
                                                        theme.primaryColor : 
                                                        theme.borderColor, 
                                                        lineWidth: focusedField == .subtaskName ? 2 : 1
                                                    )
                                            )
                                    )
                                    .themedPrimaryText()
                                    .accentColor(theme.primaryColor)
                                    .focused($focusedField, equals: .subtaskName)
                                    .animation(.easeInOut(duration: 0.2), value: focusedField)
                                
                                Button(action: {
                                    if !newSubtaskName.isEmpty {
                                        viewModel.addSubtask(name: newSubtaskName)
                                        newSubtaskName = ""
                                    }
                                }) {
                                    Text("add".localized)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(theme.backgroundColor)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(theme.primaryColor)
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
                                                .themedSecondaryText()
                                            Text(subtask.name)
                                                .font(.subheadline)
                                                .themedPrimaryText()
                                            Spacer()
                                            
                                            Button(action: {
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    viewModel.removeSubtask(withId: subtask.id)
                                                }
                                            }) {
                                                Image(systemName: "minus.circle.fill")
                                                    .font(.system(size: 16))
                                                    .foregroundColor(.red)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                                .transition(.asymmetric(
                                    insertion: .opacity,
                                    removal: .opacity.animation(.easeInOut(duration: 0.3))
                                ))
                            }
                        }
                    }
                    
                    // Rewards Card
                    ModernCard(title: "reward_points".localized, icon: "star") {
                        VStack(spacing: 16) {
                            HStack {
                                Text("earn_reward_points".localized)
                                    .font(.subheadline.weight(.medium))
                                    .themedPrimaryText()
                                Spacer()
                                ModernToggle(isOn: $viewModel.hasRewardPoints)
                            }
                            
                            if viewModel.hasRewardPoints {
                                VStack(spacing: 16) {
                                    HStack {
                                        Text("custom_points".localized)
                                            .font(.subheadline.weight(.medium))
                                            .themedPrimaryText()
                                        Spacer()
                                        ModernToggle(isOn: $viewModel.useCustomPoints)
                                    }
                                    
                                    HStack(alignment: .center) {
                                        Text("points".localized)
                                            .font(.subheadline.weight(.medium))
                                            .themedPrimaryText()
                                        Spacer()
                                        
                                        Group {
                                            if viewModel.useCustomPoints {
                                                TextField("points".localized, text: $viewModel.customPointsText)
                                                    .keyboardType(.numberPad)
                                                    .textFieldStyle(PlainTextFieldStyle())
                                                    .multilineTextAlignment(.center)
                                                    .frame(width: 60)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 8)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .fill(theme.backgroundColor)
                                                            .overlay(
                                                                RoundedRectangle(cornerRadius: 8)
                                                                    .strokeBorder(
                                                                        focusedField == .customPoints ? 
                                                                        theme.primaryColor : 
                                                                        theme.borderColor, 
                                                                        lineWidth: focusedField == .customPoints ? 2 : 1
                                                                    )
                                                            )
                                                    )
                                                    .themedPrimaryText()
                                                    .accentColor(theme.primaryColor)
                                                    .focused($focusedField, equals: .customPoints)
                                                    .animation(.easeInOut(duration: 0.2), value: focusedField)
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
                                                    .themedSecondaryText()
                                            } else {
                                                Picker("points".localized, selection: $viewModel.rewardPoints) {
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
                                        Text("point_guidelines".localized)
                                            .font(.caption.weight(.medium))
                                            .themedSecondaryText()
                                        Text("• 1-10: " + "quick_tasks_5_15_min".localized)
                                            .font(.caption)
                                            .themedSecondaryText()
                                        Text("• 15-50: " + "regular_tasks_30_90_min".localized)
                                            .font(.caption)
                                            .themedSecondaryText()
                                        Text("• 75-200: " + "complex_tasks_2_4_hours".localized)
                                            .font(.caption)
                                            .themedSecondaryText()
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
                    }
                    
                    // Save Button
                    Button(action: {
                        Task {
                            let task = viewModel.createTask()
                            await saveTask(task)
                        }
                    }) {
                        HStack {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .medium))
                            Text("save_task".localized)
                                .font(.headline)
                        }
                        .foregroundColor(theme.backgroundColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            viewModel.isValid ? theme.gradient : 
                            LinearGradient(colors: [theme.secondaryTextColor, theme.secondaryTextColor.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                        )
                        .cornerRadius(16)
                        .shadow(color: viewModel.isValid ? theme.primaryColor.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                    }
                    .disabled(!viewModel.isValid)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .padding(.top, 8)
            }
            .themedBackground()
            .simultaneousGesture(
                TapGesture()
                    .onEnded { _ in
                        focusedField = nil
                    }
            )
            .contentShape(Rectangle())
            .navigationTitle("new_task".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                    .themedSecondaryText()
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("save".localized) {
                        Task {
                            let task = viewModel.createTask()
                            await saveTask(task)
                        }
                    }
                    .fontWeight(.semibold)
                    .themedPrimary()
                    .disabled(!viewModel.isValid)
                }
            }
            .sheet(isPresented: $showDurationPicker) {
                DurationPickerView(duration: $viewModel.duration)
            }
            .onAppear {
                taskNotificationManager.checkAuthorizationStatus()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    hasAppeared = true
                }
            }
        }
    }
    
    private func saveTask(_ task: TodoTask) async {
        onSave(task)
        dismiss()
    }
}

// MARK: - Modern UI Components

struct ModernCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.theme) private var theme
    
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
                    .themedPrimary()
                Text(title)
                    .font(.headline)
                    .themedPrimaryText()
            }
            
            content
        }
        .padding(20)
        .themedCard()
        .padding(.horizontal)
    }
}

struct ModernToggle: View {
    @Binding var isOn: Bool
    @Environment(\.theme) private var theme
    
    var body: some View {
        Toggle("", isOn: $isOn)
            .toggleStyle(SwitchToggleStyle(tint: theme.primaryColor))
            .labelsHidden()
            .frame(width: 51, alignment: .trailing)
            .scaleEffect(0.9, anchor: .trailing)
            .animation(.easeInOut(duration: 0.3), value: isOn)
    }
}

struct ModernNavigationRow: View {
    let title: String
    let value: String
    let isSystemImage: Bool
    @Environment(\.theme) private var theme
    
    init(title: String, value: String, isSystemImage: Bool = false) {
        self.title = title
        self.value = value
        self.isSystemImage = isSystemImage
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.medium))
                .themedPrimaryText()
            Spacer()
            if isSystemImage {
                Image(systemName: value)
                    .themedSecondaryText()
            } else {
                Text(value)
                    .font(.subheadline)
                    .themedSecondaryText()
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .themedSecondaryText()
        }
    }
}

#Preview {
    TaskFormView(
        initialDate: Date(),
        onSave: { _ in }
    )
}