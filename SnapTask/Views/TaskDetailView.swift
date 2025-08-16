import SwiftUI
import MapKit
import Charts
import PhotosUI
import UIKit
import AVFoundation
import Combine

struct TaskDetailView: View {
    let taskId: UUID
    private let fixedDate: Date  // FIXED DATE - never changes!
    let targetDate: Date?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.theme) private var theme
    @ObservedObject private var taskManager = TaskManager.shared
    @StateObject private var taskNotificationManager = TaskNotificationManager.shared
    @State private var localTask: TodoTask?
    @State private var showingEditSheet = false
    @State private var showingPomodoro = false
    @State private var showingTrackingModeSelection = false
    @State private var showingTimeTracker = false
    @State private var selectedTrackingMode: TrackingMode = .simple
    @State private var showingDurationPicker = false
    @State private var showingPerformanceChart = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var fullScreenPhoto: TaskPhoto?
    @State private var showingCameraPicker = false
    @StateObject private var voiceMemoService = VoiceMemoService()
    @State private var isRecordingVoice = false
    @State private var showMicDeniedAlert = false
    @State private var meterCancellable: AnyCancellable?
    @State private var isEditingVoiceMemo = false
    
    private var effectiveDate: Date {
        let calendar = Calendar.current
        return calendar.startOfDay(for: fixedDate)
    }
    
    private var completionKey: Date {
        return localTask?.completionKey(for: fixedDate) ?? effectiveDate
    }
    
    private var isCompleted: Bool {
        return localTask?.completions[completionKey]?.isCompleted == true
    }
    
    init(taskId: UUID, targetDate: Date? = nil) {
        self.taskId = taskId
        self.targetDate = targetDate
        self.fixedDate = targetDate ?? Date()
    }
    
    var body: some View {
        Group {
            if let task = localTask {
                taskContent(task)
            } else {
                Text("task_not_found".localized)
                    .themedSecondaryText()
            }
        }
        .themedBackground()
        .navigationTitle("task_details".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("close".localized) {
                    dismiss()
                }
                .themedPrimary()
            }
        }
        .onAppear {
            loadLocalTask()
            taskNotificationManager.checkAuthorizationStatus()
        }
        .onChange(of: taskManager.tasks) { _, _ in
            updateLocalTaskFromManager()
        }
        .sheet(isPresented: $showingEditSheet) {
            if let task = localTask {
                TaskFormView(initialTask: task, onSave: { updatedTask in
                    Task {
                        await TaskManager.shared.updateTask(updatedTask)
                    }
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
                            return task.completions[completionKey]?.actualDuration ?? 0 
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
        .sheet(item: $fullScreenPhoto) { photo in
            NavigationStack {
                VStack {
                    Spacer()
                    if let image = AttachmentService.loadImage(from: photo.photoPath) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .ignoresSafeArea()
                    }
                    Spacer()
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close") {
                            fullScreenPhoto = nil
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingCameraPicker) {
            CameraImagePicker { image in
                if let task = localTask {
                    Task {
                        await handleCapturedImage(image, task: task)
                    }
                } else {
                    showingCameraPicker = false
                }
            }
        }
        .alert("Microphone Access Denied", isPresented: $showMicDeniedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Enable microphone access in Settings to record voice memos.")
        }
    }
    
    private func loadLocalTask() {
        if let managerTask = taskManager.tasks.first(where: { $0.id == taskId }) {
            localTask = managerTask
        }
    }
    
    private func updateLocalTaskFromManager() {
        if let managerTask = taskManager.tasks.first(where: { $0.id == taskId }) {
            if localTask == nil || managerTask.lastModifiedDate > (localTask?.lastModifiedDate ?? Date.distantPast) {
                localTask = managerTask
            }
        }
    }
    
    private func updateLocalTaskRating(actualDuration: TimeInterval? = nil, difficultyRating: Int? = nil, qualityRating: Int? = nil, notes: String? = nil, updateDuration: Bool = false, updateDifficulty: Bool = false, updateQuality: Bool = false, updateNotes: Bool = false) {
        guard var task = localTask else { return }
        
        var completion = task.completions[completionKey] ?? TaskCompletion(
            isCompleted: false,
            completedSubtasks: [],
            actualDuration: nil,
            difficultyRating: nil,
            qualityRating: nil,
            completionDate: nil,
            notes: nil
        )
        
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
        
        if completion.completionDate == nil && (completion.actualDuration != nil || completion.difficultyRating != nil || completion.qualityRating != nil || completion.notes != nil) {
            completion.completionDate = Date()
        }
        
        task.completions[completionKey] = completion
        task.lastModifiedDate = Date()
        localTask = task
        
        if updateDuration {
            TaskManager.shared.updateTaskRating(
                taskId: task.id, 
                actualDuration: actualDuration, 
                for: fixedDate
            )
        }
        
        if updateDifficulty {
            TaskManager.shared.updateTaskRating(
                taskId: task.id, 
                difficultyRating: difficultyRating, 
                for: fixedDate
            )
        }
        
        if updateQuality {
            TaskManager.shared.updateTaskRating(
                taskId: task.id, 
                qualityRating: qualityRating, 
                for: fixedDate
            )
        }
        
        if updateNotes {
            TaskManager.shared.updateTaskRating(
                taskId: task.id, 
                notes: notes, 
                for: fixedDate
            )
        }
    }
    
    private func taskContent(_ task: TodoTask) -> some View {
        ZStack {
            theme.backgroundColor
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
                    .themedPrimary()
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .fill(theme.primaryColor.opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.name)
                        .font(.title2.bold())
                        .themedPrimaryText()
                    
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
                .themedSecondaryText()
        }
    }
    
    private func priorityInfo(_ task: TodoTask) -> some View {
        HStack(spacing: 4) {
            Image(systemName: task.priority.icon)
                .font(.system(size: 10))
                .foregroundColor(Color(hex: task.priority.color))
            Text(task.priority.displayName)
                .font(.caption)
                .themedSecondaryText()
        }
    }
    
    private var completionStatus: some View {
        Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 24))
            .foregroundColor(isCompleted ? .green : theme.secondaryTextColor)
    }
    
    private var headerBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(theme.surfaceColor)
            .shadow(
                color: theme.shadowColor,
                radius: colorScheme == .dark ? 0.5 : 12,
                x: 0,
                y: colorScheme == .dark ? 1 : 4
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        theme.borderColor,
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
            
            photoCard(task)
            
            voiceMemosCard(task)
            
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
    
    private func scheduleCard(_ task: TodoTask) -> some View {
        DetailCard(icon: "clock", title: "time".localized, color: Color.orange) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("time_range".localized)
                        .font(.subheadline.weight(.medium))
                        .themedSecondaryText()
                    Spacer()
                    Text(task.displayPeriod)
                        .font(.subheadline)
                        .themedPrimaryText()
                }
                
                if task.hasSpecificTime {
                    HStack {
                        Text("start_time".localized)
                            .font(.subheadline.weight(.medium))
                            .themedSecondaryText()
                        Spacer()
                        Text(task.startTime.formatted(date: .omitted, time: .shortened))
                            .font(.subheadline)
                            .themedPrimaryText()
                    }
                }
                
                if task.hasNotification {
                    HStack {
                        Text("notifications".localized)
                            .font(.subheadline.weight(.medium))
                            .themedSecondaryText()
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.blue)
                            Text("enabled".localized)
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                durationSection(task)
            }
        }
    }
    
    private func descriptionCard(_ description: String) -> some View {
        DetailCard(icon: "doc.text", title: "description".localized, color: .blue) {
            Text(description)
                .font(.body)
                .themedPrimaryText()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func locationCard(_ location: TaskLocation) -> some View {
        DetailCard(icon: "location", title: "location".localized, color: .green) {
            VStack(alignment: .leading, spacing: 16) {
                LocationMapView(location: location, height: 120)
                
                Button(action: {
                    openInMaps(location: location)
                }) {
                    HStack {
                        Image(systemName: "map")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                        Text("open_in_maps".localized)
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
    
    private func durationSection(_ task: TodoTask) -> some View {
        let hasActualDuration = task.completions[completionKey]?.actualDuration != nil
        let hasEstimatedDuration = task.hasDuration
        let actualDuration = task.completions[completionKey]?.actualDuration
        let estimatedDuration = task.duration
        
        return Group {
            if hasActualDuration {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("actual_duration".localized)
                            .font(.subheadline.weight(.medium))
                            .themedSecondaryText()
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Button("edit".localized) {
                                showingDurationPicker = true
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                            
                            Button("clear".localized) {
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
                    
                    if hasEstimatedDuration {
                        HStack {
                            Text("estimation_accuracy".localized)
                                .font(.caption)
                                .themedSecondaryText()
                            Spacer()
                            
                            let difference = actualDuration! - estimatedDuration
                            let isUnder = difference < 0
                            let percentage = abs(difference) / estimatedDuration * 100
                            
                            HStack(spacing: 4) {
                                Text(formatDuration(estimatedDuration))
                                    .font(.caption)
                                    .themedSecondaryText()
                                    .strikethrough()
                                
                                Text(isUnder ? "(-\(Int(percentage))%)" : "(+\(Int(percentage))%)")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(isUnder ? .green : .orange)
                            }
                        }
                    }
                }
            } else if hasEstimatedDuration {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("duration".localized)
                            .font(.subheadline.weight(.medium))
                            .themedSecondaryText()
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
                            Text("add_duration".localized)
                                .font(.caption)
                                .foregroundColor(.blue)
                            Spacer()
                        }
                        .padding(.top, 2)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("duration".localized)
                            .font(.subheadline.weight(.medium))
                            .themedSecondaryText()
                        Spacer()
                        Text("none".localized)
                            .font(.subheadline)
                            .themedSecondaryText()
                    }
                    
                    Button(action: {
                        showingDurationPicker = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 12))
                            Text("add_duration".localized)
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
        DetailCard(icon: "repeat", title: "recurrence".localized, color: .purple) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("patterns_enum".localized)
                        .font(.subheadline.weight(.medium))
                        .themedSecondaryText()
                    Spacer()
                    Text(recurrenceDescription(recurrence))
                        .font(.subheadline)
                        .themedPrimaryText()
                }
                
                if let endDate = recurrence.endDate {
                    HStack {
                        Text("end_date".localized)
                            .font(.subheadline.weight(.medium))
                            .themedSecondaryText()
                        Spacer()
                        Text(endDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                            .themedPrimaryText()
                    }
                }
                
                HStack {
                    Text("current_streak".localized)
                        .font(.subheadline.weight(.medium))
                        .themedSecondaryText()
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
        DetailCard(icon: "checklist", title: "subtasks".localized, color: .indigo) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(task.subtasks) { subtask in
                    subtaskRow(task, subtask)
                }
            }
        }
    }
    
    private func subtaskRow(_ task: TodoTask, _ subtask: Subtask) -> some View {
        HStack {
            let isCompleted = task.completions[completionKey]?.completedSubtasks.contains(subtask.id) == true
            
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundColor(isCompleted ? .green : theme.secondaryTextColor)
            
            Text(subtask.name)
                .font(.body)
                .themedPrimaryText()
                .strikethrough(isCompleted)
            
            Spacer()
        }
    }
    
    private func pomodoroCard(_ task: TodoTask, _ pomodoroSettings: PomodoroSettings) -> some View {
        DetailCard(icon: "timer", title: "pomodoro".localized, color: .red) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("work_duration".localized)
                        .font(.subheadline.weight(.medium))
                        .themedSecondaryText()
                    Spacer()
                    Text("\(Int(pomodoroSettings.workDuration / 60)) min")
                        .font(.subheadline)
                        .themedPrimaryText()
                }
                
                HStack {
                    Text("break_time".localized)
                        .font(.subheadline.weight(.medium))
                        .themedSecondaryText()
                    Spacer()
                    Text("\(Int(pomodoroSettings.breakDuration / 60)) min")
                        .font(.subheadline)
                        .themedPrimaryText()
                }
                
                Button(action: {
                    PomodoroViewModel.shared.setActiveTask(task)
                    showingPomodoro = true
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("start_pomodoro".localized)
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundColor(theme.backgroundColor)
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
                    .shadow(color: Color.red.opacity(colorScheme == .dark ? 0.4 : 0.3), radius: colorScheme == .dark ? 4 : 6, x: 0, y: colorScheme == .dark ? 2 : 3)
                }
                .padding(.top, 8)
            }
        }
    }
    
    private func rewardsCard(_ task: TodoTask) -> some View {
        DetailCard(icon: "star", title: "rewards".localized, color: .yellow) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("available_points".localized)
                        .font(.subheadline.weight(.medium))
                        .themedSecondaryText()
                    Text("\(task.rewardPoints) \(("points".localized))")
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
        DetailCard(icon: "note.text", title: "notes".localized, color: .purple) {
            TaskNotesSection(
                notes: Binding(
                    get: { task.completions[completionKey]?.notes ?? "" },
                    set: { newValue in
                        updateLocalTaskRating(notes: newValue, updateNotes: true)
                    }
                )
            )
        }
    }
    
    private func actionButtons(_ task: TodoTask) -> some View {
        VStack(spacing: 0) {
            if !isEditingVoiceMemo {
                LinearGradient(
                    colors: [
                        theme.backgroundColor.opacity(0),
                        theme.backgroundColor.opacity(0.8),
                        theme.backgroundColor
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
                .background(theme.backgroundColor)
            }
        }
    }
    
    private func trackButton(_ task: TodoTask) -> some View {
        Button(action: {
            showingTrackingModeSelection = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .medium))
                Text("track".localized)
                    .font(.headline)
            }
            .themedButtonText()
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
            TaskManager.shared.toggleTaskCompletion(task.id, on: fixedDate)
        }) {
            HStack(spacing: 8) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .medium))
                Text(isCompleted ? "mark_incomplete".localized : "done".localized)
                    .font(.headline)
            }
            .themedButtonText()
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
                Text("edit".localized)
                    .font(.headline)
            }
            .themedButtonText()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(theme.gradient)
            .cornerRadius(16)
            .shadow(color: theme.primaryColor.opacity(0.3), radius: 8, x: 0, y: 4)
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
                            .themedSecondaryText()
                        
                        Spacer()
                        
                        if let difficultyRating = task.completions[completionKey]?.difficultyRating, difficultyRating > 0 {
                            Button("Clear") {
                                updateLocalTaskRating(difficultyRating: 0, updateDifficulty: true)
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        } else if !isCompleted {
                            Text("Rate after completing")
                                .font(.caption)
                                .themedSecondaryText()
                                .italic()
                        }
                    }
                    
                    DifficultyRatingView(
                        rating: Binding(
                            get: { task.completions[completionKey]?.difficultyRating ?? 0 },
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
                            .themedSecondaryText()
                        
                        Spacer()

                        
                        if let qualityRating = task.completions[completionKey]?.qualityRating, qualityRating > 0 {
                            Button("Clear") {
                                updateLocalTaskRating(qualityRating: 0, updateQuality: true)
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        } else if !isCompleted {
                            Text("Rate after completing")
                                .font(.caption)
                                .themedSecondaryText()
                                .italic()
                        }
                    }
                    
                    QualityRatingView(
                        rating: Binding(
                            get: { task.completions[completionKey]?.qualityRating ?? 0 },
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
    
    private func photoCard(_ task: TodoTask) -> some View {
        DetailCard(icon: "photo", title: "Photos", color: .blue) {
            VStack(alignment: .leading, spacing: 12) {
                if !task.photos.isEmpty {
                    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(task.photos) { photo in
                            ZStack(alignment: .topTrailing) {
                                if let image = AttachmentService.loadImage(from: photo.thumbnailPath) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 90)
                                        .frame(maxWidth: .infinity)
                                        .clipped()
                                        .cornerRadius(10)
                                        .onTapGesture {
                                            fullScreenPhoto = photo
                                        }
                                } else {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(height: 90)
                                }
                                
                                Button {
                                    removePhoto(photo, from: task)
                                } label: {
                                    Image(systemName: "trash.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.red)
                                        .background(
                                            Circle()
                                                .fill(Color.white)
                                                .frame(width: 16, height: 16)
                                                .opacity(0.001)
                                        )
                                }
                                .padding(6)
                            }
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Button {
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                showingCameraPicker = true
                            }
                        } label: {
                            HStack {
                                Image(systemName: "camera")
                                    .font(.system(size: 16))
                                Text("Take Photo")
                                    .font(.subheadline.weight(.medium))
                            }
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.blue.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        
                        PhotosPicker(
                            selection: $selectedPhotoItems,
                            maxSelectionCount: 10,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            HStack {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                                Text("Add Photos")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.blue.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                } else if let thumbPath = task.photoThumbnailPath, let image = AttachmentService.loadImage(from: thumbPath) {
                    HStack(spacing: 12) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 90, height: 90)
                            .clipped()
                            .cornerRadius(10)
//                            .onTapGesture {
//                                showingFullImage = true
//                            }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                    showingCameraPicker = true
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "camera")
                                        .font(.system(size: 14))
                                    Text("Take Photo")
                                        .font(.subheadline.weight(.medium))
                                }
                                .foregroundColor(.blue)
                            }
                            
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                                HStack {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 14))
                                    Text("Change Photo")
                                        .font(.subheadline.weight(.medium))
                                }
                                .foregroundColor(.blue)
                            }
                            
                            Button {
                                removeLegacyPhoto(task)
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14))
                                    Text("Remove Photo")
                                        .font(.subheadline.weight(.medium))
                                }
                                .foregroundColor(.red)
                            }
                        }
                        
                        Spacer()
                    }
                } else {
                    VStack(spacing: 8) {
                        Button {
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                showingCameraPicker = true
                            }
                        } label: {
                            HStack {
                                Image(systemName: "camera")
                                    .font(.system(size: 16))
                                Text("Take Photo")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.blue.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        
                        PhotosPicker(
                            selection: $selectedPhotoItems,
                            maxSelectionCount: 10,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            HStack {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                                Text("Add Photos")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.blue.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .onChange(of: selectedPhotoItems) { _, newItems in
                if !newItems.isEmpty {
                    Task {
                        await handlePickedPhotos(newItems, task: task)
                        selectedPhotoItems.removeAll()
                    }
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                if let item = newItem {
                    Task {
                        await handlePickedPhoto(item, task: task)
                    }
                }
            }
        }
    }
    
    private func handlePickedPhoto(_ item: PhotosPickerItem, task: TodoTask) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        guard let result = AttachmentService.savePhoto(for: task.id, imageData: data) else { return }
        
        var updated = task
        updated.photoPath = result.photoPath
        updated.photoThumbnailPath = result.thumbnailPath
        if updated.photos.isEmpty, let added = AttachmentService.addPhoto(for: task.id, imageData: data) {
            updated.photos.append(added)
        }
        updated.lastModifiedDate = Date()
        localTask = updated
        await TaskManager.shared.updateTask(updated)
        selectedPhotoItem = nil
    }
    
    private func handlePickedPhotos(_ items: [PhotosPickerItem], task: TodoTask) async {
        var updated = task
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let added = AttachmentService.addPhoto(for: task.id, imageData: data) {
                updated.photos.append(added)
                if updated.photoPath == nil {
                    if let legacy = AttachmentService.savePhoto(for: task.id, imageData: data) {
                        updated.photoPath = legacy.photoPath
                        updated.photoThumbnailPath = legacy.thumbnailPath
                    }
                }
            }
        }
        updated.lastModifiedDate = Date()
        localTask = updated
        await TaskManager.shared.updateTask(updated)
    }
    
    private func handleCapturedImage(_ image: UIImage, task: TodoTask) async {
        guard let data = image.jpegData(compressionQuality: 0.9) ?? image.pngData() else { return }
        if let added = AttachmentService.addPhoto(for: task.id, imageData: data) {
            var updated = task
            updated.photos.append(added)
            if updated.photoPath == nil {
                if let legacy = AttachmentService.savePhoto(for: task.id, imageData: data) {
                    updated.photoPath = legacy.photoPath
                    updated.photoThumbnailPath = legacy.thumbnailPath
                }
            }
            updated.lastModifiedDate = Date()
            localTask = updated
            await TaskManager.shared.updateTask(updated)
        }
    }
    
    private func removeLegacyPhoto(_ task: TodoTask) {
        AttachmentService.deletePhoto(for: task.id)
        var updated = task
        updated.photoPath = nil
        updated.photoThumbnailPath = nil
        updated.lastModifiedDate = Date()
        localTask = updated
        Task {
            await TaskManager.shared.updateTask(updated)
        }
    }
    
    private func removePhoto(_ photo: TaskPhoto, from task: TodoTask) {
        AttachmentService.deletePhoto(for: task.id, photo: photo)
        var updated = task
        updated.photos.removeAll { $0.id == photo.id }
        updated.lastModifiedDate = Date()
        localTask = updated
        Task {
            await TaskManager.shared.updateTask(updated)
        }
    }
    
    private func voiceMemosCard(_ task: TodoTask) -> some View {
        DetailCard(icon: "waveform", title: "Voice Memos", color: .pink) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Button {
                        if isRecordingVoice {
                            // Stop recording
                            if let memo = voiceMemoService.stopRecording() {
                                var updated = task
                                updated.voiceMemos.insert(memo, at: 0)
                                updated.lastModifiedDate = Date()
                                localTask = updated
                                Task {
                                    await TaskManager.shared.updateTask(updated)
                                }
                            }
                            isRecordingVoice = false
                        } else {
                            // Start recording
                            Task {
                                let granted = await voiceMemoService.requestPermission()
                                if !granted {
                                    showMicDeniedAlert = true
                                    return
                                }
                                do {
                                    try voiceMemoService.startRecording(for: task.id)
                                    isRecordingVoice = true
                                } catch {
                                    isRecordingVoice = false
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: isRecordingVoice ? "stop.circle.fill" : "record.circle.fill")
                                .font(.system(size: 16))
                            Text(isRecordingVoice ? "Stop" : "Record")
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.9)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isRecordingVoice ? Color.orange : Color.red)
                        )
                    }
                    .frame(minWidth: 110)
                    
                    Spacer()
                }
                
                if isRecordingVoice {
                    VStack(alignment: .leading, spacing: 6) {
                        WaveformView(levels: voiceMemoService.meterLevels, color: .pink)
                            .frame(height: 40)
                        Text("Recording...")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .transition(.opacity)
                }

                if task.voiceMemos.isEmpty {
                    Text("No voice memos yet.")
                        .font(.subheadline)
                        .themedSecondaryText()
                } else {
                    VStack(spacing: 8) {
                        ForEach(task.voiceMemos) { memo in
                            VoiceMemoRow(
                                memo: memo,
                                onDelete: {
                                    removeVoiceMemo(memo, from: task)
                                },
                                onRename: { newName in
                                    renameMemo(memo, to: newName, from: task)
                                },
                                onEditingStateChanged: { editing in
                                    isEditingVoiceMemo = editing
                                }
                            )
                        }
                    }
                }
            }
        }
    }
    
    private func removeVoiceMemo(_ memo: TaskVoiceMemo, from task: TodoTask) {
        voiceMemoService.deleteMemo(memo)
        var updated = task
        updated.voiceMemos.removeAll { $0.id == memo.id }
        updated.lastModifiedDate = Date()
        localTask = updated
        Task {
            await TaskManager.shared.updateTask(updated)
        }
    }
    
    private func renameMemo(_ memo: TaskVoiceMemo, to newName: String, from task: TodoTask) {
        let renamedMemo = voiceMemoService.renameMemo(memo, to: newName)
        var updated = task
        if let index = updated.voiceMemos.firstIndex(where: { $0.id == memo.id }) {
            updated.voiceMemos[index] = renamedMemo
        }
        updated.lastModifiedDate = Date()
        localTask = updated
        Task {
            await TaskManager.shared.updateTask(updated)
        }
    }
}

private struct VoiceMemoRow: View {
    let memo: TaskVoiceMemo
    let onDelete: () -> Void
    let onRename: (String) -> Void
    let onEditingStateChanged: (Bool) -> Void
    @StateObject private var player = AudioPlayerObject()
    @State private var waveform: [Float] = []
    @State private var isLoadingWaveform = true
    @State private var isEditing = false
    @State private var editingText = ""

    var body: some View {
        HStack {
            Button {
                if player.isPlaying {
                    player.pause()
                } else {
                    player.play(path: memo.audioPath)
                }
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.blue)
            }
            .disabled(isEditing)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if isEditing {
                        TextField("Nome memo vocale", text: $editingText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.subheadline.weight(.medium))
                            .onSubmit {
                                saveName()
                            }
                        
                        Button("Salva") {
                            saveName()
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        
                        Button("Annulla") {
                            cancelEditing()
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    } else {
                        HStack(spacing: 4) {
                            Text(memo.displayName)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                            
                            Button(action: {
                                startEditing()
                            }) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        Spacer()
                        
                        if player.isPlaying || player.currentTime > 0 {
                            Text("\(formatTime(player.currentTime)) / \(formatTime(memo.duration))")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                if !isEditing {
                    Text(formatted(duration: memo.duration) + " • " + memo.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    WaveformWithProgress(
                        levels: waveform, 
                        color: .blue, 
                        progress: memo.duration > 0 ? player.currentTime / memo.duration : 0,
                        onScrub: { p in
                            let t = max(0, min(memo.duration, p * memo.duration))
                            player.seek(to: t)
                        }
                    )
                    .frame(height: 28)
                }
            }
            
            if !isEditing {
                Spacer()

                Button {
                    player.stop()
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10).fill(Color.blue.opacity(0.05))
        )
        .onAppear {
            player.prepare(path: memo.audioPath)
            if waveform.isEmpty {
                let path = memo.audioPath
                Task {
                    let samples = await WaveformGenerator.generate(from: URL(fileURLWithPath: path), samples: 60)
                    await MainActor.run {
                        self.waveform = samples.isEmpty ? Array(repeating: 0.2, count: 60) : samples
                        self.isLoadingWaveform = false
                    }
                }
            } else {
                isLoadingWaveform = false
            }
        }
    }
    
    private func startEditing() {
        editingText = memo.name ?? ""
        isEditing = true
        onEditingStateChanged(true)
    }
    
    private func saveName() {
        onRename(editingText)
        isEditing = false
        onEditingStateChanged(false)
    }
    
    private func cancelEditing() {
        editingText = ""
        isEditing = false
        onEditingStateChanged(false)
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    private func formatted(duration: TimeInterval) -> String {
        let h = Int(duration) / 3600
        let m = (Int(duration) % 3600) / 60
        let s = Int(duration) % 60
        if h > 0 {
            return String(format: "%dh %02dm %02ds", h, m, s)
        } else {
            return String(format: "%02dm %02ds", m, s)
        }
    }
}

private final class AudioPlayerObject: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var lastURL: URL?

    func prepare(path: String) {
        let url = URL(fileURLWithPath: path)
        if let existing = lastURL, existing == url, player != nil {
            duration = player?.duration ?? duration
            return
        }
        do {
            lastURL = url
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            duration = player?.duration ?? 0
            currentTime = 0
        } catch {
            player = nil
            duration = 0
            currentTime = 0
        }
    }

    func play(path: String) {
        if let p = player, let last = lastURL, last.path == path {
            if !p.isPlaying {
                p.play()
                isPlaying = true
                startTimer()
            }
            return
        }
        
        let url = URL(fileURLWithPath: path)
        lastURL = url
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            duration = player?.duration ?? 0
            player?.play()
            isPlaying = true
            startTimer()
        } catch {
            isPlaying = false
        }
    }

    func seek(to time: TimeInterval) {
        if player == nil, let url = lastURL {
            player = try? AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            duration = player?.duration ?? 0
        }
        guard let p = player else { return }
        let clamped = max(0, min(time, p.duration))
        p.currentTime = clamped
        currentTime = clamped
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        stopTimer()
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let player = self.player else { return }
            self.currentTime = player.currentTime
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.currentTime = 0
            self.stopTimer()
        }
    }
}

private struct WaveformWithProgress: View {
    let levels: [Float]
    var color: Color = .blue
    var spacing: CGFloat = 2
    let progress: Double 
    var onScrub: ((Double) -> Void)? = nil
    
    var body: some View {
        GeometryReader { geo in
            let count = max(1, levels.count)
            let totalSpacing = spacing * CGFloat(max(0, count - 1))
            let barWidth = max(1, (geo.size.width - totalSpacing) / CGFloat(count))
            let progressIndex = Int(Double(count) * progress)
            
            ZStack {
                HStack(alignment: .center, spacing: spacing) {
                    ForEach(0..<count, id: \.self) { i in
                        let raw = (i < levels.count) ? levels[i] : 0
                        let level = max(0, min(1, raw))
                        let h = max(2, CGFloat(level) * geo.size.height)
                        
                        Capsule(style: .continuous)
                            .fill(i <= progressIndex ? color : color.opacity(0.3))
                            .frame(width: barWidth, height: h)
                            .frame(height: geo.size.height, alignment: .center)
                    }
                }
                
                ZStack {
                    Capsule()
                        .fill(color.opacity(0.6))
                        .frame(width: 4, height: geo.size.height + 4)
                        .blur(radius: 1)
                    
                    Capsule()
                        .fill(color)
                        .frame(width: 2, height: geo.size.height)
                    
                }
                .position(x: progress * geo.size.width, y: geo.size.height / 2)
                .animation(.easeOut(duration: 0.1), value: progress) 

                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let p = max(0, min(1, value.location.x / geo.size.width))
                                onScrub?(p)
                            }
                            .onEnded { value in
                                let p = max(0, min(1, value.location.x / geo.size.width))
                                onScrub?(p)
                            }
                    )
            }
        }
        .drawingGroup()
    }
}

private struct DetailCard<Content: View>: View {
    let icon: String
    let title: String
    let color: Color
    let content: Content
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.theme) private var theme
    
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
                    .themedPrimaryText()
            }
            
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .themedCard()
    }
}

private struct TaskPerformanceChartView: View {
    let task: TodoTask
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
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
            .themedBackground()
            .navigationTitle("performance_charts".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .themedPrimary()
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
                Text("time_range".localized)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .themedPrimaryText()
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
                            .foregroundColor(selectedTimeRange == range ? theme.primaryColor : theme.textColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedTimeRange == range ? theme.primaryColor.opacity(0.15) : theme.surfaceColor)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(selectedTimeRange == range ? theme.primaryColor : Color.clear, lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .themedCard()
    }
    
    private func loadTaskAnalytics() {
        let completionAnalytics = task.completions.compactMap { (date, completion) -> StatisticsViewModel.TaskCompletionAnalytics? in
            guard completion.isCompleted else { return nil }
            
            return StatisticsViewModel.TaskCompletionAnalytics(
                date: date,
                actualDuration: completion.actualDuration,
                difficultyRating: completion.difficultyRating,
                qualityRating: completion.qualityRating,
                estimatedDuration: task.hasDuration ? task.duration : nil,
                wasTracked: false
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
                improvementTrend: .stable
            )
        }
    }
    
    private var emptyDataStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("no_data".localized)
                .font(.title3.bold())
            
            VStack(spacing: 8) {
                Text("This task has no performance data for the selected time period.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
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
                .fill(theme.surfaceColor)
                .shadow(color: theme.shadowColor, radius: 8, x: 0, y: 2)
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
                        .themedPrimaryText()
                    
                    if let categoryName = analytics.categoryName {
                        Text(categoryName)
                            .font(.subheadline)
                            .themedSecondaryText()
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
                        value: formatted(duration: avgDuration),
                        color: .green,
                        icon: "clock.fill"
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.surfaceColor)
                .shadow(color: theme.shadowColor, radius: 8, x: 0, y: 2)
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
                Text("quality_trend".localized)
                    .font(.headline)
                    .themedPrimaryText()
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
                .chartXAxisLabel("date".localized, position: .bottom)
                .chartYAxisLabel("quality_rating".localized, position: .leading)
            } else {
                VStack(spacing: 8) {
                    Text("no_quality_ratings_in_period".localized("\(selectedTimeRange.rawValue)"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("complete_tasks_add_quality_ratings".localized)
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
                .fill(theme.surfaceColor)
                .shadow(color: theme.shadowColor, radius: 8, x: 0, y: 2)
        )
    }
    
    private func difficultyChartSection(_ analytics: StatisticsViewModel.TaskPerformanceAnalytics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.orange)
                Text("difficulty_trend".localized)
                    .font(.headline)
                    .themedPrimaryText()
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
                .chartXAxisLabel("date".localized, position: .bottom)
                .chartYAxisLabel("difficulty_rating".localized, position: .leading)
            } else {
                VStack(spacing: 8) {
                    Text("no_difficulty_ratings_in_period".localized("\(selectedTimeRange.rawValue)"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("complete_tasks_add_difficulty_ratings".localized)
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
                .fill(theme.surfaceColor)
                .shadow(color: theme.shadowColor, radius: 8, x: 0, y: 2)
        )
    }
    
    private func formatChartDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        switch selectedTimeRange {
        case .week:
            formatter.dateFormat = "E dd"
        case .month:
            formatter.dateFormat = "dd MMM"
        case .year:
            formatter.dateFormat = "MMM yyyy"
        case .all:
            let calendar = Calendar.current
            let now = Date()
            let daysDiff = calendar.dateComponents([.day], from: date, to: now).day ?? 0
            
            if daysDiff <= 30 {
                formatter.dateFormat = "dd MMM"
            } else if daysDiff <= 365 {
                formatter.dateFormat = "MMM yyyy"
            } else {
                formatter.dateFormat = "yyyy"
            }
        }
        
        return formatter.string(from: date)
    }
    
    private func completionsSection(_ analytics: StatisticsViewModel.TaskPerformanceAnalytics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(.blue)
                Text("completions_period".localized("\(selectedTimeRange.rawValue)"))
                    .font(.headline)
                    .themedPrimaryText()
                Spacer()
            }
            
            if analytics.completions.isEmpty {
                VStack(spacing: 8) {
                    Text("no_completions_in_period".localized("\(selectedTimeRange.rawValue)"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("complete_this_task_start_tracking".localized)
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
                .fill(theme.surfaceColor)
                .shadow(color: theme.shadowColor, radius: 8, x: 0, y: 2)
        )
    }
    
    private func formatted(duration: TimeInterval) -> String {
        let h = Int(duration) / 3600
        let m = (Int(duration) % 3600) / 60
        let s = Int(duration) % 60
        if h > 0 {
            return String(format: "%dh %02dm %02ds", h, m, s)
        } else {
            return String(format: "%02dm %02ds", m, s)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("no_completion_data".localized)
                .font(.title2.bold())
            
            Text("complete_recurring_tasks_performance".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.surfaceColor)
                .shadow(color: theme.shadowColor, radius: 8, x: 0, y: 2)
        )
    }
}

private struct TaskDetailMetricCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3.bold())
                    .themedPrimaryText()
                
                Text(title)
                    .font(.caption)
                    .themedSecondaryText()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.surfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

private struct CompletionDetailRow: View {
    let completion: StatisticsViewModel.TaskCompletionAnalytics
    @Environment(\.theme) private var theme
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(completion.date.formatted(.dateTime.month().day().year()))
                    .font(.subheadline.weight(.medium))
                    .themedPrimaryText()
                
                Text(completion.date.formatted(.dateTime.hour().minute()))
                    .font(.caption)
                    .themedSecondaryText()
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                if let duration = completion.actualDuration {
                    MetricBadge(
                        icon: "clock.fill",
                        value: formatted(duration: duration),
                        color: .green
                    )
                }
                
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
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.surfaceColor.opacity(0.5))
        )
    }
    
    private func formatted(duration: TimeInterval) -> String {
        let h = Int(duration) / 3600
        let m = (Int(duration) % 3600) / 60
        let s = Int(duration) % 60
        if h > 0 {
            return String(format: "%dh %02dm %02ds", h, m, s)
        } else {
            return String(format: "%02dm %02ds", m, s)
        }
    }
}

private struct MetricBadge: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
            Text(value)
                .font(.caption.weight(.medium))
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(0.1))
        )
    }
}

#Preview {
    NavigationStack {
        TaskDetailView(taskId: UUID(), targetDate: nil)
    }
}