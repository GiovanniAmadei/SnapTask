import SwiftUI

struct WatchTaskFormView: View {
    enum Mode {
        case create
        case edit(TodoTask)
    }
    
    let mode: Mode
    @EnvironmentObject var syncManager: WatchSyncManager
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Task Details
    @State private var name: String = ""
    @State private var taskDescription: String = ""
    @State private var icon: String = "circle"
    
    // MARK: - Time Settings
    @State private var startTime: Date = Date()
    @State private var hasSpecificTime: Bool = false
    @State private var hasDuration: Bool = false
    @State private var durationMinutes: Double = 30
    @State private var hasNotification: Bool = false
    @State private var notificationLeadTimeMinutes: Double = 0
    @State private var selectedTimeScope: TaskTimeScope = .today
    @State private var autoCarryOver: Bool = false
    // Period pickers
    @State private var selectedWeekDate: Date = Date()
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    
    // MARK: - Category & Priority
    @State private var selectedCategory: Category?
    @State private var priority: Priority = .medium
    
    // MARK: - Recurrence
    @State private var isRecurring: Bool = false
    @State private var recurrenceType: Recurrence.RecurrenceType = .daily
    @State private var selectedDays: Set<Int> = []
    @State private var hasRecurrenceEndDate: Bool = false
    @State private var recurrenceEndDate: Date = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    @State private var trackInStatistics: Bool = true
    
    // MARK: - Subtasks
    @State private var subtasks: [Subtask] = []
    @State private var newSubtaskName: String = ""
    
    // MARK: - Rewards
    @State private var hasRewardPoints: Bool = false
    @State private var rewardPointsValue: Double = 5
    
    // MARK: - Focus state for digital crown
    @FocusState private var focusedSection: FocusSection?
    
    enum FocusSection: Hashable {
        case time
        case duration
        case points
    }
    
    private var rewardPoints: Int { Int(rewardPointsValue) }
    private var durationSeconds: TimeInterval { Double(durationMinutes) * 60 }
    
    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }
    
    private var existingTask: TodoTask? {
        if case .edit(let task) = mode { return task }
        return nil
    }
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private var isDaily: Bool {
        if case .daily = recurrenceType { return true }
        return false
    }
    
    private var isWeekly: Bool {
        if case .weekly = recurrenceType { return true }
        return false
    }
    
    // Helper per nomi scope leggibili (fallback se localizzazione non disponibile)
    private func scopeName(_ scope: TaskTimeScope) -> String {
        switch scope {
        case .today: return "Today"
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        case .longTerm: return "Long Term"
        case .all: return "All"
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    // Header
                    headerSection
                
                // MARK: - 1. Task Details
                FormSection(title: "Task Details") {
                    VStack(spacing: 10) {
                        // Name
                        TextField("Task name", text: $name)
                            .font(.system(.body, design: .rounded))
                        
                        // Description
                        TextField("Description", text: $taskDescription)
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Icon picker (fuori dalla sezione per navigazione corretta)
                NavigationLink(destination: WatchIconPickerView(selectedIcon: $icon)) {
                    HStack {
                        Text("Icon")
                            .font(.system(.footnote, design: .rounded))
                        Spacer()
                        Image(systemName: icon)
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.15))
                    )
                }
                .buttonStyle(.plain)
                
                // MARK: - 2. Time
                FormSection(title: "Time") {
                    VStack(spacing: 10) {
                        // Time Scope - bottoni compatti
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Scope")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundColor(.secondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(TaskTimeScope.allCases, id: \.self) { scope in
                                        Button {
                                            selectedTimeScope = scope
                                        } label: {
                                            Text(scopeName(scope))
                                                .font(.system(.caption2, design: .rounded, weight: .medium))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(
                                                    Capsule()
                                                        .fill(selectedTimeScope == scope ? Color.blue : Color.gray.opacity(0.3))
                                                )
                                                .foregroundColor(selectedTimeScope == scope ? .white : .primary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        // Specific Time Toggle
                        HStack {
                            Text("Specific Time")
                                .font(.system(.footnote, design: .rounded))
                            Spacer()
                            Toggle("", isOn: $hasSpecificTime)
                                .labelsHidden()
                        }
                        
                        if hasSpecificTime {
                            DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                            
                            // Notification
                            HStack {
                                Text("Notification")
                                    .font(.system(.footnote, design: .rounded))
                                Spacer()
                                Toggle("", isOn: $hasNotification)
                                    .labelsHidden()
                            }

                            if hasNotification {
                                // Lead time (parity con iOS)
                                HStack {
                                    Text("Lead time")
                                        .font(.system(.footnote, design: .rounded))
                                    Spacer()
                                    Text("\(Int(notificationLeadTimeMinutes))m")
                                        .font(.system(.footnote, design: .rounded, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                                .focusable()
                                .digitalCrownRotation($notificationLeadTimeMinutes, from: 0, through: 120, by: 5, sensitivity: .medium)
                            }
                        }
                        
                        // Duration Toggle
                        HStack {
                            Text("Duration")
                                .font(.system(.footnote, design: .rounded))
                            Spacer()
                            Toggle("", isOn: $hasDuration)
                                .labelsHidden()
                        }
                        
                        if hasDuration {
                            HStack {
                                Text("\(Int(durationMinutes)) min")
                                    .font(.system(.body, design: .rounded, weight: .medium))
                                    .foregroundColor(.orange)
                                Spacer()
                                Image(systemName: "timer")
                                    .foregroundColor(.orange)
                            }
                            .focusable()
                            .focused($focusedSection, equals: .duration)
                            .digitalCrownRotation($durationMinutes, from: 5, through: 480, by: 5, sensitivity: .medium)
                        }

                        // Auto carry over (come iOS, solo se non ricorrente)
                        if !isRecurring {
                            HStack {
                                Text("Auto Carry Over")
                                    .font(.system(.footnote, design: .rounded))
                                Spacer()
                                Toggle("", isOn: $autoCarryOver).labelsHidden()
                            }
                        }
                    }
                }
                
                // MARK: - 3. Category & Priority
                FormSection(title: "Category") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            CategoryPill(name: "None", color: .gray, isSelected: selectedCategory == nil) {
                                selectedCategory = nil
                            }
                            ForEach(syncManager.categories) { category in
                                CategoryPill(
                                    name: category.name,
                                    color: Color(hex: category.color),
                                    isSelected: selectedCategory?.id == category.id
                                ) {
                                    selectedCategory = category
                                }
                            }

                            // End date + Track in statistics
                            HStack {
                                Text("End Date")
                                    .font(.system(.footnote, design: .rounded))
                                Spacer()
                                Toggle("", isOn: $hasRecurrenceEndDate).labelsHidden()
                            }
                            if hasRecurrenceEndDate {
                                DatePicker("", selection: $recurrenceEndDate, displayedComponents: .date)
                                    .labelsHidden()
                            }
                            HStack {
                                Text("Track in Statistics")
                                    .font(.system(.footnote, design: .rounded))
                                Spacer()
                                Toggle("", isOn: $trackInStatistics).labelsHidden()
                            }
                        }
                    }
                }
                
                FormSection(title: "Priority") {
                    HStack(spacing: 4) {
                        ForEach(Priority.allCases, id: \.self) { p in
                            PriorityButton(priority: p, isSelected: priority == p) {
                                priority = p
                            }
                        }
                    }
                }
                
                // MARK: - 4. Recurrence
                FormSection(title: "Recurrence") {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Repeat")
                                .font(.system(.footnote, design: .rounded))
                            Spacer()
                            Toggle("", isOn: $isRecurring)
                                .labelsHidden()
                        }
                        
                        if isRecurring {
                            // Simple recurrence options for watch
                            VStack(spacing: 6) {
                                RecurrenceOptionButton(title: "Daily", isSelected: isDaily) {
                                    recurrenceType = .daily
                                }
                                RecurrenceOptionButton(title: "Weekly", isSelected: isWeekly) {
                                    recurrenceType = .weekly(days: [Calendar.current.component(.weekday, from: Date())])
                                }
                                RecurrenceOptionButton(title: "Monthly", isSelected: { if case .monthly = recurrenceType { return true } else { return false } }()) {
                                    recurrenceType = .monthly(days: [Calendar.current.component(.day, from: Date())])
                                }
                            }
                            
                            if isWeekly {
                                // Day selector
                                HStack(spacing: 2) {
                                    ForEach(1...7, id: \.self) { day in
                                        let dayLetter = Calendar.current.veryShortWeekdaySymbols[day - 1]
                                        Button {
                                            if selectedDays.contains(day) {
                                                selectedDays.remove(day)
                                            } else {
                                                selectedDays.insert(day)
                                            }
                                            recurrenceType = .weekly(days: selectedDays)
                                        } label: {
                                            Text(dayLetter)
                                                .font(.system(size: 10, weight: .medium))
                                                .frame(width: 20, height: 20)
                                                .background(
                                                    Circle()
                                                        .fill(selectedDays.contains(day) ? Color.blue : Color.gray.opacity(0.3))
                                                )
                                                .foregroundColor(selectedDays.contains(day) ? .white : .primary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // MARK: - 5. Subtasks
                FormSection(title: "Subtasks") {
                    VStack(spacing: 6) {
                        HStack {
                            TextField("Add subtask", text: $newSubtaskName)
                                .font(.system(.caption, design: .rounded))
                            
                            Button {
                                if !newSubtaskName.isEmpty {
                                    subtasks.append(Subtask(name: newSubtaskName))
                                    newSubtaskName = ""
                                }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.green)
                            }
                            .buttonStyle(.plain)
                            .disabled(newSubtaskName.isEmpty)
                        }
                        
                        if !subtasks.isEmpty {
                            ForEach(subtasks) { subtask in
                                HStack {
                                    Image(systemName: "circle")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                    Text(subtask.name)
                                        .font(.system(.caption, design: .rounded))
                                    Spacer()
                                    Button {
                                        subtasks.removeAll { $0.id == subtask.id }
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red)
                                            .font(.system(size: 14))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                
                // MARK: - 6. Reward Points
                FormSection(title: "Rewards") {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Reward Points")
                                .font(.system(.footnote, design: .rounded))
                            Spacer()
                            Toggle("", isOn: $hasRewardPoints)
                                .labelsHidden()
                        }
                        
                        if hasRewardPoints {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text("\(rewardPoints)")
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                    .foregroundColor(.yellow)
                                Spacer()
                            }
                            .focusable()
                            .focused($focusedSection, equals: .points)
                            .digitalCrownRotation($rewardPointsValue, from: 1, through: 200, by: 1, sensitivity: .medium)
                            
                            Text("Use Crown to adjust (1-200)")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Save Button
                saveButton
                    .padding(.top, 8)
            }
                .padding(.horizontal, 2)
                .padding(.bottom, 20)
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            loadExistingTask()
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Text("Cancel")
                    .font(.system(.footnote, design: .rounded, weight: .medium))
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.red.opacity(0.2))
                    )
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text(isEditing ? "Edit Task" : "New Task")
                .font(.system(.footnote, design: .rounded, weight: .semibold))
        }
        .padding(.bottom, 4)
    }
    
    // MARK: - Save Button
    private var saveButton: some View {
        Button {
            saveTask()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                Text(isEditing ? "Save" : "Create")
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(name.isEmpty ? Color.gray.opacity(0.3) : Color.green)
            )
            .foregroundColor(name.isEmpty ? .secondary : .white)
        }
        .buttonStyle(.plain)
        .disabled(name.isEmpty)
    }
    
    // MARK: - Data Loading
    private func loadExistingTask() {
        guard let task = existingTask else { return }
        
        name = task.name
        taskDescription = task.description ?? ""
        startTime = task.startTime
        hasSpecificTime = task.hasSpecificTime
        hasDuration = task.hasDuration
        durationMinutes = task.duration / 60
        hasNotification = task.hasNotification
        notificationLeadTimeMinutes = Double(task.notificationLeadTimeMinutes)
        selectedTimeScope = task.timeScope
        autoCarryOver = task.autoCarryOver
        if let start = task.scopeStartDate { // derive pickers
            selectedWeekDate = start
            let cal = Calendar.current
            selectedMonth = cal.component(.month, from: start)
            selectedYear = cal.component(.year, from: start)
        }
        selectedCategory = task.category
        priority = task.priority
        icon = task.icon
        subtasks = task.subtasks
        hasRewardPoints = task.hasRewardPoints
        rewardPointsValue = Double(task.rewardPoints)
        
        // Load recurrence
        if let recurrence = task.recurrence {
            isRecurring = true
            recurrenceType = recurrence.type
            if case .weekly(let days) = recurrence.type {
                selectedDays = days
            }
            hasRecurrenceEndDate = recurrence.endDate != nil
            recurrenceEndDate = recurrence.endDate ?? recurrenceEndDate
            trackInStatistics = recurrence.trackInStatistics
        }
    }
    
    // MARK: - Build Recurrence
    private func buildRecurrence() -> Recurrence? {
        guard isRecurring else { return nil }
        return Recurrence(type: recurrenceType, startDate: startTime, endDate: hasRecurrenceEndDate ? recurrenceEndDate : nil, trackInStatistics: trackInStatistics)
    }
    
    // MARK: - Save Task
    private func saveTask() {
        if isEditing, let existing = existingTask {
            var updatedTask = existing
            updatedTask.name = name
            updatedTask.description = taskDescription.isEmpty ? nil : taskDescription
            updatedTask.startTime = startTime
            updatedTask.hasSpecificTime = hasSpecificTime
            updatedTask.hasDuration = hasDuration
            updatedTask.duration = durationSeconds
            updatedTask.hasNotification = hasNotification
            updatedTask.notificationLeadTimeMinutes = Int(notificationLeadTimeMinutes)
            updatedTask.timeScope = selectedTimeScope
            // Scope period
            let cal = Calendar.current
            switch selectedTimeScope {
            case .today:
                updatedTask.scopeStartDate = nil
                updatedTask.scopeEndDate = nil
            case .week:
                let start = cal.startOfWeek(for: selectedWeekDate)
                updatedTask.scopeStartDate = start
                updatedTask.scopeEndDate = cal.date(byAdding: .day, value: 6, to: start)
            case .month:
                var comps = DateComponents()
                comps.year = selectedYear; comps.month = selectedMonth; comps.day = 1
                let start = cal.date(from: comps) ?? Date()
                updatedTask.scopeStartDate = start
                updatedTask.scopeEndDate = cal.date(byAdding: .month, value: 1, to: start)
            case .year:
                var comps = DateComponents()
                comps.year = selectedYear; comps.month = 1; comps.day = 1
                let start = cal.date(from: comps) ?? Date()
                updatedTask.scopeStartDate = start
                updatedTask.scopeEndDate = cal.date(byAdding: .year, value: 1, to: start)
            case .longTerm, .all:
                updatedTask.scopeStartDate = nil
                updatedTask.scopeEndDate = nil
            }
            updatedTask.autoCarryOver = autoCarryOver
            updatedTask.category = selectedCategory
            updatedTask.priority = priority
            updatedTask.icon = icon
            updatedTask.subtasks = subtasks
            updatedTask.recurrence = buildRecurrence()
            updatedTask.hasRewardPoints = hasRewardPoints
            updatedTask.rewardPoints = hasRewardPoints ? rewardPoints : 0
            
            syncManager.updateTask(updatedTask)
        } else {
            let newTask = TodoTask(
                name: name,
                description: taskDescription.isEmpty ? nil : taskDescription,
                startTime: startTime,
                hasSpecificTime: hasSpecificTime,
                duration: durationSeconds,
                hasDuration: hasDuration,
                category: selectedCategory,
                priority: priority,
                icon: icon,
                recurrence: buildRecurrence(),
                subtasks: subtasks,
                hasRewardPoints: hasRewardPoints,
                rewardPoints: hasRewardPoints ? rewardPoints : 0,
                hasNotification: hasNotification,
                timeScope: selectedTimeScope,
                scopeStartDate: {
                    let cal = Calendar.current
                    switch selectedTimeScope {
                    case .today: return nil
                    case .week: return cal.startOfWeek(for: selectedWeekDate)
                    case .month:
                        var c = DateComponents(); c.year = selectedYear; c.month = selectedMonth; c.day = 1
                        return cal.date(from: c)
                    case .year:
                        var c = DateComponents(); c.year = selectedYear; c.month = 1; c.day = 1
                        return cal.date(from: c)
                    case .longTerm, .all: return nil
                    }
                }(),
                scopeEndDate: nil,
                notificationLeadTimeMinutes: Int(notificationLeadTimeMinutes),
                autoCarryOver: autoCarryOver
            )
            
            syncManager.createTask(newTask)
        }
        
        dismiss()
    }
}

// MARK: - Form Section Component
private struct FormSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            content
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.15))
                )
        }
    }
}

// MARK: - Category Pill Component
private struct CategoryPill: View {
    let name: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? color : Color.gray.opacity(0.3))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Priority Button Component
private struct PriorityButton: View {
    let priority: Priority
    let isSelected: Bool
    let action: () -> Void
    
    private var priorityColor: Color {
        Color(hex: priority.color)
    }
    
    private var priorityLabel: String {
        switch priority {
        case .low: return "Low"
        case .medium: return "Med"
        case .high: return "High"
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                // Priority icon (same as iOS: arrow.down, minus, arrow.up)
                Image(systemName: priority.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? priorityColor : .secondary)
                
                Text(priorityLabel)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(isSelected ? priorityColor : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? priorityColor.opacity(0.2) : Color.gray.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? priorityColor.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recurrence Option Button
private struct RecurrenceOptionButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(.footnote, design: .rounded))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.blue.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Icon Picker (inline to ensure target membership)
struct WatchIconPickerView: View {
    @Binding var selectedIcon: String
    @Environment(\.dismiss) private var dismiss
    
    private let icons: [String] = [
        // Common
        "circle", "star", "heart", "bolt", "flame",
        // Tasks
        "checkmark.circle", "list.bullet", "doc.text", "pencil", "book",
        // Health
        "figure.walk", "figure.run", "dumbbell", "heart.fill", "bed.double",
        // Work
        "briefcase", "laptopcomputer", "phone", "envelope", "calendar",
        // Home
        "house", "cart", "fork.knife", "cup.and.saucer", "leaf",
        // Finance
        "dollarsign.circle", "creditcard", "banknote", "chart.line.uptrend.xyaxis",
        // Social
        "person", "person.2", "message", "bubble.left", "hand.thumbsup",
        // Creative
        "paintbrush", "camera", "music.note", "gamecontroller", "film",
        // Travel
        "car", "airplane", "tram", "bicycle", "figure.hiking",
        // Misc
        "gift", "tag", "flag", "bell", "lightbulb"
    ]
    
    private let columns = [ GridItem(.adaptive(minimum: 36), spacing: 8) ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(icons, id: \.self) { icon in
                    Button {
                        selectedIcon = icon
                        dismiss()
                    } label: {
                        Image(systemName: icon)
                            .font(.system(size: 16))
                            .frame(width: 36, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedIcon == icon ? Color.blue : Color.gray.opacity(0.2))
                            )
                            .foregroundColor(selectedIcon == icon ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Icon")
    }
}

#Preview {
    WatchTaskFormView(mode: .create)
        .environmentObject(WatchSyncManager.shared)
}
