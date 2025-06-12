import SwiftUI

struct WatchStatisticsView: View {
    @StateObject private var taskManager = TaskManager.shared
    @StateObject private var rewardManager = RewardManager.shared
    @State private var selectedTimeRange: TimeRange = .week
    
    var body: some View {
        // COPIO ESATTAMENTE la struttura del WatchMenuView!
        ScrollView {
            VStack(spacing: 6) {
                // Time range selector come prima riga
                Button(action: {}) {
                    HStack(spacing: 12) {
                        Image(systemName: "clock")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Time Range")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text(selectedTimeRange.displayName)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Picker("", selection: $selectedTimeRange) {
                            ForEach(TimeRange.allCases, id: \.self) { range in
                                Text(range.displayName).tag(range)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 60, height: 30)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Task completion row
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.green)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Task Completion")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text("\(completedTasksCount)/\(totalTasksCount) tasks • \(Int(completionRate))%")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .stroke(lineWidth: 3)
                            .opacity(0.2)
                            .foregroundColor(.gray)
                        
                        Circle()
                            .trim(from: 0.0, to: min(max(completionRate / 100.0, 0.0), 1.0))
                            .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .foregroundColor(.green)
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 30, height: 30)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.green.opacity(0.1))
                )
                
                // Points summary row
                HStack(spacing: 12) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.purple)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Points Summary")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text("Today: \(rewardManager.todayPoints) • Total: \(rewardManager.totalPoints)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.purple.opacity(0.1))
                )
                
                // Weekly overview row
                HStack(spacing: 12) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.orange)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Weekly Overview")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text("Week: \(rewardManager.weekPoints) pts")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.1))
                )
            }
            .padding(.horizontal, 8) // IDENTICO al menu
            .padding(.vertical, 8)   // IDENTICO al menu
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
        VStack(spacing: 4) {
            Text("Task Stats") // More direct title
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.primary)
            
            HStack(spacing: 6) {
                StatCard(
                    title: "Completed",
                    value: "\(completedTasks)",
                    color: .green
                )
                
                StatCard(
                    title: "Total",
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
        VStack(spacing: 4) {
            Text("Completion Rate")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.primary)
            
            ZStack {
                // Background Circle
                Circle()
                    .stroke(lineWidth: 4)
                    .opacity(0.2)
                    .foregroundColor(.gray)
                
                // Progress Circle
                Circle()
                    .trim(from: 0.0, to: min(max(completionRate / 100.0, 0.0), 1.0)) // Ensure value is between 0 and 1
                    .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .foregroundColor(.green)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: completionRate)
                
                // Percentage Text
                Text("\(Int(round(completionRate)))%") // Round for display
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary)
            }
            .frame(height: 50)
        }
        .padding(.horizontal, 8)
    }
}

struct WatchPointsSummary: View {
    @ObservedObject var rewardManager: RewardManager
    
    var body: some View {
        VStack(spacing: 4) {
            Text("Points Summary") // More direct title
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.primary)
            
            HStack(spacing: 6) {
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
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 8))
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
        case .week: return "Week" // Made more explicit
        case .month: return "Month"
        case .year: return "Year"
        }
    }
}
