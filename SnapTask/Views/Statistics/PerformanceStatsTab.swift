import SwiftUI
import Charts

// MARK: - Aggregation

/// Average quality/difficulty per time bucket, so long periods stay readable.
struct PerformanceBucket: Identifiable, Equatable {
    var id: Date { start }
    let start: Date
    let quality: Double?
    let difficulty: Double?
    let count: Int

    static func make(from completions: [StatisticsViewModel.TaskCompletionAnalytics],
                     unit: Calendar.Component) -> [PerformanceBucket] {
        let calendar = Calendar.current
        var grouped: [Date: [StatisticsViewModel.TaskCompletionAnalytics]] = [:]
        for completion in completions where completion.qualityRating != nil || completion.difficultyRating != nil {
            let key = calendar.dateInterval(of: unit, for: completion.date)?.start ?? calendar.startOfDay(for: completion.date)
            grouped[key, default: []].append(completion)
        }
        return grouped.map { start, items in
            let q = items.compactMap(\.qualityRating)
            let d = items.compactMap(\.difficultyRating)
            return PerformanceBucket(
                start: start,
                quality: q.isEmpty ? nil : Double(q.reduce(0, +)) / Double(q.count),
                difficulty: d.isEmpty ? nil : Double(d.reduce(0, +)) / Double(d.count),
                count: items.count
            )
        }
        .sorted { $0.start < $1.start }
    }
}

extension StatisticsViewModel.TimeRange {
    /// Grouping used by performance charts.
    var performanceUnit: Calendar.Component {
        switch self {
        case .today, .week: return .day
        case .month: return .weekOfYear
        case .year, .allTime: return .month
        }
    }
}

// MARK: - Tab

struct PerformanceStatsTab: View {
    @ObservedObject var viewModel: StatisticsViewModel
    @State private var selectedTask: StatisticsViewModel.TaskPerformanceAnalytics?
    @State private var filterTaskId: UUID?
    @Environment(\.theme) private var theme

    private var rated: [StatisticsViewModel.TaskPerformanceAnalytics] {
        viewModel.taskPerformanceAnalytics
            .filter { $0.averageDifficulty != nil || $0.averageQuality != nil }
            .sorted { $0.completions.count > $1.completions.count }
    }

    private var chartCompletions: [StatisticsViewModel.TaskCompletionAnalytics] {
        if let filterTaskId, let task = rated.first(where: { $0.taskId == filterTaskId }) {
            return task.completions
        }
        return rated.flatMap(\.completions)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                if rated.isEmpty {
                    StatsCard(title: "performance".localized) {
                        StatsEmptyState(systemImage: "speedometer",
                                        title: "no_performance_data".localized,
                                        message: "complete_recurring_tasks_performance".localized)
                    }
                } else {
                    tiles
                    trendCard
                    tasksCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .sheet(item: $selectedTask) { task in
            PerformanceTaskDetailView(task: task, timeRange: viewModel.selectedTimeRange)
        }
        .onChange(of: viewModel.selectedTimeRange) { _, _ in
            if let filterTaskId, !rated.contains(where: { $0.taskId == filterTaskId }) {
                self.filterTaskId = nil
            }
        }
    }

    private var tiles: some View {
        let all = rated.flatMap(\.completions)
        let q = all.compactMap(\.qualityRating)
        let d = all.compactMap(\.difficultyRating)
        let palette = StatsPalette(theme: theme)
        return HStack(spacing: 10) {
            StatTile(value: "\(all.count)", label: "stats_ratings".localized,
                     systemImage: "checkmark.seal.fill", tint: .blue,
                     caption: String(format: "stats_tasks_count".localized, rated.count))
            StatTile(value: q.isEmpty ? "–" : String(format: "%.1f", Double(q.reduce(0, +)) / Double(q.count)),
                     label: "quality".localized, systemImage: "star.fill", tint: palette.quality)
            StatTile(value: d.isEmpty ? "–" : String(format: "%.1f", Double(d.reduce(0, +)) / Double(d.count)),
                     label: "difficulty".localized, systemImage: "bolt.fill", tint: palette.difficulty)
        }
    }

    private var trendCard: some View {
        StatsCard(title: "stats_quality_difficulty".localized,
                  subtitle: filterTaskId.flatMap { id in rated.first { $0.taskId == id }?.taskName } ?? "stats_all_tasks".localized) {
            Menu {
                Picker("task".localized, selection: $filterTaskId) {
                    Text("stats_all_tasks".localized).tag(UUID?.none)
                    ForEach(rated) { task in
                        Text(task.taskName).tag(Optional(task.taskId))
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.title3)
                    .foregroundColor(theme.accentColor)
            }
        } content: {
            PerformanceTrendChart(buckets: PerformanceBucket.make(from: chartCompletions, unit: viewModel.selectedTimeRange.performanceUnit),
                                  unit: viewModel.selectedTimeRange.performanceUnit)
        }
    }

    private var tasksCard: some View {
        StatsCard(title: "tasks_with_performance_data".localized) {
            VStack(spacing: 0) {
                ForEach(Array(rated.enumerated()), id: \.element.id) { index, task in
                    Button { selectedTask = task } label: {
                        PerformanceTaskRow(task: task)
                    }
                    .buttonStyle(.plain)
                    if index < rated.count - 1 {
                        Divider().padding(.leading, 42)
                    }
                }
            }
        }
    }
}

// MARK: - Chart

struct PerformanceTrendChart: View {
    let buckets: [PerformanceBucket]
    let unit: Calendar.Component
    @Environment(\.theme) private var theme
    @State private var selectedDate: Date?

    private var selected: PerformanceBucket? {
        guard let selectedDate else { return nil }
        let calendar = Calendar.current
        let key = calendar.dateInterval(of: unit, for: selectedDate)?.start
        return buckets.first { $0.start == key }
    }

    var body: some View {
        let palette = StatsPalette(theme: theme)
        VStack(alignment: .leading, spacing: 10) {
            if buckets.isEmpty {
                StatsEmptyState(systemImage: "chart.xyaxis.line", title: "stats_no_data_title".localized,
                                message: "stats_no_data_period".localized)
            } else {
                Chart {
                    ForEach(buckets) { bucket in
                        if let quality = bucket.quality {
                            LineMark(x: .value("date".localized, bucket.start, unit: unit),
                                     y: .value("quality".localized, quality),
                                     series: .value("series", "quality"))
                                .foregroundStyle(palette.quality)
                                .interpolationMethod(.monotone)
                                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                .symbol { if buckets.count <= 16 { Circle().fill(palette.quality).frame(width: 6) } }
                        }
                        if let difficulty = bucket.difficulty {
                            LineMark(x: .value("date".localized, bucket.start, unit: unit),
                                     y: .value("difficulty".localized, difficulty),
                                     series: .value("series", "difficulty"))
                                .foregroundStyle(palette.difficulty)
                                .interpolationMethod(.monotone)
                                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                .symbol { if buckets.count <= 16 { Circle().fill(palette.difficulty).frame(width: 6) } }
                        }
                    }
                    if let bucket = selected {
                        RuleMark(x: .value("date".localized, bucket.start, unit: unit))
                            .foregroundStyle(theme.secondaryTextColor.opacity(0.4))
                            .annotation(position: .top, spacing: 4,
                                        overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                                ChartTooltip(title: title(for: bucket.start), lines: [
                                    (palette.quality, bucket.quality.map { "quality".localized + " " + String(format: "%.1f", $0) } ?? "–"),
                                    (palette.difficulty, bucket.difficulty.map { "difficulty".localized + " " + String(format: "%.1f", $0) } ?? "–")
                                ])
                            }
                    }
                }
                .chartYScale(domain: 0...10)
                .chartXSelection(value: $selectedDate)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 5, 10]) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                            .foregroundStyle(theme.secondaryTextColor.opacity(0.2))
                        AxisValueLabel()
                            .font(.caption2)
                            .foregroundStyle(theme.secondaryTextColor)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 6)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) { Text(label(for: date)) }
                        }
                        .font(.caption2)
                        .foregroundStyle(theme.secondaryTextColor)
                    }
                }
                .frame(height: 180)

                HStack(spacing: 14) {
                    LegendDot(color: palette.quality, label: "quality".localized)
                    LegendDot(color: palette.difficulty, label: "difficulty".localized)
                }
            }
        }
    }

    private func label(for date: Date) -> String {
        switch unit {
        case .day: return date.formatted(.dateTime.day().month(.abbreviated))
        case .weekOfYear: return date.formatted(.dateTime.day().month(.abbreviated))
        default: return date.formatted(.dateTime.month(.abbreviated))
        }
    }

    private func title(for date: Date) -> String {
        switch unit {
        case .day: return date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
        case .weekOfYear: return String(format: "stats_week_of".localized, date.formatted(.dateTime.day().month(.abbreviated)))
        default: return date.formatted(.dateTime.month(.wide).year())
        }
    }
}

// MARK: - Rows

private struct PerformanceTaskRow: View {
    let task: StatisticsViewModel.TaskPerformanceAnalytics
    @Environment(\.theme) private var theme

    var body: some View {
        let palette = StatsPalette(theme: theme)
        HStack(spacing: 10) {
            Image(systemName: task.improvementTrend.icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(task.improvementTrend.color)
                .frame(width: 30, height: 30)
                .background(Circle().fill(task.improvementTrend.color.opacity(0.12)))
            VStack(alignment: .leading, spacing: 1) {
                Text(task.taskName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .themedPrimaryText()
                Text(String(format: "stats_ratings_count".localized, task.completions.count))
                    .font(.caption2)
                    .themedSecondaryText()
            }
            Spacer(minLength: 6)
            if let quality = task.averageQuality {
                value(icon: "star.fill", tint: palette.quality, text: String(format: "%.1f", quality))
            }
            if let difficulty = task.averageDifficulty {
                value(icon: "bolt.fill", tint: palette.difficulty, text: String(format: "%.1f", difficulty))
            }
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundColor(theme.secondaryTextColor.opacity(0.5))
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }

    private func value(icon: String, tint: Color, text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 10, weight: .semibold)).foregroundColor(tint)
            Text(text).font(.caption.weight(.semibold)).monospacedDigit().themedPrimaryText()
        }
        .frame(minWidth: 40, alignment: .trailing)
    }
}

// MARK: - Detail

struct PerformanceTaskDetailView: View {
    let task: StatisticsViewModel.TaskPerformanceAnalytics
    let timeRange: StatisticsViewModel.TimeRange
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    private var durations: [TimeInterval] { task.completions.compactMap(\.actualDuration).filter { $0 > 0 } }

    var body: some View {
        let palette = StatsPalette(theme: theme)
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        StatTile(value: task.averageQuality.map { String(format: "%.1f", $0) } ?? "–",
                                 label: "quality".localized, systemImage: "star.fill", tint: palette.quality)
                        StatTile(value: task.averageDifficulty.map { String(format: "%.1f", $0) } ?? "–",
                                 label: "difficulty".localized, systemImage: "bolt.fill", tint: palette.difficulty)
                        StatTile(value: durations.isEmpty ? "–" : StatsFormat.hours(durations.reduce(0, +) / Double(durations.count) / 3600),
                                 label: "stats_avg_duration".localized, systemImage: "clock.fill", tint: .blue)
                        StatTile(value: task.estimationAccuracy.map { StatsFormat.percent($0) } ?? "–",
                                 label: "stats_estimate_accuracy".localized, systemImage: "scope", tint: .purple)
                    }

                    StatsCard(title: "stats_quality_difficulty".localized) {
                        PerformanceTrendChart(buckets: PerformanceBucket.make(from: task.completions, unit: timeRange.performanceUnit),
                                              unit: timeRange.performanceUnit)
                    }

                    StatsCard(title: "stats_recent_ratings".localized) {
                        VStack(spacing: 0) {
                            let recent = task.completions.sorted { $0.date > $1.date }.prefix(30)
                            ForEach(Array(recent.enumerated()), id: \.element.id) { index, completion in
                                completionRow(completion, palette: palette)
                                if index < recent.count - 1 { Divider() }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .themedBackground()
            .navigationTitle(task.taskName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("done".localized) { dismiss() }
                }
            }
        }
    }

    private func completionRow(_ completion: StatisticsViewModel.TaskCompletionAnalytics, palette: StatsPalette) -> some View {
        HStack(spacing: 12) {
            Text(completion.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year()))
                .font(.subheadline)
                .themedPrimaryText()
            Spacer()
            if let quality = completion.qualityRating {
                Label("\(quality)", systemImage: "star.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.quality)
            }
            if let difficulty = completion.difficultyRating {
                Label("\(difficulty)", systemImage: "bolt.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.difficulty)
            }
            if let duration = completion.actualDuration, duration > 0 {
                Text(StatsFormat.hours(duration / 3600))
                    .font(.caption)
                    .monospacedDigit()
                    .themedSecondaryText()
                    .frame(minWidth: 44, alignment: .trailing)
            }
        }
        .padding(.vertical, 9)
    }
}
