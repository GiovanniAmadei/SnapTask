import SwiftUI

struct TimeTrackingCompletionView: View {
    let task: TodoTask?
    let session: TrackingSession?
    let onSave: () -> Void
    let onDiscard: () -> Void
    let onContinue: () -> Void
    
    @Environment(\.dismiss) private var dismiss
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
                                .fill(
                                    LinearGradient(
                                        colors: [.green.opacity(0.2), .blue.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.green, .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .symbolEffect(.bounce, value: showingSuccess)
                        
                        VStack(spacing: 8) {
                            Text("focus_session_complete".localized)
                                .font(.title2.bold())
                            
                            Text("focused_for".localized + " \(formatDuration(editedFocusTime))")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Session Details Card - Editable
                    VStack(spacing: 16) {
                        HStack {
                            Text("session_details".localized)
                                .font(.headline)
                            Spacer()
                            Button(isEditingDetails ? "done".localized : "edit".localized) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isEditingDetails.toggle()
                                }
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.blue)
                        }
                        
                        VStack(spacing: 12) {
                            // Task Name
                            VStack(alignment: .leading, spacing: 8) {
                                Text("task_name".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if isEditingDetails {
                                    TextField("enter_task_name".localized, text: $editedTaskName)
                                        .textFieldStyle(.roundedBorder)
                                } else {
                                    HStack {
                                        if let category = task?.category {
                                            Circle()
                                                .fill(Color(hex: category.color))
                                                .frame(width: 12, height: 12)
                                        }
                                        Text(editedTaskName)
                                            .font(.body)
                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            
                            // Focus Time with Wheel Picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("focus_time".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if isEditingDetails {
                                    HStack {
                                        // Hours Picker
                                        VStack {
                                            Text("hours".localized)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            Picker("hours".localized, selection: $editedFocusHours) {
                                                ForEach(0...23, id: \.self) { hour in
                                                    Text("\(hour)").tag(hour)
                                                }
                                            }
                                            .pickerStyle(.wheel)
                                            .frame(width: 80, height: 120)
                                        }
                                        
                                        Text(":")
                                            .font(.title2.bold())
                                            .padding(.top, 20)
                                        
                                        // Minutes Picker
                                        VStack {
                                            Text("minutes".localized)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            Picker("minutes".localized, selection: $editedFocusMinutes) {
                                                ForEach(0...59, id: \.self) { minute in
                                                    Text(String(format: "%02d", minute)).tag(minute)
                                                }
                                            }
                                            .pickerStyle(.wheel)
                                            .frame(width: 80, height: 120)
                                        }
                                        
                                        Spacer()
                                    }
                                } else {
                                    Text(formatDuration(editedFocusTime))
                                        .font(.body)
                                        .padding(.vertical, 4)
                                }
                            }
                            
                            // Mode
                            VStack(alignment: .leading, spacing: 8) {
                                Text("mode".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Image(systemName: session?.mode.icon ?? "timer")
                                        .foregroundColor(.yellow)
                                        .font(.system(size: 12))
                                    Text(session?.mode.displayName ?? "simple_timer".localized)
                                        .font(.body)
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                            
                            // Category
                            if let category = task?.category {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("original_category".localized)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    HStack {
                                        Circle()
                                            .fill(Color(hex: category.color))
                                            .frame(width: 12, height: 12)
                                        Text(category.name)
                                            .font(.body)
                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray6))
                    )
                    .padding(.horizontal)
                    
                    // Time Tracking Options
                    VStack(spacing: 16) {
                        HStack {
                            Text("track_time_in".localized)
                                .font(.headline)
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        VStack(spacing: 12) {
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
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 100)
                }
            }
            
            // Bottom Action Buttons
            VStack(spacing: 12) {
                Button {
                    Task { @MainActor in
                        await saveTimeTracking()
                        onSave()
                    }
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("save_and_finish".localized)
                    }
                    .font(.body.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                }
                // Allow saving without selecting an option; defaults will apply in logic
                
                HStack(spacing: 12) {
                    // Continue button
                    Button {
                        onContinue()
                    } label: {
                        HStack {
                            Image(systemName: "play.circle")
                            Text("continue".localized)
                        }
                        .font(.body.weight(.medium))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(16)
                    }
                    
                    // Skip button
                    Button {
                        onDiscard()
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("skip".localized)
                        }
                        .font(.body.weight(.medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
            .background(
                LinearGradient(
                    colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)],
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
                        await saveTimeTracking()
                        onSave()
                    }
                }
                .font(.body.weight(.medium))
                // Allow saving without selecting an option; defaults will apply in logic
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