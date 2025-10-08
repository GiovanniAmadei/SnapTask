import SwiftUI

struct TaskCreationOptionsView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @ObservedObject private var taskManager = TaskManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    
    @State private var taskName: String = ""
    @State private var isExpanded: Bool = false
    @State private var showingFullForm = false
    @State private var formSource: FormSource = .new
    @FocusState private var isTextFieldFocused: Bool
    
    private enum FormSource {
        case new
        case template(TodoTask)
    }
    
    private var baseDateForScope: Date {
        let cal = Calendar.current
        switch viewModel.selectedTimeScope {
        case .today:
            return viewModel.selectedDate
        case .week:
            return viewModel.currentWeek
        case .month:
            return viewModel.currentMonth
        case .year:
            return viewModel.currentYear
        case .longTerm:
            return Date()
        case .all:
            return Date()
        }
    }
    
    private var uniqueRecentTemplates: [TodoTask] {
        var byName: [String: TodoTask] = [:]
        for t in taskManager.tasks {
            // Prefer the most recently modified per name
            if let existing = byName[t.name] {
                if t.lastModifiedDate > existing.lastModifiedDate {
                    byName[t.name] = t
                }
            } else {
                byName[t.name] = t
            }
        }
        var list = Array(byName.values)
        // Filtra automaticamente in base al nome della task che si sta scrivendo
        if !taskName.isEmpty {
            list = list.filter { $0.name.localizedCaseInsensitiveContains(taskName) }
        }
        return list.sorted { $0.lastModifiedDate > $1.lastModifiedDate }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Campo di input principale - sempre visibile
                VStack(spacing: 12) {
                    HStack {
                        Text("how_create_task".localized)
                            .font(.title3.bold())
                            .themedPrimaryText()
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    // Campo di testo principale con toolbar
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(isExpanded ? theme.primaryColor : theme.secondaryTextColor)
                            
                            TextField("enter_task_name".localized, text: $taskName)
                                .textFieldStyle(PlainTextFieldStyle())
                                .themedPrimaryText()
                                .focused($isTextFieldFocused)
                                .submitLabel(.done)
                                .onSubmit {
                                    if !taskName.isEmpty {
                                        createQuickTask()
                                    }
                                }
                            
                            if !taskName.isEmpty {
                                Button {
                                    taskName = ""
                                    isExpanded = false
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(theme.secondaryTextColor)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(theme.surfaceColor)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(isTextFieldFocused ? theme.primaryColor : theme.borderColor, lineWidth: isTextFieldFocused ? 2 : 1)
                                )
                        )
                        .padding(.horizontal, 16)
                        
                        // Toolbar sopra la tastiera (appare quando c'è testo)
                        if !taskName.isEmpty && isTextFieldFocused {
                            HStack(spacing: 12) {
                                // Pulsante Crea
                                Button {
                                    createQuickTask()
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 16, weight: .semibold))
                                        Text("create".localized)
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(theme.primaryColor)
                                    )
                                }
                                
                                // Pulsante Personalizza
                                Button {
                                    openFullFormWithName()
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "slider.horizontal.3")
                                            .font(.system(size: 16, weight: .semibold))
                                        Text("customize".localized)
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    .foregroundColor(theme.primaryColor)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(theme.primaryColor.opacity(0.15))
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                        }
                    }
                }
                .padding(.bottom, 16)
                
                // Divider
                Divider()
                    .padding(.horizontal)
                
                // Lista template
                if uniqueRecentTemplates.isEmpty {
                    emptyStateView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            if !taskName.isEmpty {
                                Text("matching_templates".localized)
                                    .font(.headline)
                                    .themedPrimaryText()
                            } else {
                                Text("choose_from_previous_tasks".localized)
                                    .font(.headline)
                                    .themedPrimaryText()
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(uniqueRecentTemplates) { task in
                                    TaskTemplateCard(task: task) {
                                        let anchored = anchoredTask(from: task, in: viewModel.selectedTimeScope, baseDate: baseDateForScope)
                                        formSource = .template(anchored)
                                        showingFullForm = true
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                            .padding(.bottom, 20)
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: taskName.isEmpty)
            .themedBackground()
            .navigationTitle("\(String.add) \(String.task)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String.cancel) { dismiss() }
                        .themedSecondaryText()
                }
            }
            .onChange(of: taskName) { _, newValue in
                withAnimation {
                    isExpanded = !newValue.isEmpty
                }
            }
            .onAppear {
                // Auto-focus sul campo di testo
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isTextFieldFocused = true
                }
            }
            .sheet(isPresented: $showingFullForm) {
                switch formSource {
                case .new:
                    TaskFormView(
                        initialDate: baseDateForScope,
                        initialTimeScope: viewModel.selectedTimeScope,
                        onSave: { task in
                            viewModel.addTask(task)
                            dismiss()
                        }
                    )
                case .template(let anchored):
                    TaskFormView(
                        initialTask: anchored,
                        onSave: { task in
                            viewModel.addTask(task)
                            dismiss()
                        }
                    )
                }
            }
        }
    }
    
    private func createQuickTask() {
        guard !taskName.isEmpty else { return }
        
        let task = TodoTask(
            name: taskName,
            startTime: baseDateForScope,
            timeScope: viewModel.selectedTimeScope
        )
        
        viewModel.addTask(task)
        dismiss()
    }
    
    private func openFullFormWithName() {
        var task = TodoTask(
            name: taskName,
            startTime: baseDateForScope,
            timeScope: viewModel.selectedTimeScope
        )
        
        // Set scope dates based on time scope
        let cal = Calendar.current
        switch viewModel.selectedTimeScope {
        case .week:
            let weekStart = cal.startOfWeek(for: baseDateForScope)
            task.scopeStartDate = weekStart
            task.scopeEndDate = cal.date(byAdding: .day, value: 6, to: weekStart)
        case .month:
            let monthStart = cal.startOfMonth(for: baseDateForScope)
            task.scopeStartDate = monthStart
            if let next = cal.date(byAdding: .month, value: 1, to: monthStart) {
                task.scopeEndDate = cal.date(byAdding: .day, value: -1, to: next)
            }
        case .year:
            let yearStart = cal.startOfYear(for: baseDateForScope)
            task.scopeStartDate = yearStart
            var endComps = DateComponents()
            endComps.year = cal.component(.year, from: yearStart)
            endComps.month = 12
            endComps.day = 31
            task.scopeEndDate = cal.date(from: endComps)
        default:
            break
        }
        
        formSource = .template(task)
        showingFullForm = true
    }
    
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(theme.secondaryTextColor)
            Text("no_past_tasks".localized)
                .font(.subheadline)
                .themedSecondaryText()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
    
    private func scopeSubtitleText() -> String {
        switch viewModel.selectedTimeScope {
        case .today: return "\(String.today) • \(DateFormatter.localizedString(from: baseDateForScope, dateStyle: .medium, timeStyle: .none))"
        case .week: return "this_week".localized
        case .month: return "this_month".localized
        case .year: return "this_year".localized
        case .longTerm: return "long_term_objective".localized
        case .all:
            return "all_tasks".localized
        }
    }
    
    private func anchoredTask(from template: TodoTask, in scope: TaskTimeScope, baseDate: Date) -> TodoTask {
        let cal = Calendar.current
        
        let timeComponents: DateComponents = {
            let comps = cal.dateComponents([.hour, .minute, .second], from: template.startTime)
            return comps
        }()
        
        let startTime: Date
        var scopeStartDate: Date? = nil
        var scopeEndDate: Date? = nil
        
        switch scope {
        case .today:
            if template.hasSpecificTime {
                var comps = cal.dateComponents([.year, .month, .day], from: baseDate)
                comps.hour = timeComponents.hour
                comps.minute = timeComponents.minute
                comps.second = 0
                startTime = cal.date(from: comps) ?? baseDate
            } else {
                startTime = cal.startOfDay(for: baseDate)
            }
        case .week:
            let weekStart = cal.startOfWeek(for: baseDate)
            if template.hasSpecificTime {
                var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekStart)
                comps.weekday = cal.component(.weekday, from: weekStart)
                comps.hour = timeComponents.hour
                comps.minute = timeComponents.minute
                comps.second = 0
                startTime = cal.date(from: comps) ?? weekStart
            } else {
                startTime = weekStart
            }
            scopeStartDate = weekStart
            scopeEndDate = cal.date(byAdding: .day, value: 6, to: weekStart)
        case .month:
            let monthStart = cal.startOfMonth(for: baseDate)
            if template.hasSpecificTime {
                var comps = cal.dateComponents([.year, .month, .day], from: monthStart)
                comps.hour = timeComponents.hour
                comps.minute = timeComponents.minute
                comps.second = 0
                startTime = cal.date(from: comps) ?? monthStart
            } else {
                startTime = monthStart
            }
            scopeStartDate = monthStart
            if let next = cal.date(byAdding: .month, value: 1, to: monthStart) {
                scopeEndDate = cal.date(byAdding: .day, value: -1, to: next)
            }
        case .year:
            let yearStart = cal.startOfYear(for: baseDate)
            if template.hasSpecificTime {
                var comps = cal.dateComponents([.year, .month, .day], from: yearStart)
                comps.hour = timeComponents.hour
                comps.minute = timeComponents.minute
                comps.second = 0
                startTime = cal.date(from: comps) ?? yearStart
            } else {
                startTime = yearStart
            }
            scopeStartDate = yearStart
            var endComps = DateComponents()
            endComps.year = cal.component(.year, from: yearStart)
            endComps.month = 12
            endComps.day = 31
            scopeEndDate = cal.date(from: endComps)
        case .longTerm:
            if template.hasSpecificTime {
                var comps = cal.dateComponents([.year, .month, .day], from: Date())
                comps.hour = timeComponents.hour
                comps.minute = timeComponents.minute
                comps.second = 0
                startTime = cal.date(from: comps) ?? Date()
            } else {
                startTime = cal.startOfDay(for: Date())
            }
        case .all:
            if template.hasSpecificTime {
                var comps = cal.dateComponents([.year, .month, .day], from: Date())
                comps.hour = timeComponents.hour
                comps.minute = timeComponents.minute
                comps.second = 0
                startTime = cal.date(from: comps) ?? Date()
            } else {
                startTime = cal.startOfDay(for: Date())
            }
        }
        
        var duplicated = TodoTask(
            id: UUID(),
            name: template.name,
            description: template.description,
            location: template.location,
            startTime: startTime,
            hasSpecificTime: template.hasSpecificTime,
            duration: template.duration,
            hasDuration: template.hasDuration,
            category: template.category,
            priority: template.priority,
            icon: template.icon,
            recurrence: template.recurrence,
            pomodoroSettings: template.pomodoroSettings,
            subtasks: template.subtasks,
            hasRewardPoints: template.hasRewardPoints,
            rewardPoints: template.rewardPoints,
            hasNotification: template.hasNotification,
            notificationId: nil,
            timeScope: scope,
            scopeStartDate: scopeStartDate,
            scopeEndDate: scopeEndDate,
            photoPath: nil,
            photoThumbnailPath: nil,
            photos: [],
            voiceMemos: []
        )
        duplicated.completions = [:]
        duplicated.completionDates = []
        duplicated.creationDate = Date()
        duplicated.lastModifiedDate = Date()
        duplicated.totalTrackedTime = 0
        duplicated.lastTrackedDate = nil
        return duplicated
    }
}

private struct TaskTemplateCard: View {
    let task: TodoTask
    let onSelect: () -> Void
    @Environment(\.theme) private var theme
    
    private var categoryColor: Color {
        if let category = task.category {
            return Color(hex: category.color)
        }
        return theme.secondaryTextColor
    }
    
    private var categoryGradient: LinearGradient {
        if let category = task.category {
            let baseColor = Color(hex: category.color)
            return LinearGradient(
                colors: [
                    baseColor.opacity(0.12),
                    baseColor.opacity(0.06),
                    baseColor.opacity(0.02),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(categoryColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: task.icon)
                        .foregroundColor(categoryColor)
                        .font(.system(size: 18, weight: .semibold))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.name)
                        .font(.headline)
                        .themedPrimaryText()
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        if let category = task.category {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color(hex: category.color))
                                    .frame(width: 8, height: 8)
                                Text(category.name)
                                    .font(.caption)
                                    .themedSecondaryText()
                            }
                        }
                        HStack(spacing: 4) {
                            Image(systemName: task.priority.icon)
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: task.priority.color))
                            Text(task.priority.displayName)
                                .font(.caption)
                                .themedSecondaryText()
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(theme.secondaryTextColor)
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(12)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.surfaceColor)
                    
                    RoundedRectangle(cornerRadius: 12)
                        .fill(categoryGradient)
                    
                    if let category = task.category {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color(hex: category.color).opacity(0.3),
                                        Color(hex: category.color).opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(theme.borderColor, lineWidth: 1)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
}
