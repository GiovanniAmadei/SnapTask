import SwiftUI

struct PointsHistoryView: View {
    @StateObject private var taskManager = TaskManager.shared
    @Environment(\.dismiss) private var dismiss
    
    private var pointsEarningTasks: [(TodoTask, [Date])] {
        let allTasks = taskManager.tasks.filter { $0.hasRewardPoints }
        return allTasks.compactMap { task in
            let completionDates = task.completionDates.filter { _ in task.hasRewardPoints }
            return completionDates.isEmpty ? nil : (task, completionDates)
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if pointsEarningTasks.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(pointsEarningTasks, id: \.0.id) { task, dates in
                            TaskPointsCard(task: task, completionDates: dates)
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Points History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color(hex: "5E5CE6").opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 40))
                    .foregroundColor(Color(hex: "5E5CE6"))
            }
            
            VStack(spacing: 8) {
                Text("No Points Earned Yet")
                    .font(.system(size: 18, weight: .semibold))
                
                Text("Complete tasks with reward points enabled to see your earning history here.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct TaskPointsCard: View {
    let task: TodoTask
    let completionDates: [Date]
    
    private var totalPointsEarned: Int {
        completionDates.count * task.rewardPoints
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(hex: "5E5CE6"), Color(hex: "9747FF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: task.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.name)
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("\(task.rewardPoints) points per completion")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("+\(totalPointsEarned)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: "00C853"))
                    
                    Text("\(completionDates.count) times")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            if completionDates.count > 1 {
                HStack {
                    Text("Recent completions:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(completionDates.prefix(6), id: \.self) { date in
                        Text(DateFormatter.shortDate.string(from: date))
                            .font(.system(size: 11))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: "5E5CE6").opacity(0.1))
                            .foregroundColor(Color(hex: "5E5CE6"))
                            .cornerRadius(8)
                    }
                    
                    if completionDates.count > 6 {
                        Text("+\(completionDates.count - 6)")
                            .font(.system(size: 11))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.1))
                            .foregroundColor(.secondary)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}