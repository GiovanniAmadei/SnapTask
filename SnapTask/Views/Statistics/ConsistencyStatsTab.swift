import SwiftUI
import Charts

struct ConsistencyStatsTab: View {
    @ObservedObject var viewModel: StatisticsViewModel
    @State private var selectedHabit: StatisticsViewModel.HabitSummary?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                OverallTrendCard(viewModel: viewModel)
                WeekdayConsistencyCard(rates: viewModel.weekdayRates)
                HabitRankingCard(habits: viewModel.habitSummaries) { selectedHabit = $0 }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .sheet(item: $selectedHabit) { habit in
            HabitDetailView(habit: habit, viewModel: viewModel)
        }
    }
}

// MARK: - Overall trend

private struct OverallTrendCard: View {
    @ObservedObject var viewModel: StatisticsViewModel
    @Environment(\.theme) private var theme
    @State private var selectedDate: Date?

    private var unit: StatisticsViewModel.BucketUnit { viewModel.bucketUnit(forTrend: true) }
    private var buckets: [StatisticsViewModel.CompletionBucket] { viewModel.trendBuckets.filter { $0.total > 0 } }

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

    private var subtitle: String {
        let base = String(format: "stats_period_rate".localized, StatsFormat.percent(viewModel.overview.rate))
        guard buckets.count >= 4 else { return base }
        // Compare the second half of the period with the first half.
        let half = buckets.count / 2
        let first = buckets.prefix(half).reduce((0, 0)) { ($0.0 + $1.completed, $0.1 + $1.total) }
        let second = buckets.suffix(half).reduce((0, 0)) { ($0.0 + $1.completed, $0.1 + $1.total) }
        guard first.1 > 0, second.1 > 0 else { return base }
        let delta = Int(((Double(second.0) / Double(second.1)) - (Double(first.0) / Double(first.1))) * 100)
        let trend = delta == 0 ? "stats_trend_stable".localized
            : String(format: "stats_trend_delta".localized, delta > 0 ? "+\(delta)" : "\(delta)")
        return base + " · " + trend
    }

    var body: some View {
        let accent = StatsPalette(theme: theme).completed
        StatsCard(title: "stats_overall_trend".localized, subtitle: subtitle) {
            if buckets.isEmpty {
                StatsEmptyState(systemImage: "chart.line.uptrend.xyaxis",
                                title: "stats_no_data_title".localized,
                                message: "stats_no_data_period".localized)
            } else {
                Chart {
                    ForEach(buckets) { bucket in
                        AreaMark(x: .value("date".localized, bucket.start, unit: calendarUnit),
                                 y: .value("stats_completion_rate".localized, bucket.rate * 100))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(LinearGradient(colors: [accent.opacity(0.3), accent.opacity(0.02)],
                                                            startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("date".localized, bucket.start, unit: calendarUnit),
                                 y: .value("stats_completion_rate".localized, bucket.rate * 100))
                            .interpolationMethod(.monotone)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .foregroundStyle(accent)
                    }
                    if let bucket = selectedBucket {
                        RuleMark(x: .value("date".localized, bucket.start, unit: calendarUnit))
                            .foregroundStyle(theme.secondaryTextColor.opacity(0.4))
                        PointMark(x: .value("date".localized, bucket.start, unit: calendarUnit),
                                  y: .value("stats_completion_rate".localized, bucket.rate * 100))
                            .foregroundStyle(accent)
                            .annotation(position: .top, spacing: 6,
                                        overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                                ChartTooltip(title: StatsFormat.bucketTitle(bucket, unit: unit), lines: [
                                    (accent, "\(StatsFormat.percent(bucket.rate)) · \(bucket.completed)/\(bucket.total)")
                                ])
                            }
                    }
                }
                .chartYScale(domain: 0...100)
                .chartXSelection(value: $selectedDate)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                            .foregroundStyle(theme.secondaryTextColor.opacity(0.2))
                        AxisValueLabel { Text("\(value.as(Int.self) ?? 0)%") }
                            .font(.caption2)
                            .foregroundStyle(theme.secondaryTextColor)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: xAxisValues) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(xLabel(date))
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(theme.secondaryTextColor)
                    }
                }
                .frame(height: 190)
            }
        }
    }

    private var xAxisValues: AxisMarkValues {
        switch viewModel.selectedTimeRange {
        case .today, .week: return .stride(by: .day)
        case .month: return .stride(by: .day, count: 7)
        case .year: return .stride(by: .month, count: 2)
        case .allTime: return .automatic(desiredCount: 6)
        }
    }

    private func xLabel(_ date: Date) -> String {
        switch viewModel.selectedTimeRange {
        case .today, .week: return date.formatted(.dateTime.weekday(.abbreviated))
        case .month: return date.formatted(.dateTime.day().month(.abbreviated))
        case .year: return date.formatted(.dateTime.month(.abbreviated))
        case .allTime: return date.formatted(.dateTime.month(.abbreviated).year(.twoDigits))
        }
    }
}

// MARK: - Weekday

private struct WeekdayConsistencyCard: View {
    let rates: [StatisticsViewModel.WeekdayRate]
    @Environment(\.theme) private var theme

    private var best: StatisticsViewModel.WeekdayRate? {
        let active = rates.filter { $0.total > 0 }
        guard let top = active.max(by: { $0.rate < $1.rate }),
              let bottom = active.min(by: { $0.rate < $1.rate }),
              top.rate - bottom.rate >= 0.05 else { return nil }
        return top
    }

    var body: some View {
        let accent = StatsPalette(theme: theme).completed
        let symbols = Calendar.current.shortWeekdaySymbols
        let subtitle = best.map { String(format: "stats_best_day".localized, Calendar.current.weekdaySymbols[$0.weekday - 1]) }
            ?? (rates.contains { $0.total > 0 } ? "stats_weekdays_even".localized : nil)
        StatsCard(title: "stats_by_weekday".localized, subtitle: subtitle) {
            if rates.allSatisfy({ $0.total == 0 }) {
                StatsEmptyState(systemImage: "calendar", title: "stats_no_data_title".localized,
                                message: "stats_no_data_period".localized)
            } else {
                Chart(rates) { item in
                    BarMark(x: .value("day".localized, symbols[item.weekday - 1]),
                            y: .value("stats_completion_rate".localized, item.rate * 100))
                        .foregroundStyle(best == nil || item.weekday == best?.weekday ? accent : accent.opacity(0.45))
                        .cornerRadius(4)
                        .annotation(position: .top, spacing: 2) {
                            Text(item.total > 0 ? StatsFormat.percent(item.rate) : "–")
                                .font(.system(size: 9, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(theme.secondaryTextColor)
                        }
                }
                .chartYScale(domain: 0...115)
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.caption2)
                            .foregroundStyle(theme.secondaryTextColor)
                    }
                }
                .frame(height: 120)
            }
        }
    }
}

// MARK: - Per habit ranking

private struct HabitRankingCard: View {
    let habits: [StatisticsViewModel.HabitSummary]
    let onSelect: (StatisticsViewModel.HabitSummary) -> Void
    @State private var showsAll = false
    @Environment(\.theme) private var theme

    private let collapsedCount = 8

    private var ranked: [StatisticsViewModel.HabitSummary] {
        // Habits with very few occurrences (e.g. 1/1) go after the ones with enough data to be meaningful.
        habits.filter { $0.periodTotal > 0 }.sorted {
            let lhsReliable = $0.periodTotal >= 4, rhsReliable = $1.periodTotal >= 4
            if lhsReliable != rhsReliable { return lhsReliable }
            if $0.periodRate != $1.periodRate { return $0.periodRate > $1.periodRate }
            return $0.periodTotal > $1.periodTotal
        }
    }

    var body: some View {
        StatsCard(title: "stats_by_habit".localized, subtitle: "stats_by_habit_subtitle".localized) {
            if ranked.isEmpty {
                StatsEmptyState(systemImage: "list.bullet", title: "stats_no_habits_title".localized,
                                message: "stats_no_habits_message".localized)
            } else {
                VStack(spacing: 12) {
                    ForEach(showsAll ? ranked : Array(ranked.prefix(collapsedCount))) { habit in
                        Button { onSelect(habit) } label: { row(habit) }
                            .buttonStyle(.plain)
                    }
                    if ranked.count > collapsedCount {
                        Button {
                            withAnimation(.snappy) { showsAll.toggle() }
                        } label: {
                            Text(showsAll ? "stats_show_less".localized
                                 : String(format: "stats_show_all".localized, ranked.count))
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(theme.accentColor)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func row(_ habit: StatisticsViewModel.HabitSummary) -> some View {
        let color = Color(hex: habit.color)
        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Image(systemName: habit.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 16)
                Text(habit.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .themedPrimaryText()
                Spacer(minLength: 6)
                Text("\(habit.periodCompleted)/\(habit.periodTotal)")
                    .font(.caption2)
                    .monospacedDigit()
                    .themedSecondaryText()
                Text(StatsFormat.percent(habit.periodRate))
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .frame(width: 38, alignment: .trailing)
                    .themedPrimaryText()
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.15))
                    Capsule().fill(color)
                        .frame(width: max(6, proxy.size.width * habit.periodRate))
                }
            }
            .frame(height: 6)
        }
        .contentShape(Rectangle())
    }
}
