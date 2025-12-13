import SwiftUI

struct WatchStatisticsView: View {
    @EnvironmentObject var syncManager: WatchSyncManager
    @State private var selectedTimeRange: TimeRange = .week
    
    enum TimeRange: String, CaseIterable {
        case today = "Today"
        case week = "Week"
        case month = "Month"
        
        var days: Int {
            switch self {
            case .today: return 1
            case .week: return 7
            case .month: return 30
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Time range picker
                timeRangePicker
                
                // Time Distribution by Category
                timeDistributionCard
                
                // Task Completion
                taskCompletionCard
                
                // Streak
                streakCard
            }
            .padding(.horizontal, 8)
        }
        .navigationTitle("Stats")
    }
    
    private var timeRangePicker: some View {
        HStack(spacing: 4) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button {
                    selectedTimeRange = range
                } label: {
                    Text(range.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(selectedTimeRange == range ? Color.blue : Color.gray.opacity(0.3))
                        .foregroundColor(selectedTimeRange == range ? .white : .primary)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Time Distribution Card
    private var timeDistributionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Time Distribution")
                .font(.caption)
                .fontWeight(.semibold)
            
            let categoryStats = calculateCategoryStats()
            
            if categoryStats.isEmpty {
                emptyStateView(icon: "chart.pie", message: "No data yet")
            } else {
                // Mini pie chart representation
                VStack(spacing: 6) {
                    // Horizontal bar representation (better for small screen)
                    GeometryReader { geo in
                        HStack(spacing: 1) {
                            ForEach(categoryStats, id: \.name) { stat in
                                Rectangle()
                                    .fill(Color(hex: stat.color))
                                    .frame(width: max(4, geo.size.width * CGFloat(stat.percentage)))
                            }
                        }
                        .cornerRadius(4)
                    }
                    .frame(height: 12)
                    
                    // Legend
                    ForEach(categoryStats.prefix(4), id: \.name) { stat in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: stat.color))
                                .frame(width: 8, height: 8)
                            
                            Text(stat.name)
                                .font(.caption2)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(formatDuration(stat.minutes))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(10)
    }
    
    // MARK: - Task Completion Card
    private var taskCompletionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Task Completion")
                .font(.caption)
                .fontWeight(.semibold)
            
            let stats = calculateCompletionStats()
            
            HStack(spacing: 16) {
                // Completion rate
                VStack(spacing: 2) {
                    Text("\(stats.completionRate)%")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundColor(.green)
                    
                    Text("Rate")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .frame(height: 30)
                
                // Completed / Total
                VStack(spacing: 2) {
                    Text("\(stats.completed)/\(stats.total)")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                    
                    Text("Tasks")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            
            // Mini bar chart for last 7 days
            if selectedTimeRange == .week {
                HStack(spacing: 2) {
                    ForEach(0..<7, id: \.self) { dayOffset in
                        let dayStats = getDayCompletionStats(daysAgo: 6 - dayOffset)
                        VStack(spacing: 2) {
                            Rectangle()
                                .fill(dayStats.rate > 0 ? Color.green : Color.gray.opacity(0.3))
                                .frame(height: CGFloat(max(4, dayStats.rate * 20)))
                            
                            Text(dayLabel(daysAgo: 6 - dayOffset))
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(height: 40)
            }
        }
        .padding(10)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(10)
    }
    
    // MARK: - Streak Card
    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Streak")
                .font(.caption)
                .fontWeight(.semibold)
            
            let streakData = calculateStreak()
            
            HStack(spacing: 16) {
                // Current streak
                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("\(streakData.current)")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                    }
                    
                    Text("Current")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .frame(height: 30)
                
                // Best streak
                VStack(spacing: 2) {
                    Text("\(streakData.best)")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundColor(.red)
                    
                    Text("Best")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(10)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(10)
    }
    
    // MARK: - Helper Views
    private func emptyStateView(icon: String, message: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.secondary)
            Text(message)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
    
    // MARK: - Calculations
    private struct CategoryStat {
        let name: String
        let color: String
        let minutes: Int
        let percentage: Double
    }
    
    private func calculateCategoryStats() -> [CategoryStat] {
        var categoryMinutes: [UUID: (name: String, color: String, minutes: Int)] = [:]
        let calendar = Calendar.current
        let now = Date()
        
        // Calculate based on task durations and completions
        for task in syncManager.tasks {
            guard let category = task.category else { continue }
            
            for (date, completion) in task.completions {
                let daysAgo = calendar.dateComponents([.day], from: date, to: now).day ?? 0
                
                if daysAgo < selectedTimeRange.days && completion.isCompleted {
                    let duration = Int(task.duration / 60) // Convert to minutes
                    let current = categoryMinutes[category.id] ?? (name: category.name, color: category.color, minutes: 0)
                    categoryMinutes[category.id] = (current.name, current.color, current.minutes + max(duration, 15))
                }
            }
        }
        
        let totalMinutes = categoryMinutes.values.reduce(0) { $0 + $1.minutes }
        guard totalMinutes > 0 else { return [] }
        
        return categoryMinutes.values
            .map { CategoryStat(name: $0.name, color: $0.color, minutes: $0.minutes, percentage: Double($0.minutes) / Double(totalMinutes)) }
            .sorted { $0.minutes > $1.minutes }
    }
    
    private struct CompletionStats {
        let completed: Int
        let total: Int
        let completionRate: Int
    }
    
    private func calculateCompletionStats() -> CompletionStats {
        let calendar = Calendar.current
        let now = Date()
        var completed = 0
        var total = 0
        
        for dayOffset in 0..<selectedTimeRange.days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            
            for task in syncManager.tasks {
                // Check if task should appear on this day
                let shouldAppear: Bool
                if let recurrence = task.recurrence {
                    shouldAppear = recurrence.shouldOccurOn(date: date)
                } else {
                    shouldAppear = calendar.isDate(task.startTime, inSameDayAs: date)
                }
                
                if shouldAppear {
                    total += 1
                    if task.completions[startOfDay]?.isCompleted == true {
                        completed += 1
                    }
                }
            }
        }
        
        let rate = total > 0 ? Int(Double(completed) / Double(total) * 100) : 0
        return CompletionStats(completed: completed, total: total, completionRate: rate)
    }
    
    private func getDayCompletionStats(daysAgo: Int) -> (completed: Int, total: Int, rate: Double) {
        let calendar = Calendar.current
        guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) else {
            return (0, 0, 0)
        }
        let startOfDay = calendar.startOfDay(for: date)
        
        var completed = 0
        var total = 0
        
        for task in syncManager.tasks {
            let shouldAppear: Bool
            if let recurrence = task.recurrence {
                shouldAppear = recurrence.shouldOccurOn(date: date)
            } else {
                shouldAppear = calendar.isDate(task.startTime, inSameDayAs: date)
            }
            
            if shouldAppear {
                total += 1
                if task.completions[startOfDay]?.isCompleted == true {
                    completed += 1
                }
            }
        }
        
        let rate = total > 0 ? Double(completed) / Double(total) : 0
        return (completed, total, rate)
    }
    
    private func dayLabel(daysAgo: Int) -> String {
        let calendar = Calendar.current
        guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) else { return "" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(1))
    }
    
    private struct StreakData {
        let current: Int
        let best: Int
    }
    
    private func calculateStreak() -> StreakData {
        let calendar = Calendar.current
        var currentStreak = 0
        var bestStreak = 0
        var tempStreak = 0
        
        // Check last 365 days
        for dayOffset in 0..<365 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            
            var dayHadTasks = false
            var dayCompleted = true
            
            for task in syncManager.tasks {
                let shouldAppear: Bool
                if let recurrence = task.recurrence {
                    shouldAppear = recurrence.shouldOccurOn(date: date)
                } else {
                    shouldAppear = calendar.isDate(task.startTime, inSameDayAs: date)
                }
                
                if shouldAppear {
                    dayHadTasks = true
                    if task.completions[startOfDay]?.isCompleted != true {
                        dayCompleted = false
                    }
                }
            }
            
            if dayHadTasks && dayCompleted {
                tempStreak += 1
                if dayOffset == currentStreak {
                    currentStreak = tempStreak
                }
            } else if dayHadTasks {
                bestStreak = max(bestStreak, tempStreak)
                tempStreak = 0
            }
        }
        
        bestStreak = max(bestStreak, tempStreak)
        return StreakData(current: currentStreak, best: bestStreak)
    }
    
    private func formatDuration(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
        return "\(minutes)m"
    }
}

#Preview {
    WatchStatisticsView()
        .environmentObject(WatchSyncManager.shared)
}
