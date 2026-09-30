import SwiftUI

struct WatchTaskDetailView: View {
    let task: TodoTask
    @EnvironmentObject var syncManager: WatchSyncManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showingTimerSelection = false
    @State private var showingCompletionReview = false
    
    private var selectedDate: Date { Date() }
    
    private var isCompleted: Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        return task.completions[startOfDay]?.isCompleted == true
    }
    
    private var completion: TaskCompletion? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        return task.completions[startOfDay]
    }
    
    private var categoryColor: Color {
        if let colorHex = task.category?.color {
            return Color(hex: colorHex)
        }
        return .gray
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                // MARK: - Header Card
                headerCard
                
                // MARK: - Details Card
                if hasDetails {
                    detailsCard
                }
                
                // MARK: - Subtasks Card
                if !task.subtasks.isEmpty {
                    subtasksCard
                }
                
                if let completion, hasCompletionInsights(completion) {
                    completionInsightsCard(completion)
                }
                
                if hasPerformanceHistory {
                    performanceSummaryCard
                }
                
                if hasMedia {
                    mediaCard
                }
                
                if let pomodoroSettings = task.pomodoroSettings {
                    pomodoroCard(pomodoroSettings)
                }
                
                // MARK: - Actions
                actionsCard
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle(task.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEditSheet) {
            WatchTaskFormView(mode: .edit(task))
        }
        .sheet(isPresented: $showingTimerSelection) {
            WatchTimerSelectionView(preselectedTask: task)
        }
        .sheet(isPresented: $showingCompletionReview) {
            WatchCompletionReviewView(task: task, selectedDate: selectedDate)
        }
        .confirmationDialog("Delete Task?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                syncManager.deleteTask(task)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
    
    private var hasDetails: Bool {
        (task.description != nil && !task.description!.isEmpty)
        || task.location != nil
        || task.hasSpecificTime
        || (task.hasDuration && task.duration > 0)
        || (task.hasRewardPoints && task.rewardPoints > 0)
        || task.hasNotification
        || task.recurrence != nil
        || task.timeScope != .today
        || task.totalTrackedTime > 0
    }
    
    private var hasMedia: Bool {
        !task.photos.isEmpty ||
        task.photoPath != nil ||
        task.photoThumbnailPath != nil ||
        !task.voiceMemos.isEmpty
    }
    
    private var hasPerformanceHistory: Bool {
        task.completions.values.contains { completion in
            completion.actualDuration != nil ||
            completion.difficultyRating != nil ||
            completion.qualityRating != nil
        }
    }
    
    // MARK: - Header Card
    private var headerCard: some View {
        VStack(spacing: 10) {
            // Icon + Name + Category
            HStack(spacing: 8) {
                Image(systemName: task.icon)
                    .font(.title3)
                    .foregroundColor(categoryColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.name)
                        .font(.system(.footnote, design: .rounded, weight: .semibold))
                        .lineLimit(2)
                    
                    if let category = task.category {
                        Text(category.name)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(categoryColor)
                    }
                }
                
                Spacer(minLength: 0)
                
                // Priority badge
                priorityBadge
            }
            
            // Completion toggle
            Button {
                syncManager.toggleTaskCompletion(task, on: selectedDate)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.body)
                    Text(isCompleted ? "Completed" : "Mark Complete")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .tint(isCompleted ? .green : .gray)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.gray.opacity(0.14))
        )
    }
    
    // MARK: - Priority Badge
    private var priorityBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: task.priority.icon)
                .font(.system(size: 9, weight: .bold))
            Text(task.priority.displayName)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
        }
        .foregroundColor(Color(hex: task.priority.color))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color(hex: task.priority.color).opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    // MARK: - Details Card
    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Description
            if let description = task.description, !description.isEmpty {
                Text(description)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(5)
            }
            
            if let location = task.location {
                detailRow(icon: "location.fill", text: location.shortDisplayName, color: .blue)
                
                if let address = location.address, !address.isEmpty {
                    Text(address)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                } else if let formattedAddress = location.placemark?.formattedAddress, !formattedAddress.isEmpty {
                    Text(formattedAddress)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                if let coordinate = location.coordinate {
                    detailRow(
                        icon: "map",
                        text: String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude),
                        color: .blue
                    )
                }
            }
            
            // Info row
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 6) {
                detailRow(icon: task.timeScope.icon, text: scopeSummary, color: Color(hex: task.timeScope.color))
                
                // Time
                if task.hasSpecificTime {
                    detailRow(icon: "clock", text: timeSummary, color: .secondary)
                }
                
                // Duration
                if task.hasDuration && task.duration > 0 {
                    detailRow(icon: "hourglass", text: formatDuration(task.duration), color: .secondary)
                }
                
                // Points
                if task.hasRewardPoints && task.rewardPoints > 0 {
                    detailRow(icon: "star.fill", text: "\(task.rewardPoints) pts", color: .yellow)
                }
                
                if task.hasNotification {
                    detailRow(icon: "bell.fill", text: notificationSummary, color: .orange)
                }
                
                if task.totalTrackedTime > 0 {
                    detailRow(icon: "stopwatch.fill", text: formatDuration(task.totalTrackedTime), color: .green)
                }
            }
            
            if let recurrence = task.recurrence {
                detailRow(icon: "repeat", text: recurrenceSummary(recurrence), color: .purple)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.gray.opacity(0.14))
        )
    }
    
    // MARK: - Subtasks Card
    private var subtasksCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Subtasks")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.bottom, 2)
            
            ForEach(task.subtasks) { subtask in
                Button {
                    syncManager.toggleSubtaskCompletion(task, subtaskId: subtask.id, on: selectedDate)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 14))
                            .foregroundColor(subtask.isCompleted ? .green : .secondary)
                        
                        Text(subtask.name)
                            .font(.system(.caption2, design: .rounded))
                            .strikethrough(subtask.isCompleted)
                            .foregroundColor(subtask.isCompleted ? .secondary : .primary)
                        
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.gray.opacity(0.14))
        )
    }
    
    private func completionInsightsCard(_ completion: TaskCompletion) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Completion")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 6) {
                if let actualDuration = completion.actualDuration, actualDuration > 0 {
                    detailRow(icon: "clock.badge.checkmark", text: formatDuration(actualDuration), color: .green)
                }
                
                if let difficulty = completion.difficultyRating {
                    detailRow(icon: "gauge.with.dots.needle.bottom.50percent", text: "Diff \(difficulty)/10", color: .orange)
                }
                
                if let quality = completion.qualityRating {
                    detailRow(icon: "sparkles", text: "Quality \(quality)/10", color: .purple)
                }
                
                if let completionDate = completion.completionDate {
                    detailRow(icon: "checkmark.circle.fill", text: shortDateTime(completionDate), color: .green)
                }
            }
            
            if let notes = completion.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.green.opacity(0.12))
        )
    }
    
    private var performanceSummaryCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Performance")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 6) {
                detailRow(icon: "checkmark.circle.fill", text: "\(completedCount) done", color: .green)
                
                if averageActualDuration > 0 {
                    detailRow(icon: "clock.badge.checkmark", text: "Avg \(formatDuration(averageActualDuration))", color: .green)
                }
                
                if averageDifficulty > 0 {
                    detailRow(icon: "gauge.with.dots.needle.bottom.50percent", text: "Diff \(String(format: "%.1f", averageDifficulty))/10", color: .orange)
                }
                
                if averageQuality > 0 {
                    detailRow(icon: "sparkles", text: "Quality \(String(format: "%.1f", averageQuality))/10", color: .purple)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.cyan.opacity(0.10))
        )
    }
    
    private var mediaCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Media")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 6) {
                let photoCount = task.photos.count + (task.photoPath == nil ? 0 : 1)
                if photoCount > 0 {
                    detailRow(icon: "photo.fill", text: "\(photoCount) photo", color: .blue)
                }
                
                if !task.voiceMemos.isEmpty {
                    detailRow(icon: "waveform", text: "\(task.voiceMemos.count) memo", color: .orange)
                }
                
                if let latestPhotoDate = task.photos.map(\.createdAt).max() {
                    detailRow(icon: "calendar", text: shortDate(latestPhotoDate), color: .blue)
                }
                
                let totalMemoDuration = task.voiceMemos.reduce(0) { $0 + $1.duration }
                if totalMemoDuration > 0 {
                    detailRow(icon: "timer", text: formatDuration(totalMemoDuration), color: .orange)
                }
            }
            
            if let latestMemo = task.voiceMemos.sorted(by: { $0.createdAt > $1.createdAt }).first {
                Text(latestMemo.displayName)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Text("Open iPhone to view or edit attachments")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.blue.opacity(0.10))
        )
    }
    
    private func pomodoroCard(_ settings: PomodoroSettings) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Pomodoro")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 6) {
                detailRow(icon: "timer", text: "\(Int(settings.workDuration / 60))m work", color: .red)
                detailRow(icon: "cup.and.saucer.fill", text: "\(Int(settings.breakDuration / 60))m break", color: .green)
                detailRow(icon: "repeat.circle.fill", text: "\(settings.totalSessions) sessions", color: .blue)
                detailRow(icon: "clock.fill", text: formatDuration(settings.estimatedTotalTime), color: .orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.red.opacity(0.10))
        )
    }
    
    // MARK: - Actions Card
    private var actionsCard: some View {
        VStack(spacing: 6) {
            // Start Timer
            Button {
                showingTimerSelection = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11))
                    Text("Start Timer")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
            
            Button {
                showingCompletionReview = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11))
                    Text("Review")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .tint(.green)
            
            // Edit & Delete row
            HStack(spacing: 6) {
                Button {
                    showingEditSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 10))
                        Text("Edit")
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .tint(.gray)
                
                Button {
                    showingDeleteConfirmation = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                        Text("Delete")
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
    }
    
    private func detailRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func hasCompletionInsights(_ completion: TaskCompletion) -> Bool {
        completion.actualDuration != nil ||
        completion.difficultyRating != nil ||
        completion.qualityRating != nil ||
        completion.completionDate != nil ||
        (completion.notes?.isEmpty == false)
    }
    
    private func shortDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private var completedCount: Int {
        task.completions.values.filter(\.isCompleted).count
    }
    
    private var averageActualDuration: TimeInterval {
        let durations = task.completions.values.compactMap(\.actualDuration)
        guard !durations.isEmpty else { return 0 }
        return durations.reduce(0, +) / Double(durations.count)
    }
    
    private var averageDifficulty: Double {
        let ratings = task.completions.values.compactMap(\.difficultyRating)
        guard !ratings.isEmpty else { return 0 }
        return Double(ratings.reduce(0, +)) / Double(ratings.count)
    }
    
    private var averageQuality: Double {
        let ratings = task.completions.values.compactMap(\.qualityRating)
        guard !ratings.isEmpty else { return 0 }
        return Double(ratings.reduce(0, +)) / Double(ratings.count)
    }
    
    private var scopeSummary: String {
        switch task.timeScope {
        case .today:
            return "Today"
        case .week:
            return "Week"
        case .month:
            return "Month"
        case .year:
            return "Year"
        case .longTerm:
            return "Long Term"
        case .inbox:
            return "Inbox"
        case .all:
            return "All"
        }
    }
    
    private var timeSummary: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: task.startTime)
    }
    
    private var notificationSummary: String {
        let minutes = task.notificationLeadTimeMinutes
        if minutes == 0 { return "At time" }
        let value = abs(minutes)
        let suffix = minutes < 0 ? "after" : "before"
        if value >= 60 {
            let hours = value / 60
            let remaining = value % 60
            if remaining == 0 { return "\(hours)h \(suffix)" }
            return "\(hours)h \(remaining)m \(suffix)"
        }
        return "\(value)m \(suffix)"
    }
    
    private func recurrenceSummary(_ recurrence: Recurrence) -> String {
        switch recurrence.type {
        case .daily:
            let interval = recurrence.dayInterval ?? 1
            return interval > 1 ? "Every \(interval) days" : "Daily"
        case .weekly(let days):
            let interval = recurrence.weekInterval ?? 1
            let base = interval > 1 ? "Every \(interval) weeks" : "Weekly"
            return days.isEmpty ? base : "\(base) · \(days.count)d"
        case .monthly(let days):
            let interval = recurrence.monthInterval ?? 1
            let base = interval > 1 ? "Every \(interval) months" : "Monthly"
            return days.isEmpty ? base : "\(base) · \(days.count)d"
        case .monthlyOrdinal(let patterns):
            let interval = recurrence.monthInterval ?? 1
            let base = interval > 1 ? "Every \(interval) months" : "Monthly"
            return patterns.isEmpty ? base : "\(base) · ordinal"
        case .yearly:
            let interval = recurrence.yearInterval ?? 1
            return interval > 1 ? "Every \(interval) years" : "Yearly"
        }
    }
}

private struct WatchCompletionReviewView: View {
    let task: TodoTask
    let selectedDate: Date
    @EnvironmentObject var syncManager: WatchSyncManager
    @Environment(\.dismiss) private var dismiss
    @State private var actualDurationMinutes: Int = 0
    @State private var difficultyRating: Int = 0
    @State private var qualityRating: Int = 0
    @State private var notes: String = ""
    
    var body: some View {
        NavigationStack {
            List {
                Section("Duration") {
                    Stepper(actualDurationText, value: $actualDurationMinutes, in: 0...720, step: 5)
                }
                
                Section("Ratings") {
                    Stepper(difficultyRating == 0 ? "Difficulty: -" : "Difficulty: \(difficultyRating)/10", value: $difficultyRating, in: 0...10)
                    Stepper(qualityRating == 0 ? "Quality: -" : "Quality: \(qualityRating)/10", value: $qualityRating, in: 0...10)
                }
                
                Section("Notes") {
                    TextField("Notes", text: $notes)
                }
                
                Section {
                    Button {
                        saveReview()
                    } label: {
                        Label("Save Review", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Review")
            .onAppear(perform: loadReview)
        }
    }
    
    private var actualDurationText: String {
        actualDurationMinutes == 0 ? "Actual: -" : "Actual: \(actualDurationMinutes)m"
    }
    
    private func loadReview() {
        let key = Calendar.current.startOfDay(for: selectedDate)
        guard let completion = task.completions[key] else { return }
        actualDurationMinutes = Int((completion.actualDuration ?? 0) / 60)
        difficultyRating = completion.difficultyRating ?? 0
        qualityRating = completion.qualityRating ?? 0
        notes = completion.notes ?? ""
    }
    
    private func saveReview() {
        syncManager.updateTaskCompletionReview(
            task,
            on: selectedDate,
            actualDuration: actualDurationMinutes > 0 ? TimeInterval(actualDurationMinutes * 60) : nil,
            difficultyRating: difficultyRating > 0 ? difficultyRating : nil,
            qualityRating: qualityRating > 0 ? qualityRating : nil,
            notes: notes
        )
        HapticService.shared.play(.notification)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        WatchTaskDetailView(
            task: TodoTask(
                name: "Test Task",
                description: "This is a test description",
                startTime: Date(),
                hasSpecificTime: true,
                duration: 3600,
                hasDuration: true,
                priority: .high,
                icon: "star.fill",
                subtasks: [
                    Subtask(name: "Subtask 1"),
                    Subtask(name: "Subtask 2", isCompleted: true)
                ],
                hasRewardPoints: true,
                rewardPoints: 10
            )
        )
        .environmentObject(WatchSyncManager.shared)
    }
}
