import SwiftUI

struct PomodoroCompletionView: View {
    let task: TodoTask
    let focusTimeCompleted: TimeInterval
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
    
    init(task: TodoTask, focusTimeCompleted: TimeInterval) {
        self.task = task
        self.focusTimeCompleted = focusTimeCompleted
        self._editedTaskName = State(initialValue: task.name)
        let totalMinutes = Int(focusTimeCompleted / 60)
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
                            Text("pomodoro_complete".localized)
                                .font(.system(.title2, design: .rounded).bold())
                                .themedPrimaryText()
                            
                            Text("you_focused_for".localized + " \(formatDuration(editedFocusTime))")
                                .font(.system(.subheadline, design: .rounded))
                                .themedSecondaryText()
                        }
                    }
                    .padding(.top, 16)
                    
                    // Task Details Card - Editable
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
                                    TextField("task_name_placeholder".localized, text: $editedTaskName)
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
                                        if let category = task.category {
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
                            
                            // Category
                            if let category = task.category {
                                Divider()
                                    .opacity(0.3)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("category".localized)
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
                                color: task.category?.color ?? "#6366F1",
                                isSelected: trackAsTask
                            ) {
                                trackAsTask = true
                                selectedCategory = nil
                            }
                            
                            // Category option
                            if let taskCategory = task.category {
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
                        PomodoroViewModel.shared.stop()
                        PomodoroViewModel.shared.activeTask = nil
                        dismiss()
                        NotificationCenter.default.post(name: .pomodoroCompleted, object: nil)
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
                        dismiss()
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
                        Task { @MainActor in
                            HapticManager.shared.impact(.medium)
                            PomodoroViewModel.shared.stop()
                            PomodoroViewModel.shared.activeTask = nil
                            dismiss()
                            NotificationCenter.default.post(name: .pomodoroCompleted, object: nil)
                        }
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
                        PomodoroViewModel.shared.stop()
                        PomodoroViewModel.shared.activeTask = nil
                        dismiss()
                        NotificationCenter.default.post(name: .pomodoroCompleted, object: nil)
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
            if let taskCategory = task.category {
                selectedCategory = taskCategory
            }
        }
    }
    
    private var availableCategories: [Category] {
        // Get categories from CategoryManager, excluding the task's category
        let allCategories = CategoryManager.shared.categories
        if let taskCategory = task.category {
            return allCategories.filter { $0.id != taskCategory.id }
        }
        return allCategories
    }
    
    private func saveTimeTracking() async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let hasTask = taskManager.tasks.contains(where: { $0.id == task.id })
        
        var trackingSession = TrackingSession(
            taskId: (trackAsTask && hasTask) ? task.id : nil,
            taskName: (trackAsTask && hasTask) ? editedTaskName : (selectedCategory != nil ? selectedCategory?.name : editedTaskName),
            mode: .pomodoro,
            categoryId: (trackAsTask && hasTask) ? task.category?.id : selectedCategory?.id,
            categoryName: (trackAsTask && hasTask) ? task.category?.name : selectedCategory?.name
        )
        trackingSession.totalDuration = editedFocusTime
        trackingSession.elapsedTime = editedFocusTime
        trackingSession.isCompleted = true
        trackingSession.endTime = Date()
        trackingSession.lastModifiedDate = Date()
        
        if trackAsTask && hasTask {
            print("Tracking \(editedFocusTime/60) minutes for task: \(editedTaskName)")
            taskManager.toggleTaskCompletion(task.id, on: today)
            taskManager.addTrackedTime(editedFocusTime, to: task.id)
            taskManager.updateTaskRating(
                taskId: task.id,
                actualDuration: editedFocusTime,
                difficultyRating: nil,
                qualityRating: nil,
                notes: nil,
                for: today
            )
            
            taskManager.saveTrackingSession(trackingSession)
            
            // Save time tracking data to statistics as individual task
            await saveToStatistics(categoryId: task.category?.id, timeSpent: editedFocusTime, taskName: editedTaskName, taskId: task.id)
            
            if let updatedTask = TaskManager.shared.tasks.first(where: { $0.id == task.id }) {
                CloudKitService.shared.saveTask(updatedTask)
            }
        } else if let category = selectedCategory {
            print("Tracking \(editedFocusTime/60) minutes for category: \(category.name)")
            if hasTask {
                taskManager.toggleTaskCompletion(task.id, on: today)
                taskManager.addTrackedTime(editedFocusTime, to: task.id)
                taskManager.updateTaskRating(
                    taskId: task.id,
                    actualDuration: editedFocusTime,
                    difficultyRating: nil,
                    qualityRating: nil,
                    notes: nil,
                    for: today
                )
            }
            
            taskManager.saveTrackingSession(trackingSession)
            await saveToStatistics(categoryId: category.id, timeSpent: editedFocusTime)
        } else {
            // General / Uncategorized tracking
            taskManager.saveTrackingSession(trackingSession)
            await saveToStatistics(categoryId: nil, timeSpent: editedFocusTime)
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
                "color": task.category?.color ?? "#6366F1"
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
        NotificationCenter.default.post(name: .timeTrackingUpdated, object: nil)
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

struct TrackingOptionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: String
    let isSelected: Bool
    let action: () -> Void
    
    @Environment(\.theme) private var theme
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.light)
            action()
        }) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: color).opacity(0.18))
                        .frame(width: 42, height: 42)
                    
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(hex: color))
                }
                
                // Content
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .themedPrimaryText()
                        .lineLimit(1)
                    
                    Text(subtitle)
                        .font(.system(.caption, design: .rounded))
                        .themedSecondaryText()
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color(hex: color) : theme.borderColor.opacity(0.6), lineWidth: isSelected ? 2 : 1.5)
                        .frame(width: 22, height: 22)
                    
                    if isSelected {
                        Circle()
                            .fill(Color(hex: color))
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color(hex: color).opacity(0.08) : theme.surfaceColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? Color(hex: color).opacity(0.6) : theme.borderColor.opacity(0.4),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
            )
            .shadow(color: isSelected ? Color(hex: color).opacity(0.15) : theme.shadowColor.opacity(0.5), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.01 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}

extension Notification.Name {
    static let pomodoroCompleted = Notification.Name("pomodoroCompleted")
    static let timeTrackingUpdated = Notification.Name("timeTrackingUpdated")
}

#Preview {
    PomodoroCompletionView(
        task: TodoTask(
            name: "Design new feature",
            startTime: Date(),
            category: Category(id: UUID(), name: "Work", color: "#3B82F1")
        ),
        focusTimeCompleted: 1500 // 25 minutes
    )
}