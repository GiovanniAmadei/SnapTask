import SwiftUI
import MapKit
import Charts

struct TaskDetailView: View {
    let taskId: UUID
    private let fixedDate: Date  // FIXED DATE - never changes!
    let targetDate: Date?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var taskManager = TaskManager.shared
    @State private var localTask: TodoTask?
    @State private var showingEditSheet = false
    @State private var showingPomodoro = false
    @State private var showingTrackingModeSelection = false
    @State private var showingTimeTracker = false
    @State private var selectedTrackingMode: TrackingMode = .simple
    @State private var showingDurationPicker = false
    @State private var showingPerformanceChart = false
    
    private var effectiveDate: Date {
        let calendar = Calendar.current
        return calendar.startOfDay(for: fixedDate)
    }
    
    private var isCompleted: Bool {
        return localTask?.completions[effectiveDate]?.isCompleted == true
    }
    
    init(taskId: UUID, targetDate: Date? = nil) {
        self.taskId = taskId
        self.targetDate = targetDate
        // FIX: Store the EXACT date at initialization time - never changes!
        self.fixedDate = targetDate ?? Date()
    }
    
    var body: some View {
        Group {
            if let task = localTask {
                taskContent(task)
            } else {
                Text("Task not found")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Task Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Close") {
                    dismiss()
                }
                .foregroundColor(.pink)
            }
        }
        .onAppear {
            loadLocalTask()
        }
        .onChange(of: taskManager.tasks) { _, _ in
            updateLocalTaskFromManager()
        }
        .sheet(isPresented: $showingEditSheet) {
            if let task = localTask {
                TaskFormView(initialTask: task, onSave: { updatedTask in
                    TaskManager.shared.updateTask(updatedTask)
                })
            }
        }
        .sheet(isPresented: $showingPomodoro) {
            if let task = localTask {
                NavigationStack {
                    PomodoroView(task: task)
                }
            }
        }
        .sheet(isPresented: $showingTrackingModeSelection) {
            if let task = localTask {
                TrackingModeSelectionView(task: task) { mode in
                    selectedTrackingMode = mode
                    if mode == .pomodoro {
                        // For pomodoro mode, set active task and show pomodoro
                        PomodoroViewModel.shared.setActiveTask(task)
                        showingPomodoro = true
                    } else {
                        showingTimeTracker = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingTimeTracker) {
            if let task = localTask {
                NavigationStack {
                    TimeTrackerView(
                        task: task,
                        mode: selectedTrackingMode,
                        taskManager: TaskManager.shared,
                        presentationStyle: .sheet
                    )
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showingDurationPicker) {
            if let task = localTask {
                DurationPickerView(
                    duration: Binding(
                        get: { 
                            return task.completions[effectiveDate]?.actualDuration ?? 0 
                        },
                        set: { newDuration in
                            updateLocalTaskRating(actualDuration: newDuration, updateDuration: true)
                        }
                    )
                )
            }
        }
        .sheet(isPresented: $showingPerformanceChart) {
            if let task = localTask {
                TaskPerformanceChartView(task: task)
            }
        }
    }
    
    private func loadLocalTask() {
        if let managerTask = taskManager.tasks.first(where: { $0.id == taskId }) {
            localTask = managerTask
        }
    }
    
    private func updateLocalTaskFromManager() {
        if let managerTask = taskManager.tasks.first(where: { $0.id == taskId }) {
            // Only update if the manager task is newer
            if localTask == nil || managerTask.lastModifiedDate > (localTask?.lastModifiedDate ?? Date.distantPast) {
                localTask = managerTask
            }
        }
    }
    
    private func updateLocalTaskRating(actualDuration: TimeInterval? = nil, difficultyRating: Int? = nil, qualityRating: Int? = nil, notes: String? = nil, updateDuration: Bool = false, updateDifficulty: Bool = false, updateQuality: Bool = false, updateNotes: Bool = false) {
        guard var task = localTask else { return }
        
        // Get or create completion for this specific date
        var completion = task.completions[effectiveDate] ?? TaskCompletion(
            isCompleted: false,
            completedSubtasks: [],
            actualDuration: nil,
            difficultyRating: nil,
            qualityRating: nil,
            completionDate: nil,
            notes: nil
        )
        
        // Update only the fields explicitly requested
        if updateDuration {
            completion.actualDuration = actualDuration == 0 ? nil : actualDuration
        }
        
        if updateDifficulty {
            completion.difficultyRating = difficultyRating == 0 ? nil : difficultyRating
        }
        
        if updateQuality {
            completion.qualityRating = qualityRating == 0 ? nil : qualityRating
        }
        
        if updateNotes {
            completion.notes = notes?.isEmpty == true ? nil : notes
        }
        
        // Set completion date if not already set and this completion has any data
        if completion.completionDate == nil && (completion.actualDuration != nil || completion.difficultyRating != nil || completion.qualityRating != nil || completion.notes != nil) {
            completion.completionDate = Date()
        }
        
        // Update the completion in the local task
        task.completions[effectiveDate] = completion
        task.lastModifiedDate = Date()
        
        // Save to local state immediately
        localTask = task
        
        // FIXED: Use the correct method to save performance data
        if updateDuration {
            TaskManager.shared.updateTaskRating(
                taskId: task.id, 
                actualDuration: actualDuration, 
                for: effectiveDate
            )
        }
        
        if updateDifficulty {
            TaskManager.shared.updateTaskRating(
                taskId: task.id, 
                difficultyRating: difficultyRating, 
                for: effectiveDate
            )
        }
        
        if updateQuality {
            TaskManager.shared.updateTaskRating(
                taskId: task.id, 
                qualityRating: qualityRating, 
                for: effectiveDate
            )
        }
        
        if updateNotes {
            TaskManager.shared.updateTaskRating(
                taskId: task.id, 
                notes: notes, 
                for: effectiveDate
            )
        }
    }
    
    private func taskContent(_ task: TodoTask) -> some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    headerSection(task)
                    detailsSection(task)
                }
            }
            
            VStack {
                Spacer()
                actionButtons(task)
            }
        }
    }
    
    private func headerSection(_ task: TodoTask) -> some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                Image(systemName: task.icon)
                    .font(.system(size: 32))
                    .foregroundColor(.pink)
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .fill(Color.pink.opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.name)
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        if let category = task.category {
                            categoryInfo(category)
                        }
                        
                        priorityInfo(task)
                    }
                }
                
                Spacer()
                
                completionStatus
            }
        }
        .padding(20)
        .background(headerBackground)
        .padding(.horizontal)
        .padding(.top, 4)
    }
    
    private func categoryInfo(_ category: Category) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(hex: category.color))
                .frame(width: 8, height: 8)
            Text(category.name)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func priorityInfo(_ task: TodoTask) -> some View {
        HStack(spacing: 4) {
            Image(systemName: task.priority.icon)
                .font(.system(size: 10))
                .foregroundColor(Color(hex: task.priority.color))
            Text(task.priority.rawValue.capitalized)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var completionStatus: some View {
        Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 24))
            .foregroundColor(isCompleted ? .green : .gray)
    }
    
    private var headerBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color(.systemBackground))
            .shadow(
                color: colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.08),
                radius: colorScheme == .dark ? 0.5 : 12,
                x: 0,
                y: colorScheme == .dark ? 1 : 4
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        colorScheme == .dark ? .white.opacity(0.15) : .clear,
                        lineWidth: colorScheme == .dark ? 1 : 0
                    )
            )
    }
    
    private func detailsSection(_ task: TodoTask) -> some View {
        VStack(spacing: 16) {
            if let description = task.description, !description.isEmpty {
                descriptionCard(description)
            }
            
            if let location = task.location {
                locationCard(location)
            }
            
            scheduleCard(task)
            
            if let recurrence = task.recurrence {
                recurrenceCard(task, recurrence)
            }
            
            // Notes Card - Always visible
            notesCard(task)
            
            postCompletionInsightsCard(task)
            
            if !task.subtasks.isEmpty {
                subtasksCard(task)
            }
            
            if let pomodoroSettings = task.pomodoroSettings {
                pomodoroCard(task, pomodoroSettings)
            }
            
            if task.hasRewardPoints {
                rewardsCard(task)
            }
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 120)
    }
    
    private func descriptionCard(_ description: String) -> some View {
        DetailCard(icon: "doc.text", title: "Description", color: .blue) {
            Text(description)
                .font(.body)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func locationCard(_ location: TaskLocation) -> some View {
        DetailCard(icon: "location", title: "Location", color: .green) {
            VStack(alignment: .leading, spacing: 16) {
                // Map view (already shows name and address below)
                LocationMapView(location: location, height: 120)
                
                Button(action: {
                    openInMaps(location: location)
                }) {
                    HStack {
                        Image(systemName: "map")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                        Text("Open in Maps")
                            .font(.body.weight(.medium))
                            .foregroundColor(.blue)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
    }
    
    private func scheduleCard(_ task: TodoTask) -> some View {
        DetailCard(icon: "clock", title: "Schedule", color: Color.orange) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Start Time")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(task.startTime.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                
                durationSection(task)
            }
        }
    }
    
    private func durationSection(_ task: TodoTask) -> some View {
        let hasActualDuration = task.completions[effectiveDate]?.actualDuration != nil
        let hasEstimatedDuration = task.hasDuration
        let actualDuration = task.completions[effectiveDate]?.actualDuration
        let estimatedDuration = task.duration
        
        return Group {
            if hasActualDuration {
                // Priority to actual duration
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Actual Duration")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Button("Edit") {
                                showingDurationPicker = true
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                            
                            Button("Clear") {
                                updateLocalTaskRating(actualDuration: 0, updateDuration: true)
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                    }
                    
                    HStack {
                        Text(formatDuration(actualDuration!))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.green)
                        Spacer()
                    }
                    
                    // Show comparison with estimated if available
                    if hasEstimatedDuration {
                        HStack {
                            Text("vs estimated")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            
                            let difference = actualDuration! - estimatedDuration
                            let isUnder = difference < 0
                            let percentage = abs(difference) / estimatedDuration * 100
                            
                            HStack(spacing: 4) {
                                Text(formatDuration(estimatedDuration))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .strikethrough()
                                
                                Text(isUnder ? "(-\(Int(percentage))%)" : "(+\(Int(percentage))%)")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(isUnder ? .green : .orange)
                            }
                        }
                    }
                }
            } else if hasEstimatedDuration {
                // Show estimated duration with option to add actual
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Estimated Duration")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatDuration(estimatedDuration))
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: {
                        showingDurationPicker = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 12))
                                .foregroundColor(.blue)
                            Text("Add actual duration")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Spacer()
                        }
                        .padding(.top, 2)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            } else {
                // No duration at all - option to add
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Duration")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Not set")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: {
                        showingDurationPicker = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 12))
                                .foregroundColor(.blue)
                            Text("Add duration")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Spacer()
                        }
                        .padding(.top, 2)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
        }
    }
    
    private func recurrenceCard(_ task: TodoTask, _ recurrence: Recurrence) -> some View {
        DetailCard(icon: "repeat", title: "Recurrence", color: .purple) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Pattern")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(recurrenceDescription(recurrence))
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                
                if let endDate = recurrence.endDate {
                    HStack {
                        Text("Ends")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(endDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
                
                HStack {
                    Text("Current Streak")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(Color.orange)
                            .font(.system(size: 12))
                        Text("\(task.currentStreak)")
                            .font(.subheadline.bold())
                            .foregroundColor(Color.orange)
                    }
                }
            }
        }
    }
    
    private func subtasksCard(_ task: TodoTask) -> some View {
        DetailCard(icon: "checklist", title: "Subtasks", color: .indigo) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(task.subtasks) { subtask in
                    subtaskRow(task, subtask)
                }
            }
        }
    }
    
    private func subtaskRow(_ task: TodoTask, _ subtask: Subtask) -> some View {
        HStack {
            let isCompleted = task.completions[effectiveDate]?.completedSubtasks.contains(subtask.id) == true
            
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundColor(isCompleted ? .green : .gray)
            
            Text(subtask.name)
                .font(.body)
                .foregroundColor(.primary)
                .strikethrough(isCompleted)
            
            Spacer()
        }
    }
    
    private func pomodoroCard(_ task: TodoTask, _ pomodoroSettings: PomodoroSettings) -> some View {
        DetailCard(icon: "timer", title: "Pomodoro", color: .red) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Work Duration")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(pomodoroSettings.workDuration / 60)) min")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Text("Break Duration")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(pomodoroSettings.breakDuration / 60)) min")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                
                Button(action: {
                    PomodoroViewModel.shared.setActiveTask(task)
                    showingPomodoro = true
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Pomodoro")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [Color.red, Color.red.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .shadow(
                        color: Color.red.opacity(colorScheme == .dark ? 0.4 : 0.3),
                        radius: colorScheme == .dark ? 4 : 6,
                        x: 0,
                        y: colorScheme == .dark ? 2 : 3
                    )
                }
                .padding(.top, 8)
            }
        }
    }
    
    private func rewardsCard(_ task: TodoTask) -> some View {
        DetailCard(icon: "star", title: "Rewards", color: .yellow) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Points Available")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                    Text("\(task.rewardPoints) points")
                        .font(.title3.bold())
                        .foregroundColor(.yellow)
                }
                Spacer()
                Image(systemName: "star.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.yellow)
            }
        }
    }
    
    private func notesCard(_ task: TodoTask) -> some View {
        DetailCard(icon: "note.text", title: "Notes", color: .purple) {
            TaskNotesSection(
                notes: Binding(
                    get: { task.completions[effectiveDate]?.notes ?? "" },
                    set: { newValue in
                        updateLocalTaskRating(notes: newValue, updateNotes: true)
                    }
                )
            )
        }
    }
    
    private func actionButtons(_ task: TodoTask) -> some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    Color(.systemGroupedBackground).opacity(0),
                    Color(.systemGroupedBackground).opacity(0.8),
                    Color(.systemGroupedBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 30)
            
            HStack(spacing: 12) {
                trackButton(task)
                editButton
                completeButton(task)
            }
            .padding(.horizontal)
            .padding(.bottom)
            .padding(.top, 8)
            .background(Color(.systemGroupedBackground))
        }
    }
    
    private func trackButton(_ task: TodoTask) -> some View {
        Button(action: {
            showingTrackingModeSelection = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .medium))
                Text("Track")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [.yellow, .yellow.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(16)
            .shadow(color: .yellow.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
    
    private func completeButton(_ task: TodoTask) -> some View {
        Button(action: {
            TaskManager.shared.toggleTaskCompletion(task.id, on: effectiveDate)
        }) {
            HStack(spacing: 8) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .medium))
                Text(isCompleted ? "Undo" : "Done")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: isCompleted ? [.orange, .orange.opacity(0.8)] : [.green, .green.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(16)
            .shadow(color: (isCompleted ? .orange.opacity(0.3) : .green.opacity(0.3)), radius: 8, x: 0, y: 4)
        }
    }
    
    private var editButton: some View {
        Button(action: {
            showingEditSheet = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .medium))
                Text("Edit")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [.pink, .pink.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(16)
            .shadow(color: .pink.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    private func recurrenceDescription(_ recurrence: Recurrence) -> String {
        switch recurrence.type {
        case .daily:
            return "Daily"
        case .weekly(let days):
            return days.count == 7 ? "Daily" : "\(days.count) days/week"
        case .monthly(let days):
            return "\(days.count) days/month"
        case .monthlyOrdinal(let patterns):
            return patterns.isEmpty ? "Monthly Patterns" : patterns.map { $0.displayText }.joined(separator: ", ")
        case .yearly:
            return "Yearly"
        }
    }
    
    private func postCompletionInsightsCard(_ task: TodoTask) -> some View {
        DetailCard(icon: "chart.line.uptrend.xyaxis", title: "Performance Tracking", color: .cyan) {
            VStack(alignment: .leading, spacing: 16) {
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Difficulty Rating")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if let difficultyRating = task.completions[effectiveDate]?.difficultyRating, difficultyRating > 0 {
                            Button("Clear") {
                                updateLocalTaskRating(difficultyRating: 0, updateDifficulty: true)
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        } else if !isCompleted {
                            Text("Rate after completing")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                    
                    DifficultyRatingView(
                        rating: Binding(
                            get: { task.completions[effectiveDate]?.difficultyRating ?? 0 },
                            set: { newValue in
                                updateLocalTaskRating(difficultyRating: newValue == 0 ? nil : newValue, updateDifficulty: true)
                            }
                        )
                    )
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Quality Rating")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)
                        
                        Spacer()

                        
                        if let qualityRating = task.completions[effectiveDate]?.qualityRating, qualityRating > 0 {
                            Button("Clear") {
                                updateLocalTaskRating(qualityRating: 0, updateQuality: true)
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        } else if !isCompleted {
                            Text("Rate after completing")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                    
                    QualityRatingView(
                        rating: Binding(
                            get: { task.completions[effectiveDate]?.qualityRating ?? 0 },
                            set: { newValue in
                                updateLocalTaskRating(qualityRating: newValue, updateQuality: true)
                            }
                        )
                    )
                }
                
                if task.hasHistoricalRatings {
                    Divider()
                    
                    Button(action: {
                        showingPerformanceChart = true
                    }) {
                        HStack {
                            Image(systemName: "chart.xyaxis.line")
                                .font(.system(size: 16))
                                .foregroundColor(.cyan)
                            
                            Text("View Performance Charts")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.cyan)
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12))
                                .foregroundColor(.cyan)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.cyan.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private func openInMaps(location: TaskLocation) {
        let mapItem: MKMapItem
        
        if let coordinate = location.coordinate {
            let placemark = MKPlacemark(coordinate: coordinate)
            mapItem = MKMapItem(placemark: placemark)
        } else {
            let geocoder = CLGeocoder()
            geocoder.geocodeAddressString(location.displayName) { placemarks, error in
                if let placemark = placemarks?.first,
                   let clLocation = placemark.location {
                    let mapPlacemark = MKPlacemark(coordinate: clLocation.coordinate)
                    let mapItem = MKMapItem(placemark: mapPlacemark)
                    mapItem.name = location.name
                    mapItem.openInMaps()
                }
            }
            return
        }
        
        mapItem.name = location.name
        mapItem.openInMaps()
    }
}

struct DetailCard<Content: View>: View {
    let icon: String
    let title: String
    let color: Color
    let content: Content
    @Environment(\.colorScheme) private var colorScheme
    
    init(icon: String, title: String, color: Color, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(cardBackground)
    }
    
    private var cardBackground: some View {
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
                        colorScheme == .dark ? .white.opacity(0.15) : .clear,
                        lineWidth: colorScheme == .dark ? 1 : 0
                    )
            )
    }
}

private struct TaskPerformanceChartView: View {
    let task: TodoTask
    @Environment(\.dismiss) private var dismiss
    @StateObject private var statisticsViewModel = StatisticsViewModel()
    @State private var taskAnalytics: StatisticsViewModel.TaskPerformanceAnalytics?
    @State private var selectedTimeRange: TaskPerformanceTimeRange = .month
    
    enum TaskPerformanceTimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
        case all = "All Time"
        
        func filterCompletions(_ completions: [StatisticsViewModel.TaskCompletionAnalytics]) -> [StatisticsViewModel.TaskCompletionAnalytics] {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .week:
                let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now)!
                return completions.filter { $0.date >= weekAgo }
            case .month:
                let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
                return completions.filter { $0.date >= monthAgo }
            case .year:
                let yearAgo = calendar.date(byAdding: .year, value: -1, to: now)!
                return completions.filter { $0.date >= yearAgo }
            case .all:
                return completions
            }
        }
    }
    
    private var filteredAnalytics: StatisticsViewModel.TaskPerformanceAnalytics? {
        guard let analytics = taskAnalytics else { return nil }
        
        let filteredCompletions = selectedTimeRange.filterCompletions(analytics.completions)
        
        if filteredCompletions.isEmpty {
            return StatisticsViewModel.TaskPerformanceAnalytics(
                taskId: analytics.taskId,
                taskName: analytics.taskName,
                categoryName: analytics.categoryName,
                categoryColor: analytics.categoryColor,
                completions: [],
                averageDifficulty: nil,
                averageQuality: nil,
                averageDuration: nil,
                estimationAccuracy: nil,
                improvementTrend: .insufficient
            )
        }
        
        let avgDifficulty = filteredCompletions.compactMap { $0.difficultyRating }.isEmpty ? nil :
            Double(filteredCompletions.compactMap { $0.difficultyRating }.reduce(0, +)) / Double(filteredCompletions.compactMap { $0.difficultyRating }.count)
        
        let avgQuality = filteredCompletions.compactMap { $0.qualityRating }.isEmpty ? nil :
            Double(filteredCompletions.compactMap { $0.qualityRating }.reduce(0, +)) / Double(filteredCompletions.compactMap { $0.qualityRating }.count)
        
        let avgDuration = filteredCompletions.compactMap { $0.actualDuration }.isEmpty ? nil :
            filteredCompletions.compactMap { $0.actualDuration }.reduce(0, +) / Double(filteredCompletions.compactMap { $0.actualDuration }.count)
        
        return StatisticsViewModel.TaskPerformanceAnalytics(
            taskId: analytics.taskId,
            taskName: analytics.taskName,
            categoryName: analytics.categoryName,
            categoryColor: analytics.categoryColor,
            completions: filteredCompletions,
            averageDifficulty: avgDifficulty,
            averageQuality: avgQuality,
            averageDuration: avgDuration,
            estimationAccuracy: nil,
            improvementTrend: .stable
        )
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    timeRangeSelector
                    
                    if let analytics = filteredAnalytics {
                        if analytics.completions.isEmpty {
                            emptyDataStateView
                        } else {
                            taskInfoHeader(analytics)
                            
                            if hasQualityData(analytics) {
                                qualityChartSection(analytics)
                            }
                            
                            if hasDifficultyData(analytics) {
                                difficultyChartSection(analytics)
                            }
                            
                            completionsSection(analytics)
                        }
                    } else {
                        emptyStateView
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Performance Charts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadTaskAnalytics()
            }
        }
    }
    
    private var timeRangeSelector: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Time Range")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(TaskPerformanceTimeRange.allCases, id: \.self) { range in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedTimeRange = range
                        }
                    }) {
                        Text(range.rawValue)
                            .font(.system(.caption, design: .rounded, weight: selectedTimeRange == range ? .semibold : .medium))
                            .foregroundColor(selectedTimeRange == range ? .accentColor : .primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedTimeRange == range ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .strokeBorder(selectedTimeRange == range ? Color.accentColor : Color.clear, lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    private func loadTaskAnalytics() {
        // Generate analytics for this specific task
        let completionAnalytics = task.completions.compactMap { (date, completion) -> StatisticsViewModel.TaskCompletionAnalytics? in
            guard completion.isCompleted else { return nil }
            
            return StatisticsViewModel.TaskCompletionAnalytics(
                date: date,
                actualDuration: completion.actualDuration,
                difficultyRating: completion.difficultyRating,
                qualityRating: completion.qualityRating,
                estimatedDuration: task.hasDuration ? task.duration : nil,
                wasTracked: false // We can enhance this later
            )
        }.sorted { $0.date < $1.date }
        
        if !completionAnalytics.isEmpty {
            let avgDifficulty = completionAnalytics.compactMap { $0.difficultyRating }.isEmpty ? nil :
                Double(completionAnalytics.compactMap { $0.difficultyRating }.reduce(0, +)) / Double(completionAnalytics.compactMap { $0.difficultyRating }.count)
            
            let avgQuality = completionAnalytics.compactMap { $0.qualityRating }.isEmpty ? nil :
                Double(completionAnalytics.compactMap { $0.qualityRating }.reduce(0, +)) / Double(completionAnalytics.compactMap { $0.qualityRating }.count)
            
            let avgDuration = completionAnalytics.compactMap { $0.actualDuration }.isEmpty ? nil :
                completionAnalytics.compactMap { $0.actualDuration }.reduce(0, +) / Double(completionAnalytics.compactMap { $0.actualDuration }.count)
            
            taskAnalytics = StatisticsViewModel.TaskPerformanceAnalytics(
                taskId: task.id,
                taskName: task.name,
                categoryName: task.category?.name,
                categoryColor: task.category?.color,
                completions: completionAnalytics,
                averageDifficulty: avgDifficulty,
                averageQuality: avgQuality,
                averageDuration: avgDuration,
                estimationAccuracy: nil,
                improvementTrend: .stable // We can calculate this later
            )
        }
    }
    
    private var emptyDataStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("No Data for \(selectedTimeRange.rawValue)")
                .font(.title3.bold())
            
            VStack(spacing: 8) {
                Text("This task has no performance data for the selected time period.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                if let analytics = taskAnalytics, !analytics.completions.isEmpty {
                    let totalCompletions = analytics.completions.count
                    let oldestCompletion = analytics.completions.min(by: { $0.date < $1.date })?.date
                    
                    if let oldestDate = oldestCompletion {
                        VStack(spacing: 4) {
                            Text("Available data:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("\(totalCompletions) completions since \(oldestDate.formatted(.dateTime.month().day().year()))")
                                .font(.caption.bold())
                                .foregroundColor(.blue)
                        }
                        .padding(.top, 8)
                    }
                }
            }
            
            HStack(spacing: 12) {
                Button("Try All Time") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTimeRange = .all
                    }
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue)
                )
                
                Button("Try Year") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTimeRange = .year
                    }
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(.blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.blue, lineWidth: 1)
                        )
                )
            }
            .padding(.top, 8)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    private func taskInfoHeader(_ analytics: StatisticsViewModel.TaskPerformanceAnalytics) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                if let categoryColor = analytics.categoryColor {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: categoryColor))
                        .frame(width: 6, height: 50)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(analytics.taskName)
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    
                    if let categoryName = analytics.categoryName {
                        Text(categoryName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                TaskDetailMetricCard(
                    title: "Completions",
                    value: "\(analytics.completions.count)",
                    color: .blue,
                    icon: "checkmark.circle.fill"
                )
                
                if let avgQuality = analytics.averageQuality {
                    TaskDetailMetricCard(
                        title: "Quality",
                        value: String(format: "%.1f", avgQuality),
                        color: .yellow,
                        icon: "star.fill"
                    )
                }
                
                if let avgDifficulty = analytics.averageDifficulty {
                    TaskDetailMetricCard(
                        title: "Difficulty",
                        value: String(format: "%.1f", avgDifficulty),
                        color: .orange,
                        icon: "bolt.fill"
                    )
                }
                
                if let avgDuration = analytics.averageDuration {
                    TaskDetailMetricCard(
                        title: "Time",
                        value: formatDuration(avgDuration),
                        color: .green,
                        icon: "clock.fill"
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    private func hasQualityData(_ analytics: StatisticsViewModel.TaskPerformanceAnalytics) -> Bool {
        analytics.completions.contains { $0.qualityRating != nil }
    }
    
    private func hasDifficultyData(_ analytics: StatisticsViewModel.TaskPerformanceAnalytics) -> Bool {
        analytics.completions.contains { $0.difficultyRating != nil }
    }
    
    private func qualityChartSection(_ analytics: StatisticsViewModel.TaskPerformanceAnalytics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("Quality Over Time (\(selectedTimeRange.rawValue))")
                    .font(.headline)
                Spacer()
            }
            
            let qualityPoints = analytics.completions.compactMap { completion -> (Date, Double)? in
                guard let rating = completion.qualityRating else { return nil }
                return (completion.date, Double(rating))
            }.sorted { $0.0 < $1.0 }
            
            if !qualityPoints.isEmpty {
                Chart(Array(qualityPoints.enumerated()), id: \.offset) { index, point in
                    LineMark(
                        x: .value("Date", point.0),
                        y: .value("Quality", point.1)
                    )
                    .foregroundStyle(Color(hex: analytics.categoryColor ?? "#6366F1"))
                    .lineStyle(.init(lineWidth: 3.0, lineCap: .round))
                    
                    PointMark(
                        x: .value("Date", point.0),
                        y: .value("Difficulty", point.1)
                    )
                    .foregroundStyle(Color(hex: analytics.categoryColor ?? "#6366F1"))
                    .symbolSize(60)
                    .symbol(.circle)
                }
                .frame(height: 200)
                .chartYScale(domain: 0...10)
                .chartXAxis {
                    AxisMarks(position: .bottom) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.gray.opacity(0.2))
                        AxisValueLabel() {
                            if let dateValue = value.as(Date.self) {
                                Text(formatChartDateLabel(dateValue))
                                    .font(.system(.caption2, design: .rounded, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.gray.opacity(0.2))
                        AxisValueLabel() {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue)")
                                    .font(.system(.caption2, design: .rounded, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .chartXAxisLabel("Date", position: .bottom)
                .chartYAxisLabel("Quality Rating", position: .leading)
            } else {
                VStack(spacing: 8) {
                    Text("No quality ratings in \(selectedTimeRange.rawValue.lowercased())")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Complete tasks and add quality ratings to see trends")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 100, alignment: .center)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    private func difficultyChartSection(_ analytics: StatisticsViewModel.TaskPerformanceAnalytics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.orange)
                Text("Difficulty Over Time (\(selectedTimeRange.rawValue))")
                    .font(.headline)
                Spacer()
            }
            
            let difficultyPoints = analytics.completions.compactMap { completion -> (Date, Double)? in
                guard let rating = completion.difficultyRating else { return nil }
                return (completion.date, Double(rating))
            }.sorted { $0.0 < $1.0 }
            
            if !difficultyPoints.isEmpty {
                Chart(Array(difficultyPoints.enumerated()), id: \.offset) { index, point in
                    LineMark(
                        x: .value("Date", point.0),
                        y: .value("Difficulty", point.1)
                    )
                    .foregroundStyle(Color(hex: analytics.categoryColor ?? "#6366F1"))
                    .lineStyle(.init(lineWidth: 3.0, lineCap: .round))
                    
                    PointMark(
                        x: .value("Date", point.0),
                        y: .value("Difficulty", point.1)
                    )
                    .foregroundStyle(Color(hex: analytics.categoryColor ?? "#6366F1"))
                    .symbolSize(60)
                    .symbol(.circle)
                }
                .frame(height: 200)
                .chartYScale(domain: 0...10)
                .chartXAxis {
                    AxisMarks(position: .bottom) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.gray.opacity(0.2))
                        AxisValueLabel() {
                            if let dateValue = value.as(Date.self) {
                                Text(formatChartDateLabel(dateValue))
                                    .font(.system(.caption2, design: .rounded, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.gray.opacity(0.2))
                        AxisValueLabel() {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue)")
                                    .font(.system(.caption2, design: .rounded, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .chartXAxisLabel("Date", position: .bottom)
                .chartYAxisLabel("Difficulty Rating", position: .leading)
            } else {
                VStack(spacing: 8) {
                    Text("No difficulty ratings in \(selectedTimeRange.rawValue.lowercased())")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Complete tasks and add difficulty ratings to see trends")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 100, alignment: .center)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    private func formatChartDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        switch selectedTimeRange {
        case .week:
            formatter.dateFormat = "E dd"  // "Mon 15"
        case .month:
            formatter.dateFormat = "dd MMM"  // "15 Dec"
        case .year:
            formatter.dateFormat = "MMM yyyy"  // "Dec 2024"
        case .all:
            // Determine best format based on date range
            let calendar = Calendar.current
            let now = Date()
            let daysDiff = calendar.dateComponents([.day], from: date, to: now).day ?? 0
            
            if daysDiff <= 30 {
                formatter.dateFormat = "dd MMM"  // "15 Dec"
            } else if daysDiff <= 365 {
                formatter.dateFormat = "MMM yyyy"  // "Dec 2024"
            } else {
                formatter.dateFormat = "yyyy"  // "2024"
            }
        }
        
        return formatter.string(from: date)
    }
    
    private func completionsSection(_ analytics: StatisticsViewModel.TaskPerformanceAnalytics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(.blue)
                Text("Completions (\(selectedTimeRange.rawValue))")
                    .font(.headline)
                Spacer()
            }
            
            if analytics.completions.isEmpty {
                VStack(spacing: 8) {
                    Text("No completions in \(selectedTimeRange.rawValue.lowercased())")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Complete this task to start tracking performance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 60, alignment: .center)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(analytics.completions.sorted { $0.date > $1.date }) { completion in
                        CompletionDetailRow(completion: completion)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("No Performance Data")
                .font(.title2.bold())
            
            Text("Complete this task with quality and difficulty ratings to see performance charts over time")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - CompletionDetailRow - Enhanced completion display
private struct CompletionDetailRow: View {
    let completion: StatisticsViewModel.TaskCompletionAnalytics
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(completion.date.formatted(.dateTime.month().day().year()))
                    .font(.subheadline.bold())
                Text(completion.date.formatted(.dateTime.hour().minute()))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                if let quality = completion.qualityRating {
                    MetricBadge(
                        icon: "star.fill",
                        value: "\(quality)",
                        color: .yellow
                    )
                }
                
                if let difficulty = completion.difficultyRating {
                    MetricBadge(
                        icon: "bolt.fill",
                        value: "\(difficulty)",
                        color: .orange
                    )
                }
                
                if let duration = completion.actualDuration {
                    let minutes = Int(duration) / 60
                    MetricBadge(
                        icon: "clock.fill",
                        value: "\(minutes)m",
                        color: .blue
                    )
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }
}

// MARK: - MetricBadge for completion rows
private struct MetricBadge: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
            Text(value)
                .font(.caption.bold())
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - TaskDetailMetricCard
private struct TaskDetailMetricCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color)
                Text(value)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            Text(title)
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 45)
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(0.08))
        )
    }
}

#Preview {
    NavigationStack {
        TaskDetailView(taskId: UUID(), targetDate: nil)
    }
}
