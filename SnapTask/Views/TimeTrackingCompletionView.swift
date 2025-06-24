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
                            Text("Focus Session Complete!")
                                .font(.title2.bold())
                            
                            Text("Focused for \(formatDuration(editedFocusTime))")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Session Details Card - Editable
                    VStack(spacing: 16) {
                        HStack {
                            Text("Session Details")
                                .font(.headline)
                            Spacer()
                            Button(isEditingDetails ? "Done" : "Edit") {
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
                                Text("Task Name")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if isEditingDetails {
                                    TextField("Task name", text: $editedTaskName)
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
                                Text("Focus Time")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if isEditingDetails {
                                    HStack {
                                        // Hours Picker
                                        VStack {
                                            Text("Hours")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            Picker("Hours", selection: $editedFocusHours) {
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
                                            Text("Minutes")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            Picker("Minutes", selection: $editedFocusMinutes) {
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
                                Text("Mode")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Image(systemName: session?.mode.icon ?? "timer")
                                        .foregroundColor(.yellow)
                                        .font(.system(size: 12))
                                    Text(session?.mode.displayName ?? "Simple Timer")
                                        .font(.body)
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                            
                            // Category
                            if let category = task?.category {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Original Category")
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
                            Text("Track Time In")
                                .font(.headline)
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            // Task-specific option
                            TrackingOptionCard(
                                title: "This Task Only",
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
                                    subtitle: "Category",
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
                                    subtitle: "Category",
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
                        Text("Save & Finish")
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
                .disabled(!trackAsTask && selectedCategory == nil)
                
                HStack(spacing: 12) {
                    // Continue button
                    Button {
                        onContinue()
                    } label: {
                        HStack {
                            Image(systemName: "play.circle")
                            Text("Continue")
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
                            Text("Skip")
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
        .navigationTitle("Focus Session")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    Task { @MainActor in
                        await saveTimeTracking()
                        onSave()
                    }
                }
                .font(.body.weight(.medium))
                .disabled(!trackAsTask && selectedCategory == nil)
            }
        }
        .onAppear {
            showingSuccess = true
            // Pre-select task category if available
            if let taskCategory = task?.category {
                selectedCategory = taskCategory
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
        // Mark the task as completed if tracking as task
        if trackAsTask, let task = task {
            print("Tracking \(editedFocusTime/60) minutes for task: \(editedTaskName)")
            
            // Check if task still exists and hasn't been modified during tracking
            if let currentTask = TaskManager.shared.tasks.first(where: { $0.id == task.id }) {
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                
                // First mark task as completed
                TaskManager.shared.toggleTaskCompletion(task.id, on: today)
                
                // Then save the actual duration to the task's completion data
                TaskManager.shared.updateTaskRating(
                    taskId: task.id, 
                    actualDuration: editedFocusTime, 
                    difficultyRating: nil, 
                    qualityRating: nil, 
                    notes: nil, 
                    for: today
                )
                
                print(" [TRACKING] Successfully saved duration \(editedFocusTime) to task completion")
            } else {
                print(" [TRACKING ERROR] Task \(task.id.uuidString) no longer exists - task was deleted during tracking")
                // Still save to statistics as individual entry but with warning
                await saveToStatistics(categoryId: nil, timeSpent: editedFocusTime, taskName: "\(editedTaskName) (deleted)", taskId: task.id)
                return
            }
            
            // Save time tracking data to statistics as individual task (this will now sync with task completion)
            await saveToStatistics(categoryId: nil, timeSpent: editedFocusTime, taskName: editedTaskName, taskId: task.id)
        } else if let category = selectedCategory {
            // Track time for selected category
            print("Tracking \(editedFocusTime/60) minutes for category: \(category.name)")
            if let task = task {
                // Check if task still exists
                if TaskManager.shared.tasks.contains(where: { $0.id == task.id }) {
                    let calendar = Calendar.current
                    let today = calendar.startOfDay(for: Date())
                    
                    TaskManager.shared.toggleTaskCompletion(task.id, on: today)
                    
                    // Save the actual duration to the task's completion data even when tracking as category
                    TaskManager.shared.updateTaskRating(
                        taskId: task.id, 
                        actualDuration: editedFocusTime, 
                        difficultyRating: nil, 
                        qualityRating: nil, 
                        notes: nil, 
                        for: today
                    )
                    
                    print(" [TRACKING] Successfully saved duration \(editedFocusTime) to task completion (category mode)")
                } else {
                    print("Task \(task.id.uuidString) no longer exists during category tracking")
                }
            }
            
            // Save time tracking data to statistics for the selected category
            await saveToStatistics(categoryId: category.id, timeSpent: editedFocusTime)
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
