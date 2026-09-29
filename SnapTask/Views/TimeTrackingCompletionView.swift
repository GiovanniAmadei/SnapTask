import SwiftUI

struct TimeTrackingCompletionView: View {
    let task: TodoTask?
    let session: TrackingSession?
    let onSave: () -> Void
    let onDiscard: () -> Void
    let onContinue: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @StateObject private var taskManager = TaskManager.shared
    @State private var selectedCategory: Category?
    @State private var trackAsTask = false
    @State private var showingSuccess = false
    @State private var editedTaskName: String
    @State private var editedFocusHours: Int
    @State private var editedFocusMinutes: Int
    @State private var isEditingDetails = false
    
    init(task: TodoTask?, session: TrackingSession?, onSave: @escaping () -> Void, onDiscard: @escaping () -> Void, onContinue: @escaping () -> Void) {
        self.task = task
        self.session = session
        self.onSave = onSave
        self.onDiscard = onDiscard
        self.onContinue = onContinue
        
        self._editedTaskName = State(initialValue: task?.name ?? session?.taskName ?? "Focus Session")
        
        let totalMinutes = Int((session?.effectiveWorkTime ?? 0) / 60)
        self._editedFocusHours = State(initialValue: totalMinutes / 60)
        self._editedFocusMinutes = State(initialValue: totalMinutes % 60)
    }
    
    private var editedFocusTime: TimeInterval {
        TimeInterval(editedFocusHours * 3600 + editedFocusMinutes * 60)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Success Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(theme.accentColor.opacity(0.15))
                                .frame(width: 96, height: 96)
                                .blur(radius: 8)
                            
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [theme.accentColor.opacity(0.2), Color.green.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 84, height: 84)
                            
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 44, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [theme.accentColor, Color.green],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .symbolEffect(.bounce, value: showingSuccess)
                        
                        VStack(spacing: 6) {
                            Text("focus_session_complete".localized)
                                .font(.system(.title2, design: .rounded).bold())
                                .themedPrimaryText()
                            
                            Text("focused_for".localized + " \(formatDuration(editedFocusTime))")
                                .font(.system(.subheadline, design: .rounded))
                                .themedSecondaryText()
                        }
                    }
                    .padding(.top, 16)
                    
                    // Session Details Card - Editable
                    VStack(spacing: 16) {
                        HStack {
                            Label {
                                Text("session_details".localized)
                                    .font(.system(.headline, design: .rounded).weight(.semibold))
                                    .themedPrimaryText()
                            } icon: {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(theme.accentColor)
                            }
                            
                            Spacer()
                            
                            Button(isEditingDetails ? "done".localized : "edit".localized) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isEditingDetails.toggle()
                                }
                            }
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundColor(theme.accentColor)
                        }
                        
                        VStack(spacing: 14) {
                            // Task Name
                            VStack(alignment: .leading, spacing: 6) {
                                Text("task_name".localized)
                                    .font(.system(.caption2, design: .rounded).weight(.medium))
                                    .themedSecondaryText()
                                
                                if isEditingDetails {
                                    TextField("enter_task_name".localized, text: $editedTaskName)
                                        .textFieldStyle(.plain)
                                        .padding(10)
                                        .background(theme.backgroundColor.opacity(0.6))
                                        .cornerRadius(10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(theme.borderColor.opacity(0.5), lineWidth: 1)
                                        )
                                } else {
                                    HStack(spacing: 8) {
                                        if let category = task?.category {
                                            Circle()
                                                .fill(Color(hex: category.color))
                                                .frame(width: 10, height: 10)
                                        }
                                        Text(editedTaskName)
                                            .font(.system(.body, design: .rounded).weight(.medium))
                                            .themedPrimaryText()
                                        Spacer()
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                            
                            Divider()
                                .opacity(0.3)
                            
                            // Focus Time with Wheel Picker
                            VStack(alignment: .leading, spacing: 6) {
                                Text("focus_time".localized)
                                    .font(.system(.caption2, design: .rounded).weight(.medium))
                                    .themedSecondaryText()
                                
                                if isEditingDetails {
                                    HStack {
                                        // Hours Picker
                                        VStack(spacing: 2) {
                                            Text("hours".localized)
                                                .font(.caption2)
                                                .themedSecondaryText()
                                            Picker("hours".localized, selection: $editedFocusHours) {
                                                ForEach(0...23, id: \.self) { hour in
                                                    Text("\(hour)").tag(hour)
                                                }
                                            }
                                            .pickerStyle(.wheel)
                                            .frame(width: 80, height: 110)
                                        }
                                        
                                        Text(":")
                                            .font(.title2.bold())
                                            .padding(.top, 16)
                                            .themedPrimaryText()
                                        
                                        // Minutes Picker
                                        VStack(spacing: 2) {
                                            Text("minutes".localized)
                                                .font(.caption2)
                                                .themedSecondaryText()
                                            Picker("minutes".localized, selection: $editedFocusMinutes) {
                                                ForEach(0...59, id: \.self) { minute in
                                                    Text(String(format: "%02d", minute)).tag(minute)
                                                }
                                            }
                                            .pickerStyle(.wheel)
                                            .frame(width: 80, height: 110)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(8)
                                    .background(theme.backgroundColor.opacity(0.5))
                                    .cornerRadius(12)
                                } else {
                                    HStack {
                                        Image(systemName: "clock")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(theme.accentColor)
                                        Text(formatDuration(editedFocusTime))
                                            .font(.system(.body, design: .rounded).weight(.semibold))
                                            .themedPrimaryText()
                                        Spacer()
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                            
                            // Mode
                            Divider()
                                .opacity(0.3)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("mode".localized)
                                    .font(.system(.caption2, design: .rounded).weight(.medium))
                                    .themedSecondaryText()
                                
                                HStack(spacing: 8) {
                                    Image(systemName: session?.mode.icon ?? "timer")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(session?.mode.displayName ?? "simple_timer".localized)
                                        .font(.system(.body, design: .rounded).weight(.medium))
                                        .themedPrimaryText()
                                    Spacer()
                                }
                                .padding(.vertical, 2)
                            }
                            
                            // Category
                            if let category = task?.category {
                                Divider()
                                    .opacity(0.3)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("original_category".localized)
                                        .font(.system(.caption2, design: .rounded).weight(.medium))
                                        .themedSecondaryText()
                                    
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(Color(hex: category.color))
                                            .frame(width: 10, height: 10)
                                        Text(category.name)
                                            .font(.system(.body, design: .rounded).weight(.medium))
                                            .themedPrimaryText()
                                        Spacer()
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                    }
                    .padding(18)
                    .background(theme.surfaceColor)
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(theme.borderColor.opacity(0.4), lineWidth: 1)
                    )
                    .shadow(color: theme.shadowColor, radius: 8, x: 0, y: 3)
                    .padding(.horizontal, 20)
                    
                    // Time Tracking Options
                    VStack(spacing: 14) {
                        HStack {
                            Text("track_time_in".localized)
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .themedPrimaryText()
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        
                        VStack(spacing: 10) {
                            // Task-specific option
                            TrackingOptionCard(
                                title: "this_task_only".localized,
                                subtitle: editedTaskName,
                                icon: "target",
                                color: task?.category?.color ?? "#6366F1",
                                isSelected: trackAsTask
                            ) {
                                trackAsTask = true
                                selectedCategory = nil
                            }
                            
                            // Category option
                            if let taskCategory = task?.category {
                                TrackingOptionCard(
                                    title: taskCategory.name,
                                    subtitle: "category".localized,
                                    icon: "folder.fill",
                                    color: taskCategory.color,
                                    isSelected: selectedCategory?.id == taskCategory.id && !trackAsTask
                                ) {
                                    selectedCategory = taskCategory
                                    trackAsTask = false
                                }
                            }
                            
                            // Other categories
                            ForEach(availableCategories, id: \.id) { category in
                                TrackingOptionCard(
                                    title: category.name,
                                    subtitle: "category".localized,
                                    icon: "folder.fill",
                                    color: category.color,
                                    isSelected: selectedCategory?.id == category.id && !trackAsTask
                                ) {
                                    selectedCategory = category
                                    trackAsTask = false
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer(minLength: 120)
                }
            }
            .themedBackground()
            
            // Bottom Action Buttons
            VStack(spacing: 12) {
                Button {
                    Task { @MainActor in
                        HapticManager.shared.notification(.success)
                        await saveTimeTracking()
                        onSave()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("save_and_finish".localized)
                            .font(.system(.body, design: .rounded).weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [theme.accentColor, theme.primaryColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: theme.accentColor.opacity(0.35), radius: 8, x: 0, y: 4)
                }
                .disabled(editedFocusTime <= 0)
                .opacity(editedFocusTime <= 0 ? 0.5 : 1.0)
                
                HStack(spacing: 12) {
                    // Continue button
                    Button {
                        HapticManager.shared.impact(.light)
                        onContinue()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 15, weight: .medium))
                            Text("continue".localized)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        }
                        .foregroundColor(theme.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(theme.accentColor.opacity(0.12))
                        .cornerRadius(14)
                    }
                    
                    // Skip button
                    Button {
                        HapticManager.shared.impact(.medium)
                        onDiscard()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 15, weight: .medium))
                            Text("skip".localized)
                                .font(.system(.subheadline, design: .rounded).weight(.medium))
                        }
                        .foregroundColor(theme.secondaryTextColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(theme.surfaceColor)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(theme.borderColor.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .background(
                LinearGradient(
                    colors: [theme.backgroundColor.opacity(0), theme.backgroundColor.opacity(0.9), theme.backgroundColor],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .navigationTitle("focus_session".localized)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("save".localized) {
                    Task { @MainActor in
                        HapticManager.shared.notification(.success)
                        await saveTimeTracking()
                        onSave()
                    }
                }
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundColor(theme.accentColor)
                .disabled(editedFocusTime <= 0)
            }
        }
        .onAppear {
            showingSuccess = true
            // Pre-select task category if available
            if let taskCategory = task?.category {
                selectedCategory = taskCategory
            } else if let categoryId = session?.categoryId,
                      let category = CategoryManager.shared.categories.first(where: { $0.id == categoryId }) {
                selectedCategory = category
            }
        }
    }
    
    private var availableCategories: [Category] {
        // Get categories from CategoryManager, excluding the task's category
        let allCategories = CategoryManager.shared.categories
        if let taskCategory = task?.category {
            return allCategories.filter { $0.id != taskCategory.id }
        }
        return allCategories
    }
    
    private func saveTimeTracking() async {
        // Save based on user selection - ONLY ONE SAVE, not both
        if trackAsTask, let task = task {
            print(" Saving as individual task: \(editedTaskName)")
            
            // Check if task still exists and hasn't been modified during tracking
            if let currentTask = TaskManager.shared.tasks.first(where: { $0.id == task.id }) {
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                
                // First mark task as completed
                TaskManager.shared.toggleTaskCompletion(task.id, on: today)
                
                TaskManager.shared.updateTaskRating(
                    taskId: task.id, 
                    actualDuration: editedFocusTime, 
                    difficultyRating: nil, 
                    qualityRating: nil, 
                    notes: nil, 
                    for: today
                )

                // If the task has NO category, adjust statistics to show this specific task
                if currentTask.category == nil {
                    let trackingKey = "timeTracking"
                    var timeTrackingData = UserDefaults.standard.dictionary(forKey: trackingKey) as? [String: [String: Double]] ?? [:]
                    let dateKey = ISO8601DateFormatter().string(from: today)
                    // Ensure day entry exists
                    if timeTrackingData[dateKey] == nil { timeTrackingData[dateKey] = [:] }
                    let addedHours = editedFocusTime / 3600.0
                    // Remove from uncategorized if present (since updateTaskRating saved it there)
                    if let existing = timeTrackingData[dateKey]?["uncategorized"], existing > 0 {
                        let updated = max(0, existing - addedHours)
                        if updated > 0 {
                            timeTrackingData[dateKey]?["uncategorized"] = updated
                        } else {
                            timeTrackingData[dateKey]?.removeValue(forKey: "uncategorized")
                        }
                    }
                    // Add to per-task key so stats can display the task name
                    let taskKey = "task_\(task.id.uuidString)"
                    let current = timeTrackingData[dateKey]?[taskKey] ?? 0.0
                    timeTrackingData[dateKey]?[taskKey] = current + addedHours
                    UserDefaults.standard.set(timeTrackingData, forKey: trackingKey)
                    // Store task metadata (name and color) for display
                    var taskMetadata = UserDefaults.standard.dictionary(forKey: "taskMetadata") as? [String: [String: String]] ?? [:]
                    taskMetadata[taskKey] = [
                        "name": editedTaskName,
                        "color": task.category?.color ?? "#6366F1"
                    ]
                    UserDefaults.standard.set(taskMetadata, forKey: "taskMetadata")
                    UserDefaults.standard.synchronize()
                    NotificationCenter.default.post(name: Notification.Name.timeTrackingUpdated, object: nil)
                }
                
                if let session = session {
                    var updatedSession = session
                    updatedSession.categoryId = currentTask.category?.id
                    updatedSession.categoryName = currentTask.category?.name
                    updatedSession.totalDuration = editedFocusTime
                    updatedSession.elapsedTime = editedFocusTime
                    updatedSession.lastModifiedDate = Date()
                    TaskManager.shared.saveTrackingSession(updatedSession)
                }
                
                if let updatedTask = TaskManager.shared.tasks.first(where: { $0.id == task.id }) {
                    CloudKitService.shared.saveTask(updatedTask)
                }
                
                print(" Successfully saved as individual task")
            } else {
                print(" Task \(task.id.uuidString) no longer exists - task was deleted during tracking")
                // Still save to statistics as individual entry but with warning
                await saveToStatistics(
                    categoryId: nil, 
                    timeSpent: editedFocusTime, 
                    taskName: "\(editedTaskName) (deleted)", 
                    taskId: task.id
                )
            }
            
        } else if let category = selectedCategory {
            print(" Saving to category: \(category.name)")
            
            // Mark task as completed if it exists, and SAVE actual duration so it shows in task details
            if let task = task {
                if TaskManager.shared.tasks.contains(where: { $0.id == task.id }) {
                    let calendar = Calendar.current
                    let today = calendar.startOfDay(for: Date())
                    
                    TaskManager.shared.toggleTaskCompletion(task.id, on: today)
                    
                    TaskManager.shared.updateTaskRating(
                        taskId: task.id, 
                        actualDuration: editedFocusTime, 
                        difficultyRating: nil, 
                        qualityRating: nil, 
                        notes: nil, 
                        for: today
                    )
                    
                    if let session = session {
                        var updatedSession = session
                        updatedSession.categoryId = category.id
                        updatedSession.categoryName = category.name
                        updatedSession.totalDuration = editedFocusTime
                        updatedSession.elapsedTime = editedFocusTime
                        updatedSession.lastModifiedDate = Date()
                        TaskManager.shared.saveTrackingSession(updatedSession)
                    }
                    
                    if let updatedTask = TaskManager.shared.tasks.first(where: { $0.id == task.id }) {
                        CloudKitService.shared.saveTask(updatedTask)
                    }
                    
                    print(" Task marked complete and duration saved; time tracked to category")
                } else {
                    print(" Task no longer exists during category tracking")
                }
            }
            
            // Save time tracking data to statistics ONLY for the selected category
            await saveToStatistics(categoryId: category.id, timeSpent: editedFocusTime)
            print(" Successfully saved to category only")
        } else {
            // No selection made: default to Uncategorized behavior
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            if let task = task, TaskManager.shared.tasks.contains(where: { $0.id == task.id }) {
                // Mark complete and set actual duration; statistics sync will add to 'uncategorized'
                TaskManager.shared.toggleTaskCompletion(task.id, on: today)
                TaskManager.shared.updateTaskRating(
                    taskId: task.id,
                    actualDuration: editedFocusTime,
                    difficultyRating: nil,
                    qualityRating: nil,
                    notes: nil,
                    for: today
                )
                if let session = session {
                    var updatedSession = session
                    updatedSession.categoryId = nil
                    updatedSession.categoryName = nil
                    updatedSession.totalDuration = editedFocusTime
                    updatedSession.elapsedTime = editedFocusTime
                    updatedSession.lastModifiedDate = Date()
                    TaskManager.shared.saveTrackingSession(updatedSession)
                }
                print(" Saved with default: Uncategorized")
            } else {
                // General session without task: save directly to 'uncategorized'
                let trackingKey = "timeTracking"
                var timeTrackingData = UserDefaults.standard.dictionary(forKey: trackingKey) as? [String: [String: Double]] ?? [:]
                let dateKey = ISO8601DateFormatter().string(from: today)
                if timeTrackingData[dateKey] == nil { timeTrackingData[dateKey] = [:] }
                let current = timeTrackingData[dateKey]?["uncategorized"] ?? 0.0
                timeTrackingData[dateKey]?["uncategorized"] = current + (editedFocusTime / 3600.0)
                UserDefaults.standard.set(timeTrackingData, forKey: trackingKey)
                UserDefaults.standard.synchronize()
                NotificationCenter.default.post(name: Notification.Name.timeTrackingUpdated, object: nil)
                print(" General session saved as Uncategorized")
            }
        }
    }
    
    private func saveToStatistics(categoryId: UUID?, timeSpent: TimeInterval, taskName: String? = nil, taskId: UUID? = nil) async {
        // Create a simple time tracking entry in UserDefaults
        let trackingKey = "timeTracking"
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var timeTrackingData = UserDefaults.standard.dictionary(forKey: trackingKey) as? [String: [String: Double]] ?? [:]
        
        let dateKey = ISO8601DateFormatter().string(from: today)
        let categoryKey: String
        
        if let categoryId = categoryId {
            // Regular category tracking
            categoryKey = categoryId.uuidString
        } else if let taskId = taskId, let taskName = taskName {
            // Individual task tracking - use a special prefix to distinguish from categories
            categoryKey = "task_\(taskId.uuidString)"
            
            // Store task metadata for display purposes
            var taskMetadata = UserDefaults.standard.dictionary(forKey: "taskMetadata") as? [String: [String: String]] ?? [:]
            taskMetadata[categoryKey] = [
                "name": taskName,
                "color": task?.category?.color ?? "#6366F1"
            ]
            UserDefaults.standard.set(taskMetadata, forKey: "taskMetadata")
        } else {
            return // Invalid configuration
        }
        
        if timeTrackingData[dateKey] == nil {
            timeTrackingData[dateKey] = [:]
        }
        
        let currentTime = timeTrackingData[dateKey]?[categoryKey] ?? 0
        timeTrackingData[dateKey]?[categoryKey] = currentTime + (timeSpent / 3600.0) // Convert to hours
        
        UserDefaults.standard.set(timeTrackingData, forKey: trackingKey)
        UserDefaults.standard.synchronize()
        
        // Notify statistics to refresh
        NotificationCenter.default.post(name: Notification.Name.timeTrackingUpdated, object: nil)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) / 60 % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

#Preview {
    TimeTrackingCompletionView(
        task: TodoTask(
            name: "Design new feature",
            startTime: Date(),
            category: Category(id: UUID(), name: "Work", color: "#3B82F1")
        ),
        session: TrackingSession(
            taskName: "Design new feature",
            mode: .simple
        ),
        onSave: {},
        onDiscard: {},
        onContinue: {}
    )
}