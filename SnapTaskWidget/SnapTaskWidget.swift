//
//  SnapTaskWidget.swift
//  SnapTaskWidget
//
//  Created by giovanni amadei on 27/11/25.
//

import WidgetKit
import SwiftUI
import AppIntents

struct Provider: AppIntentTimelineProvider {
    typealias Entry = SimpleEntry
    typealias Intent = ScopeSelectionIntent
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), tasks: [], configuration: ScopeSelectionIntent(), effectiveScope: .today)
    }

    func snapshot(for configuration: ScopeSelectionIntent, in context: Context) async -> SimpleEntry {
        var effectiveScope = configuration.scope ?? .today
        return SimpleEntry(date: Date(), tasks: [
            TodoTask(
                name: "Design Mockup",
                startTime: Date(),
                priority: .high,
                icon: "paintbrush.fill"
            ),
            TodoTask(
                name: "Team Meeting",
                startTime: Date().addingTimeInterval(3600),
                priority: .medium,
                icon: "person.3.fill"
            ),
            TodoTask(
                name: "Code Review",
                startTime: Date().addingTimeInterval(7200),
                priority: .low,
                icon: "doc.text.fill"
            )
        ], configuration: configuration, effectiveScope: effectiveScope)
    }

    func timeline(for configuration: ScopeSelectionIntent, in context: Context) async -> Timeline<SimpleEntry> {
        var entries: [SimpleEntry] = []
        let currentDate = Date()
        
        // Recupera le task da UserDefaults condiviso
        let sharedDefaults = UserDefaults(suiteName: "group.com.snapTask.shared")
        var tasks: [TodoTask] = []
        
        if let data = sharedDefaults?.data(forKey: "savedTasks") {
            do {
                tasks = try JSONDecoder().decode([TodoTask].self, from: data)
                // Debug: log task scopes
                for task in tasks {
                    print("📋 Widget: Task '\(task.name)' has timeScope: \(task.timeScope.rawValue), scopeStartDate: \(String(describing: task.scopeStartDate))")
                }
            } catch {
                print("Error decoding tasks: \(error)")
            }
        }
        // Scope solo dalle impostazioni del widget
        let effectiveScope = configuration.scope ?? .today
        
        // Filtra per scope selezionato
        let cal = Calendar.current
        let filtered: [TodoTask] = {
            switch effectiveScope {
            case .today:
                // Task che occorrono oggi (qualsiasi timeScope)
                return tasks.filter { $0.occurs(on: currentDate) }
            case .week:
                // Solo task con timeScope week della settimana corrente
                let currentWeekStart = cal.startOfWeek(for: currentDate)
                let currentWeekEnd = cal.date(byAdding: .day, value: 6, to: currentWeekStart)!
                print("📅 Widget: Filtering for WEEK scope, currentWeekStart: \(currentWeekStart)")
                let weekTasks = tasks.filter { task in
                    print("📋 Widget: Checking task '\(task.name)' - timeScope: \(task.timeScope.rawValue)")
                    guard task.timeScope == .week else { 
                        print("❌ Widget: Task '\(task.name)' rejected - timeScope is \(task.timeScope.rawValue), not week")
                        return false 
                    }
                    
                    // Se ha ricorrenza, usa occurs(inWeekStarting:)
                    if task.recurrence != nil {
                        let occurs = task.occurs(inWeekStarting: currentWeekStart)
                        print("✅ Widget: Task '\(task.name)' has recurrence, occurs in week: \(occurs)")
                        return occurs
                    }
                    
                    // Altrimenti controlla scopeStartDate e scopeEndDate
                    if let taskScopeStart = task.scopeStartDate, let taskScopeEnd = task.scopeEndDate {
                        let matches = cal.isDate(taskScopeStart, inSameDayAs: currentWeekStart) &&
                                      cal.isDate(taskScopeEnd, inSameDayAs: currentWeekEnd)
                        print("✅ Widget: Task '\(task.name)' scope dates match: \(matches)")
                        return matches
                    }
                    
                    print("❌ Widget: Task '\(task.name)' missing scope dates")
                    return false
                }
                print("📊 Widget: Found \(weekTasks.count) week tasks")
                return weekTasks
            case .month:
                // Solo task con timeScope month del mese corrente
                return tasks.filter { task in
                    guard task.timeScope == .month else { return false }
                    
                    // Se ha ricorrenza, usa occurs(inMonth:)
                    if task.recurrence != nil {
                        return task.occurs(inMonth: currentDate)
                    }
                    
                    // Altrimenti controlla scopeStartDate
                    if let taskScopeStart = task.scopeStartDate {
                        return cal.isDate(taskScopeStart, equalTo: currentDate, toGranularity: .month)
                    }
                    
                    return false
                }
            case .year:
                // Task con timeScope year dell'anno corrente (+ longTerm)
                return tasks.filter { task in
                    guard task.timeScope == .year || task.timeScope == .longTerm else { return false }
                    
                    // Se ha ricorrenza, usa occurs(inYear:)
                    if task.recurrence != nil {
                        return task.occurs(inYear: currentDate)
                    }
                    
                    // Altrimenti controlla scopeStartDate
                    if let taskScopeStart = task.scopeStartDate {
                        return cal.isDate(taskScopeStart, equalTo: currentDate, toGranularity: .year)
                    }
                    
                    return false
                }
            }
        }()
        // Ordina SOLO per orario per non far saltare l'ordine con il check
        let scopedTasks = filtered.sorted { $0.startTime < $1.startTime }
        
        let entry = SimpleEntry(date: currentDate, tasks: scopedTasks, configuration: configuration, effectiveScope: effectiveScope)
        entries.append(entry)

        // Aggiorna con throttling (15 min)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        return Timeline(entries: entries, policy: .after(nextUpdate))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let tasks: [TodoTask]
    let configuration: ScopeSelectionIntent
    let effectiveScope: WidgetScope
}

struct SnapTaskWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme

    // Colori App Theme - allineati con ThemeManager sunset theme
    var backgroundColor: Color {
        colorScheme == .dark ? Color(red: 0.08, green: 0.08, blue: 0.1) : Color(red: 0.98, green: 0.98, blue: 0.99)
    }
    
    var surfaceColor: Color {
        colorScheme == .dark ? Color(red: 0.12, green: 0.12, blue: 0.14) : Color.white
    }
    
    var primaryColor: Color {
        Color.orange // Sunset theme primary
    }
    
    var secondaryColor: Color {
        Color.pink // Sunset theme secondary
    }
    
    var textColor: Color {
        colorScheme == .dark ? .white : Color(red: 0.1, green: 0.1, blue: 0.15)
    }
    
    var secondaryTextColor: Color {
        colorScheme == .dark ? Color(red: 0.65, green: 0.65, blue: 0.7) : Color(red: 0.45, green: 0.45, blue: 0.5)
    }
    
    var accentGradient: LinearGradient {
        LinearGradient(
            colors: [primaryColor, secondaryColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var effectiveScope: WidgetScope {
        entry.effectiveScope
    }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallWidgetView
            case .systemMedium:
                mediumWidgetView
            default:
                largeWidgetView
            }
        }
        .containerBackground(for: .widget) {
            backgroundColor
        }
        .widgetURL(URL(string: "snaptask://scope/\(effectiveScope.rawValue)"))
    }
    
    // MARK: - Small Widget (Task attuale + prossima)
    private var smallWidgetView: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header compatto
            HStack {
                Text(formattedDate)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(primaryColor)
                Spacer()
                // Contatore task
                HStack(spacing: 2) {
                    Text("\(completedCount)")
                        .foregroundColor(primaryColor)
                    Text("/")
                        .foregroundColor(secondaryTextColor)
                    Text("\(entry.tasks.count)")
                        .foregroundColor(secondaryTextColor)
                }
                .font(.system(size: 11, weight: .bold))
            }
            
            if entry.tasks.isEmpty {
                Spacer()
                Text("0")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(textColor)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                let uncompletedTasks = entry.tasks.filter { task in
                    let key = task.completionKey(for: entry.date)
                    return task.completions[key]?.isCompleted != true
                }

                let completedTasks = entry.tasks.filter { task in
                    let key = task.completionKey(for: entry.date)
                    return task.completions[key]?.isCompleted == true
                }
                
                if uncompletedTasks.isEmpty {
                    // Mostra fino a 3 task completate
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(completedTasks.prefix(3).enumerated()), id: \.element.id) { _, task in
                            SmallTaskRow(
                                task: task,
                                date: entry.date,
                                primaryColor: primaryColor,
                                secondaryColor: secondaryColor,
                                textColor: textColor,
                                secondaryTextColor: secondaryTextColor
                            )
                        }
                    }

                    Spacer(minLength: 0)
                } else {
                    // Mostra fino a 3 task non completate - tutte uguali
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(uncompletedTasks.prefix(3).enumerated()), id: \.element.id) { _, task in
                            SmallTaskRow(
                                task: task,
                                date: entry.date,
                                primaryColor: primaryColor,
                                secondaryColor: secondaryColor,
                                textColor: textColor,
                                secondaryTextColor: secondaryTextColor
                            )
                        }
                    }
                    
                    Spacer(minLength: 0)
                    
                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(secondaryTextColor.opacity(0.2))
                                .frame(height: 5)
                            
                            RoundedRectangle(cornerRadius: 3)
                                .fill(accentGradient)
                                .frame(width: geo.size.width * progressPercentage, height: 5)
                        }
                    }
                    .frame(height: 5)
                }
            }
        }
        .padding(12)
    }
    
    // MARK: - Medium Widget (Lista compatta orizzontale)
    private var mediumWidgetView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header - sempre in alto
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10, weight: .semibold))
                    Text(formattedDate)
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Capsule().fill(accentGradient))
                
                Spacer()
                
                // Scope label
                Text(scopeLabel(effectiveScope))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(secondaryTextColor)
            }
            
            if entry.tasks.isEmpty {
                VStack(spacing: 4) {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(accentGradient)
                    Text(String(localized: "No tasks"))
                        .font(.system(size: 11))
                        .foregroundColor(secondaryTextColor)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                // Due colonne di task
                HStack(alignment: .top, spacing: 12) {
                    // Colonna sinistra
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(entry.tasks.prefix(3).enumerated()), id: \.element.id) { _, task in
                            CompactTaskRow(task: task, date: entry.date, primaryColor: primaryColor, secondaryColor: secondaryColor, textColor: textColor, secondaryTextColor: secondaryTextColor)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Colonna destra
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(entry.tasks.dropFirst(3).prefix(3).enumerated()), id: \.element.id) { _, task in
                            CompactTaskRow(task: task, date: entry.date, primaryColor: primaryColor, secondaryColor: secondaryColor, textColor: textColor, secondaryTextColor: secondaryTextColor)
                        }
                        
                        if entry.tasks.count > 6 {
                            Text(String(localized: "+ \(entry.tasks.count - 6) more"))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(primaryColor)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer(minLength: 0)
            }
        }
        .padding(14)
    }
    
    // MARK: - Large Widget (Lista completa)
    private var largeWidgetView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header - sempre in alto
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10, weight: .semibold))
                    Text(formattedDate)
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Capsule().fill(accentGradient))
                
                Spacer()
                
                // Scope label
                Text(scopeLabel(effectiveScope))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(secondaryTextColor)
            }
            
            if entry.tasks.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(accentGradient)
                    Text(String(localized: "No tasks"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                // Lista task - max 7 per non tagliare
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(entry.tasks.prefix(7).enumerated()), id: \.element.id) { index, task in
                        DetailedTaskRow(
                            task: task,
                            date: entry.date,
                            primaryColor: primaryColor,
                            secondaryColor: secondaryColor,
                            textColor: textColor,
                            secondaryTextColor: secondaryTextColor
                        )
                        
                        if index < min(6, entry.tasks.count - 1) {
                            Divider().background(secondaryTextColor.opacity(0.1))
                        }
                    }
                }
                
                Spacer(minLength: 0)
                
                if entry.tasks.count > 7 {
                    HStack {
                        Spacer()
                        Link(destination: URL(string: "snaptask://tasks")!) {
                            Text(String(localized: "+ \(entry.tasks.count - 7) more →"))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(primaryColor)
                        }
                    }
                }
            }
        }
        .padding(14)
    }
    
    // MARK: - Helper Properties
    private var completedCount: Int {
        entry.tasks.filter { task in
            let key = task.completionKey(for: entry.date)
            return task.completions[key]?.isCompleted == true
        }.count
    }
    
    private var progressPercentage: CGFloat {
        guard !entry.tasks.isEmpty else { return 0 }
        return CGFloat(completedCount) / CGFloat(entry.tasks.count)
    }
    
    private var nextUncompletedTask: TodoTask? {
        entry.tasks.first { task in
            let key = task.completionKey(for: entry.date)
            return task.completions[key]?.isCompleted != true
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack(alignment: .center, spacing: 6) {
            // Date badge con gradient - più compatto
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 10, weight: .semibold))
                Text(formattedDate)
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(accentGradient)
            )
            
            Spacer(minLength: 4)
            
            Text(scopeLabel(effectiveScope))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(secondaryTextColor)
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "d MMM"
        return formatter.string(from: entry.date).capitalized
    }
    
    private var scopeSelectorView: some View {
        EmptyView()
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(primaryColor.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(accentGradient)
            }
            
            Text(String(localized: "All done!"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(textColor)
            
            Text(String(localized: "No tasks for this period"))
                .font(.system(size: 11))
                .foregroundColor(secondaryTextColor)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Task List
    private var taskListView: some View {
        // Calcola quante task mostrare in base alla dimensione del widget
        let limit: Int = {
            switch family {
            case .systemSmall: return 4
            case .systemMedium: return 6
            case .systemLarge: return 12
            default: return 6
            }
        }()
        
        return VStack(alignment: .leading, spacing: family == .systemSmall ? 4 : 6) {
            ForEach(Array(entry.tasks.prefix(limit).enumerated()), id: \.element.id) { index, task in
                TaskRowView(
                    task: task,
                    date: entry.date,
                    primaryColor: primaryColor,
                    secondaryColor: secondaryColor,
                    textColor: textColor,
                    secondaryTextColor: secondaryTextColor,
                    surfaceColor: surfaceColor,
                    isCompact: family == .systemSmall
                )
                
                if index < min(limit - 1, entry.tasks.count - 1) {
                    Divider()
                        .background(secondaryTextColor.opacity(0.1))
                }
            }
            
            if entry.tasks.count > limit {
                Link(destination: URL(string: "snaptask://tasks")!) {
                    HStack {
                        Spacer()
                        Text(String(localized: "+ \(entry.tasks.count - limit) more →"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(primaryColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(primaryColor.opacity(0.1))
                            )
                    }
                }
            }
        }
    }
    
    func isCompleted(_ task: TodoTask) -> Bool {
        let key = task.completionKey(for: entry.date)
        return task.completions[key]?.isCompleted == true
    }
}

struct TaskRowView: View {
    let task: TodoTask
    let date: Date
    let primaryColor: Color
    let secondaryColor: Color
    let textColor: Color
    let secondaryTextColor: Color
    let surfaceColor: Color
    let isCompact: Bool
    
    var isCompleted: Bool {
        let key = task.completionKey(for: date)
        return task.completions[key]?.isCompleted == true
    }
    
    private var categoryColor: Color {
        if let colorHex = task.category?.color {
            return Color(hex: colorHex)
        }
        return primaryColor
    }
    
    private var accentGradient: LinearGradient {
        LinearGradient(
            colors: [primaryColor, secondaryColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        HStack(spacing: isCompact ? 8 : 10) {
            // Category color indicator - linea verticale elegante
            RoundedRectangle(cornerRadius: 2)
                .fill(categoryColor)
                .frame(width: 3, height: isCompact ? 28 : 32)
                .opacity(isCompleted ? 0.4 : 1)

            // Content
            Link(destination: URL(string: "snaptask://task/\(task.id.uuidString)")!) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.name)
                        .font(.system(size: isCompact ? 12 : 13, weight: .semibold))
                        .foregroundColor(isCompleted ? secondaryTextColor : textColor)
                        .lineLimit(1)
                    
                    if task.hasSpecificTime {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 8))
                            Text(task.startTime, style: .time)
                                .font(.system(size: isCompact ? 9 : 10, weight: .medium))
                        }
                        .foregroundColor(secondaryTextColor)
                    }
                }
            }

            Spacer(minLength: 4)

            // Checkbox moderno
            Button(intent: ToggleTaskCompletionIntent(taskId: task.id.uuidString)) {
                ZStack {
                    if isCompleted {
                        Circle()
                            .fill(accentGradient)
                            .frame(width: isCompact ? 20 : 22, height: isCompact ? 20 : 22)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: isCompact ? 10 : 11, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [secondaryTextColor.opacity(0.4), secondaryTextColor.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                            .frame(width: isCompact ? 20 : 22, height: isCompact ? 20 : 22)
                            .background(
                                Circle()
                                    .fill(surfaceColor)
                            )
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Small Task Row (per Small Widget)
struct SmallTaskRow: View {
    let task: TodoTask
    let date: Date
    let primaryColor: Color
    let secondaryColor: Color
    let textColor: Color
    let secondaryTextColor: Color
    
    private var categoryColor: Color {
        if let colorHex = task.category?.color {
            return Color(hex: colorHex)
        }
        return primaryColor
    }
    
    var body: some View {
        HStack(spacing: 6) {
            // Indicatore categoria
            RoundedRectangle(cornerRadius: 2)
                .fill(categoryColor)
                .frame(width: 3, height: 26)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(task.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(textColor)
                    .lineLimit(1)
                
                if task.hasSpecificTime {
                    Text(task.startTime, style: .time)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(primaryColor)
                }
            }
            
            Spacer(minLength: 2)
            
            // Checkbox
            Button(intent: ToggleTaskCompletionIntent(taskId: task.id.uuidString)) {
                Circle()
                    .strokeBorder(primaryColor, lineWidth: 1.5)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Compact Task Row (per Medium Widget)
struct CompactTaskRow: View {
    let task: TodoTask
    let date: Date
    let primaryColor: Color
    let secondaryColor: Color
    let textColor: Color
    let secondaryTextColor: Color
    
    var isCompleted: Bool {
        let key = task.completionKey(for: date)
        return task.completions[key]?.isCompleted == true
    }
    
    private var categoryColor: Color {
        if let colorHex = task.category?.color {
            return Color(hex: colorHex)
        }
        return primaryColor
    }
    
    var body: some View {
        HStack(spacing: 6) {
            // Indicatore categoria
            RoundedRectangle(cornerRadius: 1.5)
                .fill(categoryColor)
                .frame(width: 3, height: 20)
                .opacity(isCompleted ? 0.4 : 1)
            
            // Nome task
            Text(task.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isCompleted ? secondaryTextColor : textColor)
                .lineLimit(1)
            
            Spacer(minLength: 2)
            
            // Checkbox
            Button(intent: ToggleTaskCompletionIntent(taskId: task.id.uuidString)) {
                ZStack {
                    if isCompleted {
                        Circle()
                            .fill(LinearGradient(colors: [primaryColor, secondaryColor], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 16, height: 16)
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Circle()
                            .strokeBorder(secondaryTextColor.opacity(0.4), lineWidth: 1.5)
                            .frame(width: 16, height: 16)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Detailed Task Row (per Large Widget)
struct DetailedTaskRow: View {
    let task: TodoTask
    let date: Date
    let primaryColor: Color
    let secondaryColor: Color
    let textColor: Color
    let secondaryTextColor: Color
    
    var isCompleted: Bool {
        let key = task.completionKey(for: date)
        return task.completions[key]?.isCompleted == true
    }
    
    private var categoryColor: Color {
        if let colorHex = task.category?.color {
            return Color(hex: colorHex)
        }
        return primaryColor
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Indicatore categoria
            RoundedRectangle(cornerRadius: 2)
                .fill(categoryColor)
                .frame(width: 3, height: 32)
                .opacity(isCompleted ? 0.4 : 1)
            
            // Content
            Link(destination: URL(string: "snaptask://task/\(task.id.uuidString)")!) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isCompleted ? secondaryTextColor : textColor)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        // Orario
                        if task.hasSpecificTime {
                            HStack(spacing: 2) {
                                Image(systemName: "clock")
                                    .font(.system(size: 8))
                                Text(task.startTime, style: .time)
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .foregroundColor(secondaryTextColor)
                        }
                        
                        // Categoria
                        if let category = task.category {
                            Text(category.name)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(categoryColor)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(categoryColor.opacity(0.15))
                                .cornerRadius(3)
                        }
                        
                        // Priorità - solo icona
                        Image(systemName: task.priority.icon)
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: task.priority.color))
                    }
                }
            }
            
            Spacer(minLength: 4)
            
            // Checkbox
            Button(intent: ToggleTaskCompletionIntent(taskId: task.id.uuidString)) {
                ZStack {
                    if isCompleted {
                        Circle()
                            .fill(LinearGradient(colors: [primaryColor, secondaryColor], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 20, height: 20)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Circle()
                            .strokeBorder(secondaryTextColor.opacity(0.4), lineWidth: 1.5)
                            .frame(width: 20, height: 20)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
}

struct SnapTaskWidget: Widget {
    let kind: String = "SnapTaskWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ScopeSelectionIntent.self, provider: Provider()) { entry in
            SnapTaskWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(String(localized: "SnapTask"))
        .description(String(localized: "View tasks for the selected scope."))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// Helper per visualizzare l'anteprima
#Preview(as: .systemSmall) {
    SnapTaskWidget()
} timeline: {
    SimpleEntry(date: Date(), tasks: [
        TodoTask(name: "Morning Workout", startTime: Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date())!, priority: .high, icon: "figure.run"),
        TodoTask(name: "Review Daily Goals", startTime: Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!, priority: .medium, icon: "target"),
        TodoTask(name: "Check Emails", startTime: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!, priority: .low, icon: "envelope"),
        TodoTask(name: "Team Standup", startTime: Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!, priority: .medium, icon: "person.3")
    ], configuration: ScopeSelectionIntent(), effectiveScope: .today)
}

#Preview(as: .systemMedium) {
    SnapTaskWidget()
} timeline: {
    SimpleEntry(date: Date(), tasks: [
        TodoTask(name: "Morning Workout", startTime: Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date())!, priority: .high, icon: "figure.run"),
        TodoTask(name: "Review Daily Goals", startTime: Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!, priority: .medium, icon: "target"),
        TodoTask(name: "Check Emails", startTime: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!, priority: .low, icon: "envelope"),
        TodoTask(name: "Strength Training", startTime: Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date())!, priority: .high, icon: "dumbbell"),
        TodoTask(name: "Prepare Healthy Meals", startTime: Calendar.current.date(bySettingHour: 19, minute: 30, second: 0, of: Date())!, priority: .medium, icon: "fork.knife"),
        TodoTask(name: "Read 15 Minutes", startTime: Calendar.current.date(bySettingHour: 21, minute: 30, second: 0, of: Date())!, priority: .low, icon: "book")
    ], configuration: ScopeSelectionIntent(), effectiveScope: .today)
}

// MARK: - Helpers
private func scopeShortLabel(_ scope: WidgetScope) -> String {
    switch scope {
    case .today: return "O"
    case .week: return "S"
    case .month: return "M"
    case .year: return "A"
    }
}

private func scopeLabel(_ scope: WidgetScope) -> String {
    switch scope {
    case .today: return "Today"
    case .week: return "Week"
    case .month: return "Month"
    case .year: return "Year"
    }
}

// MARK: - Extensions & Mocks

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
    
    func startOfYear(for date: Date) -> Date {
        let components = dateComponents([.year], from: date)
        return self.date(from: components) ?? date
    }
}

class LanguageManager {
    static let shared = LanguageManager()
    
    var actualLanguageCode: String {
        if #available(iOS 16, *) {
            return Locale.current.language.languageCode?.identifier ?? "en"
        } else {
            return Locale.current.languageCode ?? "en"
        }
    }
}

// Extension for Color initialization from Hex (duplicated here for Widget target independence)
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
