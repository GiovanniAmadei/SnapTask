import SwiftUI

/// A heat map view showing streak consistency for recurring tasks
/// Similar to GitHub contribution graph or HabitBook style
struct StreakHeatMapView: View {
    @ObservedObject var viewModel: StatisticsViewModel
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(spacing: 16) {
            if viewModel.taskStreaks.isEmpty {
                EmptyHeatMapView()
            } else {
                ForEach(viewModel.taskStreaks) { taskStreak in
                    TaskHeatMapCard(taskStreak: taskStreak, viewModel: viewModel)
                }
            }
        }
    }
}

private struct TaskHeatMapCard: View {
    let taskStreak: StatisticsViewModel.TaskStreak
    @ObservedObject var viewModel: StatisticsViewModel
    @Environment(\.theme) private var theme
    @State private var selectedTimeRange: HeatMapTimeRange = .threeMonths
    
    enum HeatMapTimeRange: String, CaseIterable {
        case oneMonth = "1M"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case year = "1Y"
        
        var weeksCount: Int {
            switch self {
            case .oneMonth: return 5
            case .threeMonths: return 13
            case .sixMonths: return 26
            case .year: return 52
            }
        }
        
        var displayName: String {
            switch self {
            case .oneMonth: return "1M"
            case .threeMonths: return "3M"
            case .sixMonths: return "6M"
            case .year: return "1Y"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Header with task info
            HStack(spacing: 12) {
                if let categoryColor = taskStreak.categoryColor {
                    Circle()
                        .fill(Color(hex: categoryColor))
                        .frame(width: 12, height: 12)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(taskStreak.taskName)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .themedPrimaryText()
                        .lineLimit(1)
                    
                    if let categoryName = taskStreak.categoryName {
                        Text(categoryName)
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .themedSecondaryText()
                    }
                }
                
                Spacer()
                
                // Streak badges
                HStack(spacing: 8) {
                    StreakBadge(value: taskStreak.currentStreak, label: "current".localized, color: .orange)
                    StreakBadge(value: taskStreak.bestStreak, label: "best".localized, color: .red)
                }
            }
            
            // Time range selector
            HStack(spacing: 6) {
                ForEach(HeatMapTimeRange.allCases, id: \.self) { range in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTimeRange = range
                        }
                    } label: {
                        Text(range.displayName)
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                            .foregroundColor(selectedTimeRange == range ? .white : theme.textColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedTimeRange == range ? 
                                          Color(hex: taskStreak.categoryColor ?? "#6366F1") : 
                                          theme.surfaceColor.opacity(0.5))
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            
            // Heat map grid
            StreakHeatMapGrid(
                taskStreak: taskStreak,
                weeksCount: selectedTimeRange.weeksCount,
                viewModel: viewModel
            )
            
            // Legend
            HeatMapLegend(categoryColor: taskStreak.categoryColor)
            
            // Stats row
            HStack(spacing: 16) {
                HeatMapStatItem(
                    icon: "checkmark.circle.fill",
                    value: "\(taskStreak.completedOccurrences)",
                    label: "completed".localized,
                    color: .green
                )
                HeatMapStatItem(
                    icon: "calendar",
                    value: "\(taskStreak.totalOccurrences)",
                    label: "total".localized,
                    color: .blue
                )
                HeatMapStatItem(
                    icon: "percent",
                    value: "\(Int(taskStreak.completionRate * 100))%",
                    label: "rate".localized,
                    color: .purple
                )
                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.surfaceColor)
                .shadow(color: theme.shadowColor.opacity(0.08), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(theme.borderColor.opacity(0.1), lineWidth: 1)
        )
    }
}

private struct StreakBadge: View {
    let value: Int
    let label: String
    let color: Color
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .themedSecondaryText()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}

struct StreakHeatMapGrid: View {
    let taskStreak: StatisticsViewModel.TaskStreak
    let weeksCount: Int
    @ObservedObject var viewModel: StatisticsViewModel
    @Environment(\.theme) private var theme
    
    private let daysInWeek = 7
    private let cellSize: CGFloat = 10
    private let cellSpacing: CGFloat = 2
    
    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let totalCellWidth = cellSize + cellSpacing
            let maxWeeks = Int(availableWidth / totalCellWidth)
            let displayWeeks = min(weeksCount, maxWeeks)
            
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 2) {
                    // Month labels
                    HStack(spacing: 0) {
                        ForEach(getMonthLabels(weeksCount: displayWeeks), id: \.offset) { monthLabel in
                            Text(monthLabel.name)
                                .font(.system(.caption2, design: .rounded, weight: .medium))
                                .themedSecondaryText()
                                .frame(width: CGFloat(monthLabel.weeks) * totalCellWidth, alignment: .leading)
                        }
                    }
                    .padding(.leading, 20)
                    
                    HStack(alignment: .top, spacing: 2) {
                        // Day labels
                        VStack(spacing: 2) {
                            ForEach(0..<daysInWeek, id: \.self) { dayIndex in
                                if dayIndex % 2 == 1 {
                                    Text(getDayLabel(dayIndex))
                                        .font(.system(.caption2, design: .rounded, weight: .medium))
                                        .themedSecondaryText()
                                        .frame(width: 16, height: cellSize, alignment: .trailing)
                                } else {
                                    Color.clear
                                        .frame(width: 16, height: cellSize)
                                }
                            }
                        }
                        
                        // Grid
                        HStack(spacing: cellSpacing) {
                            ForEach(0..<displayWeeks, id: \.self) { weekIndex in
                                VStack(spacing: cellSpacing) {
                                    ForEach(0..<daysInWeek, id: \.self) { dayIndex in
                                        let date = getDateForCell(weekIndex: weekIndex, dayIndex: dayIndex, totalWeeks: displayWeeks)
                                        let status = getCompletionStatus(for: date)
                                        
                                        HeatMapCell(
                                            status: status,
                                            categoryColor: taskStreak.categoryColor,
                                            size: cellSize
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(height: CGFloat(daysInWeek) * (cellSize + cellSpacing) + 20)
    }
    
    private func getDayLabel(_ index: Int) -> String {
        let days = ["", "M", "", "W", "", "F", ""]
        return days[index]
    }
    
    private func getMonthLabels(weeksCount: Int) -> [(name: String, weeks: Int, offset: Int)] {
        let calendar = Calendar.current
        let today = Date()
        let startDate = calendar.date(byAdding: .day, value: -(weeksCount * 7), to: today)!
        
        var labels: [(name: String, weeks: Int, offset: Int)] = []
        var currentMonth = -1
        var weekCount = 0
        var startOffset = 0
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        
        for weekIndex in 0..<weeksCount {
            let weekStart = calendar.date(byAdding: .day, value: weekIndex * 7, to: startDate)!
            let month = calendar.component(.month, from: weekStart)
            
            if month != currentMonth {
                if currentMonth != -1 && weekCount > 0 {
                    labels.append((name: formatter.string(from: calendar.date(byAdding: .day, value: startOffset * 7, to: startDate)!), weeks: weekCount, offset: startOffset))
                }
                currentMonth = month
                weekCount = 1
                startOffset = weekIndex
            } else {
                weekCount += 1
            }
        }
        
        if weekCount > 0 {
            labels.append((name: formatter.string(from: calendar.date(byAdding: .day, value: startOffset * 7, to: startDate)!), weeks: weekCount, offset: startOffset))
        }
        
        return labels
    }
    
    private func getDateForCell(weekIndex: Int, dayIndex: Int, totalWeeks: Int) -> Date {
        let calendar = Calendar.current
        let today = Date()
        let todayWeekday = calendar.component(.weekday, from: today)
        
        // Calculate the start of the grid (first day of the first week)
        let daysFromStart = (totalWeeks - 1 - weekIndex) * 7 + (todayWeekday - 1 - dayIndex)
        return calendar.date(byAdding: .day, value: -daysFromStart, to: today) ?? today
    }
    
    private func getCompletionStatus(for date: Date) -> HeatMapCellStatus {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let cellDate = calendar.startOfDay(for: date)
        
        // Future dates
        if cellDate > today {
            return .future
        }
        
        // Check if task should occur on this date
        guard let task = viewModel.recurringTasks.first(where: { $0.id == taskStreak.taskId }) else {
            return .noTask
        }
        
        guard let recurrence = task.recurrence else {
            return .noTask
        }
        
        // Check if date is before task creation
        if cellDate < calendar.startOfDay(for: task.startTime) {
            return .noTask
        }
        
        // Check if task should occur on this date
        let shouldOccur: Bool
        switch recurrence.type {
        case .daily:
            shouldOccur = true
        case .weekly(let days):
            let weekday = calendar.component(.weekday, from: cellDate)
            shouldOccur = days.contains(weekday)
        case .monthly(let days):
            let day = calendar.component(.day, from: cellDate)
            shouldOccur = days.contains(day)
        case .monthlyOrdinal:
            shouldOccur = recurrence.shouldOccurOn(date: cellDate)
        case .yearly:
            shouldOccur = recurrence.shouldOccurOn(date: cellDate)
        }
        
        if !shouldOccur {
            return .noTask
        }
        
        // Check completion status
        if let completion = task.completions[cellDate], completion.isCompleted {
            return .completed
        }
        
        return .missed
    }
}

enum HeatMapCellStatus {
    case completed
    case missed
    case noTask
    case future
}

struct HeatMapCell: View {
    let status: HeatMapCellStatus
    let categoryColor: String?
    let size: CGFloat
    @Environment(\.theme) private var theme
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(cellColor)
            .frame(width: size, height: size)
    }
    
    private var cellColor: Color {
        let baseColor = Color(hex: categoryColor ?? "#6366F1")
        
        switch status {
        case .completed:
            return baseColor
        case .missed:
            return baseColor.opacity(0.15)
        case .noTask:
            return theme.surfaceColor.opacity(0.3)
        case .future:
            return theme.surfaceColor.opacity(0.1)
        }
    }
}

private struct HeatMapLegend: View {
    let categoryColor: String?
    @Environment(\.theme) private var theme
    
    var body: some View {
        HStack(spacing: 4) {
            Text("less".localized)
                .font(.system(.caption2, design: .rounded))
                .themedSecondaryText()
            
            ForEach([0.15, 0.4, 0.7, 1.0], id: \.self) { opacity in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: categoryColor ?? "#6366F1").opacity(opacity))
                    .frame(width: 10, height: 10)
            }
            
            Text("more".localized)
                .font(.system(.caption2, design: .rounded))
                .themedSecondaryText()
            
            Spacer()
        }
    }
}

private struct HeatMapStatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    @Environment(\.theme) private var theme
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(.caption2))
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .themedPrimaryText()
                Text(label)
                    .font(.system(.caption2, design: .rounded))
                    .themedSecondaryText()
            }
        }
    }
}

private struct EmptyHeatMapView: View {
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.grid.3x3")
                .font(.system(size: 56))
                .foregroundColor(theme.secondaryTextColor)
            
            VStack(spacing: 10) {
                Text("no_streaks_yet".localized)
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .themedPrimaryText()
                
                Text("complete_recurring_tasks_streaks".localized)
                    .font(.system(.subheadline, design: .rounded))
                    .themedSecondaryText()
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.surfaceColor)
        )
    }
}

#Preview {
    StreakHeatMapView(viewModel: StatisticsViewModel())
}
