import SwiftUI
import CoreLocation
import UserNotifications

enum WatchMonthlySelectionMode: String, CaseIterable {
    case days
    case ordinal
    
    var displayName: String {
        switch self {
        case .days: return "Days"
        case .ordinal: return "Ordinal"
        }
    }
}

struct WatchTaskFormView: View {
    enum Mode {
        case create
        case edit(TodoTask)
    }
    
    let mode: Mode
    @EnvironmentObject var syncManager: WatchSyncManager
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var notificationManager = WatchTaskNotificationManager.shared
    
    // MARK: - Task Details
    @State private var name: String = ""
    @State private var taskDescription: String = ""
    @State private var icon: String = "circle.fill"
    @State private var location: TaskLocation?
    
    // MARK: - Time Settings
    @State private var startTime: Date = Date()
    @State private var hasSpecificDay: Bool = true
    @State private var specificDayDate: Date = Date()
    @State private var hasSpecificTime: Bool = false
    @State private var hasDuration: Bool = false
    @State private var durationMinutes: Int = 30
    @State private var hasNotification: Bool = false
    @State private var leadTimeMinutes: Int = 0
    @State private var notificationAuthStatus: UNAuthorizationStatus = .notDetermined
    @State private var selectedTimeScope: TaskTimeScope = .today
    @State private var autoCarryOver: Bool = false
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
    @State private var selectedMonthlyDays: Set<Int> = []
    @State private var monthlySelectionMode: WatchMonthlySelectionMode = .days
    @State private var selectedOrdinalPatterns: Set<Recurrence.OrdinalPattern> = []
    @State private var dayInterval: Int = 1
    @State private var weekInterval: Int = 1
    @State private var monthInterval: Int = 1
    @State private var yearInterval: Int = 1
    @State private var useWeekModuloPattern: Bool = false
    @State private var weekModuloK: Int = 2
    @State private var weekModuloOffset: Int = 0
    @State private var selectedWeekOrdinals: Set<Int> = []
    @State private var selectedMonths: Set<Int> = []
    @State private var useYearModuloPattern: Bool = false
    @State private var yearModuloK: Int = 2
    @State private var yearModuloOffset: Int = 0
    @State private var weeklyTimeOverrides: [Int: Date] = [:]
    @State private var monthlyDayTimeOverrides: [Int: Date] = [:]
    @State private var monthlyOrdinalTimeOverrides: [Recurrence.OrdinalPattern: Date] = [:]
    @State private var hasRecurrenceEndDate: Bool = false
    @State private var recurrenceEndDate: Date = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    @State private var trackInStatistics: Bool = true
    @State private var showAdvancedRecurrence: Bool = false
    
    // MARK: - Subtasks
    @State private var subtasks: [Subtask] = []
    @State private var newSubtaskName: String = ""
    
    // MARK: - Rewards
    @State private var hasRewardPoints: Bool = false
    @State private var rewardPoints: Int = 5
    @State private var useCustomPoints: Bool = false
    @State private var customPointsValue: Double = 5
    
    // MARK: - Navigation
    
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
    
    private var isDaily: Bool { if case .daily = recurrenceType { return true }; return false }
    private var isWeekly: Bool { if case .weekly = recurrenceType { return true }; return false }
    private var isMonthly: Bool {
        if case .monthly = recurrenceType { return true }
        if case .monthlyOrdinal = recurrenceType { return true }
        return false
    }
    private var isYearly: Bool { if case .yearly = recurrenceType { return true }; return false }
    
    private var availableScopes: [TaskTimeScope] {
        TaskTimeScope.allCases.filter { $0 != .all }
    }
    
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
    
    private var durationText: String {
        let h = durationMinutes / 60
        let m = durationMinutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }
    
    private var leadTimeText: String {
        if leadTimeMinutes == 0 { return "At time" }
        let isAfter = leadTimeMinutes < 0
        let value = abs(leadTimeMinutes)
        let suffix = isAfter ? "after" : "before"
        if value >= 60 {
            let h = value / 60
            let m = value % 60
            if m == 0 { return "\(h)h \(suffix)" }
            return "\(h)h \(m)m \(suffix)"
        }
        return "\(value)m \(suffix)"
    }
    
    private let rewardPointPresets: [Int] = [
        1, 2, 3, 5, 8, 10,
        15, 20, 25, 30, 40, 50,
        75, 100, 150, 200,
        250, 300, 400, 500
    ]
    
    private var availableYears: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return Array((current - 1)...(current + 5))
    }
    
    private var periodRange: ClosedRange<Date> {
        let calendar = Calendar.current
        switch selectedTimeScope {
        case .week:
            let start = calendar.startOfWeek(for: selectedWeekDate)
            let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
            return start...end
        case .month:
            var comps = DateComponents()
            comps.year = selectedYear
            comps.month = selectedMonth
            comps.day = 1
            let start = calendar.date(from: comps) ?? Date()
            let next = calendar.date(byAdding: .month, value: 1, to: start) ?? start
            let end = calendar.date(byAdding: .day, value: -1, to: next) ?? start
            return start...end
        case .year:
            var comps = DateComponents()
            comps.year = selectedYear
            comps.month = 1
            comps.day = 1
            let start = calendar.date(from: comps) ?? Date()
            var endComps = DateComponents()
            endComps.year = selectedYear
            endComps.month = 12
            endComps.day = 31
            let end = calendar.date(from: endComps) ?? start
            return start...end
        case .longTerm, .today, .all:
            return Date.distantPast...Date.distantFuture
        }
    }
    
    private var periodSummaryText: String {
        let formatter = DateFormatter()
        switch selectedTimeScope {
        case .week:
            formatter.dateStyle = .short
            let start = periodRange.lowerBound
            let end = periodRange.upperBound
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        case .month:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: periodRange.lowerBound)
        case .year:
            formatter.dateFormat = "yyyy"
            return formatter.string(from: periodRange.lowerBound)
        case .longTerm:
            return "Long Term"
        case .today:
            formatter.dateStyle = .medium
            return formatter.string(from: startTime)
        case .all:
            return "All"
        }
    }
    
    private var ordinalPatternsSummary: String {
        let sorted = selectedOrdinalPatterns.sorted { lhs, rhs in
            if lhs.ordinal != rhs.ordinal { return lhs.ordinal < rhs.ordinal }
            return lhs.weekday < rhs.weekday
        }
        if sorted.isEmpty { return "None" }
        return sorted.map { $0.displayText }.joined(separator: ", ")
    }
    
    private var taskPreviewTitle: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled task" : trimmed
    }
    
    private var taskPreviewSubtitle: String {
        var parts: [String] = [scopeName(selectedTimeScope)]
        if hasSpecificTime {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            parts.append(formatter.string(from: startTime))
        }
        if hasDuration {
            parts.append(durationText)
        }
        if isRecurring {
            parts.append("Repeats")
        }
        return parts.joined(separator: " • ")
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            List {
                overviewSection
                detailsSection
                timeSection
                categorySection
                prioritySection
                if selectedTimeScope != .longTerm { recurrenceSection }
                subtasksSection
                rewardsSection
                saveSection
            }
            .navigationTitle(isEditing ? "Edit Task" : "New Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") {
                        saveTask()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .onAppear {
            loadExistingTask()
            refreshNotificationStatus()
            handleScopeChange()
            clampSpecificDayDate()
        }
        .onChange(of: selectedTimeScope) { _, _ in
            handleScopeChange()
        }
        .onChange(of: selectedWeekDate) { _, _ in
            clampSpecificDayDate()
        }
        .onChange(of: selectedMonth) { _, _ in
            clampSpecificDayDate()
        }
        .onChange(of: selectedYear) { _, _ in
            clampSpecificDayDate()
        }
        .onChange(of: hasSpecificDay) { _, newValue in
            if !newValue {
                hasSpecificTime = false
                hasNotification = false
            }
        }
        .onChange(of: hasSpecificTime) { _, newValue in
            if !newValue {
                hasNotification = false
            }
        }
        .onChange(of: hasNotification) { _, newValue in
            if newValue {
                Task {
                    _ = await notificationManager.requestAuthorization()
                    await MainActor.run {
                        refreshNotificationStatus()
                    }
                }
            }
        }
        .onChange(of: selectedDays) { _, newValue in
            weeklyTimeOverrides = weeklyTimeOverrides.filter { newValue.contains($0.key) }
        }
        .onChange(of: selectedMonthlyDays) { _, newValue in
            monthlyDayTimeOverrides = monthlyDayTimeOverrides.filter { newValue.contains($0.key) }
            if monthlySelectionMode == .days {
                recurrenceType = .monthly(days: newValue)
            }
        }
        .onChange(of: selectedOrdinalPatterns) { _, newValue in
            monthlyOrdinalTimeOverrides = monthlyOrdinalTimeOverrides.filter { newValue.contains($0.key) }
            if monthlySelectionMode == .ordinal {
                recurrenceType = .monthlyOrdinal(patterns: newValue)
            }
        }
        .onChange(of: monthlySelectionMode) { _, newValue in
            switch newValue {
            case .days:
                if selectedMonthlyDays.isEmpty {
                    selectedMonthlyDays.insert(Calendar.current.component(.day, from: Date()))
                }
                recurrenceType = .monthly(days: selectedMonthlyDays)
            case .ordinal:
                if selectedOrdinalPatterns.isEmpty {
                    let wd = Calendar.current.component(.weekday, from: Date())
                    selectedOrdinalPatterns.insert(Recurrence.OrdinalPattern(ordinal: 1, weekday: wd))
                }
                recurrenceType = .monthlyOrdinal(patterns: selectedOrdinalPatterns)
            }
        }
    }
    
    private var overviewSection: some View {
        Section {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(selectedCategory.map { Color(hex: $0.color) } ?? .accentColor)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill((selectedCategory.map { Color(hex: $0.color) } ?? .accentColor).opacity(0.18)))
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(taskPreviewTitle)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .lineLimit(2)
                    Text(taskPreviewSubtitle)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 4)
            
            if !isValid {
                Label("Add a name to create the task", systemImage: "exclamationmark.circle")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
    }
    
    // MARK: - Details Section
    private var detailsSection: some View {
        Section("Details") {
            TextField("Task name", text: $name)
            NavigationLink {
                WatchMultilineTextEditorView(title: "Description", text: $taskDescription)
            } label: {
                HStack {
                    Text("Description")
                    Spacer()
                    if taskDescription.isEmpty {
                        Text("Add")
                            .foregroundColor(.secondary)
                    } else {
                        Text(taskDescription)
                            .lineLimit(1)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            NavigationLink {
                WatchLocationPickerView(selectedLocation: $location)
            } label: {
                HStack {
                    Text("Location")
                    Spacer()
                    if let location {
                        Text(location.shortDisplayName)
                            .lineLimit(1)
                            .foregroundColor(.secondary)
                    } else {
                        Text("None")
                            .foregroundColor(.secondary)
                    }
                }
            }
            NavigationLink {
                WatchIconPickerView(selectedIcon: $icon)
            } label: {
                HStack {
                    Text("Icon")
                    Spacer()
                    Image(systemName: icon)
                        .foregroundColor(.accentColor)
                }
            }
        }
    }
    
    // MARK: - Time Section
    private var timeSection: some View {
        Section("Time") {
            Picker("Scope", selection: $selectedTimeScope) {
                ForEach(availableScopes, id: \.self) { scope in
                    Text(scopeName(scope)).tag(scope)
                }
            }
            
            if selectedTimeScope == .today {
                Toggle("Specific Time", isOn: $hasSpecificTime)
                
                if hasSpecificTime {
                    DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                    
                    Toggle("Notification", isOn: $hasNotification)
                    
                    if notificationAuthStatus == .denied {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("Notifications disabled on Watch/iPhone")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if hasNotification {
                        NavigationLink {
                            WatchLeadTimeOptionsView(selectedMinutes: $leadTimeMinutes)
                        } label: {
                            HStack {
                                Text("Lead Time")
                                Spacer()
                                Text(leadTimeText)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if !syncManager.isPhoneReachable {
                            HStack(spacing: 6) {
                                Image(systemName: "iphone.slash")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                Text("Will sync when iPhone is connected")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            } else {
                // Period selection for week/month/year
                switch selectedTimeScope {
                case .week:
                    DatePicker("Week of", selection: $selectedWeekDate, displayedComponents: .date)
                    Text(periodSummaryText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                case .month:
                    NavigationLink {
                        WatchMonthYearPickerView(
                            month: $selectedMonth,
                            year: $selectedYear,
                            availableYears: availableYears
                        )
                    } label: {
                        HStack {
                            Text("Period")
                            Spacer()
                            Text(periodSummaryText)
                                .foregroundColor(.secondary)
                        }
                    }
                case .year:
                    NavigationLink {
                        WatchYearPickerView(year: $selectedYear, availableYears: availableYears)
                    } label: {
                        HStack {
                            Text("Year")
                            Spacer()
                            Text(periodSummaryText)
                                .foregroundColor(.secondary)
                        }
                    }
                case .longTerm:
                    Text("No fixed period")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                case .today, .all:
                    EmptyView()
                }
                
                Toggle("Specific Day", isOn: $hasSpecificDay)
                
                if hasSpecificDay {
                    DatePicker("Day", selection: $specificDayDate, in: periodRange, displayedComponents: .date)
                    
                    Toggle("Specific Time", isOn: $hasSpecificTime)
                    
                    if hasSpecificTime {
                        DatePicker("Time", selection: $startTime, displayedComponents: .hourAndMinute)
                        
                        Toggle("Notification", isOn: $hasNotification)
                        
                        if notificationAuthStatus == .denied {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("Notifications disabled on Watch/iPhone")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if hasNotification {
                            NavigationLink {
                                WatchLeadTimeOptionsView(selectedMinutes: $leadTimeMinutes)
                            } label: {
                                HStack {
                                    Text("Lead Time")
                                    Spacer()
                                    Text(leadTimeText)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if !syncManager.isPhoneReachable {
                                HStack(spacing: 6) {
                                    Image(systemName: "iphone.slash")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                    Text("Will sync when iPhone is connected")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            
            Toggle("Duration", isOn: $hasDuration)
            
            if hasDuration {
                NavigationLink {
                    WatchDurationPicker(minutes: $durationMinutes)
                } label: {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(durationText)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            if !isRecurring && selectedTimeScope != .longTerm {
                Toggle("Auto Carry Over", isOn: $autoCarryOver)
            }
        }
    }
    
    // MARK: - Category Section
    private var categorySection: some View {
        Section("Category") {
            NavigationLink {
                WatchCategoryPickerView(
                    categories: syncManager.categories,
                    selectedCategory: $selectedCategory
                )
            } label: {
                HStack {
                    Text("Select Category")
                    Spacer()
                    if let selectedCategory {
                        Text(selectedCategory.name)
                            .foregroundColor(.secondary)
                    } else {
                        Text("None")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
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
                        ) { selectedCategory = category }
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
        }
    }
    
    // MARK: - Priority Section
    private var prioritySection: some View {
        Section("Priority") {
            HStack(spacing: 4) {
                ForEach(Priority.allCases, id: \.self) { p in
                    PriorityButton(priority: p, isSelected: priority == p) {
                        priority = p
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
        }
    }
    
    // MARK: - Recurrence Section
    private var recurrenceSection: some View {
        Section("Recurrence") {
            Toggle("Repeat", isOn: $isRecurring)
            
            if isRecurring {
                Picker("Frequency", selection: Binding(
                    get: { recurrenceTypeTag },
                    set: { setRecurrenceType($0) }
                )) {
                    Text("Daily").tag("daily")
                    Text("Weekly").tag("weekly")
                    Text("Monthly").tag("monthly")
                    Text("Yearly").tag("yearly")
                }
                
                if selectedTimeScope != .today {
                    Text("Recurrence is contextual to selected scope")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if isDaily {
                    Stepper("Every \(dayInterval) day(s)", value: $dayInterval, in: 1...30)
                }
                
                if isWeekly {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Days")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        HStack(spacing: 3) {
                            ForEach(1...7, id: \.self) { day in
                                let sym = Calendar.current.veryShortWeekdaySymbols[day - 1]
                                Button {
                                    if selectedDays.contains(day) { selectedDays.remove(day) }
                                    else { selectedDays.insert(day) }
                                    recurrenceType = .weekly(days: selectedDays)
                                } label: {
                                    Text(sym)
                                        .font(.system(size: 11, weight: .semibold))
                                        .frame(width: 22, height: 22)
                                        .background(Circle().fill(selectedDays.contains(day) ? Color.blue : Color.gray.opacity(0.3)))
                                        .foregroundColor(selectedDays.contains(day) ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                    
                    Stepper("Every \(weekInterval) week(s)", value: $weekInterval, in: 1...12)
                    
                    if !selectedDays.isEmpty {
                        NavigationLink {
                            WatchWeeklyTimeOverridesView(
                                selectedDays: $selectedDays,
                                overrides: $weeklyTimeOverrides,
                                baseTime: startTime
                            )
                        } label: {
                            HStack {
                                Text("Times")
                                Spacer()
                                Text("Edit")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                if isMonthly {
                    Picker("Mode", selection: $monthlySelectionMode) {
                        ForEach(WatchMonthlySelectionMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    
                    Stepper("Every \(monthInterval) month(s)", value: $monthInterval, in: 1...12)

                    if monthlySelectionMode == .days {
                        NavigationLink {
                            WatchMonthlyDayPicker(selectedDays: $selectedMonthlyDays, onDone: {
                                recurrenceType = .monthly(days: selectedMonthlyDays)
                            })
                        } label: {
                            HStack {
                                Text("Days of Month")
                                Spacer()
                                Text(selectedMonthlyDays.sorted().map(String.init).joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        if !selectedMonthlyDays.isEmpty {
                            NavigationLink {
                                WatchMonthlyDayTimeOverridesView(
                                    selectedDays: $selectedMonthlyDays,
                                    overrides: $monthlyDayTimeOverrides,
                                    baseTime: startTime
                                )
                            } label: {
                                HStack {
                                    Text("Day Times")
                                    Spacer()
                                    Text("Edit")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    } else {
                        NavigationLink {
                            WatchMonthlyOrdinalPickerView(selectedPatterns: $selectedOrdinalPatterns)
                        } label: {
                            HStack {
                                Text("Ordinal Patterns")
                                Spacer()
                                Text(ordinalPatternsSummary)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        if !selectedOrdinalPatterns.isEmpty {
                            NavigationLink {
                                WatchMonthlyOrdinalTimeOverridesView(
                                    selectedPatterns: $selectedOrdinalPatterns,
                                    overrides: $monthlyOrdinalTimeOverrides,
                                    baseTime: startTime
                                )
                            } label: {
                                HStack {
                                    Text("Pattern Times")
                                    Spacer()
                                    Text("Edit")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                
                if isYearly {
                    Stepper("Every \(yearInterval) year(s)", value: $yearInterval, in: 1...10)
                }
                
                Toggle("Show Advanced", isOn: $showAdvancedRecurrence)
                
                if showAdvancedRecurrence {
                    if isWeekly {
                        Toggle("Modulo Pattern", isOn: $useWeekModuloPattern)
                        
                        if useWeekModuloPattern {
                            Stepper("Every \(weekModuloK) weeks", value: $weekModuloK, in: 2...12)
                            Stepper("Offset \(weekModuloOffset)", value: $weekModuloOffset, in: 0...(weekModuloK - 1))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Weeks of Month")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            HStack(spacing: 4) {
                                ForEach([1, 2, 3, 4, 5, -1], id: \.self) { ordinal in
                                    Button {
                                        if selectedWeekOrdinals.contains(ordinal) {
                                            selectedWeekOrdinals.remove(ordinal)
                                        } else {
                                            selectedWeekOrdinals.insert(ordinal)
                                        }
                                    } label: {
                                        Text(ordinal == -1 ? "L" : "\(ordinal)")
                                            .font(.system(size: 10, weight: .semibold))
                                            .frame(width: 22, height: 22)
                                            .background(Circle().fill(selectedWeekOrdinals.contains(ordinal) ? Color.green : Color.gray.opacity(0.3)))
                                            .foregroundColor(selectedWeekOrdinals.contains(ordinal) ? .white : .primary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    
                    if isMonthly {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Specific Months")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 28))], spacing: 4) {
                                ForEach(1...12, id: \.self) { month in
                                    Button {
                                        if selectedMonths.contains(month) {
                                            selectedMonths.remove(month)
                                        } else {
                                            selectedMonths.insert(month)
                                        }
                                    } label: {
                                        Text("\(month)")
                                            .font(.system(size: 10, weight: .semibold))
                                            .frame(width: 28, height: 22)
                                            .background(Capsule().fill(selectedMonths.contains(month) ? Color.orange : Color.gray.opacity(0.3)))
                                            .foregroundColor(selectedMonths.contains(month) ? .white : .primary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    
                    if isYearly {
                        Toggle("Modulo Pattern", isOn: $useYearModuloPattern)
                        
                        if useYearModuloPattern {
                            Stepper("Every \(yearModuloK) years", value: $yearModuloK, in: 2...20)
                            Stepper("Offset \(yearModuloOffset)", value: $yearModuloOffset, in: 0...(yearModuloK - 1))
                        }
                    }
                    
                    Toggle("Track in Stats", isOn: $trackInStatistics)
                }
                
                Toggle("End Date", isOn: $hasRecurrenceEndDate)
                
                if hasRecurrenceEndDate {
                    DatePicker("Ends", selection: $recurrenceEndDate, displayedComponents: .date)
                }
            }
        }
    }
    
    // MARK: - Subtasks Section
    private var subtasksSection: some View {
        Section {
            HStack {
                TextField("New subtask", text: $newSubtaskName)
                    .font(.caption)
                Button {
                    guard !newSubtaskName.isEmpty else { return }
                    subtasks.append(Subtask(name: newSubtaskName))
                    newSubtaskName = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
                .disabled(newSubtaskName.isEmpty)
            }
            
            ForEach(subtasks) { subtask in
                HStack(spacing: 6) {
                    Image(systemName: "circle")
                        .font(.system(size: 8))
                        .foregroundColor(.accentColor)
                    Text(subtask.name)
                        .font(.caption)
                    Spacer()
                    Button {
                        subtasks.removeAll { $0.id == subtask.id }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            HStack {
                Text("Subtasks")
                if !subtasks.isEmpty {
                    Spacer()
                    Text("\(subtasks.count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Rewards Section
    private var rewardsSection: some View {
        Section("Rewards") {
            Toggle("Reward Points", isOn: $hasRewardPoints)
            
            if hasRewardPoints {
                NavigationLink {
                    WatchRewardPointsEditorView(
                        useCustomPoints: $useCustomPoints,
                        points: $rewardPoints,
                        customPointsValue: $customPointsValue,
                        presets: rewardPointPresets
                    )
                } label: {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("\(rewardPoints) pts")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                        Spacer()
                        Text(useCustomPoints ? "Custom" : "Preset")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Save Section
    private var saveSection: some View {
        Section {
            Button {
                saveTask()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(isEditing ? "Save" : "Create Task")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(!isValid)
            .listRowBackground(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isValid ? Color.accentColor : Color.gray.opacity(0.3))
            )
            .foregroundColor(isValid ? .white : .secondary)
        }
    }
    
    // MARK: - Recurrence Type Helpers
    private var recurrenceTypeTag: String {
        switch recurrenceType {
        case .daily: return "daily"
        case .weekly: return "weekly"
        case .monthly: return "monthly"
        case .monthlyOrdinal: return "monthly"
        case .yearly: return "yearly"
        default: return "daily"
        }
    }
    
    private func setRecurrenceType(_ tag: String) {
        switch tag {
        case "daily":
            recurrenceType = .daily
        case "weekly":
            if selectedDays.isEmpty {
                selectedDays.insert(Calendar.current.component(.weekday, from: Date()))
            }
            recurrenceType = .weekly(days: selectedDays)
        case "monthly":
            if monthlySelectionMode == .ordinal {
                if selectedOrdinalPatterns.isEmpty {
                    let wd = Calendar.current.component(.weekday, from: Date())
                    selectedOrdinalPatterns.insert(Recurrence.OrdinalPattern(ordinal: 1, weekday: wd))
                }
                recurrenceType = .monthlyOrdinal(patterns: selectedOrdinalPatterns)
            } else {
                if selectedMonthlyDays.isEmpty {
                    selectedMonthlyDays.insert(Calendar.current.component(.day, from: Date()))
                }
                recurrenceType = .monthly(days: selectedMonthlyDays)
            }
        case "yearly":
            recurrenceType = .yearly
        default:
            recurrenceType = .daily
        }
    }
    
    // MARK: - Data Loading
    private func loadExistingTask() {
        guard let task = existingTask else { return }
        
        name = task.name
        taskDescription = task.description ?? ""
        location = task.location
        startTime = task.startTime
        hasSpecificDay = task.hasSpecificDay
        specificDayDate = task.startTime
        hasSpecificTime = task.hasSpecificTime
        hasDuration = task.hasDuration
        durationMinutes = Int(task.duration / 60)
        hasNotification = task.hasNotification
        leadTimeMinutes = task.notificationLeadTimeMinutes
        selectedTimeScope = task.timeScope
        autoCarryOver = task.autoCarryOver
        let cal = Calendar.current
        if let start = task.scopeStartDate {
            selectedWeekDate = start
            selectedMonth = cal.component(.month, from: start)
            selectedYear = cal.component(.year, from: start)
        } else {
            selectedWeekDate = task.startTime
            selectedMonth = cal.component(.month, from: task.startTime)
            selectedYear = cal.component(.year, from: task.startTime)
        }
        selectedCategory = task.category
        priority = task.priority
        icon = task.icon
        subtasks = task.subtasks
        hasRewardPoints = task.hasRewardPoints
        rewardPoints = task.rewardPoints
        useCustomPoints = !rewardPointPresets.contains(task.rewardPoints)
        customPointsValue = Double(task.rewardPoints)
        
        if let recurrence = task.recurrence {
            isRecurring = true
            recurrenceType = recurrence.type
            if case .weekly(let days) = recurrence.type {
                selectedDays = days
            }
            if case .monthly(let days) = recurrence.type {
                monthlySelectionMode = .days
                selectedMonthlyDays = days
            }
            if case .monthlyOrdinal(let patterns) = recurrence.type {
                monthlySelectionMode = .ordinal
                selectedOrdinalPatterns = patterns
            }
            hasRecurrenceEndDate = recurrence.endDate != nil
            recurrenceEndDate = recurrence.endDate ?? recurrenceEndDate
            trackInStatistics = recurrence.trackInStatistics
            
            dayInterval = recurrence.dayInterval ?? 1
            weekInterval = recurrence.weekInterval ?? 1
            monthInterval = recurrence.monthInterval ?? 1
            yearInterval = recurrence.yearInterval ?? 1
            useWeekModuloPattern = recurrence.weekModuloK != nil
            weekModuloK = recurrence.weekModuloK ?? 2
            weekModuloOffset = recurrence.weekModuloOffset ?? 0
            selectedWeekOrdinals = recurrence.weekSelectedOrdinals ?? []
            selectedMonths = recurrence.monthSelectedMonths ?? []
            useYearModuloPattern = recurrence.yearModuloK != nil
            yearModuloK = recurrence.yearModuloK ?? 2
            yearModuloOffset = recurrence.yearModuloOffset ?? 0
            
            let calendar = Calendar.current
            if let overrides = recurrence.weekdayTimeOverrides {
                weeklyTimeOverrides = Dictionary(uniqueKeysWithValues: overrides.map { override in
                    let date = calendar.date(bySettingHour: override.hour, minute: override.minute, second: 0, of: Date()) ?? Date()
                    return (override.weekday, date)
                })
            }
            if let overrides = recurrence.monthDayTimeOverrides {
                monthlyDayTimeOverrides = Dictionary(uniqueKeysWithValues: overrides.map { override in
                    let date = calendar.date(bySettingHour: override.hour, minute: override.minute, second: 0, of: Date()) ?? Date()
                    return (override.day, date)
                })
            }
            if let overrides = recurrence.monthOrdinalTimeOverrides {
                monthlyOrdinalTimeOverrides = Dictionary(uniqueKeysWithValues: overrides.map { override in
                    let pattern = Recurrence.OrdinalPattern(ordinal: override.ordinal, weekday: override.weekday)
                    let date = calendar.date(bySettingHour: override.hour, minute: override.minute, second: 0, of: Date()) ?? Date()
                    return (pattern, date)
                })
            }
        }
    }
    
    private func computeTaskStartAndScope() -> (Date, Date?, Date?) {
        let calendar = Calendar.current
        
        switch selectedTimeScope {
        case .today:
            let taskStart = hasSpecificTime ? startTime : calendar.startOfDay(for: startTime)
            return (taskStart, nil, nil)
        case .week:
            let weekStart = calendar.startOfWeek(for: selectedWeekDate)
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
            let taskStart: Date
            if hasSpecificDay {
                let clamped = max(weekStart, min(weekEnd, specificDayDate))
                taskStart = hasSpecificTime ? merge(date: clamped, time: startTime) : calendar.startOfDay(for: clamped)
            } else {
                taskStart = weekStart
            }
            return (taskStart, weekStart, weekEnd)
        case .month:
            var comps = DateComponents()
            comps.year = selectedYear
            comps.month = selectedMonth
            comps.day = 1
            let monthStart = calendar.date(from: comps) ?? Date()
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
            let monthEnd = calendar.date(byAdding: .day, value: -1, to: nextMonth) ?? monthStart
            let taskStart: Date
            if hasSpecificDay {
                let day = calendar.component(.day, from: specificDayDate)
                let range = calendar.range(of: .day, in: .month, for: monthStart) ?? (1..<29)
                let clampedDay = max(range.lowerBound, min(range.upperBound - 1, day))
                var d = DateComponents()
                d.year = selectedYear
                d.month = selectedMonth
                d.day = clampedDay
                let base = calendar.date(from: d) ?? monthStart
                taskStart = hasSpecificTime ? merge(date: base, time: startTime) : calendar.startOfDay(for: base)
            } else {
                taskStart = monthStart
            }
            return (taskStart, monthStart, monthEnd)
        case .year:
            var startComps = DateComponents()
            startComps.year = selectedYear
            startComps.month = 1
            startComps.day = 1
            let yearStart = calendar.date(from: startComps) ?? Date()
            var endComps = DateComponents()
            endComps.year = selectedYear
            endComps.month = 12
            endComps.day = 31
            let yearEnd = calendar.date(from: endComps) ?? yearStart
            let taskStart: Date
            if hasSpecificDay {
                var d = DateComponents()
                d.year = selectedYear
                d.month = calendar.component(.month, from: specificDayDate)
                d.day = calendar.component(.day, from: specificDayDate)
                let base = calendar.date(from: d) ?? yearStart
                taskStart = hasSpecificTime ? merge(date: base, time: startTime) : calendar.startOfDay(for: base)
            } else {
                taskStart = yearStart
            }
            return (taskStart, yearStart, yearEnd)
        case .longTerm:
            if hasSpecificDay {
                let baseDay = calendar.startOfDay(for: specificDayDate)
                let taskStart = hasSpecificTime ? merge(date: baseDay, time: startTime) : baseDay
                return (taskStart, nil, nil)
            }
            return (calendar.startOfDay(for: Date()), nil, nil)
        case .all:
            let taskStart = hasSpecificTime ? startTime : calendar.startOfDay(for: startTime)
            return (taskStart, nil, nil)
        }
    }
    
    private func merge(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        var comps = calendar.dateComponents([.year, .month, .day], from: date)
        comps.hour = calendar.component(.hour, from: time)
        comps.minute = calendar.component(.minute, from: time)
        comps.second = 0
        return calendar.date(from: comps) ?? date
    }
    
    private func clampSpecificDayDate() {
        guard selectedTimeScope != .today else {
            specificDayDate = startTime
            return
        }
        let range = periodRange
        if specificDayDate < range.lowerBound {
            specificDayDate = range.lowerBound
        } else if specificDayDate > range.upperBound {
            specificDayDate = range.upperBound
        }
    }
    
    private func handleScopeChange() {
        if selectedTimeScope == .today {
            hasSpecificDay = true
        }
        if !hasSpecificDay {
            hasSpecificTime = false
            hasNotification = false
        }
        clampSpecificDayDate()
    }
    
    private func refreshNotificationStatus() {
        notificationAuthStatus = notificationManager.authorizationStatus
        if hasNotification && notificationManager.authorizationStatus == .denied {
            hasNotification = false
        }
    }
    
    // MARK: - Build Recurrence
    private func buildRecurrence(startDate: Date) -> Recurrence? {
        guard isRecurring else { return nil }
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: startDate)
        let endDate = hasRecurrenceEndDate ? calendar.startOfDay(for: recurrenceEndDate) : nil
        
        switch recurrenceType {
        case .daily:
            var rec = Recurrence(type: .daily, startDate: startDay, endDate: endDate, trackInStatistics: trackInStatistics)
            if dayInterval > 1 { rec.dayInterval = dayInterval }
            return rec
            
        case .weekly:
            var days = selectedDays
            if days.isEmpty {
                days.insert(calendar.component(.weekday, from: startDay))
            }
            var rec = Recurrence(type: .weekly(days: days), startDate: startDay, endDate: endDate, trackInStatistics: trackInStatistics)
            if weekInterval > 1 { rec.weekInterval = weekInterval }
            if useWeekModuloPattern {
                rec.weekModuloK = weekModuloK
                rec.weekModuloOffset = min(weekModuloOffset, weekModuloK - 1)
            }
            rec.weekSelectedOrdinals = selectedWeekOrdinals.isEmpty ? nil : selectedWeekOrdinals
            let overrides: [Recurrence.WeekdayTimeOverride] = days.compactMap { day in
                guard let time = weeklyTimeOverrides[day] else { return nil }
                return Recurrence.WeekdayTimeOverride(
                    weekday: day,
                    hour: calendar.component(.hour, from: time),
                    minute: calendar.component(.minute, from: time)
                )
            }
            rec.weekdayTimeOverrides = overrides.isEmpty ? nil : overrides
            return rec
            
        case .monthly:
            if monthlySelectionMode == .ordinal {
                var patterns = selectedOrdinalPatterns
                if patterns.isEmpty {
                    let wd = calendar.component(.weekday, from: startDay)
                    patterns.insert(Recurrence.OrdinalPattern(ordinal: 1, weekday: wd))
                }
                var rec = Recurrence(type: .monthlyOrdinal(patterns: patterns), startDate: startDay, endDate: endDate, trackInStatistics: trackInStatistics)
                if monthInterval > 1 { rec.monthInterval = monthInterval }
                rec.monthSelectedMonths = selectedMonths.isEmpty ? nil : selectedMonths
                let overrides: [Recurrence.MonthOrdinalTimeOverride] = patterns.compactMap { pattern in
                    guard let time = monthlyOrdinalTimeOverrides[pattern] else { return nil }
                    return Recurrence.MonthOrdinalTimeOverride(
                        ordinal: pattern.ordinal,
                        weekday: pattern.weekday,
                        hour: calendar.component(.hour, from: time),
                        minute: calendar.component(.minute, from: time)
                    )
                }
                rec.monthOrdinalTimeOverrides = overrides.isEmpty ? nil : overrides
                return rec
            } else {
                var days = selectedMonthlyDays
                if days.isEmpty {
                    days.insert(calendar.component(.day, from: startDay))
                }
                var rec = Recurrence(type: .monthly(days: days), startDate: startDay, endDate: endDate, trackInStatistics: trackInStatistics)
                if monthInterval > 1 { rec.monthInterval = monthInterval }
                rec.monthSelectedMonths = selectedMonths.isEmpty ? nil : selectedMonths
                let overrides: [Recurrence.MonthDayTimeOverride] = days.compactMap { day in
                    guard let time = monthlyDayTimeOverrides[day] else { return nil }
                    return Recurrence.MonthDayTimeOverride(
                        day: day,
                        hour: calendar.component(.hour, from: time),
                        minute: calendar.component(.minute, from: time)
                    )
                }
                rec.monthDayTimeOverrides = overrides.isEmpty ? nil : overrides
                return rec
            }
            
        case .monthlyOrdinal:
            var patterns = selectedOrdinalPatterns
            if patterns.isEmpty {
                let wd = calendar.component(.weekday, from: startDay)
                patterns.insert(Recurrence.OrdinalPattern(ordinal: 1, weekday: wd))
            }
            var rec = Recurrence(type: .monthlyOrdinal(patterns: patterns), startDate: startDay, endDate: endDate, trackInStatistics: trackInStatistics)
            if monthInterval > 1 { rec.monthInterval = monthInterval }
            rec.monthSelectedMonths = selectedMonths.isEmpty ? nil : selectedMonths
            let overrides: [Recurrence.MonthOrdinalTimeOverride] = patterns.compactMap { pattern in
                guard let time = monthlyOrdinalTimeOverrides[pattern] else { return nil }
                return Recurrence.MonthOrdinalTimeOverride(
                    ordinal: pattern.ordinal,
                    weekday: pattern.weekday,
                    hour: calendar.component(.hour, from: time),
                    minute: calendar.component(.minute, from: time)
                )
            }
            rec.monthOrdinalTimeOverrides = overrides.isEmpty ? nil : overrides
            return rec
            
        case .yearly:
            var rec = Recurrence(type: .yearly, startDate: startDay, endDate: endDate, trackInStatistics: trackInStatistics)
            if yearInterval > 1 { rec.yearInterval = yearInterval }
            if useYearModuloPattern {
                rec.yearModuloK = yearModuloK
                rec.yearModuloOffset = min(yearModuloOffset, yearModuloK - 1)
            }
            if hasSpecificTime {
                rec.yearlyTimeOverride = Recurrence.YearlyTimeOverride(
                    hour: calendar.component(.hour, from: startTime),
                    minute: calendar.component(.minute, from: startTime)
                )
            }
            return rec
        }
    }
    
    // MARK: - Save Task
    private func saveTask() {
        let (taskStartTime, scopeStartDate, scopeEndDate) = computeTaskStartAndScope()
        let normalizedPoints = max(1, min(999, rewardPoints))
        let effectiveTimeScope: TaskTimeScope = selectedTimeScope == .all ? .today : selectedTimeScope
        let effectiveHasSpecificDay = (effectiveTimeScope == .today) ? true : hasSpecificDay
        
        if isEditing, let existing = existingTask {
            var updatedTask = existing
            updatedTask.name = name
            updatedTask.description = taskDescription.isEmpty ? nil : taskDescription
            updatedTask.location = location
            updatedTask.startTime = taskStartTime
            updatedTask.hasSpecificDay = effectiveHasSpecificDay
            updatedTask.hasSpecificTime = hasSpecificTime
            updatedTask.hasDuration = hasDuration
            updatedTask.duration = durationSeconds
            updatedTask.hasNotification = hasNotification
            updatedTask.notificationLeadTimeMinutes = leadTimeMinutes
            updatedTask.timeScope = effectiveTimeScope
            updatedTask.scopeStartDate = scopeStartDate
            updatedTask.scopeEndDate = scopeEndDate
            updatedTask.autoCarryOver = autoCarryOver
            updatedTask.category = selectedCategory
            updatedTask.priority = priority
            updatedTask.icon = icon
            updatedTask.subtasks = subtasks
            updatedTask.recurrence = buildRecurrence(startDate: taskStartTime)
            updatedTask.hasRewardPoints = hasRewardPoints
            updatedTask.rewardPoints = hasRewardPoints ? normalizedPoints : 0
            
            syncManager.updateTask(updatedTask)
        } else {
            let newTask = TodoTask(
                name: name,
                description: taskDescription.isEmpty ? nil : taskDescription,
                location: location,
                startTime: taskStartTime,
                hasSpecificDay: effectiveHasSpecificDay,
                hasSpecificTime: hasSpecificTime,
                duration: durationSeconds,
                hasDuration: hasDuration,
                category: selectedCategory,
                priority: priority,
                icon: icon,
                recurrence: buildRecurrence(startDate: taskStartTime),
                subtasks: subtasks,
                hasRewardPoints: hasRewardPoints,
                rewardPoints: hasRewardPoints ? normalizedPoints : 0,
                hasNotification: hasNotification,
                timeScope: effectiveTimeScope,
                scopeStartDate: scopeStartDate,
                scopeEndDate: scopeEndDate,
                notificationLeadTimeMinutes: leadTimeMinutes,
                autoCarryOver: autoCarryOver
            )
            
            syncManager.createTask(newTask)
        }
        
        dismiss()
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
            HStack(spacing: 4) {
                Image(systemName: priority.icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(priorityLabel)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
            }
            .foregroundColor(isSelected ? priorityColor : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
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

// MARK: - Icon Picker (matching iOS categories)
struct WatchIconPickerView: View {
    @Binding var selectedIcon: String
    @Environment(\.dismiss) private var dismiss
    
    private struct IconGroup: Identifiable {
        let id = UUID()
        let title: String
        let icons: [String]
    }
    
    private let groups: [IconGroup] = [
        IconGroup(title: "General", icons: [
            "circle.fill", "circle", "checkmark.circle.fill",
            "flag.fill", "bookmark.fill", "tag.fill",
            "star.fill", "sparkles", "crown.fill"
        ]),
        IconGroup(title: "Time", icons: [
            "bell.fill", "alarm", "calendar", "clock.fill"
        ]),
        IconGroup(title: "Study & Work", icons: [
            "book.fill", "text.book.closed.fill", "graduationcap.fill",
            "briefcase.fill", "building.2.fill",
            "pencil", "pencil.and.list.clipboard",
            "list.bullet", "checklist", "note.text"
        ]),
        IconGroup(title: "Energy", icons: [
            "bolt.fill", "flame.fill", "drop.fill", "leaf.fill", "lightbulb.fill"
        ]),
        IconGroup(title: "Sport", icons: [
            "dumbbell.fill", "figure.run", "bicycle", "sportscourt.fill",
            "heart.fill", "stethoscope", "cross.case.fill", "pills.fill"
        ]),
        IconGroup(title: "Food", icons: [
            "cup.and.saucer.fill", "fork.knife", "takeoutbag.and.cup.and.straw.fill"
        ]),
        IconGroup(title: "Home", icons: [
            "house.fill", "bed.double.fill", "moon.fill", "zzz",
            "key.fill", "lock.fill"
        ]),
        IconGroup(title: "Travel", icons: [
            "car.fill", "bus.fill", "tram.fill", "airplane", "ferry.fill",
            "globe", "map.fill", "mappin.and.ellipse"
        ]),
        IconGroup(title: "Shopping", icons: [
            "cart.fill", "bag.fill", "creditcard.fill", "banknote.fill", "receipt.fill",
            "gift.fill", "party.popper.fill"
        ]),
        IconGroup(title: "Creative", icons: [
            "brain.head.profile", "paintbrush.fill",
            "music.note", "headphones", "tv.fill", "camera.fill",
            "gamecontroller.fill", "dice.fill"
        ]),
        IconGroup(title: "Social", icons: [
            "phone.fill", "video.fill",
            "message.fill", "bubble.left.and.bubble.right.fill",
            "envelope.fill", "paperplane.fill"
        ]),
        IconGroup(title: "Weather", icons: [
            "sun.max.fill", "cloud.fill", "cloud.sun.fill",
            "cloud.rain.fill", "cloud.snow.fill",
            "wind", "umbrella.fill"
        ]),
        IconGroup(title: "Animals", icons: [
            "pawprint.fill", "ladybug.fill", "tortoise.fill", "hare.fill", "bird.fill", "fish.fill"
        ])
    ]
    
    private let columns = [GridItem(.adaptive(minimum: 36), spacing: 6)]
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(groups) { group in
                    Text(group.title)
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                    
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(group.icons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                                dismiss()
                            } label: {
                                Image(systemName: icon)
                                    .font(.system(size: 14))
                                    .frame(width: 34, height: 34)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedIcon == icon ? Color.accentColor : Color.gray.opacity(0.2))
                                    )
                                    .foregroundColor(selectedIcon == icon ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Icon")
    }
}

// MARK: - Duration Picker
struct WatchDurationPicker: View {
    @Binding var minutes: Int
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Duration")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                Picker("Hours", selection: Binding(
                    get: { minutes / 60 },
                    set: { minutes = $0 * 60 + (minutes % 60) }
                )) {
                    ForEach(0...8, id: \.self) { h in
                        Text("\(h)h").tag(h)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(width: 60)
                
                Text(":")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                Picker("Minutes", selection: Binding(
                    get: { minutes % 60 },
                    set: { minutes = (minutes / 60) * 60 + $0 }
                )) {
                    ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { m in
                        Text(String(format: "%02d", m)).tag(m)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(width: 60)
            }
            
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(.horizontal, 8)
        .navigationTitle("Duration")
    }
}

// MARK: - Lead Time Picker
struct WatchLeadTimePicker: View {
    @Binding var selectedMinutes: Int
    @Binding var isAfter: Bool
    @Environment(\.dismiss) private var dismiss
    
    // 5-minute steps from 0 to 240 minutes
    private let timeOptions = Array(stride(from: 0, through: 240, by: 5))
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Lead Time")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Picker("Minutes", selection: $selectedMinutes) {
                ForEach(timeOptions, id: \.self) { m in
                    Text(formatLeadTime(m)).tag(m)
                }
            }
            .pickerStyle(WheelPickerStyle())
            .labelsHidden()
            
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(.horizontal, 8)
        .navigationTitle("Lead Time")
    }
    
    private func formatLeadTime(_ m: Int) -> String {
        if m == 0 { return "At time" }
        let suffix = isAfter ? "after" : "before"
        if m >= 60 {
            if m % 60 == 0 { return "\(m/60)h \(suffix)" }
            return "\(m/60)h \(m % 60)m \(suffix)"
        }
        return "\(m)m \(suffix)"
    }
}

// MARK: - Monthly Day Picker
struct WatchMonthlyDayPicker: View {
    @Binding var selectedDays: Set<Int>
    var onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Day of month")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Picker("Day", selection: Binding(
                get: { selectedDays.first ?? 1 },
                set: { newDay in selectedDays = Set([newDay]) }
            )) {
                ForEach(1...31, id: \.self) { day in
                    Text("\(day)").tag(day)
                }
            }
            .pickerStyle(WheelPickerStyle())
            .labelsHidden()
            
            Button {
                onDone()
                dismiss()
            } label: {
                Text("Done")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(.horizontal, 8)
        .navigationTitle("Day")
    }
}

// MARK: - Points Picker
struct WatchPointsPicker: View {
    @Binding var points: Int
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Points")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Picker("Points", selection: $points) {
                ForEach(1...200, id: \.self) { v in
                    Text("\(v)").tag(v)
                }
            }
            .pickerStyle(WheelPickerStyle())
            .labelsHidden()
            
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(.horizontal, 8)
        .navigationTitle("Points")
    }
}

// MARK: - Multiline Text Editor
struct WatchMultilineTextEditorView: View {
    let title: String
    @Binding var text: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Enter text")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            TextField(title, text: $text)
                .padding(6)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(8)
            
            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 8)
        .navigationTitle(title)
    }
}

// MARK: - Category Picker
struct WatchCategoryPickerView: View {
    let categories: [Category]
    @Binding var selectedCategory: Category?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            Button {
                selectedCategory = nil
                dismiss()
            } label: {
                HStack {
                    Text("None")
                    Spacer()
                    if selectedCategory == nil {
                        Image(systemName: "checkmark")
                            .foregroundColor(.accentColor)
                    }
                }
            }
            
            ForEach(categories) { category in
                Button {
                    selectedCategory = category
                    dismiss()
                } label: {
                    HStack {
                        Circle()
                            .fill(Color(hex: category.color))
                            .frame(width: 10, height: 10)
                        Text(category.name)
                            .lineLimit(1)
                        Spacer()
                        if selectedCategory?.id == category.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
        }
        .navigationTitle("Category")
    }
}

// MARK: - Month/Year Picker
struct WatchMonthYearPickerView: View {
    @Binding var month: Int
    @Binding var year: Int
    let availableYears: [Int]
    
    var body: some View {
        VStack(spacing: 8) {
            Picker("Month", selection: $month) {
                ForEach(1...12, id: \.self) { m in
                    Text(Calendar.current.monthSymbols[m - 1]).tag(m)
                }
            }
            .pickerStyle(.wheel)
            
            Picker("Year", selection: $year) {
                ForEach(availableYears, id: \.self) { y in
                    Text(String(y)).tag(y)
                }
            }
            .pickerStyle(.wheel)
        }
        .navigationTitle("Period")
    }
}

struct WatchYearPickerView: View {
    @Binding var year: Int
    let availableYears: [Int]
    
    var body: some View {
        VStack(spacing: 8) {
            Picker("Year", selection: $year) {
                ForEach(availableYears, id: \.self) { y in
                    Text(String(y)).tag(y)
                }
            }
            .pickerStyle(.wheel)
        }
        .navigationTitle("Year")
    }
}

// MARK: - Lead Time Options
struct WatchLeadTimeOptionsView: View {
    @Binding var selectedMinutes: Int
    @State private var isAfter: Bool = false
    @State private var customMinutes: Int = 0
    
    private let presets: [Int] = [0, 5, 10, 15, 30, 60, 120]
    
    var body: some View {
        List {
            Section("Direction") {
                Picker("Notify", selection: $isAfter) {
                    Text("Before").tag(false)
                    Text("After").tag(true)
                }
            }
            
            Section("Presets") {
                ForEach(presets, id: \.self) { minutes in
                    Button {
                        selectedMinutes = minutes == 0 ? 0 : (isAfter ? -minutes : minutes)
                        customMinutes = abs(selectedMinutes)
                    } label: {
                        HStack {
                            Text(label(for: minutes))
                            Spacer()
                            if abs(selectedMinutes) == minutes && (minutes == 0 || (selectedMinutes < 0) == isAfter) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            
            Section("Custom") {
                NavigationLink {
                    WatchLeadTimePicker(selectedMinutes: $customMinutes, isAfter: $isAfter)
                } label: {
                    HStack {
                        Text("Custom")
                        Spacer()
                        Text(label(for: customMinutes))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .onAppear {
            isAfter = selectedMinutes < 0
            customMinutes = abs(selectedMinutes)
        }
        .onChange(of: customMinutes) { _, newValue in
            selectedMinutes = newValue == 0 ? 0 : (isAfter ? -newValue : newValue)
        }
        .onChange(of: isAfter) { _, _ in
            selectedMinutes = customMinutes == 0 ? 0 : (isAfter ? -customMinutes : customMinutes)
        }
        .navigationTitle("Lead Time")
    }
    
    private func label(for minutes: Int) -> String {
        if minutes == 0 { return "At time" }
        let suffix = isAfter ? "after" : "before"
        if minutes >= 60 {
            if minutes % 60 == 0 { return "\(minutes/60)h \(suffix)" }
            return "\(minutes/60)h \(minutes % 60)m \(suffix)"
        }
        return "\(minutes)m \(suffix)"
    }
}

// MARK: - Reward Points Editor
struct WatchRewardPointsEditorView: View {
    @Binding var useCustomPoints: Bool
    @Binding var points: Int
    @Binding var customPointsValue: Double
    let presets: [Int]
    
    var body: some View {
        List {
            Toggle("Custom Points", isOn: $useCustomPoints)
            
            if useCustomPoints {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Points")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("\(Int(customPointsValue))")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                    }
                    .focusable()
                    .digitalCrownRotation($customPointsValue, from: 1, through: 999, by: 1, sensitivity: .medium)
                    
                    Text("Use Digital Crown to adjust (1-999)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .onChange(of: customPointsValue) { _, newValue in
                    points = max(1, min(999, Int(newValue)))
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Presets")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        ForEach(presets, id: \.self) { value in
                            Button {
                                points = value
                                customPointsValue = Double(value)
                            } label: {
                                Text("\(value)")
                                    .font(.caption2)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(points == value ? Color.yellow : Color.gray.opacity(0.3))
                                    .foregroundColor(points == value ? .black : .primary)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            
            Section("Guidelines") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("1-10: Quick tasks")
                    Text("15-50: Regular tasks")
                    Text("75-200: Complex tasks")
                    Text("250-500: Premium tasks")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
        .onAppear {
            customPointsValue = Double(points)
        }
        .onChange(of: useCustomPoints) { _, newValue in
            if !newValue {
                if !presets.contains(points), let first = presets.first {
                    points = first
                    customPointsValue = Double(first)
                }
            }
        }
        .navigationTitle("Points")
    }
}

// MARK: - Time Overrides
struct WatchWeeklyTimeOverridesView: View {
    @Binding var selectedDays: Set<Int>
    @Binding var overrides: [Int: Date]
    let baseTime: Date
    
    var body: some View {
        List {
            ForEach(selectedDays.sorted(), id: \.self) { day in
                DatePicker(dayName(day), selection: binding(for: day), displayedComponents: .hourAndMinute)
            }
        }
        .onAppear {
            for day in selectedDays where overrides[day] == nil {
                overrides[day] = baseTime
            }
        }
        .navigationTitle("Times")
    }
    
    private func binding(for day: Int) -> Binding<Date> {
        Binding(
            get: { overrides[day] ?? baseTime },
            set: { overrides[day] = $0 }
        )
    }
    
    private func dayName(_ day: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        let index = max(0, min(symbols.count - 1, day - 1))
        return symbols[index]
    }
}

struct WatchMonthlyDayTimeOverridesView: View {
    @Binding var selectedDays: Set<Int>
    @Binding var overrides: [Int: Date]
    let baseTime: Date
    
    var body: some View {
        List {
            ForEach(selectedDays.sorted(), id: \.self) { day in
                DatePicker("Day \(day)", selection: binding(for: day), displayedComponents: .hourAndMinute)
            }
        }
        .onAppear {
            for day in selectedDays where overrides[day] == nil {
                overrides[day] = baseTime
            }
        }
        .navigationTitle("Day Times")
    }
    
    private func binding(for day: Int) -> Binding<Date> {
        Binding(
            get: { overrides[day] ?? baseTime },
            set: { overrides[day] = $0 }
        )
    }
}

// MARK: - Monthly Ordinal Picker
struct WatchMonthlyOrdinalPickerView: View {
    @Binding var selectedPatterns: Set<Recurrence.OrdinalPattern>
    @State private var selectedOrdinal: Int = 1
    @State private var selectedWeekday: Int = Calendar.current.component(.weekday, from: Date())
    
    private let ordinals: [Int] = [1, 2, 3, 4, -1]
    
    var body: some View {
        List {
            Section("Add Pattern") {
                Picker("Ordinal", selection: $selectedOrdinal) {
                    ForEach(ordinals, id: \.self) { value in
                        Text(ordinalName(value)).tag(value)
                    }
                }
                
                Picker("Weekday", selection: $selectedWeekday) {
                    ForEach(1...7, id: \.self) { day in
                        Text(Calendar.current.weekdaySymbols[day - 1]).tag(day)
                    }
                }
                
                Button("Add") {
                    let pattern = Recurrence.OrdinalPattern(ordinal: selectedOrdinal, weekday: selectedWeekday)
                    selectedPatterns.insert(pattern)
                }
                .buttonStyle(.bordered)
            }
            
            Section("Selected") {
                if selectedPatterns.isEmpty {
                    Text("None")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(selectedPatterns.sorted { lhs, rhs in
                        if lhs.ordinal != rhs.ordinal { return lhs.ordinal < rhs.ordinal }
                        return lhs.weekday < rhs.weekday
                    }, id: \.self) { pattern in
                        HStack {
                            Text(pattern.displayText)
                                .lineLimit(1)
                            Spacer()
                            Button {
                                selectedPatterns.remove(pattern)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .navigationTitle("Ordinal")
    }
    
    private func ordinalName(_ value: Int) -> String {
        switch value {
        case 1: return "First"
        case 2: return "Second"
        case 3: return "Third"
        case 4: return "Fourth"
        case -1: return "Last"
        default: return "\(value)th"
        }
    }
}

struct WatchMonthlyOrdinalTimeOverridesView: View {
    @Binding var selectedPatterns: Set<Recurrence.OrdinalPattern>
    @Binding var overrides: [Recurrence.OrdinalPattern: Date]
    let baseTime: Date
    
    var body: some View {
        List {
            ForEach(selectedPatterns.sorted { lhs, rhs in
                if lhs.ordinal != rhs.ordinal { return lhs.ordinal < rhs.ordinal }
                return lhs.weekday < rhs.weekday
            }, id: \.self) { pattern in
                DatePicker(pattern.displayText, selection: binding(for: pattern), displayedComponents: .hourAndMinute)
            }
        }
        .onAppear {
            for pattern in selectedPatterns where overrides[pattern] == nil {
                overrides[pattern] = baseTime
            }
        }
        .navigationTitle("Pattern Times")
    }
    
    private func binding(for pattern: Recurrence.OrdinalPattern) -> Binding<Date> {
        Binding(
            get: { overrides[pattern] ?? baseTime },
            set: { overrides[pattern] = $0 }
        )
    }
}

// MARK: - Location Picker
final class WatchLocationFetcher: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation?
    @Published var errorMessage: String?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    private let manager = CLLocationManager()
    
    override init() {
        super.init()
        manager.delegate = self
    }
    
    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            manager.requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.first
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
    }
}

struct WatchLocationPickerView: View {
    @Binding var selectedLocation: TaskLocation?
    @EnvironmentObject var syncManager: WatchSyncManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var fetcher = WatchLocationFetcher()
    
    @State private var name: String = ""
    @State private var address: String = ""
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var isResolving = false
    @State private var errorMessage: String?
    
    private var recentLocations: [TaskLocation] {
        var seen = Set<TaskLocation>()
        var list: [TaskLocation] = []
        for task in syncManager.tasks {
            if let location = task.location, !seen.contains(location) {
                seen.insert(location)
                list.append(location)
            }
        }
        return list
    }
    
    var body: some View {
        List {
            if let selectedLocation {
                Section("Selected") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedLocation.name)
                            if let address = selectedLocation.address, !address.isEmpty {
                                Text(address)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Button("Clear") {
                            self.selectedLocation = nil
                            dismiss()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            
            Section("Current Location") {
                Button {
                    errorMessage = nil
                    isResolving = true
                    fetcher.requestLocation()
                } label: {
                    HStack {
                        Image(systemName: "location.fill")
                        Text("Use Current Location")
                    }
                }
                
                if isResolving {
                    HStack {
                        ProgressView()
                        Text("Getting location...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            if !recentLocations.isEmpty {
                Section("Recent") {
                    ForEach(recentLocations, id: \.self) { location in
                        Button {
                            selectedLocation = location
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(location.name)
                                if let address = location.address, !address.isEmpty {
                                    Text(address)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            
            Section("Custom") {
                TextField("Name", text: $name)
                TextField("Address (optional)", text: $address)
                
                Button("Save") {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    let location = TaskLocation(
                        name: trimmed,
                        address: address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : address,
                        coordinate: coordinate
                    )
                    selectedLocation = location
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("Location")
        .onAppear {
            if let selectedLocation {
                name = selectedLocation.name
                address = selectedLocation.address ?? ""
                coordinate = selectedLocation.coordinate
            }
        }
        .onReceive(fetcher.$location) { location in
            guard let location else { return }
            reverseGeocode(location)
        }
        .onReceive(fetcher.$errorMessage) { error in
            if let error {
                isResolving = false
                errorMessage = error
            }
        }
    }
    
    private func reverseGeocode(_ location: CLLocation) {
        isResolving = true
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                isResolving = false
                if let error {
                    errorMessage = error.localizedDescription
                    return
                }
                let placemark = placemarks?.first
                let locationName = placemark?.name ?? placemark?.thoroughfare ?? "Location"
                var components: [String] = []
                if let thoroughfare = placemark?.thoroughfare { components.append(thoroughfare) }
                if let locality = placemark?.locality { components.append(locality) }
                if let administrativeArea = placemark?.administrativeArea { components.append(administrativeArea) }
                let formatted = components.joined(separator: ", ")
                name = locationName
                address = formatted
                coordinate = location.coordinate
            }
        }
    }
}

#Preview {
    WatchTaskFormView(mode: .create)
        .environmentObject(WatchSyncManager.shared)
}
