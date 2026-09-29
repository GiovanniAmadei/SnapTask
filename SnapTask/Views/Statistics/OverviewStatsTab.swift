import SwiftUI
import Charts

struct OverviewStatsTab: View {
    @ObservedObject var viewModel: StatisticsViewModel
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                kpiGrid
                TimeDistributionChartCard(stats: viewModel.categoryStats)
                CompletionChartCard(viewModel: viewModel)
                MoodTrendCard(timeRange: viewModel.selectedTimeRange)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
    }

    private var kpiGrid: some View {
        let overview = viewModel.overview
        let palette = StatsPalette(theme: theme)
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            StatTile(value: "\(overview.completed)",
                     label: "stats_completed".localized,
                     systemImage: "checkmark.circle.fill",
                     tint: palette.completed,
                     caption: String(format: "stats_of_scheduled".localized, overview.total))
            StatTile(value: StatsFormat.percent(overview.rate),
                     label: "stats_completion_rate".localized,
                     systemImage: "chart.bar.fill",
                     tint: .blue,
                     caption: String(format: "stats_active_days_of".localized, overview.activeDays, overview.daysInPeriod))
            StatTile(value: StatsFormat.hours(overview.trackedHours),
                     label: "stats_time_spent".localized,
                     systemImage: "clock.fill",
                     tint: .purple)
            StatTile(value: "\(viewModel.currentStreak)",
                     label: "stats_active_streak".localized,
                     systemImage: "flame.fill",
                     tint: .orange,
                     caption: String(format: "stats_record_days".localized, viewModel.bestStreak))
        }
    }
}

// MARK: - Time distribution

private struct TimeDistributionChartCard: View {
    let stats: [StatisticsViewModel.CategoryStat]
    @Environment(\.theme) private var theme
    @State private var selectedAngle: Double?

    private struct Slice: Identifiable {
        let id: String
        let name: String
        let color: Color
        let hours: Double
    }

    /// Top 5 categories, the rest grouped as "Altro" so the donut stays readable.
    private var slices: [Slice] {
        let sorted = stats.sorted { $0.hours > $1.hours }
        var result = sorted.prefix(5).map { Slice(id: $0.name, name: displayName($0.name), color: Color(hex: $0.color), hours: $0.hours) }
        let rest = sorted.dropFirst(5).reduce(0) { $0 + $1.hours }
        if rest > 0 {
            result.append(Slice(id: "__other", name: "stats_other".localized, color: theme.secondaryTextColor.opacity(0.4), hours: rest))
        }
        return result
    }

    private func displayName(_ name: String) -> String {
        name == "Uncategorized" ? "uncategorized".localized : name
    }

    private var total: Double { slices.reduce(0) { $0 + $1.hours } }

    private var selectedSlice: Slice? {
        guard let selectedAngle else { return nil }
        var cumulative = 0.0
        for slice in slices {
            cumulative += slice.hours
            if selectedAngle <= cumulative { return slice }
        }
        return nil
    }

    var body: some View {
        StatsCard(title: "time_distribution".localized) {
            if slices.isEmpty {
                StatsEmptyState(systemImage: "clock",
                                title: "stats_no_time_title".localized,
                                message: "stats_no_time_message".localized)
            } else {
                HStack(alignment: .center, spacing: 16) {
                    donut.frame(width: 140, height: 140)
                    legend
                }
            }
        }
    }

    private var donut: some View {
        Chart(slices) { slice in
            SectorMark(angle: .value("hours".localized, slice.hours),
                       innerRadius: .ratio(0.68),
                       angularInset: 1.5)
                .cornerRadius(3)
                .foregroundStyle(slice.color)
                .opacity(selectedSlice == nil || selectedSlice?.id == slice.id ? 1 : 0.35)
        }
        .chartAngleSelection(value: $selectedAngle)
        .chartBackground { _ in
            VStack(spacing: 0) {
                Text(StatsFormat.hours(selectedSlice?.hours ?? total))
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .themedPrimaryText()
                Text(selectedSlice?.name ?? "stats_total".localized)
                    .font(.caption2)
                    .lineLimit(1)
                    .frame(maxWidth: 80)
                    .themedSecondaryText()
            }
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(slices) { slice in
                HStack(spacing: 8) {
                    Circle().fill(slice.color).frame(width: 8, height: 8)
                    Text(slice.name)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                        .themedPrimaryText()
                    Spacer(minLength: 4)
                    Text(StatsFormat.hours(slice.hours))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .themedPrimaryText()
                    Text(StatsFormat.percent(total > 0 ? slice.hours / total : 0))
                        .font(.caption2)
                        .monospacedDigit()
                        .frame(width: 32, alignment: .trailing)
                        .themedSecondaryText()
                }
                .opacity(selectedSlice == nil || selectedSlice?.id == slice.id ? 1 : 0.4)
            }
        }
    }
}

// MARK: - Completion

private struct CompletionChartCard: View {
    @ObservedObject var viewModel: StatisticsViewModel
    @Environment(\.theme) private var theme
    @State private var selectedDate: Date?

    private var unit: StatisticsViewModel.BucketUnit { viewModel.bucketUnit(forTrend: false) }
    private var buckets: [StatisticsViewModel.CompletionBucket] { viewModel.completionBuckets }

    private var calendarUnit: Calendar.Component {
        switch unit {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        }
    }

    private var selectedBucket: StatisticsViewModel.CompletionBucket? {
        guard let selectedDate else { return nil }
        let day = Calendar.current.startOfDay(for: selectedDate)
        return buckets.first { day >= $0.start && day <= $0.end }
    }

    private var averageCompleted: Double {
        guard !buckets.isEmpty else { return 0 }
        return Double(buckets.reduce(0) { $0 + $1.completed }) / Double(buckets.count)
    }

    var body: some View {
        let palette = StatsPalette(theme: theme)
        StatsCard(title: "task_completion_rate".localized,
                  subtitle: String(format: "stats_average_per_bucket".localized, averageCompleted, bucketName)) {
            if buckets.allSatisfy({ $0.total == 0 }) {
                StatsEmptyState(systemImage: "checklist",
                                title: "stats_no_tasks_title".localized,
                                message: "stats_no_tasks_message".localized)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    chart(palette)
                        .frame(height: 180)
                    HStack(spacing: 14) {
                        LegendDot(color: palette.completed, label: "completed".localized)
                        LegendDot(color: palette.missed, label: "stats_legend_missed".localized)
                    }
                }
            }
        }
    }

    private var bucketName: String {
        switch unit {
        case .day: return "stats_per_day".localized
        case .week: return "stats_per_week".localized
        case .month: return "stats_per_month".localized
        }
    }

    private func chart(_ palette: StatsPalette) -> some View {
        Chart {
            ForEach(buckets) { bucket in
                BarMark(x: .value("date".localized, bucket.start, unit: calendarUnit),
                        y: .value("completed".localized, bucket.completed))
                    .foregroundStyle(palette.completed)
                    .opacity(selectedBucket == nil || selectedBucket == bucket ? 1 : 0.4)
                BarMark(x: .value("date".localized, bucket.start, unit: calendarUnit),
                        y: .value("stats_legend_missed".localized, bucket.missed))
                    .foregroundStyle(palette.missed)
                    .opacity(selectedBucket == nil || selectedBucket == bucket ? 1 : 0.4)
            }
            RuleMark(y: .value("average".localized, averageCompleted))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(theme.textColor.opacity(0.35))

            if let bucket = selectedBucket {
                RuleMark(x: .value("date".localized, bucket.start, unit: calendarUnit))
                    .foregroundStyle(.clear)
                    .annotation(position: .top, spacing: 4,
                                overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        ChartTooltip(title: StatsFormat.bucketTitle(bucket, unit: unit), lines: [
                            (palette.completed, "\(bucket.completed)/\(bucket.total) · \(StatsFormat.percent(bucket.rate))")
                        ])
                    }
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartXAxis {
            AxisMarks(values: xAxisValues) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(StatsFormat.bucketLabel(date, unit: unit, period: viewModel.selectedTimeRange))
                    }
                }
                .font(.caption2)
                .foregroundStyle(theme.secondaryTextColor)
            }
        }
        .statsAxisStyle(theme)
    }

    private var xAxisValues: AxisMarkValues {
        switch (unit, viewModel.selectedTimeRange) {
        case (.day, .week): return .stride(by: .day)
        case (.day, _): return .stride(by: .day, count: 7)
        case (.week, _): return .stride(by: .month)
        case (.month, .allTime): return .automatic(desiredCount: 6)
        case (.month, _): return .stride(by: .month)
        }
    }
}
