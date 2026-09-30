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

extension StatisticsViewModel.TaskPerformanceAnalytics {
    /// Task icon, falling back to the category icon when the task uses the default one.
    @MainActor var displayIcon: String {
        let task = TaskManager.shared.tasks.first { $0.id == taskId }
        guard let task else { return "checkmark.circle" }
        return (task.icon.isEmpty || task.icon == "circle") ? (task.category?.icon ?? "checkmark.circle") : task.icon
    }
}

// MARK: - Tab

struct PerformanceStatsTab: View {
    @ObservedObject var viewModel: StatisticsViewModel
    @State private var selectedTask: StatisticsViewModel.TaskPerformanceAnalytics?
    @State private var compared: [String] = []
    @State private var metric: Metric = .quality
    @AppStorage("statsPerformanceSort") private var sortRaw = Sort.ratings.rawValue
    @Environment(\.theme) private var theme

    enum Metric: String, CaseIterable {
        case quality, difficulty
        var title: String { self == .quality ? "quality".localized : "difficulty".localized }
    }

    enum Sort: String, CaseIterable {
        case ratings, quality, difficulty, name
        var title: String {
            switch self {
            case .ratings: return "stats_ratings".localized
            case .quality: return "quality".localized
            case .difficulty: return "difficulty".localized
            case .name: return "stats_sort_name".localized
            }
        }
    }

    private var rated: [StatisticsViewModel.TaskPerformanceAnalytics] {
        viewModel.taskPerformanceAnalytics
            .filter { $0.averageDifficulty != nil || $0.averageQuality != nil }
            .sorted { $0.completions.count > $1.completions.count }
    }

    private var sortedList: [StatisticsViewModel.TaskPerformanceAnalytics] {
        switch Sort(rawValue: sortRaw) ?? .ratings {
        case .ratings: return rated
        case .quality: return rated.sorted { ($0.averageQuality ?? 0) > ($1.averageQuality ?? 0) }
        case .difficulty: return rated.sorted { ($0.averageDifficulty ?? 0) > ($1.averageDifficulty ?? 0) }
        case .name: return rated.sorted { $0.taskName.localizedCaseInsensitiveCompare($1.taskName) == .orderedAscending }
        }
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
                    QualityDifficultyMap(tasks: rated) { selectedTask = $0 }
                        .id(viewModel.selectedTimeRange)
                    trendCard
                    tasksCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 110) // clears the floating tab bar
        }
        .statsDebugScrollAnchor()
        .sheet(item: $selectedTask) { task in
            PerformanceTaskDetailView(task: task, timeRange: viewModel.selectedTimeRange)
        }
        .onChange(of: rated.map(\.taskId)) { _, ids in
            compared.removeAll { id in !ids.contains { $0.uuidString == id } }
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
                     label: "quality".localized, systemImage: "star.fill", tint: palette.quality,
                     caption: "stats_average_short".localized)
            StatTile(value: d.isEmpty ? "–" : String(format: "%.1f", Double(d.reduce(0, +)) / Double(d.count)),
                     label: "difficulty".localized, systemImage: "bolt.fill", tint: palette.difficulty,
                     caption: "stats_average_short".localized)
        }
    }

    private var unit: Calendar.Component { viewModel.selectedTimeRange.performanceUnit }

    private func series(for task: StatisticsViewModel.TaskPerformanceAnalytics, color: Color) -> ComparisonSeries {
        let buckets = PerformanceBucket.make(from: task.completions, unit: unit)
        return ComparisonSeries(id: task.taskId.uuidString, name: task.taskName, color: color,
                                points: buckets.compactMap { bucket in
                                    (metric == .quality ? bucket.quality : bucket.difficulty)
                                        .map { ComparisonPoint(date: bucket.start, value: $0) }
                                })
    }

    private var trendCard: some View {
        let overallBuckets = PerformanceBucket.make(from: rated.flatMap(\.completions), unit: unit)
        let overall = ComparisonSeries(id: "overall", name: "stats_overall".localized, color: theme.accentColor,
                                       points: overallBuckets.compactMap { bucket in
                                           (metric == .quality ? bucket.quality : bucket.difficulty)
                                               .map { ComparisonPoint(date: bucket.start, value: $0) }
                                       })
        let selected = compared.enumerated().compactMap { index, id -> ComparisonSeries? in
            guard let task = rated.first(where: { $0.taskId.uuidString == id }) else { return nil }
            return series(for: task, color: ComparisonPalette.colors[index % ComparisonPalette.colors.count])
        }
        return StatsCard(title: "stats_trend".localized, subtitle: "stats_compare_hint".localized) {
            Picker("", selection: $metric) {
                ForEach(Metric.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 170)
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                ComparisonChips(items: rated.map { .init(id: $0.taskId.uuidString, name: $0.taskName,
                                                         icon: $0.displayIcon) },
                                selection: $compared)
                ComparisonLineChart(series: selected, reference: overall, unit: unit,
                                    yDomain: 0...10, yTicks: [0, 5, 10],
                                    format: { String(format: "%.1f", $0) },
                                    axisLabel: axisLabel, tooltipTitle: tooltipTitle)
                    .frame(height: 190)
                    .id("\(viewModel.selectedTimeRange)-\(metric)-\(compared.joined())")
            }
        }
    }

    private var tasksCard: some View {
        StatsCard(title: "tasks_with_performance_data".localized) {
            Menu {
                Picker("stats_sort_by".localized, selection: $sortRaw) {
                    ForEach(Sort.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down.circle")
                    .font(.title3)
                    .foregroundColor(theme.accentColor)
            }
        } content: {
            VStack(spacing: 0) {
                ForEach(Array(sortedList.enumerated()), id: \.element.id) { index, task in
                    Button { selectedTask = task } label: {
                        PerformanceTaskRow(task: task)
                    }
                    .buttonStyle(.plain)
                    if index < sortedList.count - 1 {
                        Divider().padding(.leading, 42)
                    }
                }
            }
        }
    }

    private func axisLabel(_ date: Date) -> String {
        switch unit {
        case .day, .weekOfYear: return date.formatted(.dateTime.day().month(.abbreviated))
        default: return date.formatted(.dateTime.month(.abbreviated))
        }
    }

    private func tooltipTitle(_ date: Date) -> String {
        switch unit {
        case .day: return date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
        case .weekOfYear: return String(format: "stats_week_of".localized, date.formatted(.dateTime.day().month(.abbreviated)))
        default: return date.formatted(.dateTime.month(.wide).year())
        }
    }
}

// MARK: - Quality vs difficulty map

/// One dot per task: where each task sits between "easy/hard" and "low/high quality".
private struct QualityDifficultyMap: View {
    let tasks: [StatisticsViewModel.TaskPerformanceAnalytics]
    let onOpen: (StatisticsViewModel.TaskPerformanceAnalytics) -> Void
    @Environment(\.theme) private var theme
    @State private var selectedId: UUID?

    private var points: [StatisticsViewModel.TaskPerformanceAnalytics] {
        tasks.filter { $0.averageQuality != nil && $0.averageDifficulty != nil }
    }

    private var selected: StatisticsViewModel.TaskPerformanceAnalytics? {
        points.first { $0.taskId == selectedId }
    }

    private var maxCount: Int { max(1, points.map { $0.completions.count }.max() ?? 1) }

    /// Zoom on the data but always keep the "5" dividers inside, with at least one unit beyond them.
    private var yDomain: ClosedRange<Double> {
        let minQuality = points.compactMap(\.averageQuality).min() ?? 0
        return max(0, min(4, (minQuality - 1).rounded(.down)))...10
    }

    private var xDomain: ClosedRange<Double> {
        let maxDifficulty = points.compactMap(\.averageDifficulty).max() ?? 10
        return 0...min(10, max(6, (maxDifficulty + 1).rounded(.up)))
    }

    var body: some View {
        StatsCard(title: "stats_quality_vs_difficulty".localized, subtitle: "stats_map_hint".localized) {
            if points.isEmpty {
                StatsEmptyState(systemImage: "circle.grid.cross", title: "stats_no_data_title".localized,
                                message: "stats_no_data_period".localized)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    chart.frame(height: 240)
                    if let selected {
                        selectedRow(selected)
                    }
                }
            }
        }
    }

    private var chart: some View {
        Chart {
            RuleMark(x: .value("difficulty".localized, 5)).foregroundStyle(theme.secondaryTextColor.opacity(0.25))
            RuleMark(y: .value("quality".localized, 5)).foregroundStyle(theme.secondaryTextColor.opacity(0.25))
            ForEach(points) { task in
                let isSelected = task.taskId == selectedId
                PointMark(x: .value("difficulty".localized, task.averageDifficulty ?? 0),
                          y: .value("quality".localized, task.averageQuality ?? 0))
                    .symbolSize(isSelected ? 260 : 60 + 140 * Double(task.completions.count) / Double(maxCount))
                    .foregroundStyle(Color(hex: task.categoryColor ?? "#6366F1"))
                    .opacity(selectedId == nil || isSelected ? 0.85 : 0.25)
                    .annotation(position: .top, spacing: 2) {
                        if isSelected {
                            Text(task.taskName)
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(theme.backgroundColor).shadow(color: .black.opacity(0.1), radius: 2))
                        }
                    }
            }
        }
        .chartXScale(domain: xDomain)
        .chartYScale(domain: yDomain)
        .chartXAxisLabel("difficulty".localized, alignment: .trailing)
        .chartYAxisLabel("quality".localized, position: .leading, alignment: .top)
        .chartXAxis {
            AxisMarks(values: .stride(by: 1)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3])).foregroundStyle(theme.secondaryTextColor.opacity(0.2))
                AxisValueLabel().font(.caption2).foregroundStyle(theme.secondaryTextColor)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .stride(by: 1)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3])).foregroundStyle(theme.secondaryTextColor.opacity(0.2))
                AxisValueLabel().font(.caption2).foregroundStyle(theme.secondaryTextColor)
            }
        }
        .chartBackground { proxy in
            GeometryReader { geo in
                if let frame = proxy.plotFrame.map({ geo[$0] }) {
                    quadrantLabels.frame(width: frame.width, height: frame.height).offset(x: frame.minX, y: frame.minY)
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .onTapGesture { location in
                        guard let frame = proxy.plotFrame.map({ geo[$0] }) else { return }
                        let point = CGPoint(x: location.x - frame.minX, y: location.y - frame.minY)
                        // Pick the closest dot within ~28pt.
                        var best: (UUID, CGFloat)?
                        for task in points {
                            guard let x = proxy.position(forX: task.averageDifficulty ?? 0),
                                  let y = proxy.position(forY: task.averageQuality ?? 0) else { continue }
                            let distance = hypot(x - point.x, y - point.y)
                            if distance < 28, distance < (best?.1 ?? .infinity) { best = (task.taskId, distance) }
                        }
                        withAnimation(.snappy) {
                            selectedId = best?.0 == selectedId ? nil : best?.0
                        }
                    }
            }
        }
    }

    private var quadrantLabels: some View {
        let style = Font.system(size: 9, weight: .medium)
        let color = theme.secondaryTextColor.opacity(0.7)
        return ZStack {
            Text("stats_quadrant_easy_good".localized).font(style).foregroundColor(color)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(6)
            Text("stats_quadrant_hard_good".localized).font(style).foregroundColor(color)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(6)
            Text("stats_quadrant_easy_low".localized).font(style).foregroundColor(color)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading).padding(6)
            Text("stats_quadrant_hard_low".localized).font(style).foregroundColor(color)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(6)
        }
    }

    private func selectedRow(_ task: StatisticsViewModel.TaskPerformanceAnalytics) -> some View {
        let palette = StatsPalette(theme: theme)
        return Button { onOpen(task) } label: {
            HStack(spacing: 10) {
                Circle().fill(Color(hex: task.categoryColor ?? "#6366F1")).frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 1) {
                    Text(task.taskName).font(.subheadline.weight(.semibold)).lineLimit(1).themedPrimaryText()
                    Text(String(format: "stats_ratings_count".localized, task.completions.count))
                        .font(.caption2).themedSecondaryText()
                }
                Spacer()
                Label(String(format: "%.1f", task.averageQuality ?? 0), systemImage: "star.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(palette.quality)
                Label(String(format: "%.1f", task.averageDifficulty ?? 0), systemImage: "bolt.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(palette.difficulty)
                Image(systemName: "chevron.right").font(.caption2.weight(.bold)).themedSecondaryText()
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(theme.backgroundColor))
        }
        .buttonStyle(.plain)
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
            CategoryIconTile(icon: task.displayIcon, color: Color(hex: task.categoryColor ?? "#6366F1"), size: 30)
                .overlay(alignment: .bottomTrailing) {
                    // Only a real change is worth a badge.
                    if task.improvementTrend == .improving || task.improvementTrend == .declining {
                        Image(systemName: task.improvementTrend.icon)
                            .font(.system(size: 7, weight: .black))
                            .foregroundColor(.white)
                            .frame(width: 14, height: 14)
                            .background(Circle().fill(task.improvementTrend.color))
                            .offset(x: 4, y: 4)
                    }
                }
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
