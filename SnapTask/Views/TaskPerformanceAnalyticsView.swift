import SwiftUI
import Charts

struct TaskPerformanceAnalyticsView: View {
    @ObservedObject var viewModel: StatisticsViewModel
    @State private var selectedTask: StatisticsViewModel.TaskPerformanceAnalytics?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    timeRangeSelector
                    
                    if !viewModel.taskPerformanceAnalytics.isEmpty {
                        topPerformersSection
                        improvementNeededSection
                        allTasksSection
                    } else {
                        emptyStateView
                    }
                }
                .padding()
            }
            .navigationTitle("task_performance".localized)
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailAnalyticsView(task: task, viewModel: viewModel)
        }
    }
    
    private var timeRangeSelector: some View {
        Picker("time_range".localized, selection: $viewModel.selectedTimeRange) {
            ForEach(StatisticsViewModel.TimeRange.allCases, id: \.self) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .padding(.bottom)
    }
    
    private var topPerformersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.yellow)
                Text("top_performers".localized)
                    .font(.headline)
                Spacer()
            }
            
            if viewModel.topPerformingTasks.isEmpty {
                Text("no_high_quality_completions".localized)
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(viewModel.topPerformingTasks) { task in
                    TaskPerformanceCard(task: task) {
                        selectedTask = task
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(radius: 2)
        )
    }
    
    private var improvementNeededSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("needs_improvement".localized)
                    .font(.headline)
                Spacer()
            }
            
            if viewModel.tasksNeedingImprovement.isEmpty {
                Text("all_tasks_performing_well".localized)
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(viewModel.tasksNeedingImprovement) { task in
                    TaskPerformanceCard(task: task) {
                        selectedTask = task
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(radius: 2)
        )
    }
    
    private var allTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(.blue)
                Text("all_tasks".localized)
                    .font(.headline)
                Spacer()
            }
            
            ForEach(viewModel.taskPerformanceAnalytics) { task in
                TaskPerformanceCard(task: task) {
                    selectedTask = task
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(radius: 2)
        )
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("no_performance_data".localized)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("complete_tasks_quality_difficulty_analytics".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct TaskPerformanceCard: View {
    let task: StatisticsViewModel.TaskPerformanceAnalytics
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Category indicator
                if let categoryColor = task.categoryColor {
                    Circle()
                        .fill(Color(hex: categoryColor))
                        .frame(width: 12, height: 12)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.taskName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let categoryName = task.categoryName {
                        Text(categoryName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    if let avgQuality = task.averageQuality {
                        VStack(spacing: 2) {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.yellow)
                                Text(String(format: "%.1f", avgQuality))
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            Text("quality".localized)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let avgDifficulty = task.averageDifficulty {
                        VStack(spacing: 2) {
                            HStack(spacing: 2) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.orange)
                                Text(String(format: "%.1f", avgDifficulty))
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            Text("difficulty".localized)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    VStack(spacing: 2) {
                        HStack(spacing: 2) {
                            Image(systemName: task.improvementTrend.icon)
                                .font(.system(size: 10))
                                .foregroundColor(task.improvementTrend.color)
                            Text(task.improvementTrend.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(task.improvementTrend.color)
                        }
                        Text("trend".localized)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
    }
}

struct TaskDetailAnalyticsView: View {
    let task: StatisticsViewModel.TaskPerformanceAnalytics
    @ObservedObject var viewModel: StatisticsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    summarySection
                    
                    if !task.completions.isEmpty {
                        if task.completions.compactMap({ $0.qualityRating }).count >= 2 {
                            qualityTrendChart
                        }
                        
                        if task.completions.compactMap({ $0.difficultyRating }).count >= 2 {
                            difficultyTrendChart
                        }
                        
                        if task.completions.compactMap({ $0.actualDuration }).count >= 2 {
                            durationTrendChart
                        }
                        
                        if let accuracy = task.estimationAccuracy {
                            estimationAccuracySection(accuracy)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(task.taskName)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) { dismiss() }
                }
            }
        }
    }
    
    private var summarySection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("performance_summary".localized)
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 6) {
                if let avgQuality = task.averageQuality {
                    StatCard(
                        title: "quality".localized,
                        value: String(format: "%.1f", avgQuality),
                        icon: "star.fill",
                        color: .yellow
                    )
                }
                
                if let avgDifficulty = task.averageDifficulty {
                    StatCard(
                        title: "difficulty".localized,
                        value: String(format: "%.1f", avgDifficulty),
                        icon: "bolt.fill",
                        color: .orange
                    )
                }
                
                StatCard(
                    title: "completions".localized,
                    value: "\(task.completions.count)",
                    icon: "checkmark.circle.fill",
                    color: .blue
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(radius: 2)
        )
    }
    
    private var qualityTrendChart: some View {
        ChartSection(
            title: "quality_trend".localized,
            icon: "star.fill",
            color: .yellow
        ) {
            Chart {
                ForEach(Array(task.completions.enumerated()), id: \.offset) { index, completion in
                    if let quality = completion.qualityRating {
                        LineMark(
                            x: .value("completion".localized, index),
                            y: .value("quality".localized, quality)
                        )
                        .foregroundStyle(.yellow)
                        
                        PointMark(
                            x: .value("completion".localized, index),
                            y: .value("quality".localized, quality)
                        )
                        .foregroundStyle(.yellow)
                    }
                }
            }
            .frame(height: 200)
            .chartYScale(domain: 1...10)
        }
    }
    
    private var difficultyTrendChart: some View {
        ChartSection(
            title: "difficulty_trend".localized,
            icon: "bolt.fill",
            color: .orange
        ) {
            Chart {
                ForEach(Array(task.completions.enumerated()), id: \.offset) { index, completion in
                    if let difficulty = completion.difficultyRating {
                        LineMark(
                            x: .value("completion".localized, index),
                            y: .value("difficulty".localized, difficulty)
                        )
                        .foregroundStyle(.orange)
                        
                        PointMark(
                            x: .value("completion".localized, index),
                            y: .value("difficulty".localized, difficulty)
                        )
                        .foregroundStyle(.orange)
                    }
                }
            }
            .frame(height: 200)
            .chartYScale(domain: 1...10)
        }
    }
    
    private var durationTrendChart: some View {
        ChartSection(
            title: "duration_trend".localized,
            icon: "clock.fill",
            color: .blue
        ) {
            Chart {
                ForEach(Array(task.completions.enumerated()), id: \.offset) { index, completion in
                    if let duration = completion.actualDuration {
                        LineMark(
                            x: .value("completion".localized, index),
                            y: .value("duration_min".localized, duration / 60)
                        )
                        .foregroundStyle(.blue)
                        
                        PointMark(
                            x: .value("completion".localized, index),
                            y: .value("duration_min".localized, duration / 60)
                        )
                        .foregroundStyle(.blue)
                    }
                }
            }
            .frame(height: 200)
        }
    }
    
    private func estimationAccuracySection(_ accuracy: Double) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(.purple)
                Text("estimation_accuracy".localized)
                    .font(.headline)
                Spacer()
                Text("\(Int(accuracy * 100))%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.purple)
            }
            
            ProgressView(value: accuracy)
                .tint(.purple)
                .scaleEffect(y: 2)
            
            Text(accuracyDescription(accuracy))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(radius: 2)
        )
    }
    
    private func accuracyDescription(_ accuracy: Double) -> String {
        switch accuracy {
        case 0.8...:
            return "excellent_estimation_skills".localized
        case 0.6..<0.8:
            return "good_estimation_skills".localized
        case 0.4..<0.6:
            return "fair_estimation_skills".localized
        default:
            return "consider_breaking_tasks".localized
        }
    }
}

struct ChartSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content
    
    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            
            content
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(radius: 2)
        )
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
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

#Preview {
    TaskPerformanceAnalyticsView(viewModel: StatisticsViewModel())
}