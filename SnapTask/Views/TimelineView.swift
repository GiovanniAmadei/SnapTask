import SwiftUI
import Combine

struct TimelineView: View {
    @StateObject var viewModel: TimelineViewModel
    @State private var showingNewTask = false
    @State private var selectedDayOffset = 0
    @State private var showingCalendarPicker = false
    @State private var scrollProxy: ScrollViewProxy?
    @Environment(\.theme) private var theme
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Header con mese e selettore data
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
                    
                    ViewControlBarView(viewModel: viewModel)
                        .themedSurface()
                        .zIndex(1)
                    
                    // Subtle divider between controls and content
                    Divider()
                        .padding(.horizontal)
                        .foregroundColor(theme.borderColor)
                    
                    if viewModel.viewMode == .timeline {
                        TimelineContentView(viewModel: viewModel)
                            .frame(maxHeight: .infinity)
                    } else {
                        TaskListView(
                            viewModel: viewModel,
                            showingNewTask: $showingNewTask
                        )
                        .frame(maxHeight: .infinity)
                    }
                }
            }
            .themedBackground()
            .navigationBarHidden(true)
            .sheet(isPresented: $showingNewTask) {
                TaskCreationOptionsView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingCalendarPicker) {
                CalendarPickerView(
                    selectedDate: $viewModel.selectedDate,
                    selectedDayOffset: $selectedDayOffset,
                    viewModel: viewModel,
                    scrollProxy: scrollProxy
                )
            }
            .sheet(isPresented: $viewModel.showingFilterSheet) {
                TimelineOrganizationView(viewModel: viewModel)
            }
        }
    }
}

struct ViewControlBarView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @StateObject private var cloudKitService = CloudKitService.shared
    @Environment(\.theme) private var theme
    
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
                ForEach(TimelineViewMode.allCases, id: \.self) { mode in
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
            
            Spacer()
            
            // Organization status - themed
            HStack(spacing: 4) {
                Image(systemName: viewModel.organization.icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.secondaryTextColor)
                
                Text(viewModel.organizationStatusText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.secondaryTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(theme.surfaceColor)
            )
            
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
            
            // Reset button - themed
            if viewModel.organization != .none {
                Button(action: {
                    viewModel.resetView()
                }) {
                    Image(systemName: "arrow.clockwise.circle")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(theme.secondaryTextColor)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(theme.surfaceColor)
                        )
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

struct TimelineContentView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @StateObject private var cloudKitService = CloudKitService.shared
    @State private var scrollProxy: ScrollViewProxy?
    @State private var isRefreshing = false
    @Environment(\.theme) private var theme
    
    private let hourHeight: CGFloat = 80
    
    private var allDayTasks: [TodoTask] {
        return viewModel.tasksForSelectedDate().filter { !$0.hasSpecificTime }
    }
    
    private var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }
    
    private var currentMinute: Int {
        Calendar.current.component(.minute, from: Date())
    }
    
    private var timelineRange: ClosedRange<Int> {
        let tasks = viewModel.tasksForSelectedDate().filter { $0.hasSpecificTime }
        
        if tasks.isEmpty {
            // If no tasks, show around current time or reasonable default
            if viewModel.isToday {
                return max(0, currentHour - 2)...min(23, currentHour + 8)
            } else {
                return 8...20 // Default business hours
            }
        }
        
        let taskHours = tasks.map { Calendar.current.component(.hour, from: $0.startTime) }
        let minHour = taskHours.min() ?? 8
        let maxHour = taskHours.max() ?? 20
        
        // Expand range slightly for context
        let startHour = max(0, minHour - 1)
        let endHour = min(23, maxHour + 2)
        
        // If viewing today, include current hour in range
        if viewModel.isToday {
            let expandedStart = min(startHour, max(0, currentHour - 1))
            let expandedEnd = max(endHour, min(23, currentHour + 2))
            return expandedStart...expandedEnd
        }
        
        return startHour...endHour
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if !allDayTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("all_day".localized)
                                    .font(.headline)
                                    .foregroundColor(theme.textColor)
                                Spacer()
                            }
                            
                            ForEach(allDayTasks, id: \.id) { task in
                                CompactTimelineTaskView(task: task, viewModel: viewModel)
                            }
                        }
                        .padding(.vertical, 12)
                        .background(theme.primaryColor.opacity(0.05))
                        
                        Divider()
                            .padding(.horizontal)
                            .foregroundColor(theme.borderColor)
                    }
                    
                    ForEach(Array(timelineRange), id: \.self) { hour in
                        EnhancedTimelineHourRow(
                            hour: hour,
                            tasks: tasksForHour(hour),
                            viewModel: viewModel,
                            isCurrentHour: viewModel.isToday && currentHour == hour,
                            currentMinute: viewModel.isToday && currentHour == hour ? currentMinute : nil,
                            nextTaskHour: nextTaskHour(after: hour),
                            isLastHour: hour == timelineRange.upperBound
                        )
                        .id(hour)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .refreshable {
                await performCloudKitSync()
            }
            .onAppear {
                scrollProxy = proxy
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation {
                        proxy.scrollTo(currentHour, anchor: .center)
                    }
                }
            }
        }
    }
    
    private func nextTaskHour(after hour: Int) -> Int? {
        let tasks = viewModel.tasksForSelectedDate().filter { $0.hasSpecificTime }
        let futureTaskHours = tasks
            .map { Calendar.current.component(.hour, from: $0.startTime) }
            .filter { $0 > hour }
            .sorted()
        
        return futureTaskHours.first
    }
    
    private func tasksForHour(_ hour: Int) -> [TodoTask] {
        let calendar = Calendar.current
        return viewModel.tasksForSelectedDate().filter { task in
            // Only include tasks with specific time for timeline view
            guard task.hasSpecificTime else { return false }
            let taskHour = calendar.component(.hour, from: task.startTime)
            return taskHour == hour
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
}

struct EnhancedTimelineHourRow: View {
    let hour: Int
    let tasks: [TodoTask]
    @ObservedObject var viewModel: TimelineViewModel
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    
    let isCurrentHour: Bool
    let currentMinute: Int?
    let nextTaskHour: Int?
    let isLastHour: Bool
    
    private var hasCurrentTask: Bool {
        !tasks.isEmpty
    }
    
    private var timeToNextTask: String? {
        guard let nextHour = nextTaskHour, !hasCurrentTask else { return nil }
        let hoursDiff = nextHour - hour
        
        if hoursDiff == 1 {
            return "next_task_in_1_hour".localized
        } else if hoursDiff > 1 {
            return String(format: "next_task_in_hours".localized, hoursDiff)
        }
        return nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // Time column with enhanced current time indicator
                VStack(spacing: 4) {
                    Text(hourString)
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(isCurrentHour ? .bold : .medium)
                        .foregroundColor(isCurrentHour ? theme.primaryColor : theme.secondaryTextColor)
                    
                    if isCurrentHour {
                        VStack(spacing: 2) {
                            Circle()
                                .fill(theme.primaryColor)
                                .frame(width: 10, height: 10)
                            
                            if let minute = currentMinute {
                                Text(String(format: "%02d", minute))
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(theme.primaryColor)
                                    .fontWeight(.bold)
                            }
                            
                            Text("NOW")
                                .font(.system(.caption2, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(theme.primaryColor)
                        }
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isCurrentHour)
                    }
                }
                .frame(width: 60)
                
                // Task content area with smart layout
                VStack(alignment: .leading, spacing: 8) {
                    if hasCurrentTask {
                        // Show tasks for this hour
                        ForEach(tasks, id: \.id) { task in
                            EnhancedTimelineTaskView(task: task, viewModel: viewModel)
                        }
                    } else {
                        // Show empty state with next task info
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isCurrentHour ? theme.primaryColor.opacity(0.08) : theme.surfaceColor)
                            .frame(height: 50)
                            .overlay(
                                VStack(spacing: 4) {
                                    if isCurrentHour && currentMinute != nil {
                                        // Current time indicator line
                                        HStack {
                                            Circle()
                                                .fill(theme.primaryColor)
                                                .frame(width: 6, height: 6)
                                            Rectangle()
                                                .fill(theme.primaryColor.opacity(0.6))
                                                .frame(height: 2)
                                            Spacer()
                                        }
                                    } else if let nextTaskInfo = timeToNextTask {
                                        Text(nextTaskInfo)
                                            .font(.system(.caption, design: .rounded))
                                            .foregroundColor(theme.secondaryTextColor)
                                            .fontWeight(.medium)
                                    }
                                }
                                .padding(.horizontal, 12)
                            )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    // Enhanced background for current hour
                    isCurrentHour ?
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.primaryColor.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(theme.primaryColor.opacity(0.2), lineWidth: 1.5)
                        )
                        .shadow(color: theme.shadowColor, radius: 4)
                    : nil
                )
            }
            .padding(.vertical, 6)
            
            // Connection line to next hour
            if !isLastHour {
                HStack {
                    Spacer()
                        .frame(width: 30)
                    
                    VStack(spacing: 0) {
                        if hasCurrentTask || nextTaskHour != nil {
                            // Animated connection line
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            isCurrentHour ? theme.primaryColor.opacity(0.6) : theme.borderColor,
                                            theme.borderColor.opacity(0.1)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 2, height: 20)
                        } else {
                            // Dotted line for empty periods
                            VStack(spacing: 2) {
                                ForEach(0..<4, id: \.self) { _ in
                                    Circle()
                                        .fill(theme.borderColor)
                                        .frame(width: 2, height: 2)
                                }
                            }
                        }
                        
                        Divider()
                            .background(
                                isCurrentHour ?
                                theme.primaryColor.opacity(0.4) :
                                theme.borderColor
                            )
                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    private var hourString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let date = Calendar.current.date(
            bySettingHour: hour,
            minute: 0,
            second: 0,
            of: Date()
        ) ?? Date()
        return formatter.string(from: date)
    }
}

struct EnhancedTimelineTaskView: View {
    let task: TodoTask
    @ObservedObject var viewModel: TimelineViewModel
    @State private var showingPomodoro = false
    @State private var showingDetailView = false
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("showCategoryGradients") private var gradientEnabled: Bool = true

    private var isCompleted: Bool {
        
        let completionDate = task.completionKey(for: viewModel.selectedDate)
        if let completion = task.completions[completionDate] {
            return completion.isCompleted
        }
        return false
    }

    private var taskTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: task.startTime)
    }

    private var timeUntilTask: String? {
        guard viewModel.isToday else { return nil }
        
        let now = Date()
        let timeInterval = task.startTime.timeIntervalSince(now)
        
        if timeInterval > 0 {
            let minutes = Int(timeInterval / 60)
            if minutes < 60 {
                return "in \(minutes)m"
            } else {
                let hours = minutes / 60
                return "in \(hours)h"
            }
        } else if timeInterval > -3600 { // Within last hour
            return "now"
        }
        
        return nil
    }

    private var categoryGradient: LinearGradient {
        if gradientEnabled, let category = task.category {
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
        HStack(spacing: 12) {
            // Completion button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.toggleTaskCompletion(task.id)
                }
            }) {
                ZStack {
                    Circle()
                        .fill(isCompleted ? theme.primaryColor.opacity(0.2) : theme.surfaceColor)
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isCompleted ? theme.primaryColor : theme.secondaryTextColor)
                        .font(.system(size: 20, weight: .medium))
                }
            }
            .buttonStyle(BorderlessButtonStyle())

            // Task content with shared leading column for category dot
            HStack(alignment: .top, spacing: 8) {
                // Leading dot column (fixed width)
                Group {
                    if let category = task.category {
                        Circle()
                            .fill(Color(hex: category.color))
                            .frame(width: 8, height: 8)
                    } else {
                        Color.clear.frame(width: 8, height: 8)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(isCompleted ? theme.secondaryTextColor : theme.textColor)

                    if let description = task.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(theme.secondaryTextColor)
                            .lineLimit(2)
                    }
                    
                    // Priority and Pomodoro indicators
                    HStack(spacing: 8) {
                        Image(systemName: task.priority.icon)
                            .foregroundColor(Color(hex: task.priority.color))
                            .font(.system(size: 12))
                        
                        if task.pomodoroSettings != nil {
                            Button(action: {
                                PomodoroViewModel.shared.setActiveTask(task)
                                showingPomodoro = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "timer")
                                        .font(.system(size: 10))
                                    Text("Focus")
                                        .font(.system(.caption2, design: .rounded))
                                }
                                .foregroundColor(theme.primaryColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(theme.primaryColor.opacity(0.15))
                                .cornerRadius(8)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        
                        Spacer()
                    }
                }
            }
            // Trailing time info overlay on the whole content row
            .overlay(
                VStack(alignment: .trailing, spacing: 2) {
                    Text(taskTime)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(theme.secondaryTextColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.surfaceColor)
                        .cornerRadius(4)
                    
                    if let timeInfo = timeUntilTask {
                        Text(timeInfo)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundColor(timeInfo == "now" ? .orange : theme.secondaryTextColor)
                            .fontWeight(.medium)
                    }
                }, alignment: .topTrailing
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.surfaceColor)
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(categoryGradient)
                
                if gradientEnabled, let category = task.category {
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
                }
            }
            .shadow(color: theme.shadowColor, radius: 2, x: 0, y: 1)
        )
        .opacity(isCompleted ? 0.7 : 1.0)
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
        .onTapGesture {
            showingDetailView = true
        }
    }
}

struct TimelineHeaderView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @Binding var selectedDayOffset: Int
    @Binding var showingCalendarPicker: Bool
    @Binding var scrollProxy: ScrollViewProxy?
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(spacing: 0) {
            // Fixed height header - sempre la stessa altezza
            VStack(spacing: 8) {
                HStack(alignment: .center) {
                    // Period text - flexible but not compressed
                    Text(viewModel.currentPeriodString)
                        .font(.title2.bold())
                        .themedPrimaryText()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .layoutPriority(1)
                    
                    Spacer(minLength: 8)
                    
                    // Navigation controls and menu - flexible layout
                    HStack(spacing: 8) {
                        // Navigation arrows (when needed)
                        if viewModel.selectedTimeScope != .today && viewModel.selectedTimeScope != .longTerm {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.navigateToPrevious()
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
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        viewModel.selectedTimeScope = scope
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: scope.icon)
                                            .foregroundColor(Color(scope.color))
                                            .font(.system(size: 14, weight: .medium))
                                        
                                        Text(scope.displayName)
                                            .font(.subheadline)
                                        
                                        Spacer()
                                        
                                        // Checkmark per opzione selezionata
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
                                Image(systemName: viewModel.selectedTimeScope.icon)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(viewModel.selectedTimeScope.color))
                                
                                Text(viewModel.selectedTimeScope.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .themedPrimaryText()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .medium))
                                    .themedSecondaryText()
                            }
                            .padding(.leading, 0)
                            .padding(.trailing, 4)
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
                        
                        // Calendar button (only for today)
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
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 60)
            
            // Date selector only for 'today' scope
            if viewModel.selectedTimeScope == .today {
                DateSelectorView(
                    viewModel: viewModel,
                    selectedDayOffset: $selectedDayOffset,
                    scrollProxy: $scrollProxy
                )
                .padding(.top, 4)
            }
        }
    }
}

struct DateSelectorView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @Binding var selectedDayOffset: Int
    @Binding var scrollProxy: ScrollViewProxy?
    @State private var isDragging = false
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
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
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    
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
                .onAppear {
                    scrollProxy = proxy
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(selectedDayOffset, anchor: .center)
                        }
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
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
}

struct TaskListView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @Binding var showingNewTask: Bool
    @StateObject private var pomodoroViewModel = PomodoroViewModel.shared
    @StateObject private var timeTrackerViewModel = TimeTrackerViewModel.shared
    @StateObject private var cloudKitService = CloudKitService.shared
    @State private var showingActivePomodoroSession = false
    @State private var showingGeneralPomodoroFullScreen = false
    @State private var showingActiveTimeTrackerSession = false
    @State private var selectedSessionId: UUID?
    @State private var isRefreshing = false
    @Environment(\.theme) private var theme
    
    var body: some View {
        ZStack {
            if viewModel.tasks.isEmpty {
                // Empty state
                VStack(spacing: 20) {
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
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        switch viewModel.organizedTasksForSelectedDate() {
                        case .single(let tasks):
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
                        
                        case .sections(let sections):
                            ForEach(sections) { section in
                                OrganizedTaskSection(
                                    section: section,
                                    viewModel: viewModel
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 100)
                    .padding(.top, 8)
                    .animation(.interpolatingSpring(stiffness: 300, damping: 30), value: viewModel.tasks.map { $0.id })
                }
                .refreshable {
                    await performCloudKitSync()
                }
                .onTapGesture {
                    viewModel.closeAllSwipeMenus()
                }
            }
            
            VStack {
                Spacer()
                
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
                                        showingActiveTimeTrackerSession = true
                                    }
                                )
                            }
                            
                            if pomodoroViewModel.hasActiveTask {
                                MiniPomodoroWidget(viewModel: pomodoroViewModel) {
                                    // Present on next run loop to stabilize presentation
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
                    .zIndex(1)
                    
                    AddTaskButton(
                        isShowingTaskForm: $showingNewTask,
                        timeScope: viewModel.selectedTimeScope
                    )
                }
                .padding(.bottom, 16)
            }
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
        .sheet(isPresented: $showingActiveTimeTrackerSession) {
            if let sessionId = selectedSessionId {
                NavigationStack {
                    TimeTrackerView(
                        sessionId: sessionId,
                        presentationStyle: .sheet
                    )
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
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
}

struct OrganizedTaskSection: View {
    let section: TaskSection
    @ObservedObject var viewModel: TimelineViewModel
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let color = section.color {
                    Circle()
                        .fill(Color(hex: color))
                        .frame(width: 12, height: 12)
                }
                
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
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}

private struct TimelineTaskCard: View {
    let task: TodoTask
    let onToggleComplete: () -> Void
    let onToggleSubtask: (UUID) -> Void
    @ObservedObject var viewModel: TimelineViewModel
    @State private var isExpanded = false
    @State private var showingPomodoro = false
    @State private var showingEditSheet = false
    @State private var showingDetailView = false
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

    private var isCompleted: Bool {
        
        let completionDate = task.completionKey(for: viewModel.selectedDate)
        if let completion = task.completions[completionDate] {
            return completion.isCompleted
        }
        return false
    }

    private var completionProgress: Double {
        guard !task.subtasks.isEmpty else { return isCompleted ? 1.0 : 0.0 }
        
        let completionDate = task.completionKey(for: viewModel.selectedDate)
        let completion = task.completions[completionDate]
        let completedCount = completion?.completedSubtasks.count ?? 0
        return Double(completedCount) / Double(task.subtasks.count)
    }

    private var completedSubtasks: Set<UUID> {
        
        let completionDate = task.completionKey(for: viewModel.selectedDate)
        return task.completions[completionDate]?.completedSubtasks ?? []
    }

    private var currentStreak: Int {
        guard let recurrence = task.recurrence else { return 0 }
        
        let selectedDate = viewModel.selectedDate.startOfDay
        
        var streak = 0
        var currentDate = selectedDate
        
        let isCompletedOnSelectedDate = task.completions[selectedDate]?.isCompleted == true
        
        if isCompletedOnSelectedDate {
            streak = 1
            currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate)!
        }
        
        // Limit iterations to prevent infinite loops (max 1000 days back)
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

    private let maxSwipeDistance: CGFloat = -210

    var body: some View {
        ZStack {
            // Background actions layer
            HStack(spacing: 0) {
                Spacer()
                
                HStack(spacing: 8) {
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
                    
                    Button(action: {
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
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    task.category.map { Color(hex: $0.color) } ?? theme.secondaryTextColor,
                                    task.category.map { Color(hex: $0.color).opacity(0.7) } ?? theme.secondaryTextColor.opacity(0.7)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 4)
                        .cornerRadius(2)
                        .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .center) {
                            Text(task.name)
                                .font(.headline)
                                .foregroundColor(theme.textColor)
                            
                            if task.recurrence != nil && currentStreak > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "flame.fill")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 12))
                                    Text("\(currentStreak)")
                                        .font(.system(.caption, design: .rounded).bold())
                                        .foregroundColor(.orange)
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.orange.opacity(0.15))
                                )
                            }
                            
                            Spacer()
                            
                            if !task.subtasks.isEmpty {
                                Button(action: {
                                    withAnimation(.interpolatingSpring(stiffness: 350, damping: 30)) {
                                        isExpanded.toggle()
                                    }
                                }) {
                                    VStack {
                                        if task.description != nil {
                                            Spacer()
                                        }
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 12))
                                            .foregroundColor(theme.secondaryTextColor)
                                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                                            .animation(.interpolatingSpring(stiffness: 400, damping: 25), value: isExpanded)
                                        if task.description != nil {
                                            Spacer()
                                        }
                                    }
                                    .frame(width: 24, height: 24)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(BorderlessButtonStyle())
                            }
                        }
                        .padding(.leading, 0)
                        
                        if let description = task.description {
                            Text(description)
                                .font(.subheadline)
                                .foregroundColor(theme.secondaryTextColor)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer()
                    
                    if task.timeScope == .today {
                        if task.hasSpecificTime {
                            let calendar = Calendar.current
                            let hour = calendar.component(.hour, from: task.startTime)
                            let minute = calendar.component(.minute, from: task.startTime)
                            Text(String(format: "%02d:%02d", hour, minute))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(theme.secondaryTextColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(theme.surfaceColor)
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
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                
                if isExpanded && !task.subtasks.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(task.subtasks) { subtask in
                            TimelineSubtaskRow(
                                subtask: subtask,
                                isCompleted: completedSubtasks.contains(subtask.id),
                                onToggle: { onToggleSubtask(subtask.id) }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(theme.surfaceColor)
                    
                    RoundedRectangle(cornerRadius: 14)
                        .fill(categoryGradient)
                    
                    if gradientEnabled, let category = task.category {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color(hex: category.color).opacity(0.25),
                                        Color(hex: category.color).opacity(0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                }
                .shadow(color: theme.shadowColor, radius: 5, x: 0, y: 2)
            )
            .offset(x: dragOffset)
            .scaleEffect(deleteScale)
            .opacity(deleteOpacity)
        }
        .id(task.id)
        .contentShape(Rectangle())

        .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    if !isHorizontalSwipe {
                        isHorizontalSwipe = abs(value.translation.width) > abs(value.translation.height) && abs(value.translation.width) > 8
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
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.6)
                .onEnded { _ in
                    if dragOffset != 0 {
                        resetSwipe()
                    } else {
                        showingDetailView = true
                    }
                }
        )
        .onTapGesture {
            if dragOffset != 0 {
                resetSwipe()
            } else {
                showingDetailView = true
            }
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
            .presentationDetents([.medium])
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
    @State private var showingPomodoro = false
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    
    private var isCompleted: Bool {
        
        let completionDate = task.completionKey(for: viewModel.selectedDate)
        if let completion = task.completions[completionDate] {
            return completion.isCompleted
        }
        return false
    }
    
    private var taskTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: task.startTime)
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.toggleTaskCompletion(task.id)
                }
            }) {
                ZStack {
                    Circle()
                        .fill(isCompleted ? theme.primaryColor.opacity(0.2) : theme.surfaceColor)
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isCompleted ? theme.primaryColor : theme.secondaryTextColor)
                        .font(.system(size: 20, weight: .medium))
                }
            }
            .buttonStyle(BorderlessButtonStyle())
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if let category = task.category {
                        Circle()
                            .fill(Color(hex: category.color))
                            .frame(width: 6, height: 6)
                    }
                    
                    Text(task.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(isCompleted ? theme.secondaryTextColor : theme.textColor)
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
            
            HStack(spacing: 8) {
                if task.hasSpecificTime {
                    Text(taskTime)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(theme.secondaryTextColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.surfaceColor)
                        .cornerRadius(4)
                }
                
                Image(systemName: task.priority.icon)
                    .foregroundColor(Color(hex: task.priority.color))
                    .font(.system(size: 12))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.surfaceColor)
                .shadow(color: theme.shadowColor, radius: 2, x: 0, y: 1)
        )
    }
}