import SwiftUI

struct PomodoroCompletionView: View {
    let task: TodoTask
    let focusTimeCompleted: TimeInterval
    @Environment(\.dismiss) private var dismiss
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
                            Text("Pomodoro Complete!")
                                .font(.title2.bold())
                            
                            Text("You focused for \(formatDuration(editedFocusTime))")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Task Details Card - Editable
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
                                        if let category = task.category {
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
                            
                            // Category
                            if let category = task.category {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Category")
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
                        // Stop the pomodoro timer and clear active task
                        PomodoroViewModel.shared.stop()
                        PomodoroViewModel.shared.activeTask = nil
                        
                        // Dismiss the completion sheet
                        dismiss()
                        
                        // Also dismiss the parent Pomodoro view by sending notification
                        NotificationCenter.default.post(name: .pomodoroCompleted, object: nil)
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
                        dismiss()
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
                        Task { @MainActor in
                            // Stop the pomodoro timer when skipping
                            PomodoroViewModel.shared.stop()
                            PomodoroViewModel.shared.activeTask = nil
                            
                            dismiss()
                            
                            // Also dismiss the parent Pomodoro view
                            NotificationCenter.default.post(name: .pomodoroCompleted, object: nil)
                        }
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
                        PomodoroViewModel.shared.stop()
                        PomodoroViewModel.shared.activeTask = nil
                        dismiss()
                        NotificationCenter.default.post(name: .pomodoroCompleted, object: nil)
                    }
                }
                .font(.body.weight(.medium))
                .disabled(!trackAsTask && selectedCategory == nil)
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
        // Mark the task as completed
        if trackAsTask {
            // Track time for this specific task and mark it as complete
            print("Tracking \(editedFocusTime/60) minutes for task: \(editedTaskName)")
            taskManager.toggleTaskCompletion(task.id)
            
            // Save time tracking data to statistics
            await saveToStatistics(categoryId: task.category?.id, timeSpent: editedFocusTime)
        } else if let category = selectedCategory {
            // Track time for selected category
            print("Tracking \(editedFocusTime/60) minutes for category: \(category.name)")
            taskManager.toggleTaskCompletion(task.id)
            
            // Save time tracking data to statistics for the selected category
            await saveToStatistics(categoryId: category.id, timeSpent: editedFocusTime)
        }
    }
    
    private func saveToStatistics(categoryId: UUID?, timeSpent: TimeInterval) async {
        // Create a simple time tracking entry in UserDefaults
        let trackingKey = "timeTracking"
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var timeTrackingData = UserDefaults.standard.dictionary(forKey: trackingKey) as? [String: [String: Double]] ?? [:]
        
        let dateKey = ISO8601DateFormatter().string(from: today)
        let categoryKey = categoryId?.uuidString ?? "uncategorized"
        
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
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: color).opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color(hex: color))
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray4), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color(hex: color))
                            .frame(width: 16, height: 16)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? Color(hex: color).opacity(0.5) : Color(.systemGray5),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
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
