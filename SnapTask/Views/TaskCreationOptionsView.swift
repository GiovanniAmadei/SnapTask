import SwiftUI

struct TaskCreationOptionsView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @ObservedObject private var taskManager = TaskManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    
    @State private var searchText: String = ""
    @State private var showingForm = false
    @State private var formSource: FormSource = .new
    
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
        if !searchText.isEmpty {
            list = list.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return list.sorted { $0.lastModifiedDate > $1.lastModifiedDate }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header fisso in alto
                headerSection
                    .padding(.top, 8)
                
                // Campo di ricerca fisso
                searchField
                    .padding(.vertical, 16)
                
                // Solo la lista delle task è scrollabile
                if uniqueRecentTemplates.isEmpty {
                    emptyStateView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Scegli tra task precedenti")
                            .font(.headline)
                            .themedPrimaryText()
                            .padding(.horizontal, 16)
                        
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(uniqueRecentTemplates) { task in
                                    TaskTemplateCard(task: task) {
                                        let anchored = anchoredTask(from: task, in: viewModel.selectedTimeScope, baseDate: baseDateForScope)
                                        formSource = .template(anchored)
                                        showingForm = true
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .themedBackground()
            .navigationTitle("Aggiungi Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annulla") { dismiss() }
                        .themedSecondaryText()
                }
            }
            .sheet(isPresented: $showingForm) {
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
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Come vuoi creare la task?")
                    .font(.title3.bold())
                    .themedPrimaryText()
                Spacer()
            }
            .padding(.horizontal, 16)
            
            Button {
                formSource = .new
                showingForm = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(theme.primaryColor.opacity(0.12))
                            .frame(width: 38, height: 38)
                        Image(systemName: "plus")
                            .foregroundColor(theme.primaryColor)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Crea nuova task")
                            .font(.headline)
                            .themedPrimaryText()
                        Text(scopeSubtitleText())
                            .font(.caption)
                            .themedSecondaryText()
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .themedSecondaryText()
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(theme.surfaceColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(theme.borderColor, lineWidth: 1)
                        )
                )
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(theme.secondaryTextColor)
            TextField("Cerca tra le tue task passate", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .themedPrimaryText()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(theme.secondaryTextColor)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.surfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(theme.borderColor, lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(theme.secondaryTextColor)
            Text("Non ci sono task passate da mostrare.")
                .font(.subheadline)
                .themedSecondaryText()
            Text("Crea una nuova task, poi la ritroverai qui come template veloce.")
                .font(.caption)
                .themedSecondaryText()
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
    
    private func scopeSubtitleText() -> String {
        switch viewModel.selectedTimeScope {
        case .today: return "Oggi • \(DateFormatter.localizedString(from: baseDateForScope, dateStyle: .medium, timeStyle: .none))"
        case .week: return "Questa settimana"
        case .month: return "Questo mese"
        case .year: return "Quest'anno"
        case .longTerm: return "Obiettivo a lungo termine"
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