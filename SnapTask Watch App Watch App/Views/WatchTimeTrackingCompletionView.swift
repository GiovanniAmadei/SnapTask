import SwiftUI

struct WatchTimeTrackingCompletionView: View {
    let task: TodoTask?
    let timeSpent: TimeInterval
    let onSave: () -> Void
    let onDiscard: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var taskManager = TaskManager.shared
    @StateObject private var categoryManager = CategoryManager.shared
    @State private var selectedCategory: Category?
    @State private var trackAsTask = false
    @State private var editedTaskName: String
    @State private var editedTimeMinutes: Int
    
    init(task: TodoTask?, timeSpent: TimeInterval, onSave: @escaping () -> Void, onDiscard: @escaping () -> Void) {
        self.task = task
        self.timeSpent = timeSpent
        self.onSave = onSave
        self.onDiscard = onDiscard
        
        self._editedTaskName = State(initialValue: task?.name ?? "Focus Session")
        self._editedTimeMinutes = State(initialValue: Int(timeSpent / 60))
        
    }
    
    private var editedTimeSpent: TimeInterval {
        TimeInterval(editedTimeMinutes * 60)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Success Header
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green)
                        
                        Text("Session Complete!")
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text(formatDuration(editedTimeSpent))
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                    
                    // Time Editor
                    VStack(spacing: 12) {
                        Text("Adjust Time")
                            .font(.system(size: 14, weight: .medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack {
                            Text("Minutes:")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Picker("Minutes", selection: $editedTimeMinutes) {
                                ForEach(1...300, id: \.self) { minute in
                                    Text("\(minute)").tag(minute)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 80, height: 80)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                    )
                    
                    // Tracking Options
                    VStack(spacing: 8) {
                        Text("Choose Where to Track")
                            .font(.system(size: 14, weight: .medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        if !hasValidSelection {
                            HStack {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 10))
                                    .foregroundColor(.orange)
                                
                                Text("Please select an option below")
                                    .font(.system(size: 10))
                                    .foregroundColor(.orange)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 4)
                        }
                        
                        // Task-specific option (only if we have a task)
                        if task != nil {
                            Button(action: {
                                trackAsTask = true
                                selectedCategory = nil
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: trackAsTask ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 16))
                                        .foregroundColor(trackAsTask ? .blue : .gray)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("This Task Only")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.primary)
                                        
                                        Text(editedTaskName)
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(trackAsTask ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // Categories
                        ForEach(availableCategories, id: \.id) { category in
                            Button(action: {
                                selectedCategory = category
                                trackAsTask = false
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: (selectedCategory?.id == category.id && !trackAsTask) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 16))
                                        .foregroundColor((selectedCategory?.id == category.id && !trackAsTask) ? .blue : .gray)
                                    
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(Color(hex: category.color))
                                            .frame(width: 8, height: 8)
                                        
                                        Text(category.name)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.primary)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill((selectedCategory?.id == category.id && !trackAsTask) ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 8)
            }
            
            // Bottom Buttons
            VStack(spacing: 8) {
                Button(action: {
                    saveTimeTracking()
                    onSave()
                }) {
                    HStack {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12))
                        Text("Save")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(hasValidSelection ? Color.blue : Color.gray.opacity(0.5))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!hasValidSelection)
                
                Button(action: {
                    onDiscard()
                }) {
                    Text("Skip")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.1))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .navigationTitle("Save Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Skip") { onDiscard() }
                    .font(.system(size: 12))
            }
        }
    }
    
    private var availableCategories: [Category] {
        categoryManager.categories
    }
    
    private var hasValidSelection: Bool {
        return trackAsTask || selectedCategory != nil
    }
    
    private func saveTimeTracking() {
        // Mark the task as completed if tracking as task
        if trackAsTask, let task = task {
            print("✅ Watch: Tracking \(editedTimeMinutes) minutes for task: \(editedTaskName)")
            taskManager.toggleTaskCompletion(task.id)
            
            // Add tracked time to task completion
            taskManager.addTrackedTime(editedTimeSpent, to: task.id, on: Date())
        } else if let category = selectedCategory {
            // Track time for selected category
            print("✅ Watch: Tracking \(editedTimeMinutes) minutes for category: \(category.name)")
            if let task = task {
                taskManager.toggleTaskCompletion(task.id)
            }
        }
        
        // Save to statistics (same format as iOS)
        saveToStatistics()
    }
    
    private func saveToStatistics() {
        let trackingKey = "timeTracking"
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var timeTrackingData = UserDefaults.standard.dictionary(forKey: trackingKey) as? [String: [String: Double]] ?? [:]
        
        let dateKey = ISO8601DateFormatter().string(from: today)
        let categoryKey: String
        
        if trackAsTask, let task = task {
            // Individual task tracking
            categoryKey = "task_\(task.id.uuidString)"
            
            // Store task metadata for display purposes
            var taskMetadata = UserDefaults.standard.dictionary(forKey: "taskMetadata") as? [String: [String: String]] ?? [:]
            taskMetadata[categoryKey] = [
                "name": editedTaskName,
                "color": task.category?.color ?? "#6366F1"
            ]
            UserDefaults.standard.set(taskMetadata, forKey: "taskMetadata")
        } else if let category = selectedCategory {
            // Regular category tracking
            categoryKey = category.id.uuidString
        } else {
            return // Invalid configuration
        }
        
        if timeTrackingData[dateKey] == nil {
            timeTrackingData[dateKey] = [:]
        }
        
        let currentTime = timeTrackingData[dateKey]?[categoryKey] ?? 0
        timeTrackingData[dateKey]?[categoryKey] = currentTime + (editedTimeSpent / 3600.0) // Convert to hours
        
        UserDefaults.standard.set(timeTrackingData, forKey: trackingKey)
        UserDefaults.standard.synchronize()
        
        // Notify statistics to refresh
        NotificationCenter.default.post(name: .timeTrackingUpdated, object: nil)
        
        print("💾 Watch: Saved \(String(format: "%.2f", editedTimeSpent / 3600.0))h to statistics for key: \(categoryKey)")
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        
        if minutes > 0 {
            return "\(minutes)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
}

// MARK: - Extensions for Notification
extension Notification.Name {
    static let timeTrackingUpdated = Notification.Name("timeTrackingUpdated")
}

#Preview {
    WatchTimeTrackingCompletionView(
        task: nil,
        timeSpent: 1800, // 30 minutes
        onSave: {},
        onDiscard: {}
    )
}
