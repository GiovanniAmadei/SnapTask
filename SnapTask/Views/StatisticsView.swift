import SwiftUI
import Charts

struct StatisticsView: View {
    @StateObject private var viewModel = StatisticsViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: StatisticsTab = .overview
    
    enum StatisticsTab: String, CaseIterable {
        case overview = "overview"
        case streaks = "streaks"
        case consistency = "consistency"
        case performance = "performance"
        
        var icon: String {
            switch self {
            case .overview: return "chart.pie.fill"
            case .streaks: return "flame.fill"
            case .consistency: return "chart.line.uptrend.xyaxis"
            case .performance: return "speedometer"
            }
        }
        
        var displayName: String {
            switch self {
            case .overview: return "overview".localized
            case .streaks: return "streaks".localized
            case .consistency: return "consistency".localized
            case .performance: return "performance".localized
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header con titolo manuale - REMOVE: background bianco
                VStack(spacing: 16) {
                    HStack {
                        Text("statistics".localized)
                            .font(.largeTitle.bold())
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    // Tab bar senza background
                    HStack(spacing: 0) {
                        ForEach(StatisticsTab.allCases, id: \.self) { tab in
                            Button {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    selectedTab = tab
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 18, weight: .medium))
                                    
                                    Text(tab.displayName)
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
                }
                
                TabView(selection: $selectedTab) {
                    OverviewTab(viewModel: viewModel)
                        .tag(StatisticsTab.overview)
                    
                    StreaksTab(viewModel: viewModel)
                        .tag(StatisticsTab.streaks)
                    
                    ConsistencyTab(viewModel: viewModel)
                        .tag(StatisticsTab.consistency)
                    
                    PerformanceTab(viewModel: viewModel)
                        .tag(StatisticsTab.performance)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationBarHidden(true)
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

// MARK: - Overview Tab
private struct OverviewTab: View {
    @ObservedObject var viewModel: StatisticsViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                TimeDistributionCard(viewModel: viewModel)
                TaskCompletionCard(viewModel: viewModel)
                OverallStreakCard(viewModel: viewModel)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
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
    }
}

// MARK: - Supporting Types for PerformanceTab
private struct TaskChartData: Identifiable, Equatable {
    let id = UUID()
    let taskId: String
    let taskName: String
    let color: String
    let points: [ChartPoint]
    
    static func == (lhs: TaskChartData, rhs: TaskChartData) -> Bool {
        lhs.id == rhs.id && lhs.taskId == rhs.taskId && lhs.points == rhs.points
    }
}

private struct ChartPoint: Equatable {
    let value: Double
    let date: Date
    
    init(value: Double, date: Date) {
        self.value = value
        self.date = date
    }
    
    static func == (lhs: ChartPoint, rhs: ChartPoint) -> Bool {
        lhs.value == rhs.value && lhs.date == rhs.date
    }
}

private struct FlatChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let taskName: String
    let taskId: String
    let color: String
}

// MARK: - Task Legend View for PerformanceTab
private struct TaskLegendView: View {
    let tasks: [(id: String, name: String, color: String)]
    @Binding var highlightedTaskId: String?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(tasks, id: \.id) { task in
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if highlightedTaskId == task.id {
                                highlightedTaskId = nil
                            } else {
                                highlightedTaskId = task.id
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: task.color))
                                .frame(width: 8, height: 8)
                            
                            Text(task.name)
                                .font(.system(.caption, design: .rounded, weight: .medium))
                                .foregroundColor(
                                    highlightedTaskId == task.id ? .primary :
                                    highlightedTaskId == nil ? .primary : .secondary
                                )
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    highlightedTaskId == task.id ?
                                    Color(hex: task.color).opacity(0.2) :
                                    Color(.systemGray6)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(
                                            highlightedTaskId == task.id ?
                                            Color(hex: task.color) : Color.clear,
                                            lineWidth: 1.5
                                        )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct QualityChart: View {
    let data: [TaskChartData]
    @Binding var highlightedTaskId: String?
    
    var body: some View {
        Chart(flattenedQualityData) { point in
            LineMark(
                x: .value("date".localized, point.date),
                y: .value("quality".localized, point.value)
            )
            .foregroundStyle(by: .value("task".localized, point.taskName))
            .opacity(lineOpacity(for: point.taskName))
            
            PointMark(
                x: .value("date".localized, point.date),
                y: .value("quality".localized, point.value)
            )
            .foregroundStyle(by: .value("task".localized, point.taskName))
            .opacity(lineOpacity(for: point.taskName))
            .symbol(.circle)
        }
        .frame(height: 200)
        .chartYScale(domain: 0...10)
        .chartForegroundStyleScale(range: data.map { Color(hex: $0.color) })
        .chartXAxis {
            AxisMarks(position: .bottom) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.gray.opacity(0.2))
                AxisValueLabel() {
                    if let dateValue = value.as(Date.self) {
                        Text(formatDateForChart(dateValue))
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
    }
    
    private var flattenedQualityData: [FlatChartPoint] {
        data.flatMap { taskData in
            taskData.points.map { point in
                FlatChartPoint(
                    date: point.date,
                    value: point.value,
                    taskName: taskData.taskName,
                    taskId: taskData.taskId,
                    color: taskData.color
                )
            }
        }
    }
    
    private func lineOpacity(for taskName: String) -> Double {
        guard let highlightedTaskId = highlightedTaskId else { return 0.8 }
        let taskId = data.first { $0.taskName == taskName }?.taskId ?? ""
        return taskId == highlightedTaskId ? 1.0 : 0.3
    }
    
    private func formatDateForChart(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM"
        return formatter.string(from: date)
    }
}

private struct DifficultyChart: View {
    let data: [TaskChartData]
    @Binding var highlightedTaskId: String?
    
    var body: some View {
        Chart(flattenedDifficultyData) { point in
            LineMark(
                x: .value("date".localized, point.date),
                y: .value("difficulty".localized, point.value)
            )
            .foregroundStyle(by: .value("task".localized, point.taskName))
            .opacity(lineOpacity(for: point.taskName))
            
            PointMark(
                x: .value("date".localized, point.date),
                y: .value("difficulty".localized, point.value)
            )
            .foregroundStyle(by: .value("task".localized, point.taskName))
            .opacity(lineOpacity(for: point.taskName))
            .symbol(.circle)
        }
        .frame(height: 200)
        .chartYScale(domain: 0...10)
        .chartForegroundStyleScale(range: data.map { Color(hex: $0.color) })
        .chartXAxis {
            AxisMarks(position: .bottom) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.gray.opacity(0.2))
                AxisValueLabel() {
                    if let dateValue = value.as(Date.self) {
                        Text(formatDateForChart(dateValue))
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
    }
    
    private var flattenedDifficultyData: [FlatChartPoint] {
        data.flatMap { taskData in
            taskData.points.map { point in
                FlatChartPoint(
                    date: point.date,
                    value: point.value,
                    taskName: taskData.taskName,
                    taskId: taskData.taskId,
                    color: taskData.color
                )
            }
        }
    }
    
    private func lineOpacity(for taskName: String) -> Double {
        guard let highlightedTaskId = highlightedTaskId else { return 0.8 }
        let taskId = data.first { $0.taskName == taskName }?.taskId ?? ""
        return taskId == highlightedTaskId ? 1.0 : 0.3
    }
    
    private func formatDateForChart(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM"
        return formatter.string(from: date)
    }
}

// MARK: - Performance Tab
private struct PerformanceTab: View {
    @ObservedObject var viewModel: StatisticsViewModel
    @State private var selectedTaskForSheet: StatisticsViewModel.TaskPerformanceAnalytics?
    @State private var highlightedTaskId: String?
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                timeRangeSelector
                
                if !viewModel.taskPerformanceAnalytics.isEmpty {
                    overallMetricsSection
                    qualityProgressionChart
                    difficultyAssessmentChart
                    allTasksWithRatingsSection
                } else {
                    emptyStateView
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(item: $selectedTaskForSheet) { task in
            TaskPerformanceDetailView(task: task)
        }
        .onAppear {
            if viewModel.selectedTimeRange == .today {
                viewModel.selectedTimeRange = .week
            }
        }
    }
    
    private var timeRangeSelector: some View {
        VStack(spacing: 12) {
            HStack {
                Text("performance_analytics".localized)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
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
        .padding(20)
        .background(cardBackground)
    }
    
    private var overallMetricsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("overview".localized)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                Spacer()
            }
            
            let tasksWithRatings = viewModel.taskPerformanceAnalytics
            let avgQuality = tasksWithRatings.compactMap { $0.averageQuality }.isEmpty ? 0 :
                tasksWithRatings.compactMap { $0.averageQuality }.reduce(0, +) / Double(tasksWithRatings.compactMap { $0.averageQuality }.count)
            let avgDifficulty = tasksWithRatings.compactMap { $0.averageDifficulty }.isEmpty ? 0 :
                tasksWithRatings.compactMap { $0.averageDifficulty }.reduce(0, +) / Double(tasksWithRatings.compactMap { $0.averageDifficulty }.count)
            
            HStack(spacing: 12) {
                PerformanceStatCard(
                    title: "tasks".localized,
                    value: "\(tasksWithRatings.count)",
                    color: .blue
                )
                
                if avgQuality > 0 {
                    PerformanceStatCard(
                        title: "quality".localized,
                        value: String(format: "%.1f", avgQuality),
                        color: .yellow
                    )
                }
                
                if avgDifficulty > 0 {
                    PerformanceStatCard(
                        title: "difficulty".localized,
                        value: String(format: "%.1f", avgDifficulty),
                        color: .orange
                    )
                }
            }
        }
        .padding(20)
        .background(cardBackground)
    }
    
    private var qualityProgressionChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("quality_progression".localized)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                Spacer()
            }
            
            let qualityData = generateQualityData()
            
            if !qualityData.isEmpty {
                QualityChart(data: qualityData, highlightedTaskId: $highlightedTaskId)
                
                TaskLegendView(
                    tasks: qualityData.map { ($0.taskId, $0.taskName, $0.color) },
                    highlightedTaskId: $highlightedTaskId
                )
            } else {
                Text("no_quality_data_available".localized)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                    .frame(height: 100, alignment: .center)
            }
        }
        .padding(20)
        .background(cardBackground)
    }
    
    private var difficultyAssessmentChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.orange)
                Text("difficulty_assessment".localized)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                Spacer()
            }
            
            let difficultyData = generateDifficultyData()
            
            if !difficultyData.isEmpty {
                DifficultyChart(data: difficultyData, highlightedTaskId: $highlightedTaskId)
                
                TaskLegendView(
                    tasks: difficultyData.map { ($0.taskId, $0.taskName, $0.color) },
                    highlightedTaskId: $highlightedTaskId
                )
            } else {
                Text("no_difficulty_data_available".localized)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                    .frame(height: 100, alignment: .center)
            }
        }
        .padding(20)
        .background(cardBackground)
    }
    
    private func generateQualityData() -> [TaskChartData] {
        viewModel.taskPerformanceAnalytics.compactMap { task in
            let qualityPoints = task.completions.compactMap { completion -> ChartPoint? in
                guard let rating = completion.qualityRating else { return nil }
                return ChartPoint(value: Double(rating), date: completion.date)
            }.sorted { $0.date < $1.date }
            
            guard !qualityPoints.isEmpty else { return nil }
            return TaskChartData(taskId: task.taskId.uuidString, taskName: task.taskName, color: task.categoryColor ?? "#6366F1", points: qualityPoints)
        }
    }
    
    private func generateDifficultyData() -> [TaskChartData] {
        viewModel.taskPerformanceAnalytics.compactMap { task in
            let difficultyPoints = task.completions.compactMap { completion -> ChartPoint? in
                guard let rating = completion.difficultyRating else { return nil }
                return ChartPoint(value: Double(rating), date: completion.date)
            }.sorted { $0.date < $1.date }
            
            guard !difficultyPoints.isEmpty else { return nil }
            return TaskChartData(taskId: task.taskId.uuidString, taskName: task.taskName, color: task.categoryColor ?? "#6366F1", points: difficultyPoints)
        }
    }
    
    private var allTasksWithRatingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "list.bullet.circle")
                    .foregroundColor(.blue)
                Text("tasks_with_performance_data".localized)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                Spacer()
            }
            
            LazyVStack(spacing: 8) {
                ForEach(viewModel.taskPerformanceAnalytics) { task in
                    TaskPerformanceRowCard(task: task) {
                        self.selectedTaskForSheet = task
                    }
                }
            }
        }
        .padding(20)
        .background(cardBackground)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("no_performance_data".localized)
                .font(.system(.title2, design: .rounded, weight: .semibold))
            
            Text("complete_recurring_tasks_performance".localized)
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .frame(height: 200, alignment: .center)
        .background(cardBackground)
    }
}

// MARK: - TaskPerformanceRowCard - Simple and clean list item
private struct TaskPerformanceRowCard: View {
    let task: StatisticsViewModel.TaskPerformanceAnalytics
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Color indicator
                if let categoryColor = task.categoryColor {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: categoryColor))
                        .frame(width: 4, height: 32)
                }
                
                // Task info
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.taskName)
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let categoryName = task.categoryName {
                        Text(categoryName)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Metrics badges - Fixed to stay on same line
                HStack(spacing: 4) {
                    if let avgQuality = task.averageQuality {
                        MetricBadge(
                            icon: "star.fill",
                            value: String(format: "%.1f", avgQuality),
                            color: .yellow
                        )
                    }
                    
                    if let avgDifficulty = task.averageDifficulty {
                        MetricBadge(
                            icon: "bolt.fill",
                            value: String(format: "%.1f", avgDifficulty),
                            color: .orange
                        )
                    }
                    
                    MetricBadge(
                        icon: "checkmark.circle.fill",
                        value: "\(task.completions.count)",
                        color: .blue
                    )
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - MetricBadge - Compact metric display
private struct MetricBadge: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundColor(color)
            Text(value)
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(color.opacity(0.08))
        )
    }
}

// MARK: - Performance Stat Card
private struct PerformanceStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 55)
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.08))
        )
    }
}

// MARK: - TimeDistributionCard
private struct TimeDistributionCard: View {
    @ObservedObject var viewModel: StatisticsViewModel
    @State private var hasAnimated = false
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                HStack {
                    Text("time_distribution".localized)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                    Spacer()
                }
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(StatisticsViewModel.TimeRange.allCases, id: \.self) { range in
                        TimeRangeButton(range: range, isSelected: viewModel.selectedTimeRange == range) {
                            hasAnimated = false
                            withAnimation(.smooth(duration: 0.8)) { 
                                viewModel.selectedTimeRange = range 
                            }
                        }
                    }
                }
            }
            
            if viewModel.categoryStats.isEmpty {
                EmptyTimeDistributionView()
            } else {
                VStack(spacing: 12) {
                    Chart(viewModel.categoryStats) { stat in
                        SectorMark(angle: .value("hours".localized, stat.hours), innerRadius: .ratio(0.618), angularInset: 1.5)
                            .cornerRadius(3)
                            .foregroundStyle(Color(hex: stat.color))
                    }
                    .frame(height: 200)
                    .animation(hasAnimated ? nil : .smooth(duration: 0.8), value: viewModel.categoryStats)
                    .onAppear {
                        if !viewModel.categoryStats.isEmpty && !hasAnimated {
                            hasAnimated = true
                        }
                    }
                    .onChange(of: viewModel.selectedTimeRange) { _, _ in
                        hasAnimated = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            hasAnimated = true
                        }
                    }
                    
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(viewModel.categoryStats) { stat in CategoryLegendItem(stat: stat) }
                    }
                }
            }
        }
        .padding(20)
        .background(cardBackground)
    }
}

// MARK: - TaskCompletionCard 
private struct TaskCompletionCard: View {
    @ObservedObject var viewModel: StatisticsViewModel
    @State private var selectedPeriod: CompletionPeriod = .week
    
    enum CompletionPeriod: String, CaseIterable {
        case week = "7d"
        case month = "30d"
        case year = "1y"
        
        var displayName: String {
            switch self {
            case .week: return "seven_days".localized
            case .month: return "thirty_days".localized
            case .year: return "one_year".localized
            }
        }
        
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
                    Text("task_completion_rate".localized)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                    Spacer()
                }
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(CompletionPeriod.allCases, id: \.self) { period in
                        PeriodButton(period: period, isSelected: selectedPeriod == period) {
                            withAnimation(.smooth(duration: 0.4)) { selectedPeriod = period }
                        }
                    }
                }
            }
            VStack(spacing: 12) {
                VStack(spacing: 12) {
                    if hasTaskData {
                        Chart(completionStats) { stat in
                            BarMark(
                                x: .value("day".localized, stat.day),
                                y: .value("completed".localized, Double(stat.completedTasks))
                            )
                            .foregroundStyle(Color.green)
                            .cornerRadius(4)
                            
                            BarMark(
                                x: .value("day".localized, stat.day),
                                y: .value("incomplete".localized, Double(max(0, stat.totalTasks - stat.completedTasks))),
                                stacking: .standard
                            )
                            .foregroundStyle(Color.secondary.opacity(0.3))
                            .cornerRadius(4)
                        }
                        .frame(height: 140)
                        .chartXAxis { AxisMarks(position: .bottom) { _ in AxisValueLabel().font(.caption2) } }
                        .chartYAxis { AxisMarks(position: .leading) { _ in AxisValueLabel().font(.caption2) } }
                        .animation(.smooth(duration: 0.8), value: completionStats)
                        statsLegend
                    } else {
                        EmptyTaskCompletionView()
                    }
                }
            }
            CategoryCompletionBreakdown(selectedPeriod: selectedPeriod, viewModel: viewModel)
        }
        .padding(16)
        .background(cardBackground)
    }
    
    private var statsLegend: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) { Circle().fill(Color.green).frame(width: 8, height: 8); Text("completed".localized).font(.system(.caption2, design: .rounded, weight: .medium)).foregroundColor(.secondary) }
            HStack(spacing: 6) { Rectangle().fill(Color.secondary.opacity(0.3)).frame(width: 8, height: 8); Text("total_available".localized).font(.system(.caption2, design: .rounded, weight: .medium)).foregroundColor(.secondary) }
            Spacer()
            let totalCompleted = completionStats.reduce(0) { $0 + $1.completedTasks }
            let totalTasks = completionStats.reduce(0) { $0 + $1.totalTasks }
            let avgRate = totalTasks > 0 ? Double(totalCompleted) / Double(totalTasks) : 0.0
            Text("\(Int(avgRate * 100))%").font(.system(.caption, design: .rounded, weight: .bold)).foregroundColor(.primary)
        }
    }
    
    private var hasTaskData: Bool {
        let totalTasks = completionStats.reduce(0) { $0 + $1.totalTasks }
        return totalTasks > 0
    }
    
    private var completionStats: [StatisticsViewModel.WeeklyStat] {
        let calendar = Calendar.current
        let today = Date()
        let startDate = calendar.date(byAdding: .day, value: selectedPeriod.dayOffset, to: today)!
        
        switch selectedPeriod {
        case .week:
            return Array(0...6).map { dayOffset in
                let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate)!
                let dayStats = viewModel.getWeeklyStatsForDay(date: date)
                return StatisticsViewModel.WeeklyStat(
                    day: date.formatted(.dateTime.weekday(.abbreviated)),
                    completedTasks: dayStats.completed,
                    totalTasks: dayStats.total,
                    completionRate: dayStats.rate
                )
            }
        case .month:
            return Array(0..<5).map { weekOffset in
                let weekStats = viewModel.getWeeklyStatsForWeekOffset(weekOffset)
                return StatisticsViewModel.WeeklyStat(
                    day: "W\(weekOffset + 1)",
                    completedTasks: weekStats.completed,
                    totalTasks: weekStats.total,
                    completionRate: weekStats.rate
                )
            }
        case .year:
            return Array(0..<12).map { monthOffset in
                let monthStart = calendar.date(byAdding: .month, value: monthOffset, to: startDate)!
                let monthStats = viewModel.getMonthlyStatsForMonth(monthStart)
                return StatisticsViewModel.WeeklyStat(
                    day: monthStart.formatted(.dateTime.month(.abbreviated)),
                    completedTasks: monthStats.completed,
                    totalTasks: monthStats.total,
                    completionRate: monthStats.rate
                )
            }
        }
    }
}

// MARK: - CategoryCompletionBreakdown 
private struct CategoryCompletionBreakdown: View {
    let selectedPeriod: TaskCompletionCard.CompletionPeriod
    @ObservedObject var viewModel: StatisticsViewModel
    
    private var categoryCompletionStats: [(name: String, color: String, completionRate: Double, completed: Int, total: Int)] {
        let categories = CategoryManager.shared.categories
        let calendar = Calendar.current
        let today = Date()
        let startDate = calendar.date(byAdding: .day, value: selectedPeriod.dayOffset, to: today)!
        
        return categories.compactMap { category in
            var totalCompleted = 0
            var totalTasks = 0
            
            switch selectedPeriod {
            case .week:
                for dayOffset in 0...6 {
                    let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate)!
                    let dayStats = viewModel.getWeeklyStatsForDay(date: date)
                    totalCompleted += dayStats.completed / max(1, categories.count)
                    totalTasks += dayStats.total / max(1, categories.count)
                }
            case .month:
                for weekOffset in 0..<5 {
                    let weekStats = viewModel.getWeeklyStatsForWeekOffset(weekOffset)
                    totalCompleted += weekStats.completed / max(1, categories.count)
                    totalTasks += weekStats.total / max(1, categories.count)
                }
            case .year:
                for monthOffset in 0..<12 {
                    let monthStart = calendar.date(byAdding: .month, value: monthOffset, to: startDate)!
                    let monthStats = viewModel.getMonthlyStatsForMonth(monthStart)
                    totalCompleted += monthStats.completed / max(1, categories.count)
                    totalTasks += monthStats.total / max(1, categories.count)
                }
            }
            
            let completionRate = totalTasks > 0 ? Double(totalCompleted) / Double(totalTasks) : 0.0
            
            return (
                name: category.name,
                color: category.color,
                completionRate: completionRate,
                completed: totalCompleted,
                total: totalTasks
            )
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("by_category".localized)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }
            if categoryCompletionStats.isEmpty {
                Text("no_data".localized)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                    ForEach(categoryCompletionStats, id: \.name) { stat in
                        CompactCategoryItem(stat: stat)
                    }
                }
            }
        }
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
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: stat.color).opacity(0.06))
        )
    }
}

// MARK: - OverallStreakCard
private struct OverallStreakCard: View {
    @ObservedObject var viewModel: StatisticsViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("overall_streak".localized)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                Spacer()
            }
            HStack(spacing: 30) {
                VStack(spacing: 8) {
                    Text("\(viewModel.currentStreak)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                    Text("current".localized)
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Divider().frame(height: 60)
                VStack(spacing: 8) {
                    Text("\(viewModel.bestStreak)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.red)
                    Text("best".localized)
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

// MARK: - EmptyStreaksView
private struct EmptyStreaksView: View {
    var body: some View { VStack(spacing: 20) { Image(systemName: "flame").font(.system(size: 56)).foregroundStyle(LinearGradient(colors: [.orange.opacity(0.6), .red.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)); VStack(spacing: 10) { Text("no_streaks_yet".localized).font(.system(.title2, design: .rounded, weight: .semibold)).foregroundColor(.primary); Text("complete_recurring_tasks_streaks".localized).font(.system(.subheadline, design: .rounded)).foregroundColor(.secondary).multilineTextAlignment(.center).lineLimit(nil) } }.frame(maxWidth: .infinity).padding(.horizontal, 24).padding(.vertical, 40).background(cardBackground) }
}

// MARK: - EmptyTimeDistributionView
private struct EmptyTimeDistributionView: View {
    var body: some View { VStack(spacing: 16) { Image(systemName: "chart.pie").font(.system(size: 48)).foregroundStyle(LinearGradient(colors: [.secondary.opacity(0.6), .secondary.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)); VStack(spacing: 8) { Text("no_time_data".localized).font(.system(.headline, design: .rounded, weight: .semibold)).foregroundColor(.primary); Text("complete_tasks_time_distribution".localized).font(.system(.caption, design: .rounded)).foregroundColor(.secondary).multilineTextAlignment(.center).lineLimit(nil) } }.frame(height: 180, alignment: .center) }
}

// MARK: - CategoryLegendItem
private struct CategoryLegendItem: View {
    let stat: StatisticsViewModel.CategoryStat
    var body: some View { HStack(spacing: 10) { Circle().fill(Color(hex: stat.color)).frame(width: 12, height: 12); VStack(alignment: .leading, spacing: 1) { Text(stat.name).font(.system(.caption, design: .rounded, weight: .semibold)).lineLimit(1).foregroundColor(.primary); Text(formatTimeValue(stat.hours)).font(.system(.caption2, design: .rounded, weight: .medium)).foregroundColor(.secondary).animation(.smooth(duration: 0.8), value: stat.hours) }; Spacer(minLength: 0) }.padding(.horizontal, 12).padding(.vertical, 8).background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: stat.color).opacity(0.03))) }

    private func formatTimeValue(_ hours: Double) -> String {
        let totalMinutes = Int(hours * 60)
        let displayHours = totalMinutes / 60
        let displayMinutes = totalMinutes % 60
        
        if displayHours > 0 {
            return "\(displayHours)h \(displayMinutes)m"
        } else {
            return "\(displayMinutes)m"
        }
    }}
// MARK: - TaskStreakCard
private struct TaskStreakCard: View { 
    let taskStreak: StatisticsViewModel.TaskStreak
    var body: some View { VStack(spacing: 16) { HStack(spacing: 12) { if let categoryColor = taskStreak.categoryColor { Circle().fill(Color(hex: categoryColor)).frame(width: 12, height: 12) }; VStack(alignment: .leading, spacing: 2) { Text(taskStreak.taskName).font(.system(.headline, design: .rounded, weight: .semibold)).foregroundColor(.primary).lineLimit(1); if let categoryName = taskStreak.categoryName { Text(categoryName).font(.system(.caption, design: .rounded, weight: .medium)).foregroundColor(.secondary) } }; Spacer(); VStack(alignment: .trailing, spacing: 2) { Text("\(Int(taskStreak.completionRate * 100))%").font(.system(.title3, design: .rounded, weight: .bold)).foregroundColor(.primary); Text("complete".localized).font(.system(.caption2, design: .rounded)).foregroundColor(.secondary) } }; HStack(spacing: 24) { StatisticsStatItem(title: "current".localized, value: "\(taskStreak.currentStreak)", color: .orange, icon: "flame.fill"); StatisticsStatItem(title: "best".localized, value: "\(taskStreak.bestStreak)", color: .red, icon: "trophy.fill"); StatisticsStatItem(title: "completed".localized, value: "\(taskStreak.completedOccurrences)/\(taskStreak.totalOccurrences)", color: .green, icon: "checkmark.circle.fill"); Spacer() }; if !taskStreak.streakHistory.isEmpty { Chart(taskStreak.streakHistory) { point in LineMark(x: .value("date".localized, point.date), y: .value("streak".localized, point.streakValue)).foregroundStyle(Color(hex: taskStreak.categoryColor ?? "#6366F1")).lineStyle(.init(lineWidth: 2, lineCap: .round)).symbol(.circle).symbolSize(40) }.frame(height: 80).chartXAxis(.hidden).chartYAxis(.hidden) } }.padding(20).background(cardBackground) }
}

// MARK: - TaskPerformanceDetailView
private struct TaskPerformanceDetailView: View {
    let task: StatisticsViewModel.TaskPerformanceAnalytics
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTimeRange: TaskPerformanceDetailView.TaskPerformanceTimeRange = .month
    
    private enum TaskPerformanceTimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
        case all = "All Time"
        
        var displayName: String {
            switch self {
            case .week: return "week".localized
            case .month: return "month".localized
            case .year: return "year".localized
            case .all: return "all_time".localized
            }
        }
        
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
    
    private var filteredCompletions: [StatisticsViewModel.TaskCompletionAnalytics] {
        selectedTimeRange.filterCompletions(task.completions)
    }
    
    private var hasQualityData: Bool {
        filteredCompletions.contains { $0.qualityRating != nil }
    }
    
    private var hasDifficultyData: Bool {
        filteredCompletions.contains { $0.difficultyRating != nil }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    timeRangeSelector
                    basicTaskInfo
                    
                    if hasQualityData {
                        qualityChartSection
                    }
                    
                    if hasDifficultyData {
                        difficultyChartSection
                    }
                    
                    completionsSection
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("task_performance".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var timeRangeSelector: some View {
        VStack(spacing: 12) {
            HStack {
                Text("time_range".localized)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(TaskPerformanceDetailView.TaskPerformanceTimeRange.allCases, id: \.self) { range in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedTimeRange = range
                        }
                    }) {
                        Text(range.displayName)
                            .font(.system(.caption, design: .rounded, weight: selectedTimeRange == range ? .semibold : .medium))
                            .foregroundColor(selectedTimeRange == range ? .accentColor : .primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedTimeRange == range ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .strokeBorder(selectedTimeRange == range ? Color.accentColor : Color.clear, lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .background(cardBackground)
    }
    
    private var basicTaskInfo: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                if let categoryColor = task.categoryColor {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: categoryColor))
                        .frame(width: 6, height: 50)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.taskName)
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    
                    if let categoryName = task.categoryName {
                        Text(categoryName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            
            let filteredQuality = filteredCompletions.compactMap { $0.qualityRating }
            let filteredDifficulty = filteredCompletions.compactMap { $0.difficultyRating }
            let filteredDuration = filteredCompletions.compactMap { $0.actualDuration }
            
            HStack(spacing: 6) {
                TaskDetailMetricCard(
                    title: "completions".localized,
                    value: "\(filteredCompletions.count)",
                    color: .blue,
                    icon: "checkmark.circle.fill"
                )
                
                if !filteredQuality.isEmpty {
                    let avgQuality = Double(filteredQuality.reduce(0, +)) / Double(filteredQuality.count)
                    TaskDetailMetricCard(
                        title: "quality".localized,
                        value: String(format: "%.1f", avgQuality),
                        color: .yellow,
                        icon: "star.fill"
                    )
                }
                
                if !filteredDifficulty.isEmpty {
                    let avgDifficulty = Double(filteredDifficulty.reduce(0, +)) / Double(filteredDifficulty.count)
                    TaskDetailMetricCard(
                        title: "difficulty".localized,
                        value: String(format: "%.1f", avgDifficulty),
                        color: .orange,
                        icon: "bolt.fill"
                    )
                }
                
                if !filteredDuration.isEmpty {
                    let avgDuration = filteredDuration.reduce(0, +) / Double(filteredDuration.count)
                    TaskDetailMetricCard(
                        title: "time".localized,
                        value: formatDuration(avgDuration),
                        color: .green,
                        icon: "clock.fill"
                    )
                }
            }
        }
        .padding(20)
        .background(cardBackground)
    }
    
    private var qualityChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("quality_over_time".localized + " (\(selectedTimeRange.displayName))")
                    .font(.headline)
                Spacer()
            }
            
            let qualityPoints = filteredCompletions.compactMap { completion -> (Date, Double)? in
                guard let rating = completion.qualityRating else { return nil }
                return (completion.date, Double(rating))
            }.sorted { $0.0 < $1.0 }
            
            if !qualityPoints.isEmpty {
                Chart(Array(qualityPoints.enumerated()), id: \.offset) { index, point in
                    LineMark(
                        x: .value("date".localized, point.0),
                        y: .value("quality".localized, point.1)
                    )
                    .foregroundStyle(Color(hex: task.categoryColor ?? "#6366F1"))
                    .lineStyle(.init(lineWidth: 3.0, lineCap: .round))
                    
                    PointMark(
                        x: .value("date".localized, point.0),
                        y: .value("quality".localized, point.1)
                    )
                    .foregroundStyle(Color(hex: task.categoryColor ?? "#6366F1"))
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
                    Text("no_quality_ratings_in_period".localized.replacingOccurrences(of: "{period}", with: selectedTimeRange.displayName.lowercased()))
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
        .background(cardBackground)
    }
    
    private var difficultyChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.orange)
                Text("difficulty_over_time".localized + " (\(selectedTimeRange.displayName))")
                    .font(.headline)
                Spacer()
            }
            
            let difficultyPoints = filteredCompletions.compactMap { completion -> (Date, Double)? in
                guard let rating = completion.difficultyRating else { return nil }
                return (completion.date, Double(rating))
            }.sorted { $0.0 < $1.0 }
            
            if !difficultyPoints.isEmpty {
                Chart(Array(difficultyPoints.enumerated()), id: \.offset) { index, point in
                    LineMark(
                        x: .value("date".localized, point.0),
                        y: .value("difficulty".localized, point.1)
                    )
                    .foregroundStyle(Color(hex: task.categoryColor ?? "#6366F1"))
                    .lineStyle(.init(lineWidth: 3.0, lineCap: .round))
                    
                    PointMark(
                        x: .value("date".localized, point.0),
                        y: .value("difficulty".localized, point.1)
                    )
                    .foregroundStyle(Color(hex: task.categoryColor ?? "#6366F1"))
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
                    Text("no_difficulty_ratings_in_period".localized.replacingOccurrences(of: "{period}", with: selectedTimeRange.displayName.lowercased()))
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
        .background(cardBackground)
    }
    
    private var completionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(.blue)
                Text("completions_period".localized.replacingOccurrences(of: "{period}", with: selectedTimeRange.displayName))
                    .font(.headline)
                Spacer()
            }
            
            if filteredCompletions.isEmpty {
                VStack(spacing: 8) {
                    Text("no_completions_in_period".localized.replacingOccurrences(of: "{period}", with: selectedTimeRange.displayName.lowercased()))
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
                    ForEach(filteredCompletions.sorted { $0.date > $1.date }) { completion in
                        CompletionRowView(completion: completion)
                    }
                }
            }
        }
        .padding(20)
        .background(cardBackground)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
    
    private func formatChartDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        switch selectedTimeRange {
        case .week:
            formatter.dateFormat = "E dd"  // "Mon 15"
        case .month:
            formatter.dateFormat = "dd MMM"  // "15 Dec"
        case .year:
            formatter.dateFormat = "MMM yyyy"  // "Dec 2024"
        case .all:
            // Determine best format based on date range
            let calendar = Calendar.current
            let now = Date()
            let daysDiff = calendar.dateComponents([.day], from: date, to: now).day ?? 0
            
            if daysDiff <= 30 {
                formatter.dateFormat = "dd MMM"  // "15 Dec"
            } else if daysDiff <= 365 {
                formatter.dateFormat = "MMM yyyy"  // "Dec 2024"
            } else {
                formatter.dateFormat = "yyyy"  // "2024"
            }
        }
        
        return formatter.string(from: date)
    }
}

// MARK: - CompletionRowView - Clean completion display
private struct CompletionRowView: View {
    let completion: StatisticsViewModel.TaskCompletionAnalytics
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(completion.date.formatted(.dateTime.month().day().year()))
                    .font(.subheadline.bold())
                Text(completion.date.formatted(.dateTime.hour().minute()))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                if let quality = completion.qualityRating {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                        Text("\(quality)")
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.yellow.opacity(0.1))
                    )
                }
                
                if let difficulty = completion.difficultyRating {
                    HStack(spacing: 3) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                        Text("\(difficulty)")
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.orange.opacity(0.1))
                    )
                }
                
                if let duration = completion.actualDuration {
                    let minutes = Int(duration) / 60
                    HStack(spacing: 3) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                        Text("\(minutes)m")
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue.opacity(0.1))
                    )
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }
}

// MARK: - TaskDetailMetricCard
private struct TaskDetailMetricCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color)
                Text(value)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            Text(title)
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 45)
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(0.08))
        )
    }
}

// MARK: - Button Components
private struct PeriodButton: View {
    let period: TaskCompletionCard.CompletionPeriod
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(period.displayName)
                .font(.system(.caption, design: .rounded, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .accentColor : .primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

private struct TimeRangeButton: View {
    let range: StatisticsViewModel.TimeRange
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(range.localizedName)
                .font(.system(.caption, design: .rounded, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .accentColor : .primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - EmptyTaskCompletionView
private struct EmptyTaskCompletionView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar")
                .font(.system(size: 48))
                .foregroundStyle(LinearGradient(
                    colors: [.secondary.opacity(0.6), .secondary.opacity(0.3)], 
                    startPoint: .topLeading, 
                    endPoint: .bottomTrailing
                ))
            
            VStack(spacing: 8) {
                Text("no_completion_data".localized)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("complete_tasks_completion_rate_trends".localized)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
        }
        .frame(height: 180, alignment: .center)
    }
}

// MARK: - StatisticsStatItem
private struct StatisticsStatItem: View {
    let title: String; let value: String; let color: Color; let icon: String
    var body: some View { VStack(spacing: 6) { HStack(spacing: 4) { Image(systemName: icon).font(.system(.caption2, weight: .medium)).foregroundColor(color); Text(value).font(.system(.callout, design: .rounded, weight: .bold)).foregroundColor(.primary) }; Text(title).font(.system(.caption2, design: .rounded)).foregroundColor(.secondary) } }
}

// MARK: - Supporting Views
private var cardBackground: some View {
    RoundedRectangle(cornerRadius: 16)
        .fill(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
}