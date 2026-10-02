import SwiftUI
import Combine

struct TimelineView: View {
    @StateObject var viewModel: TimelineViewModel
    @State private var showingNewTask = false
    @State private var showingBrainDump = false
    @State private var newTaskInitialDate: Date? = nil
    @State private var selectedDayOffset = 0
    @State private var showingCalendarPicker = false
    @State private var scrollProxy: ScrollViewProxy?
    @Environment(\.theme) private var theme
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                    // Header con mese e selettore data
                    Group {
                    TimelineHeaderView(
                        viewModel: viewModel,
                        selectedDayOffset: $selectedDayOffset,
                        showingCalendarPicker: $showingCalendarPicker,
                        scrollProxy: $scrollProxy
                    )
                    .themedSurface()
                    .zIndex(1)
                    
                    // Subtle divider between header and controls
                    Divider()
                        .padding(.horizontal)
                        .foregroundColor(theme.borderColor)
                    
                    // The inbox is a quick list: no view mode, grouping or filter controls.
                    if viewModel.selectedTimeScope != .inbox {
                        ViewControlBarView(viewModel: viewModel)
                            .themedSurface()
                            .zIndex(1)
                        
                        // Subtle divider between controls and content
                        Divider()
                            .padding(.horizontal)
                            .foregroundColor(theme.borderColor)
                    }
                    }
                    // Fades together with the list on scope changes (see TimelineViewModel.changeScope).
                    .opacity(viewModel.scopeTransitionProgress)
                    
                    if viewModel.viewMode == .timeline && viewModel.selectedTimeScope == .today {
                        TimelineContentView(
                            viewModel: viewModel,
                            showingNewTask: $showingNewTask,
                            showingBrainDump: $showingBrainDump,
                            newTaskInitialDate: $newTaskInitialDate
                        )
                        .frame(maxHeight: .infinity)
                    } else {
                        TaskListView(
                            viewModel: viewModel,
                            showingNewTask: $showingNewTask,
                            showingBrainDump: $showingBrainDump
                        )
                        .frame(maxHeight: .infinity)
                    }
                }
            .themedBackground()
            .navigationBarHidden(true)
            .sheet(isPresented: $showingNewTask, onDismiss: { newTaskInitialDate = nil }) {
                TaskCreationOptionsView(
                    viewModel: viewModel,
                    initialDate: newTaskInitialDate,
                    hasSpecificTime: newTaskInitialDate != nil
                )
                .id(newTaskInitialDate?.timeIntervalSince1970 ?? 0)
            }
            // Sheet Brain Dump IA disabilitato
            /*
            .sheet(isPresented: $showingBrainDump) {
                AIBrainDumpView(viewModel: viewModel)
            }
            */
            .sheet(isPresented: $showingCalendarPicker) {
                MediaHubCalendarView(
                    selectedDate: $viewModel.selectedDate,
                    selectedDayOffset: $selectedDayOffset,
                    viewModel: viewModel,
                    scrollProxy: scrollProxy
                )
            }
            .sheet(isPresented: $viewModel.showingFilterSheet) {
                TimelineOrganizationView(viewModel: viewModel)
            }
            .onChange(of: viewModel.selectedTimeScope) { newScope in
                // Ensure timeline (hourly) view is only used for Today scope
                if newScope != .today {
                    if viewModel.viewMode == .timeline {
                        viewModel.viewMode = .list
                    }
                    if viewModel.organization == .time {
                        viewModel.organization = .none
                    }
                }
            }
            .onAppear {
                // Fallback for cold-start: the notification may have fired
                // before this view subscribed, so also check the in-memory flag.
                if QuickAddTrigger.pending {
                    QuickAddTrigger.pending = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showingNewTask = true
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openQuickAdd)) { _ in
                // Triggered when the Control Center / Lock Screen / Action
                // Button "Quick Add Task" button opens the app.
                QuickAddTrigger.pending = false
                showingNewTask = true
            }
        }
    }
}

struct ViewControlBarView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @StateObject private var cloudKitService = CloudKitService.shared
    @Environment(\.theme) private var theme
    @AppStorage("allScopeShowHistory") private var allScopeShowHistory: Bool = false
    
    private var availableViewModes: [TimelineViewMode] {
        viewModel.selectedTimeScope == .today ? TimelineViewMode.allCases : [.list]
    }
    
    private var syncStatusIcon: String {
        switch cloudKitService.syncStatus {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.circle.fill"
        default:
            return "circle"
        }
    }
    
    private var syncStatusColor: Color {
        switch cloudKitService.syncStatus {
        case .success:
            return .green
        case .error:
            return .red
        default:
            return theme.secondaryTextColor
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // View mode toggle - styled with theme colors
            HStack(spacing: 2) {
                ForEach(availableViewModes, id: \.self) { mode in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.viewMode = mode
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 11, weight: .medium))
                            Text(mode == .list ? "list".localized : "time".localized)
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .multilineTextAlignment(.leading)
                        }
                        .foregroundColor(viewModel.viewMode == mode ? theme.backgroundColor : theme.primaryColor)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(viewModel.viewMode == mode ? theme.primaryColor : Color.clear)
                        )
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.primaryColor.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(theme.primaryColor.opacity(viewModel.viewMode == .list ? 0.6 : 0.25), lineWidth: 1)
                    )
            )
            .fixedSize()
            
            if viewModel.selectedTimeScope == .all {
                Button(action: {
                    allScopeShowHistory.toggle()
                    viewModel.showAllHistory = allScopeShowHistory
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 11, weight: .medium))
                        Text("Storico")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(viewModel.showAllHistory ? theme.backgroundColor : theme.primaryColor)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(viewModel.showAllHistory ? theme.primaryColor : theme.primaryColor.opacity(0.08))
                    )
                }
            }
            
            Spacer()
            
            // Organization status - themed. When grouped/sorted it doubles as the reset control.
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.organization = .none
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.organization.icon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.secondaryTextColor)
                    
                    Text(viewModel.organizationStatusText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.secondaryTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    if viewModel.organization != .none {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(theme.secondaryTextColor.opacity(0.7))
                    }
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(theme.surfaceColor)
                )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.organization == .none)
            
            // Filter button - themed
            Button(action: {
                viewModel.showingFilterSheet = true
            }) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundColor(theme.primaryColor)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(theme.primaryColor.opacity(0.08))
                    )
            }
            
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .onAppear {
            viewModel.showAllHistory = allScopeShowHistory
        }
        .onChange(of: allScopeShowHistory) { newValue in
            viewModel.showAllHistory = newValue
        }
        .onChange(of: viewModel.selectedTimeScope) { newScope in
            if newScope == .all {
                viewModel.showAllHistory = allScopeShowHistory
            }
        }
    }
}

struct TimelineContentView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @Binding var showingNewTask: Bool
    @Binding var showingBrainDump: Bool
    @Binding var newTaskInitialDate: Date?
    @StateObject private var cloudKitService = CloudKitService.shared
    @State private var scrollProxy: ScrollViewProxy?
    @State private var isRefreshing = false
    @State private var isAllDayExpanded: Bool = true
    @State private var currentTime = Date()
    @Environment(\.theme) private var theme
    
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    
    private var allDayTasks: [TodoTask] {
        return viewModel.tasksForSelectedDate().filter { !$0.hasSpecificTime }
    }
    
    private var currentHour: Int {
        Calendar.current.component(.hour, from: currentTime)
    }
    
    private var currentMinute: Int {
        Calendar.current.component(.minute, from: currentTime)
    }
    
    // Continuous 24-hour timeline range to avoid layout jumps
    private var timelineRange: ClosedRange<Int> {
        return 0...23
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                // Top daily stats and quick-jump bar
                dailyStatsBar
                
                Divider()
                    .foregroundColor(theme.borderColor.opacity(0.4))
                
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Collapsible All-Day Tasks Section
                        if !allDayTasks.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        isAllDayExpanded.toggle()
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "sun.max.fill")
                                            .foregroundColor(.orange)
                                            .font(.system(size: 13))
                                        
                                        Text("all_day".localized)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(theme.textColor)
                                        
                                        Text("\(allDayTasks.count)")
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 2)
                                            .background(theme.primaryColor.opacity(0.12))
                                            .foregroundColor(theme.primaryColor)
                                            .clipShape(Capsule())
                                        
                                        Spacer()
                                        
                                        Image(systemName: isAllDayExpanded ? "chevron.up" : "chevron.down")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(theme.secondaryTextColor)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                
                                if isAllDayExpanded {
                                    VStack(spacing: 6) {
                                        ForEach(allDayTasks, id: \.id) { task in
                                            CompactTimelineTaskView(task: task, viewModel: viewModel)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.bottom, 8)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                            .background(theme.surfaceColor.opacity(0.5))
                            
                            Divider()
                                .foregroundColor(theme.borderColor.opacity(0.5))
                        }
                        
                        // Continuous 24-Hour Timeline Rows
                        ForEach(Array(timelineRange), id: \.self) { hour in
                            EnhancedTimelineHourRow(
                                hour: hour,
                                tasks: tasksForHour(hour),
                                viewModel: viewModel,
                                isCurrentHour: viewModel.isToday && currentHour == hour,
                                currentMinute: viewModel.isToday && currentHour == hour ? currentMinute : nil,
                                freeHoursCount: isStartOfFreeBlock(hour: hour) ? freeHoursStarting(at: hour) : nil,
                                onScheduleAtHour: { selectedHour in
                                    scheduleTask(at: selectedHour)
                                }
                            )
                            .id(hour)
                        }
                        
                        // Closing divider after last hour
                        Rectangle()
                            .fill(theme.borderColor.opacity(0.3))
                            .frame(height: 1)
                            .padding(.leading, 56)
                    }
                    .padding(.top, 10)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 160)
                }
                .refreshable {
                    await performCloudKitSync()
                }
            }
            .onReceive(timer) { newTime in
                currentTime = newTime
            }
            .onAppear {
                scrollProxy = proxy
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    scrollToRelevantTime(proxy)
                }
            }
            .onChange(of: viewModel.selectedDate) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    if let proxy = scrollProxy {
                        scrollToRelevantTime(proxy)
                    }
                }
            }
            .overlay(alignment: .bottom) {
                ZStack(alignment: .bottom) {
                    HStack {
                        Spacer()
                    }
                    
                    AddTaskButton(
                        isShowingTaskForm: $showingNewTask,
                        timeScope: viewModel.selectedTimeScope
                    )
                }
                .padding(.bottom, 16)
                .allowsHitTesting(true)
            }
        }
    }
    
    // MARK: - Daily Snapshot Bar
    private var dailyStatsBar: some View {
        let tasksForDay = viewModel.tasksForSelectedDate()
        let completedCount = tasksForDay.filter { task in
            let completionDate = task.completionKey(for: viewModel.selectedDate)
            return task.completions[completionDate]?.isCompleted == true
        }.count
        let totalCount = tasksForDay.count
        let percent = totalCount > 0 ? Int(Double(completedCount) / Double(totalCount) * 100) : 0
        
        let totalDurationSeconds = tasksForDay.reduce(0.0) { sum, task in
            task.hasDuration ? sum + task.duration : sum
        }
        let totalHours = Int(totalDurationSeconds) / 3600
        let totalMinutes = (Int(totalDurationSeconds) % 3600) / 60
        
        return HStack(spacing: 8) {
            // Progress badge
            HStack(spacing: 5) {
                Image(systemName: completedCount == totalCount && totalCount > 0 ? "checkmark.circle.fill" : "circle.dashed")
                    .foregroundColor(theme.primaryColor)
                    .font(.system(size: 12, weight: .bold))
                
                Text("\(completedCount)/\(totalCount)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textColor)
                
                if totalCount > 0 {
                    Text("• \(percent)%")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.secondaryTextColor)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(theme.surfaceColor)
                    .overlay(Capsule().stroke(theme.borderColor.opacity(0.6), lineWidth: 1))
            )
            
            // Duration badge (if any tasks have duration)
            if totalDurationSeconds > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(theme.secondaryTextColor)
                    Text(totalHours > 0 ? "\(totalHours)h \(totalMinutes)m" : "\(totalMinutes)m")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.secondaryTextColor)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(theme.surfaceColor)
                        .overlay(Capsule().stroke(theme.borderColor.opacity(0.6), lineWidth: 1))
                )
            }
            
            Spacer()
            
            // Jump to Now button (only if viewing today)
            if viewModel.isToday {
                Button(action: {
                    HapticManager.shared.selection()
                    if let proxy = scrollProxy {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            proxy.scrollTo(max(0, currentHour - 1), anchor: .top)
                        }
                    }
                }) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 6, height: 6)
                        Text("Adesso")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(theme.primaryColor)
                    )
                    .shadow(color: theme.primaryColor.opacity(0.35), radius: 3, y: 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(theme.backgroundColor)
    }
    
    // MARK: - Navigation & Interaction Helpers
    private func scrollToRelevantTime(_ proxy: ScrollViewProxy) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if viewModel.isToday {
                let target = max(0, currentHour - 1)
                proxy.scrollTo(target, anchor: .top)
            } else {
                let tasks = viewModel.tasksForSelectedDate().filter { $0.hasSpecificTime }
                let cal = Calendar.current
                let earliestHour = tasks.map { task -> Int in
                    let date = task.recurrence != nil ? task.occurrenceDate(on: viewModel.selectedDate) : task.startTime
                    return cal.component(.hour, from: date)
                }.min() ?? 8
                let target = max(0, earliestHour - 1)
                proxy.scrollTo(target, anchor: .top)
            }
        }
    }
    
    private func scheduleTask(at hour: Int) {
        let calendar = Calendar.current
        if let targetDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: viewModel.selectedDate) {
            newTaskInitialDate = targetDate
            showingNewTask = true
            HapticManager.shared.selection()
        }
    }
    
    private func tasksForHour(_ hour: Int) -> [TodoTask] {
        let calendar = Calendar.current
        return viewModel.tasksForSelectedDate().filter { task in
            guard task.hasSpecificTime else { return false }
            let date = task.recurrence != nil ? task.occurrenceDate(on: viewModel.selectedDate) : task.startTime
            let taskHour = calendar.component(.hour, from: date)
            return taskHour == hour
        }
    }
    
    private func freeHoursStarting(at hour: Int) -> Int {
        let tasks = viewModel.tasksForSelectedDate().filter { $0.hasSpecificTime }
        let calendar = Calendar.current
        let busyHours = Set(tasks.map { task -> Int in
            let date = task.recurrence != nil ? task.occurrenceDate(on: viewModel.selectedDate) : task.startTime
            return calendar.component(.hour, from: date)
        })
        
        guard !busyHours.contains(hour) else { return 0 }
        
        var count = 0
        for h in hour...23 {
            if !busyHours.contains(h) {
                count += 1
            } else {
                break
            }
        }
        return count
    }
    
    private func isStartOfFreeBlock(hour: Int) -> Bool {
        let tasks = viewModel.tasksForSelectedDate().filter { $0.hasSpecificTime }
        let calendar = Calendar.current
        let busyHours = Set(tasks.map { task -> Int in
            let date = task.recurrence != nil ? task.occurrenceDate(on: viewModel.selectedDate) : task.startTime
            return calendar.component(.hour, from: date)
        })
        
        guard !busyHours.contains(hour) else { return false }
        if hour == 0 { return true }
        return busyHours.contains(hour - 1)
    }
    
    private func performCloudKitSync() async {
        guard cloudKitService.isCloudKitEnabled else { return }
        
        await MainActor.run {
            isRefreshing = true
        }
        
        cloudKitService.syncNow()
        
        for _ in 0..<10 {
            if cloudKitService.syncStatus == .success || cloudKitService.syncStatus.description.contains("error") {
                break
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        await MainActor.run {
            isRefreshing = false
        }
    }
}

// MARK: - Enhanced Timeline Hour Row
struct EnhancedTimelineHourRow: View {
    /// Re-render when the 12/24h preference changes (it is injected as the locale).
    @Environment(\.locale) private var locale
    let hour: Int
    let tasks: [TodoTask]
    @ObservedObject var viewModel: TimelineViewModel
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    
    let isCurrentHour: Bool
    let currentMinute: Int?
    let freeHoursCount: Int?
    let onScheduleAtHour: (Int) -> Void
    
    private var hourString: String {
        TimeFormat.hourLabel(hour)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Left Time Axis Column
            VStack(alignment: .trailing, spacing: 0) {
                HStack(spacing: 3) {
                    if isCurrentHour {
                        Circle()
                            .fill(theme.primaryColor)
                            .frame(width: 5, height: 5)
                    }
                    Text(hourString)
                        .font(.system(size: 12, weight: isCurrentHour ? .bold : .medium, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundColor(isCurrentHour ? theme.primaryColor : theme.secondaryTextColor)
                }
                .offset(y: -7) // Vertically aligned with the top grid line
                
                Spacer(minLength: 0)
            }
            .frame(width: 48, alignment: .topTrailing)
            
            // Schedule & Content Area (Right Column Canvas)
            VStack(alignment: .leading, spacing: 0) {
                // Top hairline grid divider
                Rectangle()
                    .fill(theme.borderColor.opacity(0.3))
                    .frame(height: 1)
                
                if tasks.isEmpty {
                    // Clean, serene empty hour slot - tap anywhere to schedule
                    ZStack(alignment: .topLeading) {
                        Button {
                            HapticManager.shared.selection()
                            onScheduleAtHour(hour)
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isCurrentHour ? theme.primaryColor.opacity(0.04) : Color.clear)
                                
                                // Faint 30-min guideline
                                VStack {
                                    Spacer()
                                    Rectangle()
                                        .fill(theme.borderColor.opacity(0.12))
                                        .frame(height: 0.5)
                                    Spacer()
                                }
                            }
                            .frame(height: 52)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(EmptyHourSlotButtonStyle())
                        
                        // Live Current Time Indicator ONLY when the hour is empty (never slices across cards!)
                        if isCurrentHour, let minute = currentMinute {
                            GeometryReader { geo in
                                let minuteRatio = CGFloat(minute) / 60.0
                                let yPos = max(2, min(geo.size.height - 2, geo.size.height * minuteRatio))
                                
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(theme.primaryColor)
                                        .frame(height: 1.5)
                                    
                                    Circle()
                                        .fill(theme.primaryColor)
                                        .frame(width: 7, height: 7)
                                        .offset(x: -3.5)
                                        .shadow(color: theme.primaryColor.opacity(0.4), radius: 2)
                                }
                                .offset(y: yPos - 1)
                            }
                            .allowsHitTesting(false)
                        }
                    }
                } else {
                    // Scheduled Tasks for this Hour (using the exact list view TimelineTaskCard design!)
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(tasks, id: \.id) { task in
                            TimelineTaskCard(
                                task: task,
                                onToggleComplete: { viewModel.toggleTaskCompletion(task.id) },
                                onToggleSubtask: { subtaskId in
                                    viewModel.toggleSubtask(taskId: task.id, subtaskId: subtaskId)
                                },
                                viewModel: viewModel
                            )
                        }
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 0)
    }
}

// Subtle press feedback for empty hour slot
private struct EmptyHourSlotButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.65 : 1.0)
    }
}

struct TimelineHeaderView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @Binding var selectedDayOffset: Int
    @Binding var showingCalendarPicker: Bool
    @Binding var scrollProxy: ScrollViewProxy?
    @Environment(\.theme) private var theme
    @State private var showingJournal = false
    @State private var showingSettings = false
    @ObservedObject private var journalManager = JournalManager.shared
    @ObservedObject private var settingsManager = CloudKitSettingsManager.shared

    /// Title sizes tried in order (title2 is 22pt).
    private static let titleSizes: [CGFloat] = [22, 20, 18, 17]

    /// The spelled-out period at each size, then (week only) the numeric range at each size.
    private var titleCandidates: [(id: Int, text: String, size: CGFloat)] {
        let texts = [viewModel.currentPeriodString] + (viewModel.compactPeriodString.map { [$0] } ?? [])
        var result: [(id: Int, text: String, size: CGFloat)] = []
        for text in texts {
            for size in Self.titleSizes {
                result.append((id: result.count, text: text, size: size))
            }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    Button(action: {
                        if !viewModel.isCurrentPeriod {
                            HapticManager.shared.selection()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                selectedDayOffset = 0
                                viewModel.navigateToToday()
                            }
                        }
                    }) {
                        VStack(alignment: .leading, spacing: 1) {
                            // One line, never truncated: the largest size that fits; week ranges
                            // fall back to the numeric form before getting any smaller.
                            ViewThatFits(in: .horizontal) {
                                ForEach(titleCandidates, id: \.id) { candidate in
                                    Text(candidate.text)
                                        .font(candidate.size == Self.titleSizes.first ? .title2.bold() : .system(size: candidate.size, weight: .bold))
                                        .lineLimit(1)
                                        .fixedSize()
                                }
                                
                                Text(viewModel.compactPeriodString ?? viewModel.currentPeriodString)
                                    .font(.system(size: Self.titleSizes.last ?? 17, weight: .bold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            }
                            .themedPrimaryText()
                            
                            if !viewModel.isCurrentPeriod {
                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.uturn.backward")
                                        .font(.system(size: 9, weight: .bold))
                                    Text("today".localized)
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundColor(theme.primaryColor)
                                .transition(.opacity)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    // Take the room before the spacer does: the title shrinks only when it has to.
                    .layoutPriority(1)
                    
                    if viewModel.selectedTimeScope == .today {
                        Button(action: { showingJournal = true }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(theme.primaryColor.opacity(0.12))
                                    .frame(width: 34, height: 34)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(theme.primaryColor.opacity(0.35), lineWidth: 1)
                                    )
                                    .shadow(color: theme.shadowColor, radius: 2, x: 0, y: 1)

                                Image(systemName: "book.closed.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(theme.primaryColor)

                                if hasJournalContentForSelectedDate {
                                    Circle()
                                        .fill(theme.accentColor)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 12, y: -12)
                                        .shadow(color: theme.accentColor.opacity(0.5), radius: 2)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .sheet(isPresented: $showingJournal) {
                            JournalView(date: viewModel.selectedDate)
                        }
                    }
                    
                    Spacer(minLength: 8)
                    
                    HStack(spacing: 8) {
                        if (viewModel.selectedTimeScope != .today || settingsManager.hideDaysBar) && viewModel.selectedTimeScope != .longTerm && viewModel.selectedTimeScope != .inbox && viewModel.selectedTimeScope != .all {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.navigateToPrevious()
                                    if viewModel.selectedTimeScope == .today {
                                        if let daysDiff = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: viewModel.selectedDate)).day {
                                            selectedDayOffset = daysDiff
                                        }
                                    }
                                }
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .medium))
                                    .themedPrimary()
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(theme.primaryColor.opacity(0.1))
                                    )
                            }
                            .disabled(!viewModel.canNavigatePrevious)
                            
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.navigateToNext()
                                    if viewModel.selectedTimeScope == .today {
                                        if let daysDiff = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: viewModel.selectedDate)).day {
                                            selectedDayOffset = daysDiff
                                        }
                                    }
                                }
                            }) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .themedPrimary()
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(theme.primaryColor.opacity(0.1))
                                    )
                            }
                            .disabled(!viewModel.canNavigateNext)
                        }
                        
                        Menu {
                            ForEach(TaskTimeScope.allCases, id: \.self) { scope in
                                Button(action: {
                                    viewModel.changeScope(to: scope)
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: scope.icon)
                                            .foregroundColor(scope.tint)
                                            .font(.system(size: 14, weight: .medium))
                                        
                                        Text(scope.timelineMenuName)
                                            .font(.subheadline)
                                        
                                        Spacer()
                                        
                                        if viewModel.selectedTimeScope == scope {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                                .font(.system(size: 12, weight: .semibold))
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                // Text only (the icons are in the menu): the scope name must never be cut.
                                Text(viewModel.selectedTimeScope.timelineMenuName)
                                    .font(.subheadline.weight(.semibold))
                                    .themedPrimaryText()
                                    .lineLimit(1)
                                
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .medium))
                                    .themedSecondaryText()
                            }
                            .padding(.leading, 10)
                            .padding(.trailing, 8)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(theme.surfaceColor)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(theme.borderColor, lineWidth: 1)
                                    )
                            )
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize(horizontal: true, vertical: false)

                        if viewModel.selectedTimeScope == .today {
                            Button(action: { showingCalendarPicker = true }) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 16, weight: .medium))
                                    .themedPrimary()
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(theme.primaryColor.opacity(0.1))
                                    )
                            }
                        }

                        Button(action: { showingSettings = true }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(theme.primaryColor.opacity(0.12))
                                    .frame(width: 34, height: 34)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(theme.primaryColor.opacity(0.35), lineWidth: 1)
                                    )
                                    .shadow(color: theme.shadowColor, radius: 2, x: 0, y: 1)

                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(theme.primaryColor)
                            }
                        }
                        .buttonStyle(.plain)
                        .sheet(isPresented: $showingSettings) {
                            SettingsView()
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 60)
            
            if viewModel.selectedTimeScope == .today && !settingsManager.hideDaysBar {
                DateSelectorView(
                    viewModel: viewModel,
                    selectedDayOffset: $selectedDayOffset,
                    scrollProxy: $scrollProxy
                )
                .padding(.top, 4)
            }
        }
    }

    private var hasJournalContentForSelectedDate: Bool {
        let entry = journalManager.entry(for: viewModel.selectedDate)
        return !entry.isEmpty
    }
}

struct DateSelectorView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @Binding var selectedDayOffset: Int
    @Binding var scrollProxy: ScrollViewProxy?
    @Environment(\.theme) private var theme
    @State private var isDragging = false
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                // Lazy: only the visible days are built (731 eager cells made every
                // appearance of the strip cost ~200ms).
                LazyHStack(spacing: 12) {
                    ForEach(-365...365, id: \.self) { offset in
                        DayCell(
                            date: Calendar.current.date(
                                byAdding: .day,
                                value: offset,
                                to: Date()
                            ) ?? Date(),
                            isSelected: offset == selectedDayOffset,
                            offset: offset
                        ) { _ in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedDayOffset = offset
                                viewModel.selectDate(offset)
                                HapticManager.shared.selection()
                                proxy.scrollTo(offset, anchor: .center)
                            }
                        }
                        .id(offset)
                        .scaleEffect(offset == selectedDayOffset ? 1.08 : 1.0)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
            }
            // A lazy stack takes all the height it is offered: pin it to the cells (60 + 2×6).
            .frame(height: 72)
            // The strip is symmetric around today, so it starts centred on it; onAppear then places
            // the selected day without animating (it used to slide in from far away every time
            // the strip came back, e.g. when leaving the inbox).
            .defaultScrollAnchor(.center)
            .onAppear {
                scrollProxy = proxy
                proxy.scrollTo(selectedDayOffset, anchor: .center)
                DispatchQueue.main.async {
                    proxy.scrollTo(selectedDayOffset, anchor: .center)
                }
            }
            .onChange(of: selectedDayOffset) { _, newValue in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        isDragging = false
                        let velocity = value.predictedEndLocation.x - value.location.x

                        if abs(velocity) > 50 {
                            let direction = velocity > 0 ? -1 : 1
                            let newOffset = selectedDayOffset + direction
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedDayOffset = newOffset
                                viewModel.selectDate(newOffset)
                                proxy.scrollTo(newOffset, anchor: .center)
                                HapticManager.shared.selection()
                            }
                        } else {
                            let cellWidth: CGFloat = 62
                            let estimatedOffset = Int(round(dragOffset / cellWidth))
                            let newOffset = selectedDayOffset - estimatedOffset

                            if newOffset != selectedDayOffset {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedDayOffset = newOffset
                                    viewModel.selectDate(newOffset)
                                    proxy.scrollTo(newOffset, anchor: .center)
                                    HapticManager.shared.selection()
                                }
                            } else {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                     proxy.scrollTo(selectedDayOffset, anchor: .center)
                                }
                            }
                        }
                    }
            )
        }
    }
}


struct TaskListView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @Binding var showingNewTask: Bool
    @Binding var showingBrainDump: Bool
    @StateObject private var pomodoroViewModel = PomodoroViewModel.shared
    @StateObject private var timeTrackerViewModel = TimeTrackerViewModel.shared
    @StateObject private var cloudKitService = CloudKitService.shared
    @State private var showingActivePomodoroSession = false
    @State private var showingGeneralPomodoroFullScreen = false
    @State private var showingActiveTimeTrackerSession = false
    @State private var selectedSessionId: UUID?
    @State private var isRefreshing = false
    @State private var showingMandalaSheet = false
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(spacing: 0) {
            // Pinned above both the empty state and the list, so it keeps focus
            // (and the keyboard) while notes are being added one after another.
            if viewModel.selectedTimeScope == .inbox {
                InboxQuickAddField()
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .padding(.bottom, 2)
            }
        Group {
            if viewModel.tasks.isEmpty && viewModel.selectedTimeScope == .inbox {
                VStack(spacing: 0) {
                    Spacer()
                    InboxEmptyState()
                    Spacer()
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { UIApplication.shared.dismissKeyboard() }
            } else if viewModel.tasks.isEmpty {
                // Empty state
                VStack(spacing: 20) {
                    if viewModel.selectedTimeScope == .year || viewModel.selectedTimeScope == .longTerm {
                        mandalaBannerCard
                            .padding(.top, 8)
                    }
                    
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 64))
                        .foregroundColor(theme.secondaryTextColor.opacity(0.6))
                    
                    VStack(spacing: 8) {
                        Text(viewModel.progressText)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.textColor)
                        
                        Text("tap_plus_add_first_task".localized)
                            .font(.subheadline)
                            .foregroundColor(theme.secondaryTextColor)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .sheet(isPresented: $showingMandalaSheet) {
                    MandalaHubView()
                }
            } else {
                if viewModel.effectiveOrganization == .eisenhower {
                    EisenhowerMatrixView(viewModel: viewModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                        .padding(.bottom, 100)
                } else if viewModel.canReorderTasks {
                    reorderableTaskList
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            if viewModel.selectedTimeScope == .year || viewModel.selectedTimeScope == .longTerm {
                                mandalaBannerCard
                            }

                            
                            switch viewModel.organizedTasksForSelectedDate() {
                            case .single(let tasks):
                                ForEach(tasks, id: \.id) { task in
                                    taskCardRow(for: task)
                                }
                            
                            case .sections(let sections):
                                ForEach(sections) { section in
                                    OrganizedTaskSection(
                                        section: section,
                                        viewModel: viewModel
                                    )
                                }
                            }
                        }
                        .sheet(isPresented: $showingMandalaSheet) {
                            MandalaHubView()
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 100)
                        .padding(.top, 8)
                        .animation(.interpolatingSpring(stiffness: 300, damping: 30), value: viewModel.tasks.map { $0.id })
                        .onTapGesture {
                            if viewModel.openSwipeTaskId != nil {
                                viewModel.closeAllSwipeMenus()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scrollDismissesKeyboard(.immediately)
                    .refreshable {
                        await performCloudKitSync()
                    }
                }
            }
        }
        }
        // Scope changes fade this content out, switch while it is invisible, and fade it back in
        // (TimelineViewModel.changeScope). The + stays put above it.
        .opacity(viewModel.scopeTransitionProgress)
        .offset(y: (1 - viewModel.scopeTransitionProgress) * 8)
        .overlay(alignment: .bottom) {
            bottomBarOverlay
                .padding(.bottom, 16)
        }
        .fullScreenCover(isPresented: $showingActivePomodoroSession) {
            if pomodoroViewModel.activeTask != nil {
                NavigationStack {
                    PomodoroTabView()
                }
            }
        }
        .fullScreenCover(isPresented: $showingGeneralPomodoroFullScreen) {
            NavigationStack {
                PomodoroTabView()
            }
        }
        .sheet(isPresented: Binding(
            get: { selectedSessionId != nil },
            set: { if !$0 { selectedSessionId = nil } }
        )) {
            if let sessionId = selectedSessionId {
                NavigationStack {
                    TimeTrackerView(
                        sessionId: sessionId,
                        presentationStyle: .sheet,
                        allowExpand: true
                    )
                }
                .presentationDetents(timeTrackerViewModel.showingCompletion ? [.large] : [.height(410), .medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }
    
    private var mandalaBannerCard: some View {
        Button(action: {
            showingMandalaSheet = true
            HapticManager.shared.impact(.light)
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(theme.primaryColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "square.grid.3x3.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(theme.primaryColor)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Mandala Goal Method")
                            .font(.subheadline.bold())
                            .themedPrimaryText()
                        
                        Text("81 Caselle")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.primaryColor.opacity(0.15))
                            .foregroundColor(theme.primaryColor)
                            .clipShape(Capsule())
                    }
                    
                    Text("Pianifica i grandi obiettivi e trasformali in azioni quotidiane.")
                        .font(.caption)
                        .themedSecondaryText()
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(theme.secondaryTextColor)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(theme.surfaceColor)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(theme.primaryColor.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var bottomBarOverlay: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                
                HStack(spacing: 8) {
                    ForEach(timeTrackerViewModel.activeSessions) { session in
                        MiniTimerWidget(
                            sessionId: session.id,
                            viewModel: timeTrackerViewModel,
                            onTap: {
                                selectedSessionId = session.id
                            }
                        )
                    }
                    
                    if pomodoroViewModel.hasActiveTask {
                        MiniPomodoroWidget(viewModel: pomodoroViewModel) {
                            DispatchQueue.main.async {
                                if pomodoroViewModel.activeTask != nil {
                                    showingActivePomodoroSession = true
                                } else {
                                    if pomodoroViewModel.state == .notStarted {
                                        pomodoroViewModel.initializeGeneralSession()
                                    }
                                    showingGeneralPomodoroFullScreen = true
                                }
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, timeTrackerViewModel.hasActiveSession || pomodoroViewModel.hasActiveTask ? 10 : 0)
            
            ZStack(alignment: .bottom) {
                HStack {
                    // BrainDumpButton disabilitato per il rilascio
                    Spacer()
                }
                
                AddTaskButton(
                    isShowingTaskForm: $showingNewTask,
                    timeScope: viewModel.selectedTimeScope
                )
                
                // Beside the + (56pt): quick way in and out of the inbox, with the open count.
                InboxShortcutButton(viewModel: viewModel)
                    .offset(x: -(28 + 18 + 22))
                    .padding(.bottom, 6)
            }
            .padding(.bottom, 16)
        }
    }
    private func performCloudKitSync() async {
        guard cloudKitService.isCloudKitEnabled else { return }
        
        await MainActor.run {
            isRefreshing = true
        }
        
        // Trigger CloudKit sync
        cloudKitService.syncNow()
        
        // Wait for sync to complete
        for _ in 0..<10 { // Max 5 seconds wait
            if cloudKitService.syncStatus == .success || cloudKitService.syncStatus.description.contains("error") {
                break
            }
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        await MainActor.run {
            isRefreshing = false
        }
    }
    
    /// Vista predefinita: List nativa, così il riordino (tieni premuto e trascina)
    /// ha scorrimento automatico, animazioni e vibrazione di sistema.
    private var reorderableTaskList: some View {
        List {
            if viewModel.selectedTimeScope == .year || viewModel.selectedTimeScope == .longTerm {
                mandalaBannerCard
                    .listRowInsets(EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            
            if case .single(let tasks) = viewModel.organizedTasksForSelectedDate() {
                ForEach(tasks, id: \.id) { task in
                    taskCardRow(for: task)
                        .contentShape(.dragPreview, RoundedRectangle(cornerRadius: TimelineTaskCard.cornerRadius, style: .continuous))
                        .listRowInsets(EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .onMove { source, destination in
                    viewModel.moveTasks(fromOffsets: source, toOffset: destination)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .environment(\.defaultMinListRowHeight, 0)
        .contentMargins(.top, 2, for: .scrollContent)
        .contentMargins(.bottom, 100, for: .scrollContent)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .refreshable {
            await performCloudKitSync()
        }
        .sheet(isPresented: $showingMandalaSheet) {
            MandalaHubView()
        }
    }
    
    @ViewBuilder
    private func taskCardRow(for task: TodoTask) -> some View {
        TimelineTaskCard(
            task: task,
            onToggleComplete: { viewModel.toggleTaskCompletion(task.id) },
            onToggleSubtask: { subtaskId in
                viewModel.toggleSubtask(taskId: task.id, subtaskId: subtaskId)
            },
            viewModel: viewModel
        )
    }
}

struct OrganizedTaskSection: View {
    let section: TaskSection
    @ObservedObject var viewModel: TimelineViewModel
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                
                if let icon = section.icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(section.color.map { Color(hex: $0) } ?? theme.secondaryTextColor)
                }
                
                Text(section.title)
                    .font(.headline)
                    .foregroundColor(theme.textColor)
                
                Spacer()
                
                Text("\(section.tasks.count)")
                    .font(.caption)
                    .foregroundColor(theme.secondaryTextColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.surfaceColor)
                    .cornerRadius(4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.surfaceColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(section.color.map { Color(hex: $0).opacity(0.2) } ?? theme.borderColor, lineWidth: 1)
                    )
            )
            
            ForEach(section.tasks) { task in
                TimelineTaskCard(
                    task: task,
                    onToggleComplete: { viewModel.toggleTaskCompletion(task.id) },
                    onToggleSubtask: { subtaskId in
                        viewModel.toggleSubtask(taskId: task.id, subtaskId: subtaskId)
                    },
                    viewModel: viewModel
                )
            }
        }
    }
}

struct CalendarPickerView: View {
    @Binding var selectedDate: Date
    @Binding var selectedDayOffset: Int
    @ObservedObject var viewModel: TimelineViewModel
    let scrollProxy: ScrollViewProxy?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                DatePicker("",
                          selection: $selectedDate,
                          displayedComponents: [.date])
                    .datePickerStyle(.graphical)
                    .padding()
                
                Button("done".localized) {
                    let calendar = Calendar.current
                    let today = Date()
                    if let daysDiff = calendar.dateComponents([.day], from: today, to: selectedDate).day {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedDayOffset = daysDiff
                            viewModel.selectDate(daysDiff)
                            scrollProxy?.scrollTo(daysDiff, anchor: .center)
                        }
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .padding(.bottom)
            }
            .navigationBarHidden(true)
            .presentationDetents([.height(500)])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let offset: Int
    let action: (Int) -> Void
    @Environment(\.theme) private var theme
    
    init(date: Date, isSelected: Bool, offset: Int, action: @escaping (Int) -> Void) {
        self.date = date
        self.isSelected = isSelected
        self.offset = offset
        self.action = action
    }
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(dayName)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? theme.backgroundColor : (isToday ? theme.primaryColor : theme.secondaryTextColor))
            
            Text(dayNumber)
                .font(.callout)
                .fontWeight(.bold)
                .foregroundColor(isSelected ? theme.backgroundColor : (isToday ? theme.primaryColor : theme.textColor))
        }
        .frame(width: 45, height: 60)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ?
                    AnyShapeStyle(theme.gradient) :
                    (isToday ?
                        AnyShapeStyle(theme.primaryColor.opacity(0.1)) :
                        AnyShapeStyle(theme.surfaceColor)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isSelected ? Color.clear : (isToday ? theme.primaryColor.opacity(0.3) : theme.borderColor),
                            lineWidth: 1)
        )
        .onTapGesture {
            action(offset)
        }
    }
    
    private var dayName: String {
        let weekday = Calendar.current.component(.weekday, from: date)
        switch weekday {
        case 1: return "sunday".localized.prefix(3).lowercased()
        case 2: return "monday".localized.prefix(3).lowercased()
        case 3: return "tuesday".localized.prefix(3).lowercased()
        case 4: return "wednesday".localized.prefix(3).lowercased()
        case 5: return "thursday".localized.prefix(3).lowercased()
        case 6: return "friday".localized.prefix(3).lowercased()
        case 7: return "saturday".localized.prefix(3).lowercased()
        default: return ""
        }
    }
    
    /// Shared: the strip builds 731 cells, a formatter per cell made every scope change stutter.
    private static let dayNumberFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    
    private var dayNumber: String {
        Self.dayNumberFormatter.string(from: date)
    }
}

struct TimelineTaskCard: View {
    /// Re-render when the 12/24h preference changes (it is injected as the locale).
    @Environment(\.locale) private var locale
    let task: TodoTask
    let onToggleComplete: () -> Void
    let onToggleSubtask: (UUID) -> Void
    @ObservedObject var viewModel: TimelineViewModel
    @State private var isExpanded = false
    @State private var subtasksHeight: CGFloat = 0
    @State private var showingPomodoro = false
    @State private var showingEditSheet = false
    @State private var showingDetailView = false
    @State private var showingPlanSheet = false
    @State private var dragOffset: CGFloat = 0
    @State private var isAutoCompleting = false
    @State private var showingTrackingModeSelection = false
    @State private var showingTimeTracker = false
    @State private var selectedTrackingMode: TrackingMode = .simple
    @State private var isDeleting = false
    @State private var deleteOpacity: Double = 1.0
    @State private var deleteScale: CGFloat = 1.0
    @State private var isHorizontalSwipe = false
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("showCategoryGradients") private var gradientEnabled: Bool = true

    // Helpers for non-today scopes: date/time badges
    private var occurrenceDateForBadges: Date {
        guard let recurrence = task.recurrence else { return task.startTime }
        let calendar = Calendar.current

        let periodStart: Date
        let periodEnd: Date
        switch viewModel.selectedTimeScope {
        case .week:
            periodStart = calendar.startOfWeek(for: viewModel.currentWeek)
            periodEnd = calendar.date(byAdding: .day, value: 6, to: periodStart) ?? periodStart
        case .month:
            periodStart = calendar.startOfMonth(for: viewModel.currentMonth)
            let next = calendar.date(byAdding: .month, value: 1, to: periodStart) ?? periodStart
            periodEnd = calendar.date(byAdding: .day, value: -1, to: next) ?? periodStart
        case .year:
            periodStart = calendar.startOfYear(for: viewModel.currentYear)
            let next = calendar.date(byAdding: .year, value: 1, to: periodStart) ?? periodStart
            periodEnd = calendar.date(byAdding: .day, value: -1, to: next) ?? periodStart
        default:
            return task.startTime
        }

        var day = calendar.startOfDay(for: periodStart)
        let dayEnd = calendar.startOfDay(for: periodEnd)

        let anchorStart = calendar.startOfDay(for: recurrence.startDate)
        if day < anchorStart {
            day = anchorStart
        }

        while day <= dayEnd {
            if recurrence.shouldOccurOn(date: day) {
                return task.occurrenceDate(on: day)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        return task.startTime
    }

    private var dateBadgeText: String? {
        switch viewModel.selectedTimeScope {
        case .week:
            let f = DateFormatter()
            f.setLocalizedDateFormatFromTemplate("EEE d")
            return f.string(from: occurrenceDateForBadges).capitalized
        case .month:
            let f = DateFormatter()
            f.setLocalizedDateFormatFromTemplate("d MMM")
            return f.string(from: occurrenceDateForBadges)
        case .year:
            let f = DateFormatter()
            f.setLocalizedDateFormatFromTemplate("d MMM")
            return f.string(from: occurrenceDateForBadges)
        case .longTerm:
            let f = DateFormatter()
            f.setLocalizedDateFormatFromTemplate("d MMM yyyy")
            return f.string(from: task.startTime)
        default:
            return nil
        }
    }

    private var timeBadgeText: String? {
        guard task.hasSpecificTime else { return nil }
        return TimeFormat.time(occurrenceDateForBadges)
    }

    private var isCurrentlyActiveNow: Bool {
        guard viewModel.isToday && task.hasSpecificTime else { return false }
        let now = Date()
        let t = task.recurrence != nil ? task.occurrenceDate(on: viewModel.selectedDate) : task.startTime
        let duration = task.hasDuration && task.duration > 0 ? task.duration : 1800
        let end = t.addingTimeInterval(duration)
        return now >= t && now <= end
    }

    // Get the correct target date based on the current scope
    private var targetDateForScope: Date {
        switch viewModel.selectedTimeScope {
        case .today:
            return viewModel.selectedDate
        case .week:
            return viewModel.currentWeek
        case .month:
            return viewModel.currentMonth
        case .year:
            return viewModel.currentYear
        case .longTerm, .inbox:
            return Calendar.current.startOfDay(for: task.startTime)
        case .all:
            // For "all" scope, use the task's own scope to determine the date
            switch task.timeScope {
            case .today:
                return viewModel.selectedDate
            case .week:
                return viewModel.currentWeek
            case .month:
                return viewModel.currentMonth
            case .year:
                return viewModel.currentYear
            case .longTerm, .inbox:
                return Calendar.current.startOfDay(for: task.startTime)
            case .all:
                return Calendar.current.startOfDay(for: Date())
            }
        }
    }
    
    private var isCompleted: Bool {
        let completionDate = task.completionKey(for: targetDateForScope)
        if let completion = task.completions[completionDate] {
            return completion.isCompleted
        }
        return false
    }

    private var completionProgress: Double {
        guard !task.subtasks.isEmpty else { return isCompleted ? 1.0 : 0.0 }
        let completionDate = task.completionKey(for: targetDateForScope)
        let completion = task.completions[completionDate]
        let completedCount = completion?.completedSubtasks.count ?? 0
        return Double(completedCount) / Double(task.subtasks.count)
    }

    private var completedSubtasks: Set<UUID> {
        let completionDate = task.completionKey(for: targetDateForScope)
        return task.completions[completionDate]?.completedSubtasks ?? []
    }

    private var currentStreak: Int {
        guard let recurrence = task.recurrence else { return 0 }
        let scopeDate = targetDateForScope.startOfDay
        var streak = 0
        var currentDate = scopeDate
        let isCompletedOnScopeDate = task.completions[scopeDate]?.isCompleted == true
        if isCompletedOnScopeDate {
            streak = 1
            currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate)!
        }
        var iterationCount = 0
        let maxIterations = 1000
        while iterationCount < maxIterations {
            guard recurrence.shouldOccurOn(date: currentDate) else {
                currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate)!
                iterationCount += 1
                continue
            }
            if task.completions[currentDate]?.isCompleted == true {
                streak += 1
                currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate)!
                iterationCount += 1
            } else {
                break
            }
        }
        return streak
    }

    private var categoryGradient: LinearGradient {
        if gradientEnabled, let category = task.category {
            let baseColor = Color(hex: category.color)
            return LinearGradient(
                stops: [
                    .init(color: baseColor.opacity(0.22), location: 0),
                    .init(color: baseColor.opacity(0.10), location: 0.35),
                    .init(color: baseColor.opacity(0.03), location: 0.7),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private let maxSwipeDistance: CGFloat = -210

    /// Uniform inset around the 38pt icon (radius 11): the card radius follows it
    /// (11 + 12 ≈ 22) so icon and card corners stay concentric.
    static let contentInset: CGFloat = 12
    static let cornerRadius: CGFloat = 22


    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(task.name)
                .font(.headline)
                .foregroundColor(theme.textColor)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let description = task.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(theme.secondaryTextColor)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var categoryTint: Color {
        task.category.map { Color(hex: $0.color) } ?? theme.accentColor
    }

    /// "circle" is the default when no icon was picked: it would read as a second checkbox,
    /// so fall back to the category icon (or a neutral symbol).
    private var displayIcon: String {
        guard task.icon == "circle" || task.icon.isEmpty else { return task.icon }
        return task.category?.icon ?? "list.bullet"
    }

    private var taskIcon: some View {
        Image(systemName: displayIcon)
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(categoryTint)
            .frame(width: 38, height: 38)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(categoryTint.opacity(0.16))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(categoryTint.opacity(0.25), lineWidth: 0.5)
            )
            .overlay(alignment: .bottom) {
                // Walks the completion history: compute it once per render.
                let streak = currentStreak
                if streak > 0 {
                    streakBadge(streak)
                        .offset(y: 9)
                }
            }
    }

    /// Streak lives on the icon corner so the info row always fits on one line.
    private func streakBadge(_ streak: Int) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "flame.fill")
                .font(.system(size: 9, weight: .bold))
            Text("\(streak)")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .monospacedDigit()
        }
        .foregroundColor(.white)
        .padding(.horizontal, 5)
        .frame(minWidth: 22, minHeight: 17)
        .background(
            Capsule().fill(
                LinearGradient(colors: [Color(hex: "FF9F0A"), Color(hex: "FF6B00")],
                               startPoint: .top, endPoint: .bottom)
            )
        )
        .overlay(Capsule().strokeBorder(Color(.systemBackground), lineWidth: 2))
        .shadow(color: Color.orange.opacity(0.35), radius: 2, y: 1)
        .fixedSize()
    }

    private var hasScheduleBadge: Bool {
        if viewModel.selectedTimeScope == .today { return true }
        return (task.hasSpecificTime || task.hasSpecificDay) && dateBadgeText != nil
    }

    /// Fixed info row under the title: schedule · subtasks chip (always one line).
    @ViewBuilder
    private var metaRow: some View {
        if hasScheduleBadge || !task.subtasks.isEmpty {
            HStack(spacing: 6) {
                if hasScheduleBadge {
                    scheduleBadge
                }
                if !task.subtasks.isEmpty {
                    subtasksChip
                }
            }
        }
    }

    /// Shows subtask progress and toggles the subtask list.
    private var subtasksChip: some View {
        Button(action: {
            withAnimation(.smooth(duration: 0.3)) {
                isExpanded.toggle()
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: "checklist")
                    .font(.system(size: 11, weight: .medium))
                Text("\(completedSubtasks.count)/\(task.subtasks.count)")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .animation(.interpolatingSpring(stiffness: 400, damping: 25), value: isExpanded)
            }
            .foregroundColor(theme.secondaryTextColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(theme.surfaceColor)
            .cornerRadius(4)
            .contentShape(Rectangle())
            .fixedSize()
        }
        .buttonStyle(BorderlessButtonStyle())
        .layoutPriority(1)
    }

    @ViewBuilder
    private var scheduleBadge: some View {
        if viewModel.selectedTimeScope == .today {
            if task.hasSpecificTime {
                let t = task.recurrence != nil ? task.occurrenceDate(on: viewModel.selectedDate) : task.startTime
                let timeText: String = {
                    if task.hasDuration && task.duration > 0 {
                        return TimeFormat.range(t, t.addingTimeInterval(task.duration))
                    }
                    return TimeFormat.time(t)
                }()
                
                HStack(spacing: 4) {
                    if isCurrentlyActiveNow {
                        Circle()
                            .fill(theme.primaryColor)
                            .frame(width: 5, height: 5)
                    }
                    Text(timeText)
                        .font(.caption.monospacedDigit())
                        .fontWeight(isCurrentlyActiveNow ? .semibold : .medium)
                        .foregroundColor(isCurrentlyActiveNow ? theme.primaryColor : theme.secondaryTextColor)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(isCurrentlyActiveNow ? theme.primaryColor.opacity(0.12) : theme.surfaceColor)
                .cornerRadius(4)
            } else {
                Text("all_day".localized)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            }
        } else if (task.hasSpecificTime || task.hasSpecificDay), let dayText = dateBadgeText {
            HStack(spacing: 6) {
                Text(dayText)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(theme.secondaryTextColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.surfaceColor)
                    .cornerRadius(4)
                if let timeText = timeBadgeText {
                    Text(timeText)
                        .font(.caption.monospacedDigit().weight(.medium))
                        .foregroundColor(theme.secondaryTextColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.surfaceColor)
                        .cornerRadius(4)
                }
            }
            .lineLimit(1)
            .fixedSize()
        }
    }

    var body: some View {
        ZStack {
            // Background actions layer
            HStack(spacing: 0) {
                // ...
                Spacer()
                
                HStack(spacing: 8) {
                    if task.timeScope == .inbox {
                        Button(action: {
                            UIApplication.shared.dismissKeyboard()
                            showingPlanSheet = true
                            resetSwipe()
                        }) {
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.indigo)
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Image(systemName: "calendar.badge.plus")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.white)
                                    )
                                
                                Text("inbox_plan".localized)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.indigo)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .frame(width: 56)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                    Button(action: {
                        showingTrackingModeSelection = true
                        resetSwipe()
                    }) {
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.yellow)
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                )
                            
                            Text("track".localized)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.yellow)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    }
                    
                    Button(action: {
                        UIApplication.shared.dismissKeyboard()
                        showingEditSheet = true
                        resetSwipe()
                    }) {
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.orange)
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: "pencil")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                )
                            
                            Text("edit".localized)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.orange)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        deleteTaskWithAnimation()
                    }) {
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.red)
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: "trash")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                )
                            
                            Text("delete".localized)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.red)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .opacity(dragOffset.magnitude > 40 ? min(1.0, (dragOffset.magnitude - 40.0) / 60.0) : 0.0)
            }
            
            // Main task card content
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .center, spacing: 8) {
                    // Icon (category-tinted) sits beside the first line of the title.
                    HStack(alignment: .top, spacing: 12) {
                        taskIcon
                        
                        // Fixed structure: title, optional description, info row (time · subtasks).
                        VStack(alignment: .leading, spacing: 5) {
                            titleBlock
                            metaRow
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Image(systemName: task.priority.icon)
                        .foregroundColor(Color(hex: task.priority.color))
                        .font(.system(size: 12))
                    
                    if task.pomodoroSettings != nil {
                        Button(action: {
                            PomodoroViewModel.shared.setActiveTask(task)
                            showingPomodoro = true
                        }) {
                            ZStack {
                                Circle()
                                    .fill(theme.accentColor.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: "timer")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(task.category.map { Color(hex: $0.color) } ?? theme.accentColor)
                            }
                            .overlay(
                                Circle()
                                    .strokeBorder(theme.accentColor.opacity(0.5), lineWidth: 1)
                            )
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                    
                    Button(action: {
                        if isCompleted {
                            HapticManager.shared.impact(.light)
                        } else {
                            HapticManager.shared.notification(.success)
                        }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            onToggleComplete()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .stroke(theme.borderColor, lineWidth: 2)
                                .frame(width: 32, height: 32)
                            
                            if !task.subtasks.isEmpty {
                                Circle()
                                    .trim(from: 0, to: completionProgress)
                                    .stroke(theme.primaryColor, lineWidth: 3)
                                    .frame(width: 32, height: 32)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.easeInOut(duration: 0.35), value: completionProgress)
                            }
                            
                            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isCompleted ? .green : theme.secondaryTextColor)
                                .font(.title2)
                        }
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .frame(width: 44, height: 44)
                }
                .padding(Self.contentInset)
                
                if !task.subtasks.isEmpty {
                    // Always in the hierarchy; the height is animated frame by frame so the
                    // List row grows/shrinks together with the card instead of jumping.
                    VStack(spacing: 8) {
                        ForEach(task.subtasks) { subtask in
                            TimelineSubtaskRow(
                                subtask: subtask,
                                isCompleted: completedSubtasks.contains(subtask.id),
                                onToggle: { onToggleSubtask(subtask.id) }
                            )
                        }
                    }
                    .padding(.top, 2)
                    .padding(.bottom, Self.contentInset)
                    .fixedSize(horizontal: false, vertical: true)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { subtasksHeight = $0 }
                    .modifier(RevealHeight(progress: isExpanded ? 1 : 0, fullHeight: subtasksHeight))
                    .allowsHitTesting(isExpanded)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                        .fill(theme.surfaceColor)
                    
                    RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                        .fill(categoryGradient)
                    
                    if isCurrentlyActiveNow {
                        RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                            .strokeBorder(theme.primaryColor.opacity(0.85), lineWidth: 1.5)
                    } else if gradientEnabled, let category = task.category {
                        RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color(hex: category.color).opacity(0.35),
                                        Color(hex: category.color).opacity(0.08)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1
                            )
                    } else {
                        RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                            .strokeBorder(theme.borderColor.opacity(0.4), lineWidth: 1)
                    }
                }
                .shadow(
                    color: isCurrentlyActiveNow ? theme.primaryColor.opacity(0.25) : theme.shadowColor,
                    radius: isCurrentlyActiveNow ? 6 : 5,
                    x: 0,
                    y: 2
                )
            )
            .overlay(alignment: .topTrailing) {
                // Names the accent border: this task is happening right now.
                if isCurrentlyActiveNow {
                    Text("task_in_progress_now".localized)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(theme.primaryColor))
                        .offset(x: -22, y: -8)
                }
            }
            .offset(x: dragOffset)
            .scaleEffect(deleteScale)
            .opacity(deleteOpacity)
        }
        .id(task.id)
        .contentShape(Rectangle())

        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    if !isHorizontalSwipe {
                        let isDefinitelyHorizontal = abs(value.translation.width) > abs(value.translation.height) * 1.5
                            && abs(value.translation.width) > 12
                        isHorizontalSwipe = isDefinitelyHorizontal
                    }
                    guard isHorizontalSwipe else { return }
                    let translation = value.translation.width
                    if translation < 0 {
                        dragOffset = max(translation, maxSwipeDistance)
                    }
                }
                .onEnded { value in
                    defer { isHorizontalSwipe = false }
                    guard isHorizontalSwipe else { return }
                    let translation = value.translation.width
                    let velocity = value.velocity.width
                    if translation < -60 || velocity < -500 {
                        viewModel.setOpenSwipeTask(task.id)
                        withAnimation(.interpolatingSpring(stiffness: 400, damping: 30)) {
                            dragOffset = -180
                        }
                    } else {
                        resetSwipe()
                    }
                }
        )

        .onChange(of: viewModel.isSwipeMenuOpen(for: task.id)) { _, isOpen in
            if !isOpen && dragOffset != 0 {
                resetSwipe()
            }
        }
        .onTapGesture {
            if dragOffset != 0 {
                resetSwipe()
            } else {
                UIApplication.shared.dismissKeyboard()
                showingDetailView = true
            }
        }
        .sheet(isPresented: $showingPlanSheet) {
            PlanInboxItemSheet(task: task)
        }
        .sheet(isPresented: $showingEditSheet) {
            TaskFormView(initialTask: task, onSave: { updatedTask in
                Task {
                    await TaskManager.shared.updateTask(updatedTask)
                }
            })
        }
        .fullScreenCover(isPresented: $showingPomodoro) {
            NavigationStack {
                PomodoroTabView()
            }
        }
        .sheet(isPresented: $showingDetailView) {
            NavigationStack {
                TaskDetailView(taskId: task.id, targetDate: viewModel.selectedDate)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingTrackingModeSelection) {
            TrackingModeSelectionView(task: task) { mode in
                selectedTrackingMode = mode
                if mode == .pomodoro {
                    PomodoroViewModel.shared.setActiveTask(task)
                    showingPomodoro = true
                } else {
                    showingTimeTracker = true
                }
            }
        }
        .sheet(isPresented: $showingTimeTracker) {
            NavigationStack {
                TimeTrackerView(
                    task: task,
                    mode: selectedTrackingMode,
                    taskManager: TaskManager.shared,
                    presentationStyle: .sheet,
                    allowExpand: false
                )
            }
            .presentationDetents(TimeTrackerViewModel.shared.showingCompletion ? [.large] : [.height(410), .medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onReceive(NotificationCenter.default.publisher(for: .startPomodoroFromTracking)) { notification in
            if let receivedTask = notification.object as? TodoTask, receivedTask.id == task.id {
                showingPomodoro = true
            }
        }
    }

    private func resetSwipe() {
        if viewModel.isSwipeMenuOpen(for: task.id) {
            viewModel.setOpenSwipeTask(nil)
        }
        withAnimation(.interpolatingSpring(stiffness: 400, damping: 35)) {
            dragOffset = 0
        }
    }

    private func deleteTaskWithAnimation() {
        guard !isDeleting else { return }
        
        isDeleting = true
        resetSwipe()
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
            deleteOpacity = 0.0
            deleteScale = 0.85
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            Task {
                await TaskManager.shared.removeTask(task)
            }
        }
    }
}

private struct BrainDumpButton: View {
    @Binding var isShowingBrainDump: Bool
    @Environment(\.theme) private var theme
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.interpolatingSpring(stiffness: 600, damping: 25)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.interpolatingSpring(stiffness: 600, damping: 25)) {
                    isPressed = false
                }
                isShowingBrainDump = true
            }
        }) {
            Image(systemName: "sparkles")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(theme.primaryColor)
                .frame(width: 52, height: 52)
                .background(
                    ZStack {
                        Circle()
                            .fill(theme.surfaceColor)
                        Circle()
                            .strokeBorder(theme.primaryColor.opacity(0.4), lineWidth: 1.5)
                    }
                    .shadow(
                        color: theme.shadowColor,
                        radius: 6,
                        x: 0,
                        y: 3
                    )
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .animation(.interpolatingSpring(stiffness: 600, damping: 25), value: isPressed)
        }
        .buttonStyle(BorderlessButtonStyle())
    }
}

private struct AddTaskButton: View {
    @Binding var isShowingTaskForm: Bool
    var timeScope: TaskTimeScope = .today
    @Environment(\.theme) private var theme
    @State private var isPressed = false
    
    var body: some View {
        Button(action: { 
            withAnimation(.interpolatingSpring(stiffness: 600, damping: 25)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.interpolatingSpring(stiffness: 600, damping: 25)) {
                    isPressed = false
                }
                isShowingTaskForm = true
            }
        }) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(theme.backgroundColor)
                .frame(width: 56, height: 56)
                .background(
                    ZStack {
                        Circle()
                            .fill(theme.gradient)
                        Circle()
                            .fill(theme.primaryColor.opacity(0.3))
                            .blur(radius: 8)
                            .scaleEffect(1.2)

                        
                        Circle()
                            .fill(theme.gradient)
                    }
                    .shadow(
                        color: theme.shadowColor,
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .animation(.interpolatingSpring(stiffness: 600, damping: 25), value: isPressed)
        }
        .buttonStyle(BorderlessButtonStyle())
    }
}

/// Reveals content from the top by animating its layout height (not just its rendering),
/// so containers such as List rows resize in step with the animation.
private struct RevealHeight: ViewModifier, Animatable {
    var progress: CGFloat
    let fullHeight: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .opacity(Double(min(1, progress * 1.5)))
            .frame(height: fullHeight * progress, alignment: .top)
            .clipped()
    }
}

private struct TimelineSubtaskRow: View {
    let subtask: Subtask
    let isCompleted: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    onToggle()
                }
            }) {
                SubtaskCheckmark(isCompleted: isCompleted)
            }
            .buttonStyle(BorderlessButtonStyle())
            .contentShape(Rectangle())
            .frame(width: 32, height: 32)
            
            Text(subtask.name)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.leading, 16)
    }
}

struct CompactTimelineTaskView: View {
    let task: TodoTask
    @ObservedObject var viewModel: TimelineViewModel
    @State private var showingDetailView = false
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    
    private var isCompleted: Bool {
        let completionDate = task.completionKey(for: viewModel.selectedDate)
        if let completion = task.completions[completionDate] {
            return completion.isCompleted
        }
        return false
    }
    
    private var subtaskProgress: (completed: Int, total: Int)? {
        guard !task.subtasks.isEmpty else { return nil }
        let completed = task.subtasks.filter { $0.isCompleted }.count
        return (completed, task.subtasks.count)
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Button(action: {
                if !isCompleted {
                    HapticManager.shared.notification(.success)
                } else {
                    HapticManager.shared.selection()
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.toggleTaskCompletion(task.id)
                }
            }) {
                ZStack {
                    Circle()
                        .fill(isCompleted ? theme.primaryColor.opacity(0.2) : theme.surfaceColor)
                        .frame(width: 26, height: 26)
                    
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isCompleted ? theme.primaryColor : theme.secondaryTextColor)
                        .font(.system(size: 19, weight: .medium))
                }
            }
            .buttonStyle(BorderlessButtonStyle())
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if let category = task.category {
                        Circle()
                            .fill(Color(hex: category.color))
                            .frame(width: 7, height: 7)
                    }
                    
                    Text(task.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isCompleted ? theme.secondaryTextColor : theme.textColor)
                        .strikethrough(isCompleted, color: theme.secondaryTextColor)
                        .lineLimit(1)
                }
                
                if let description = task.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(theme.secondaryTextColor)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                if let subtasks = subtaskProgress {
                    HStack(spacing: 2) {
                        Image(systemName: "checklist")
                            .font(.system(size: 9))
                        Text("\(subtasks.completed)/\(subtasks.total)")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(theme.secondaryTextColor)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(theme.surfaceColor)
                    )
                }
                
                if task.priority == .high {
                    Image(systemName: task.priority.icon)
                        .foregroundColor(Color(hex: task.priority.color))
                        .font(.system(size: 11))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.surfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(theme.borderColor.opacity(0.6), lineWidth: 1)
                )
                .shadow(color: theme.shadowColor, radius: 1, x: 0, y: 1)
        )
        .opacity(isCompleted ? 0.65 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            showingDetailView = true
        }
        .contextMenu {
            Button {
                HapticManager.shared.selection()
                viewModel.toggleTaskCompletion(task.id)
            } label: {
                Label(isCompleted ? "Segna da completare" : "Segna come completata", systemImage: isCompleted ? "circle" : "checkmark.circle")
            }

            Button {
                HapticManager.shared.selection()
                viewModel.moveTaskToTomorrow(task)
            } label: {
                Label("Sposta a domani", systemImage: "arrow.right.circle")
            }

            Button {
                HapticManager.shared.selection()
                viewModel.duplicateTask(task)
            } label: {
                Label("Duplica", systemImage: "plus.square.on.square")
            }

            Divider()

            Button(role: .destructive) {
                HapticManager.shared.impact(.medium)
                viewModel.deleteTask(task)
            } label: {
                Label("Elimina", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showingDetailView) {
            NavigationStack {
                TaskDetailView(taskId: task.id, targetDate: viewModel.selectedDate)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}

extension TaskTimeScope {
    /// Name in the timeline scope menu. The day scope reads "Day" (like Week/Month/Year):
    /// the title next to it already says Today or the date, so repeating it wasted the room
    /// the title needs, and it was wrong while looking at another day.
    var timelineMenuName: String {
        self == .today ? "day".localized : displayName
    }

    /// SwiftUI color for `color` (a plain name, not an asset: `Color("blue")` rendered nothing).
    var tint: Color {
        switch self {
        case .today: return .blue
        case .week: return .green
        case .month: return .orange
        case .year: return .purple
        case .longTerm: return .pink
        case .inbox: return .indigo
        case .all: return .teal
        }
    }
}
