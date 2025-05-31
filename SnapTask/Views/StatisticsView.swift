import SwiftUI
import Charts

struct StatisticsView: View {
    @StateObject private var viewModel = StatisticsViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: StatisticsTab = .overview
    
    enum StatisticsTab: String, CaseIterable {
        case overview = "Overview"
        case streaks = "Streaks"
        case consistency = "Consistency"
        
        var icon: String {
            switch self {
            case .overview: return "chart.pie.fill"
            case .streaks: return "flame.fill"
            case .consistency: return "chart.line.uptrend.xyaxis"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom Tab Bar
                CustomTabBar(selectedTab: $selectedTab)
                
                TabView(selection: $selectedTab) {
                    OverviewTab(viewModel: viewModel)
                        .tag(StatisticsTab.overview)
                    
                    StreaksTab(viewModel: viewModel)
                        .tag(StatisticsTab.streaks)
                    
                    ConsistencyTab(viewModel: viewModel)
                        .tag(StatisticsTab.consistency)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            viewModel.refreshStats()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                viewModel.refreshStats()
            }
        }
        .refreshable {
            viewModel.refreshStats()
        }
    }
}

// MARK: - Custom Tab Bar
private struct CustomTabBar: View {
    @Binding var selectedTab: StatisticsView.StatisticsTab
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(StatisticsView.StatisticsTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18, weight: .medium))
                        
                        Text(tab.rawValue)
                            .font(.system(.caption, design: .rounded, weight: .medium))
                    }
                    .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedTab == tab ? Color.accentColor.opacity(0.1) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Overview Tab
private struct OverviewTab: View {
    @ObservedObject var viewModel: StatisticsViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Time Distribution with Time Range Selector combined
                TimeDistributionCard(viewModel: viewModel)
                
                // Task Completion Rate
                TaskCompletionCard(viewModel: viewModel)
                
                // Overall Streak Summary
                OverallStreakCard(viewModel: viewModel)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Streaks Tab
private struct StreaksTab: View {
    @ObservedObject var viewModel: StatisticsViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if viewModel.taskStreaks.isEmpty {
                    EmptyStreaksView()
                        .padding(.top, 60)
                } else {
                    ForEach(viewModel.taskStreaks) { taskStreak in
                        TaskStreakCard(taskStreak: taskStreak)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Consistency Tab
private struct ConsistencyTab: View {
    @ObservedObject var viewModel: StatisticsViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                TaskConsistencyView(viewModel: viewModel)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Card Components
private struct TimeDistributionCard: View {
    @ObservedObject var viewModel: StatisticsViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                HStack {
                    Text("Time Distribution")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    Text("Total: \(String(format: "%.1fh", viewModel.categoryStats.reduce(0) { $0 + $1.hours }))")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundColor(.secondary)
                        .animation(.smooth(duration: 0.8), value: viewModel.categoryStats.reduce(0) { $0 + $1.hours })
                }
                
                // Time Range Selector integrated
                HStack(spacing: 8) {
                    ForEach(StatisticsViewModel.TimeRange.allCases, id: \.self) { range in
                        TimeRangeButton(
                            range: range,
                            isSelected: viewModel.selectedTimeRange == range,
                            action: {
                                withAnimation(.smooth(duration: 0.8)) {
                                    viewModel.selectedTimeRange = range
                                }
                            }
                        )
                    }
                }
            }
            
            if viewModel.categoryStats.isEmpty {
                EmptyTimeDistributionView()
            } else {
                Chart(viewModel.categoryStats) { stat in
                    SectorMark(
                        angle: .value("Hours", stat.hours),
                        innerRadius: .ratio(0.618),
                        angularInset: 1.5
                    )
                    .cornerRadius(3)
                    .foregroundStyle(Color(hex: stat.color))
                }
                .frame(height: 200)
                .animation(.smooth(duration: 0.8), value: viewModel.categoryStats)
                
                // Legend
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(viewModel.categoryStats) { stat in
                        CategoryLegendItem(stat: stat)
                    }
                }
            }
        }
        .padding(20)
        .background(cardBackground)
    }
}

private struct TaskCompletionCard: View {
    @ObservedObject var viewModel: StatisticsViewModel
    @State private var selectedPeriod: CompletionPeriod = .week
    
    enum CompletionPeriod: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
        
        var daysCount: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .year: return 365
            }
        }
        
        var dayOffset: Int {
            switch self {
            case .week: return -6
            case .month: return -29
            case .year: return -364
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                HStack {
                    Text("Task Completion Rate")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                }
                
                // Period Selector
                HStack(spacing: 8) {
                    ForEach(CompletionPeriod.allCases, id: \.self) { period in
                        PeriodButton(
                            period: period,
                            isSelected: selectedPeriod == period,
                            action: {
                                withAnimation(.smooth(duration: 0.4)) {
                                    selectedPeriod = period
                                }
                            }
                        )
                    }
                }
            }
            
            // Chart and stats in compact layout
            VStack(spacing: 12) {
                Chart(completionStats) { stat in
                    // Completed tasks (green, starts from bottom)
                    BarMark(
                        x: .value("Day", stat.day),
                        y: .value("Completed", stat.completedTasks)
                    )
                    .foregroundStyle(Color.green)
                    .cornerRadius(4)
                    
                    // Incomplete tasks (gray, stacked on top of completed)
                    BarMark(
                        x: .value("Day", stat.day),
                        y: .value("Incomplete", max(0, stat.totalTasks - stat.completedTasks)),
                        stacking: .standard
                    )
                    .foregroundStyle(Color.secondary.opacity(0.3))
                    .cornerRadius(4)
                }
                .frame(height: 140)
                .chartXAxis {
                    AxisMarks(position: .bottom) { _ in
                        AxisValueLabel()
                            .font(.caption2)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel()
                            .font(.caption2)
                    }
                }
                .animation(.smooth(duration: 0.8), value: completionStats)
                
                // Compact stats summary
                statsLegend
            }
            
            // Category breakdown - more compact
            CategoryCompletionBreakdown(selectedPeriod: selectedPeriod)
        }
        .padding(16)
        .background(cardBackground)
    }
    
    private var statsLegend: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("Completed")
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 6) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                Text("Total Available")
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            let totalCompleted = completionStats.reduce(0) { $0 + $1.completedTasks }
            let totalTasks = completionStats.reduce(0) { $0 + $1.totalTasks }
            let avgRate = totalTasks > 0 ? Double(totalCompleted) / Double(totalTasks) : 0.0
            
            Text("\(Int(avgRate * 100))%")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundColor(.primary)
        }
    }
    
    private var completionStats: [StatisticsViewModel.WeeklyStat] {
        let calendar = Calendar.current
        let today = Date()
        let startDate = calendar.date(byAdding: .day, value: selectedPeriod.dayOffset, to: today)!
        
        switch selectedPeriod {
        case .week:
            return generateWeeklyStats(from: startDate, to: today)
        case .month:
            return generateMonthlyStats(from: startDate, to: today)
        case .year:
            return generateYearlyStats(from: startDate, to: today)
        }
    }
    
    private func generateWeeklyStats(from startDate: Date, to endDate: Date) -> [StatisticsViewModel.WeeklyStat] {
        let calendar = Calendar.current
        
        return (0...6).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate)!
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!.addingTimeInterval(-1)
            
            let (completed, total) = getTasksForDate(date: startOfDay, endOfDay: endOfDay)
            let completionRate = total > 0 ? Double(completed) / Double(total) : 0.0
            
            return StatisticsViewModel.WeeklyStat(
                day: date.formatted(.dateTime.weekday(.abbreviated)),
                completedTasks: completed,
                totalTasks: total,
                completionRate: completionRate
            )
        }
    }
    
    private func generateMonthlyStats(from startDate: Date, to endDate: Date) -> [StatisticsViewModel.WeeklyStat] {
        let calendar = Calendar.current
        var stats: [StatisticsViewModel.WeeklyStat] = []
        
        // Group by weeks (show 4-5 weeks)
        for weekOffset in 0..<5 {
            let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: startDate)!
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
            
            var weekCompleted = 0
            var weekTotal = 0
            
            for dayOffset in 0...6 {
                let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart)!
                let startOfDay = calendar.startOfDay(for: date)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!.addingTimeInterval(-1)
                
                if date <= endDate {
                    let (completed, total) = getTasksForDate(date: startOfDay, endOfDay: endOfDay)
                    weekCompleted += completed
                    weekTotal += total
                }
            }
            
            let completionRate = weekTotal > 0 ? Double(weekCompleted) / Double(weekTotal) : 0.0
            
            stats.append(StatisticsViewModel.WeeklyStat(
                day: "W\(weekOffset + 1)",
                completedTasks: weekCompleted,
                totalTasks: weekTotal,
                completionRate: completionRate
            ))
        }
        
        return stats
    }
    
    private func generateYearlyStats(from startDate: Date, to endDate: Date) -> [StatisticsViewModel.WeeklyStat] {
        let calendar = Calendar.current
        var stats: [StatisticsViewModel.WeeklyStat] = []
        
        // Group by months (show 12 months)
        for monthOffset in 0..<12 {
            let monthStart = calendar.date(byAdding: .month, value: monthOffset, to: startDate)!
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)!.addingTimeInterval(-1)
            
            var monthCompleted = 0
            var monthTotal = 0
            
            var currentDate = monthStart
            while currentDate <= monthEnd && currentDate <= endDate {
                let startOfDay = calendar.startOfDay(for: currentDate)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!.addingTimeInterval(-1)
                
                let (completed, total) = getTasksForDate(date: startOfDay, endOfDay: endOfDay)
                monthCompleted += completed
                monthTotal += total
                
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            }
            
            let completionRate = monthTotal > 0 ? Double(monthCompleted) / Double(monthTotal) : 0.0
            
            stats.append(StatisticsViewModel.WeeklyStat(
                day: monthStart.formatted(.dateTime.month(.abbreviated)),
                completedTasks: monthCompleted,
                totalTasks: monthTotal,
                completionRate: completionRate
            ))
        }
        
        return stats
    }
    
    private func getTasksForDate(date: Date, endOfDay: Date) -> (completed: Int, total: Int) {
        let calendar = Calendar.current
        let allTasks = TaskManager.shared.tasks
        
        // Single day tasks
        let singleDayTasks = allTasks.filter { task in
            task.recurrence == nil && calendar.isDate(task.startTime, inSameDayAs: date)
        }
        
        // Recurring tasks
        let recurringDayTasks = allTasks.filter { task in
            guard let recurrence = task.recurrence else { return false }
            if task.startTime > endOfDay { return false }
            if let endDate = recurrence.endDate, endDate < date { return false }
            
            switch recurrence.type {
            case .daily:
                return true
            case .weekly(let days):
                let weekday = calendar.component(.weekday, from: date)
                return days.contains(weekday)
            case .monthly(let days):
                let day = calendar.component(.day, from: date)
                return days.contains(day)
            case .monthlyOrdinal(let patterns):
                return recurrence.shouldOccurOn(date: date)
            case .yearly:
                return recurrence.shouldOccurOn(date: date)
            }
        }
        
        let allDayTasks = singleDayTasks + recurringDayTasks
        
        let completedCount = allDayTasks.filter { task in
            task.completions[date]?.isCompleted == true
        }.count
        
        return (completed: completedCount, total: allDayTasks.count)
    }
}

private struct PeriodButton: View {
    let period: TaskCompletionCard.CompletionPeriod
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(period.rawValue)
                .font(.system(.subheadline, design: .rounded, weight: isSelected ? .semibold : .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 40)
                .background(buttonBackground)
                .foregroundColor(isSelected ? .accentColor : .primary)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    private var buttonBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(isSelected ?
                Color.accentColor.opacity(0.15) :
                Color.gray.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isSelected ? Color.accentColor : Color.clear,
                        lineWidth: 1.5
                    )
            )
    }
}

private struct CategoryCompletionBreakdown: View {
    let selectedPeriod: TaskCompletionCard.CompletionPeriod
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("By Category")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }
            
            if categoryCompletionStats.isEmpty {
                Text("No data")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 6),
                    GridItem(.flexible(), spacing: 6)
                ], spacing: 6) {
                    ForEach(categoryCompletionStats, id: \.name) { stat in
                        CompactCategoryItem(stat: stat)
                    }
                }
            }
        }
    }
    
    private var categoryCompletionStats: [(name: String, color: String, completionRate: Double, completed: Int, total: Int)] {
        let calendar = Calendar.current
        let today = Date()
        let startDate = calendar.date(byAdding: .day, value: selectedPeriod.dayOffset, to: today)!
        
        var categoryStats: [String: (completed: Int, total: Int, color: String)] = [:]
        let allTasks = TaskManager.shared.tasks
        
        // Process each day in the selected period
        var currentDate = startDate
        while currentDate <= today {
            let startOfDay = calendar.startOfDay(for: currentDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!.addingTimeInterval(-1)
            
            // Get all tasks for this day
            let singleDayTasks = allTasks.filter { task in
                task.recurrence == nil && calendar.isDate(task.startTime, inSameDayAs: currentDate)
            }
            
            let recurringDayTasks = allTasks.filter { task in
                guard let recurrence = task.recurrence else { return false }
                if task.startTime > endOfDay { return false }
                if let endDate = recurrence.endDate, endDate < startOfDay { return false }
                
                switch recurrence.type {
                case .daily:
                    return true
                case .weekly(let days):
                    let weekday = calendar.component(.weekday, from: currentDate)
                    return days.contains(weekday)
                case .monthly(let days):
                    let day = calendar.component(.day, from: currentDate)
                    return days.contains(day)
                case .monthlyOrdinal(let patterns):
                    return recurrence.shouldOccurOn(date: currentDate)
                case .yearly:
                    return recurrence.shouldOccurOn(date: currentDate)
                }
            }
            
            let allDayTasks = singleDayTasks + recurringDayTasks
            
            // Group by category
            for task in allDayTasks {
                let categoryName = task.category?.name ?? "No Category"
                let categoryColor = task.category?.color ?? "#8E8E93"
                let isCompleted = task.completions[startOfDay]?.isCompleted == true
                
                if categoryStats[categoryName] == nil {
                    categoryStats[categoryName] = (completed: 0, total: 0, color: categoryColor)
                }
                
                categoryStats[categoryName]?.total += 1
                if isCompleted {
                    categoryStats[categoryName]?.completed += 1
                }
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        // Convert to array and sort by completion rate
        return categoryStats.compactMap { (name, data) in
            let completionRate = data.total > 0 ? Double(data.completed) / Double(data.total) : 0.0
            return (name: name, color: data.color, completionRate: completionRate, completed: data.completed, total: data.total)
        }.sorted { $0.completionRate > $1.completionRate }
    }
}

private struct CompactCategoryItem: View {
    let stat: (name: String, color: String, completionRate: Double, completed: Int, total: Int)
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(hex: stat.color))
                .frame(width: 8, height: 8)
            
            Text(stat.name)
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .lineLimit(1)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text("\(Int(stat.completionRate * 100))%")
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundColor(stat.completionRate >= 0.8 ? .green : 
                               stat.completionRate >= 0.5 ? .orange : .red)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: stat.color).opacity(0.06))
        )
    }
}

private struct OverallStreakCard: View {
    @ObservedObject var viewModel: StatisticsViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Overall Streak")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }
            
            HStack(spacing: 30) {
                VStack(spacing: 8) {
                    Text("\(viewModel.currentStreak)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                    Text("Current")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .frame(height: 60)
                
                VStack(spacing: 8) {
                    Text("\(viewModel.bestStreak)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.red)
                    Text("Best")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(cardBackground)
    }
}

private struct TaskStreakCard: View {
    let taskStreak: StatisticsViewModel.TaskStreak
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(spacing: 12) {
                if let categoryColor = taskStreak.categoryColor {
                    Circle()
                        .fill(Color(hex: categoryColor))
                        .frame(width: 12, height: 12)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(taskStreak.taskName)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let categoryName = taskStreak.categoryName {
                        Text(categoryName)
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(taskStreak.completionRate * 100))%")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundColor(.primary)
                    Text("Complete")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            
            // Streak Stats
            HStack(spacing: 24) {
                StatItem(
                    title: "Current",
                    value: "\(taskStreak.currentStreak)",
                    color: .orange,
                    icon: "flame.fill"
                )
                
                StatItem(
                    title: "Best",
                    value: "\(taskStreak.bestStreak)",
                    color: .red,
                    icon: "trophy.fill"
                )
                
                StatItem(
                    title: "Completed",
                    value: "\(taskStreak.completedOccurrences)/\(taskStreak.totalOccurrences)",
                    color: .green,
                    icon: "checkmark.circle.fill"
                )
                
                Spacer()
            }
            
            // Mini Chart
            if !taskStreak.streakHistory.isEmpty {
                Chart(taskStreak.streakHistory) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Streak", point.streakValue)
                    )
                    .foregroundStyle(Color(hex: taskStreak.categoryColor ?? "#6366F1"))
                    .lineStyle(.init(lineWidth: 2, lineCap: .round))
                    .symbol(.circle)
                    .symbolSize(40)
                }
                .frame(height: 80)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
            }
        }
        .padding(20)
        .background(cardBackground)
    }
}

private struct StatItem: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(.caption2, weight: .medium))
                    .foregroundColor(color)
                
                Text(value)
                    .font(.system(.callout, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            Text(title)
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Empty States
private struct EmptyStreaksView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "flame")
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange.opacity(0.6), .red.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 10) {
                Text("No Streaks Yet")
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Complete recurring tasks to start building streaks and track your consistency")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 40)
        .background(cardBackground)
    }
}

private struct EmptyTimeDistributionView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.secondary.opacity(0.6), .secondary.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 8) {
                Text("No Time Data")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Complete tasks with duration or use Pomodoro sessions to see time distribution")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
        }
        .frame(height: 180)
    }
}

// MARK: - Helper Components
private struct TimeRangeButton: View {
    let range: StatisticsViewModel.TimeRange
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(range.rawValue)
                .font(.system(.subheadline, design: .rounded, weight: isSelected ? .semibold : .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 40)
                .background(buttonBackground)
                .foregroundColor(isSelected ? .accentColor : .primary)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    private var buttonBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(isSelected ?
                Color.accentColor.opacity(0.15) :
                Color.gray.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isSelected ? Color.accentColor : Color.clear,
                        lineWidth: 1.5
                    )
            )
    }
}

private struct CategoryLegendItem: View {
    let stat: StatisticsViewModel.CategoryStat
    
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(hex: stat.color))
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(stat.name)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                Text(String(format: "%.1fh", stat.hours))
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
                    .animation(.smooth(duration: 0.8), value: stat.hours)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: stat.color).opacity(0.03))
        )
    }
}

private var cardBackground: some View {
    RoundedRectangle(cornerRadius: 16)
        .fill(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
}
