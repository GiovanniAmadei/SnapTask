import SwiftUI
import Combine

struct TimelineView: View {
    @StateObject var viewModel: TimelineViewModel
    @State private var showingNewTask = false
    @State private var selectedDayOffset = 0
    @State private var showingCalendarPicker = false
    @State private var scrollProxy: ScrollViewProxy?
    
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
                    .background(Color(.systemBackground))
                    .zIndex(1)
                    
                    ViewControlBarView(viewModel: viewModel)
                        .background(Color(.systemBackground))
                        .zIndex(1)
                    
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
            .navigationBarHidden(true)
            .sheet(isPresented: $showingNewTask) {
                TaskFormView(
                    initialDate: viewModel.selectedDate,
                    onSave: { task in
                        viewModel.addTask(task)
                    }
                )
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
            return .secondary
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // View mode toggle - CHANGE: Fixed layout for iPhone 13 mini
            HStack(spacing: 2) {
                ForEach(TimelineViewMode.allCases, id: \.self) { mode in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.viewMode = mode
                        }
                    }) {
                        HStack(spacing: 2) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 10))
                            Text(mode == .list ? "List" : "Time")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(viewModel.viewMode == mode ? .white : .pink)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(viewModel.viewMode == mode ? Color.pink : Color.clear)
                        )
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.pink.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.pink.opacity(0.2), lineWidth: 1)
                    )
            )
            
            Spacer()
            
            // Organization status - CHANGE: Made more compact
            HStack(spacing: 4) {
                Image(systemName: viewModel.organization.icon)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Text(viewModel.organizationStatusText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.1))
            )
            
            // Sync status indicator
            if cloudKitService.isCloudKitEnabled {
                HStack(spacing: 2) {
                    if cloudKitService.isSyncing {
                        ProgressView()
                            .scaleEffect(0.5)
                    } else {
                        Image(systemName: syncStatusIcon)
                            .font(.system(size: 10))
                            .foregroundColor(syncStatusColor)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(syncStatusColor.opacity(0.1))
                )
            }
            
            // Organization button
            Button(action: {
                viewModel.showingFilterSheet = true
            }) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 18))
                    .foregroundColor(.pink)
            }
            
            // Reset view button (if organization is active)
            if viewModel.organization != .none {
                Button(action: {
                    viewModel.resetView()
                }) {
                    Image(systemName: "arrow.clockwise.circle")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct TimelineContentView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @State private var scrollProxy: ScrollViewProxy?
    
    private let hourHeight: CGFloat = 80
    
    private var allDayTasks: [TodoTask] {
        return viewModel.tasksForSelectedDate().filter { !$0.hasSpecificTime }
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if !allDayTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("All Day")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .padding(.horizontal)
                                Spacer()
                            }
                            
                            ForEach(allDayTasks, id: \.id) { task in
                                CompactTimelineTaskView(task: task, viewModel: viewModel)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.05))
                        
                        Divider()
                            .padding(.horizontal)
                    }
                    
                    // Existing hourly timeline
                    ForEach(viewModel.effectiveStartHour...viewModel.effectiveEndHour, id: \.self) { hour in
                        TimelineHourRow(
                            hour: hour,
                            tasks: tasksForHour(hour),
                            viewModel: viewModel
                        )
                        .id(hour)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .onAppear {
                scrollProxy = proxy
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    scrollToRelevantTime()
                }
            }
        }
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
    
    private func scrollToRelevantTime() {
        guard let proxy = scrollProxy else { return }
        
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: Date())
        
        if viewModel.isToday {
            withAnimation(.easeInOut(duration: 0.5)) {
                proxy.scrollTo(currentHour, anchor: .top)
            }
        } else {
            let tasks = viewModel.tasksForSelectedDate().filter { $0.hasSpecificTime }
            if let firstTask = tasks.first {
                let firstTaskHour = calendar.component(.hour, from: firstTask.startTime)
                withAnimation(.easeInOut(duration: 0.5)) {
                    proxy.scrollTo(firstTaskHour, anchor: .top)
                }
            }
        }
    }
}

struct TimelineHeaderView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @Binding var selectedDayOffset: Int
    @Binding var showingCalendarPicker: Bool
    @Binding var scrollProxy: ScrollViewProxy?
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(viewModel.monthYearString)
                    .font(.title2.bold())
                Spacer()
                Button(action: { showingCalendarPicker = true }) {
                    Image(systemName: "calendar")
                        .foregroundColor(.pink)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            DateSelectorView(
                viewModel: viewModel,
                selectedDayOffset: $selectedDayOffset,
                scrollProxy: $scrollProxy
            )
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
                                withAnimation {
                                    selectedDayOffset = offset
                                    viewModel.selectDate(offset)
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    
                                    proxy.scrollTo(offset, anchor: .center)
                                }
                            }
                            .id(offset)
                            .scaleEffect(offset == selectedDayOffset ? 1.08 : 1.0)
                            .animation(.spring(response: 0.3), value: offset == selectedDayOffset)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                }
                .onAppear {
                    scrollProxy = proxy
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo(selectedDayOffset, anchor: .center)
                        }
                    }
                }
                .onChange(of: selectedDayOffset) { _, newValue in
                    withAnimation {
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
                                
                                withAnimation {
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
                                    withAnimation {
                                        selectedDayOffset = newOffset
                                        viewModel.selectDate(newOffset)
                                        proxy.scrollTo(newOffset, anchor: .center)
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                } else {
                                    withAnimation {
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
    @State private var showingActivePomodoroSession = false
    
    var body: some View {
        ZStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    switch viewModel.organizedTasksForSelectedDate() {
                    case .single(let tasks):
                        ForEach(tasks.indices, id: \.self) { index in
                            TimelineTaskCard(
                                task: tasks[index],
                                onToggleComplete: { viewModel.toggleTaskCompletion(tasks[index].id) },
                                onToggleSubtask: { subtaskId in
                                    viewModel.toggleSubtask(taskId: tasks[index].id, subtaskId: subtaskId)
                                },
                                viewModel: viewModel
                            )
                            .padding(.horizontal, 4)
                            .padding(.top, index == 0 ? 8 : 0)
                        }
                    
                    case .sections(let sections):
                        ForEach(sections) { section in
                            OrganizedTaskSection(
                                section: section,
                                viewModel: viewModel
                            )
                            .padding(.horizontal, 4)
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 100)
            }
            
            VStack {
                Spacer()
                
                VStack(spacing: 0) {
                    if pomodoroViewModel.hasActiveTask {
                        MiniPomodoroWidget(viewModel: pomodoroViewModel) {
                            showingActivePomodoroSession = true
                        }
                        .padding(.bottom, 10)
                        .zIndex(1)
                    }
                    
                    AddTaskButton(isShowingTaskForm: $showingNewTask)
                }
                .padding(.bottom, 16)
            }
        }
        .sheet(isPresented: $showingActivePomodoroSession) {
            if pomodoroViewModel.activeTask != nil {
                NavigationStack {
                    PomodoroView(task: pomodoroViewModel.activeTask!)
                }
            }
        }
    }
}

struct OrganizedTaskSection: View {
    let section: TaskSection
    @ObservedObject var viewModel: TimelineViewModel
    
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
                        .foregroundColor(section.color.map { Color(hex: $0) } ?? .secondary)
                }
                
                Text(section.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(section.tasks.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(section.color.map { Color(hex: $0).opacity(0.2) } ?? Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
            
            ForEach(section.tasks.indices, id: \.self) { index in
                TimelineTaskCard(
                    task: section.tasks[index],
                    onToggleComplete: { viewModel.toggleTaskCompletion(section.tasks[index].id) },
                    onToggleSubtask: { subtaskId in
                        viewModel.toggleSubtask(taskId: section.tasks[index].id, subtaskId: subtaskId)
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
                
                Button("Done") {
                    let calendar = Calendar.current
                    let today = Date()
                    if let daysDiff = calendar.dateComponents([.day], from: today, to: selectedDate).day {
                        withAnimation {
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
                .foregroundColor(isSelected ? .white : (isToday ? .pink : .secondary))
            
            Text(dayNumber)
                .font(.callout)
                .fontWeight(.bold)
                .foregroundColor(isSelected ? .white : (isToday ? .pink : .primary))
        }
        .frame(width: 45, height: 60)
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ?
                    AnyShapeStyle(
                        LinearGradient(
                            colors: [.pink, .pink.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    ) :
                    (isToday ?
                        AnyShapeStyle(Color.pink.opacity(0.1)) :
                        AnyShapeStyle(Color.clear)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isSelected ? Color.clear : (isToday ? Color.pink.opacity(0.3) : Color.gray.opacity(0.2)),
                            lineWidth: 1)
        )
        .onTapGesture {
            action(offset)
        }
    }
    
    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).lowercased()
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
    @State private var offset: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme
    
    private var isCompleted: Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: viewModel.selectedDate)
        if let completion = task.completions[startOfDay] {
            return completion.isCompleted
        }
        return false
    }
    
    private var completionProgress: Double {
        guard !task.subtasks.isEmpty else { return isCompleted ? 1.0 : 0.0 }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: viewModel.selectedDate)
        let completion = task.completions[startOfDay]
        let completedCount = completion?.completedSubtasks.count ?? 0
        return Double(completedCount) / Double(task.subtasks.count)
    }
    
    private var completedSubtasks: Set<UUID> {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: viewModel.selectedDate)
        return task.completions[startOfDay]?.completedSubtasks ?? []
    }
    
    private var subtaskCountText: String {
        if task.subtasks.isEmpty { return "" }
        let completedCount = completedSubtasks.count
        let totalCount = task.subtasks.count
        return "\(completedCount)/\(totalCount)"
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
        
        while true {
            guard recurrence.shouldOccurOn(date: currentDate) else {
                currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate)!
                continue
            }
            
            if task.completions[currentDate]?.isCompleted == true {
                streak += 1
                currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate)!
            } else {
                break
            }
        }
        
        return streak
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            HStack(spacing: 4) {
                Spacer()
                
                Button(action: {
                    showingEditSheet = true
                    withAnimation(.spring()) {
                        offset = 0
                    }
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue, Color.blue.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 60, height: 50)
                            .shadow(color: Color.blue.opacity(0.2), radius: 2, x: 0, y: 1)
                        
                        VStack(spacing: 2) {
                            Image(systemName: "pencil")
                                .font(.system(size: 16, weight: .semibold))
                            Text("edit".localized)
                                .font(.system(.caption2, design: .rounded).bold())
                        }
                        .foregroundColor(.white)
                    }
                }
                
                Button(action: {
                    withAnimation(.spring()) {
                        TaskManager.shared.removeTask(task)
                        offset = 0
                    }
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [Color.red, Color.red.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 60, height: 50)
                            .shadow(color: Color.red.opacity(0.2), radius: 2, x: 0, y: 1)
                        
                        VStack(spacing: 2) {
                            Image(systemName: "trash")
                                .font(.system(size: 16, weight: .semibold))
                            Text("delete".localized)
                                .font(.system(.caption2, design: .rounded).bold())
                        }
                        .foregroundColor(.white)
                    }
                }
            }
            .padding(.trailing, 8)
            .frame(maxWidth: .infinity, minHeight: 60)
            .opacity(offset < -20 ? 1 : 0)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .center, spacing: 8) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    task.category.map { Color(hex: $0.color) } ?? .gray,
                                    task.category.map { Color(hex: $0.color).opacity(0.7) } ?? .gray.opacity(0.7)
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
                                .foregroundColor(.primary)
                            
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
                                VStack {
                                    if task.description != nil {
                                        Spacer()
                                    }
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                                    if task.description != nil {
                                        Spacer()
                                    }
                                }
                            }
                        }
                        
                        if let description = task.description {
                            Text(description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer()
                    
                    if task.hasDuration && task.duration > 0 {
                        Text(task.duration.formatted())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if task.hasSpecificTime {
                        let calendar = Calendar.current
                        let hour = calendar.component(.hour, from: task.startTime)
                        let minute = calendar.component(.minute, from: task.startTime)
                        Text(String(format: "%02d:%02d", hour, minute))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                    } else {
                        Text("All Day")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    // Priority indicator
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
                                    .fill(Color.accentColor.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                    
                                Image(systemName: "timer")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(task.category.map { Color(hex: $0.color) } ?? .accentColor)
                            }
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.accentColor.opacity(0.5), lineWidth: 1)
                            )
                            .shadow(color: Color.accentColor.opacity(0.2), radius: 2, x: 0, y: 1)
                        }
                    }
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            onToggleComplete()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                                .frame(width: 32, height: 32)
                            
                            if !task.subtasks.isEmpty {
                                Circle()
                                    .trim(from: 0, to: completionProgress)
                                    .stroke(Color.pink, lineWidth: 3)
                                    .frame(width: 32, height: 32)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: completionProgress)
                            }
                            
                            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isCompleted ? .green : .gray)
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
                RoundedRectangle(cornerRadius: 14)
                    .fill(colorScheme == .dark ? Color(.systemGray6) : .white)
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            )
            .offset(x: offset)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { gesture in
                    if abs(gesture.translation.width) > abs(gesture.translation.height) * 1.5 {
                        withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.8)) {
                            if gesture.translation.width <= 0 {
                                offset = max(-140, gesture.translation.width)
                            } else if offset < 0 {
                                offset = min(0, offset + gesture.translation.width)
                            }
                        }
                    }
                }
                .onEnded { gesture in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        if offset < -40 {
                            offset = -140
                        } else {
                            offset = 0
                        }
                    }
                }
        )
        .onTapGesture {
            if offset < 0 {
                withAnimation(.spring()) {
                    offset = 0
                }
            } else if !task.subtasks.isEmpty {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.6, maximumDistance: 10)
                .onEnded { _ in
                    showingDetailView = true
                }
        )
        .sheet(isPresented: $showingEditSheet) {
            TaskFormView(initialTask: task, onSave: { updatedTask in
                TaskManager.shared.updateTask(updatedTask)
            })
        }
        .sheet(isPresented: $showingPomodoro) {
            PomodoroView(task: task)
        }
        .fullScreenCover(isPresented: $showingDetailView) {
            NavigationStack {
                TaskDetailView(task: task)
            }
        }
    }
    
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

private struct AddTaskButton: View {
    @Binding var isShowingTaskForm: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: { isShowingTaskForm = true }) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.pink, Color.pink.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        Circle()
                            .fill(Color.pink.opacity(0.3))
                            .blur(radius: 8)
                            .scaleEffect(1.2)
                        
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.pink, Color.pink.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .shadow(
                        color: Color.pink.opacity(0.3),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                )
        }
        .padding(.horizontal, 20)
    }
}

private struct TimelineSubtaskRow: View {
    let subtask: Subtask
    let isCompleted: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack {
            Button(action: {
                withAnimation(.none) {
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
                .foregroundColor(isCompleted ? .secondary : .primary)
            
            Spacer()
        }
        .padding(.leading, 16)
    }
}

struct TimelineHourRow: View {
    let hour: Int
    let tasks: [TodoTask]
    @ObservedObject var viewModel: TimelineViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    private var isCurrentHour: Bool {
        viewModel.isToday && Calendar.current.component(.hour, from: Date()) == hour
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 4) {
                Text(hourString)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundColor(isCurrentHour ? .pink : .secondary)
                
                if isCurrentHour {
                    Circle()
                        .fill(Color.pink)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: 50)
            
            VStack(spacing: 0) {
                Rectangle()
                    .fill(isCurrentHour ? Color.pink.opacity(0.3) : Color.gray.opacity(0.2))
                    .frame(width: 2, height: tasks.isEmpty ? 60 : CGFloat(max(60, tasks.count * 80)))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                if tasks.isEmpty {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.clear)
                        .frame(height: 60)
                } else {
                    ForEach(tasks, id: \.id) { task in
                        CompactTimelineTaskView(task: task, viewModel: viewModel)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
    
    private var hourString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
}

struct CompactTimelineTaskView: View {
    let task: TodoTask
    @ObservedObject var viewModel: TimelineViewModel
    @State private var showingPomodoro = false
    @State private var showingEditSheet = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var isCompleted: Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: viewModel.selectedDate)
        if let completion = task.completions[startOfDay] {
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
        HStack(spacing: 8) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.toggleTaskCompletion(task.id)
                }
            }) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isCompleted ? .green : .gray)
                    .font(.system(size: 18))
            }
            .buttonStyle(BorderlessButtonStyle())
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    if let category = task.category {
                        Circle()
                            .fill(Color(hex: category.color))
                            .frame(width: 6, height: 6)
                    }
                    
                    Text(task.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Priority indicator
                    Image(systemName: task.priority.icon)
                        .foregroundColor(Color(hex: task.priority.color))
                        .font(.system(size: 12))
                    
                    if task.hasSpecificTime {
                        Text(taskTime)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                    } else {
                        Text("All Day")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                if let description = task.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            if task.pomodoroSettings != nil {
                Button(action: {
                    PomodoroViewModel.shared.setActiveTask(task)
                    showingPomodoro = true
                }) {
                    Image(systemName: "timer")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Color.pink)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(colorScheme == .dark ? Color(.systemGray6) : .white)
                .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
        )
        .opacity(isCompleted ? 0.6 : 1.0)
        .sheet(isPresented: $showingPomodoro) {
            PomodoroView(task: task)
        }
    }
}
