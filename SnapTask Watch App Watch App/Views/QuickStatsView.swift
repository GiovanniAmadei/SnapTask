import SwiftUI

struct QuickStatsView: View {
    @ObservedObject private var taskManager = TaskManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                completionRateCard
                topStreaksCard
            }
            .padding(10)
        }
        .navigationTitle("Stats")
    }
    
    // Completion rate card
    private var completionRateCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Today's Progress")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            HStack {
                Text("\(completionRate)%")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.blue)
                
                Spacer()
                
                Text("\(completedToday)/\(totalTasksToday)")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            // Progress bar
            progressBar
        }
        .padding(10)
        .background(Color.secondary.opacity(0.2))
        .cornerRadius(12)
    }
    
    // Progress bar
    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .frame(width: geometry.size.width, height: 10)
                    .opacity(0.2)
                    .foregroundColor(.blue)
                    .cornerRadius(5)
                
                Rectangle()
                    .frame(width: progressWidth(totalWidth: geometry.size.width), height: 10)
                    .foregroundColor(.blue)
                    .cornerRadius(5)
            }
        }
        .frame(height: 10)
    }
    
    // Helper method to calculate progress width
    private func progressWidth(totalWidth: CGFloat) -> CGFloat {
        let percentage = Double(completedToday) / max(Double(totalTasksToday), 1.0)
        return totalWidth * CGFloat(percentage)
    }
    
    // Top streaks card
    private var topStreaksCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Top Streaks")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            streakContent
        }
        .padding(10)
        .background(Color.secondary.opacity(0.2))
        .cornerRadius(12)
    }
    
    // Streak content
    private var streakContent: some View {
        Group {
            if topStreakTasks.isEmpty {
                Text("No active streaks")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            } else {
                streaksList
            }
        }
    }
    
    // Streaks list
    private var streaksList: some View {
        ForEach(topStreakTasks.prefix(3)) { task in
            HStack {
                Text(task.name)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 12))
                    
                    Text("\(task.currentStreak)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.orange)
                }
            }
        }
    }
    
    private var todayTasks: [TodoTask] {
        let today = Date().startOfDay
        
        return taskManager.tasks.filter { task in
            let taskDate = Calendar.current.startOfDay(for: task.startTime)
            
            // Include tasks for today
            if taskDate == today {
                return true
            }
            
            // Include recurring tasks active today
            if let recurrence = task.recurrence, recurrence.isActiveOn(date: today) {
                return true
            }
            
            return false
        }
    }
    
    private var completedToday: Int {
        todayTasks.filter { task in
            if let completion = task.completions[Date().startOfDay] {
                return completion.isCompleted
            }
            return false
        }.count
    }
    
    private var totalTasksToday: Int {
        todayTasks.count
    }
    
    private var completionRate: Int {
        let total = totalTasksToday
        if total == 0 {
            return 0
        }
        
        return Int(Double(completedToday) / Double(total) * 100.0)
    }
    
    private var topStreakTasks: [TodoTask] {
        taskManager.tasks
            .filter { $0.recurrence != nil && $0.currentStreak > 0 }
            .sorted { $0.currentStreak > $1.currentStreak }
    }
} 