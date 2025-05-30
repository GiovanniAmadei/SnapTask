import SwiftUI

struct WatchStatisticsView: View {
    @StateObject private var taskManager = TaskManager.shared
    @StateObject private var rewardManager = RewardManager.shared
    @State private var selectedTimeRange: TimeRange = .week
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Time Range Picker - Keep this compact at the top of scrollable content
                VStack(spacing: 4) {
                    Text("Filter by Time Range") // Slightly more descriptive
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Picker("Time Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.displayName).tag(range)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 50) // Compact height for wheel picker
                }
                .padding(.horizontal, 8)
                .padding(.top, 8) // Add padding from global header
                
                // Quick Stats
                WatchQuickStats(
                    completedTasks: completedTasksCount,
                    totalTasks: totalTasksCount
                )
                
                // Completion Rate
                WatchCompletionRate(
                    completionRate: completionRate
                )
                
                // Points Summary
                WatchPointsSummary(rewardManager: rewardManager)
            }
            .padding(.vertical, 8) // General vertical padding for scroll content
        }
    }
    
    private var completedTasksCount: Int {
        let tasks = getTasksForTimeRange(selectedTimeRange)
        return tasks.filter { isTaskCompleted($0) }.count
    }
    
    private var totalTasksCount: Int {
        return getTasksForTimeRange(selectedTimeRange).count
    }
    
    private var completionRate: Double {
        guard totalTasksCount > 0 else { return 0 }
        return Double(completedTasksCount) / Double(totalTasksCount) * 100
    }
    
    private func getTasksForTimeRange(_ range: TimeRange) -> [TodoTask] {
        let calendar = Calendar.current
        let now = Date()
        
        let startDate: Date
        switch range {
        case .week:
            startDate = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        case .month:
            startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        case .year:
            startDate = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
        }
        
        return taskManager.tasks.filter { task in
            // Ensure task.startTime is compared against the start of the range.
            // This logic might need refinement based on how tasks are stored and considered "within" a range.
            // For simplicity, let's assume tasks are relevant if their start time is within the range.
            let taskStartDate = calendar.startOfDay(for: task.startTime)
            return taskStartDate >= startDate && taskStartDate <= now
        }
    }
    
    private func isTaskCompleted(_ task: TodoTask) -> Bool {
        // This needs to check completions within the selectedTimeRange, not just "today"
        // For now, keeping original logic for simplicity, but this is an area for improvement.
        let today = Calendar.current.startOfDay(for: Date()) 
        if let completion = task.completions.first(where: { Calendar.current.isDate($0.key, inSameDayAs: task.startTime) }) {
             return completion.value.isCompleted
        }
        return false
    }
}

struct WatchQuickStats: View {
    let completedTasks: Int
    let totalTasks: Int
    
    var body: some View {
        VStack(spacing: 6) {
            Text("Task Stats") // More direct title
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
            
            HStack(spacing: 8) {
                StatCard(
                    title: "Completed",
                    value: "\(completedTasks)",
                    color: .green
                )
                
                StatCard(
                    title: "Total Tasks", // Clarified
                    value: "\(totalTasks)",
                    color: .blue
                )
            }
        }
        .padding(.horizontal, 8)
    }
}

struct WatchCompletionRate: View {
    let completionRate: Double
    
    var body: some View {
        VStack(spacing: 6) {
            Text("Completion Rate")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
            
            ZStack {
                // Background Circle
                Circle()
                    .stroke(lineWidth: 6)
                    .opacity(0.2)
                    .foregroundColor(.gray)
                
                // Progress Circle
                Circle()
                    .trim(from: 0.0, to: min(max(completionRate / 100.0, 0.0), 1.0)) // Ensure value is between 0 and 1
                    .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .foregroundColor(.green)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: completionRate)
                
                // Percentage Text
                Text("\(Int(round(completionRate)))%") // Round for display
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
            }
            .frame(height: 60)
        }
        .padding(.horizontal, 8)
    }
}

struct WatchPointsSummary: View {
    @ObservedObject var rewardManager: RewardManager
    
    var body: some View {
        VStack(spacing: 6) {
            Text("Points Summary") // More direct title
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
            
            HStack(spacing: 8) {
                StatCard(
                    title: "Today",
                    value: "\(rewardManager.todayPoints)",
                    color: .orange
                )
                
                StatCard(
                    title: "Total",
                    value: "\(rewardManager.totalPoints)",
                    color: .purple
                )
            }
        }
        .padding(.horizontal, 8)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(0.1))
        )
    }
}

enum TimeRange: String, CaseIterable {
    case week = "week"
    case month = "month" 
    case year = "year"
    
    var displayName: String {
        switch self {
        case .week: return "This Week" // Made more explicit
        case .month: return "This Month"
        case .year: return "This Year"
        }
    }
}
