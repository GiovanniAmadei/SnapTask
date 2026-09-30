import SwiftUI
import Charts

struct ConsistencyStatsTab: View {
    @ObservedObject var viewModel: StatisticsViewModel
    @State private var selectedHabit: StatisticsViewModel.HabitSummary?
    /// Habits compared in the trend chart (empty = overall only).
    @State private var compared: [String] = []

    private var comparedHabits: [StatisticsViewModel.HabitSummary] {
        compared.compactMap { id in viewModel.habitSummaries.first { $0.taskId.uuidString == id } }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                TrendComparisonCard(viewModel: viewModel, compared: $compared)
                WeekdayConsistencyCard(viewModel: viewModel,
                                       habit: comparedHabits.count == 1 ? comparedHabits.first : nil)
                HabitRankingCard(habits: viewModel.habitSummaries) { selectedHabit = $0 }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 110) // clears the floating tab bar
        }
        .statsDebugScrollAnchor()
        .sheet(item: $selectedHabit) { habit in
            HabitDetailView(habit: habit, viewModel: viewModel)
        }
    }
}

extension StatisticsViewModel.BucketUnit {
    var calendarComponent: Calendar.Component {
        switch self {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        }
    }
}

// MARK: - Trend (overall + selected habits)

private struct TrendComparisonCard: View {
    @ObservedObject var viewModel: StatisticsViewModel
    @Binding var compared: [String]
    @Environment(\.theme) private var theme

    private var unit: StatisticsViewModel.BucketUnit { viewModel.bucketUnit(forTrend: true) }

    /// Habits with data in the period, most scheduled first.
    private var habits: [StatisticsViewModel.HabitSummary] {
        viewModel.habitSummaries.filter { $0.periodTotal > 0 }.sorted { $0.periodTotal > $1.periodTotal }
    }

    private var window: Int { RollingRate.window(unit: unit.calendarComponent, period: viewModel.selectedTimeRange) }

    private var overall: ComparisonSeries {
        ComparisonSeries(id: "overall", name: "stats_overall".localized, color: theme.accentColor,
                         points: RollingRate.points(viewModel.trendBuckets.map { ($0.start, $0.completed, $0.total) },
                                                    window: window))
    }

    private var selectedSeries: [ComparisonSeries] {
        let range = viewModel.periodDays
        return compared.enumerated().compactMap { index, id in
            guard let habit = viewModel.habitSummaries.first(where: { $0.taskId.uuidString == id }) else { return nil }
            return ComparisonSeries(id: id, name: habit.name,
                                    color: ComparisonPalette.colors[index % ComparisonPalette.colors.count],
                                    points: habit.rateSeries(unit: unit.calendarComponent, from: range.start, to: range.end,
                                                             window: window))
        }
    }

    private var subtitle: String {
        let buckets = viewModel.trendBuckets.filter { $0.total > 0 }
        let base = String(format: "stats_period_rate".localized, StatsFormat.percent(viewModel.overview.rate))
        guard buckets.count >= 4 else { return base }
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
        StatsCard(title: "stats_trend".localized, subtitle: subtitle) {
            VStack(alignment: .leading, spacing: 12) {
                ComparisonChips(items: habits.map { .init(id: $0.taskId.uuidString, name: $0.name, icon: $0.icon) },
                                selection: $compared)
                if overall.points.isEmpty {
                    StatsEmptyState(systemImage: "chart.line.uptrend.xyaxis",
                                    title: "stats_no_data_title".localized,
                                    message: "stats_no_data_period".localized)
                } else {
                    ComparisonLineChart(series: selectedSeries, reference: overall,
                                        unit: unit.calendarComponent,
                                        yDomain: 0...100, yTicks: [0, 25, 50, 75, 100],
                                        format: { "\(Int($0.rounded()))%" },
                                        axisLabel: axisLabel, tooltipTitle: tooltipTitle)
                        .frame(height: 200)
                        .id("\(viewModel.selectedTimeRange)-\(compared.joined())")
                    if !selectedSeries.isEmpty {
                        legend
                    }
                    if window > 1 {
                        Text(String(format: "stats_rolling_note".localized,
                                    unit == .week ? String(format: "stats_n_weeks".localized, window)
                                                  : String(format: "stats_n_days".localized, window)))
                            .font(.caption2)
                            .themedSecondaryText()
                    }
                }
            }
        }
        .onChange(of: viewModel.habitSummaries.map(\.taskId)) { _, ids in
            compared.removeAll { id in !ids.contains { $0.uuidString == id } }
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(compared.enumerated()), id: \.element) { index, id in
                if let habit = viewModel.habitSummaries.first(where: { $0.taskId.uuidString == id }) {
                    HStack(spacing: 8) {
                        Circle().fill(ComparisonPalette.colors[index % ComparisonPalette.colors.count]).frame(width: 8, height: 8)
                        Text(habit.name).font(.caption.weight(.medium)).lineLimit(1).themedPrimaryText()
                        Spacer()
                        Text("🔥 \(habit.currentStreak)").font(.caption2).monospacedDigit().themedSecondaryText()
                        Text(StatsFormat.percent(habit.periodRate))
                            .font(.caption.weight(.bold)).monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                            .themedPrimaryText()
                    }
                }
            }
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 1).fill(theme.secondaryTextColor.opacity(0.55)).frame(width: 8, height: 2)
                Text("stats_overall".localized).font(.caption).themedSecondaryText()
                Spacer()
                Text(StatsFormat.percent(viewModel.overview.rate))
                    .font(.caption.weight(.semibold)).monospacedDigit()
                    .frame(width: 40, alignment: .trailing)
                    .themedSecondaryText()
            }
        }
    }

    private func axisLabel(_ date: Date) -> String {
        switch viewModel.selectedTimeRange {
        case .today, .week: return date.formatted(.dateTime.weekday(.abbreviated))
        case .month: return date.formatted(.dateTime.day().month(.abbreviated))
        case .year: return date.formatted(.dateTime.month(.abbreviated))
        case .allTime: return date.formatted(.dateTime.month(.abbreviated).year(.twoDigits))
        }
    }

    private func tooltipTitle(_ date: Date) -> String {
        switch unit {
        case .day: return date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
        case .week: return String(format: "stats_week_of".localized, date.formatted(.dateTime.day().month(.abbreviated)))
        case .month: return date.formatted(.dateTime.month(.wide).year())
        }
    }
}

// MARK: - Weekday

private struct WeekdayConsistencyCard: View {
    @ObservedObject var viewModel: StatisticsViewModel
    /// When a single habit is being compared, the card follows it.
    let habit: StatisticsViewModel.HabitSummary?
    @Environment(\.theme) private var theme

    private var rates: [StatisticsViewModel.WeekdayRate] {
        guard let habit else { return viewModel.weekdayRates }
        let calendar = Calendar.current
        let range = viewModel.periodDays
        var grouped: [Int: (Int, Int)] = [:]
        for day in habit.days where day.date >= range.start && day.date <= range.end && (day.state == .done || day.state == .missed) {
            let weekday = calendar.component(.weekday, from: day.date)
            grouped[weekday, default: (0, 0)].1 += 1
            if day.state == .done { grouped[weekday, default: (0, 0)].0 += 1 }
        }
        return (0..<7).map { offset in
            let weekday = (calendar.firstWeekday - 1 + offset) % 7 + 1
            return .init(weekday: weekday, completed: grouped[weekday]?.0 ?? 0, total: grouped[weekday]?.1 ?? 0)
        }
    }

    private var best: StatisticsViewModel.WeekdayRate? {
        let active = rates.filter { $0.total > 0 }
        guard let top = active.max(by: { $0.rate < $1.rate }),
              let bottom = active.min(by: { $0.rate < $1.rate }),
              top.rate - bottom.rate >= 0.05 else { return nil }
        return top
    }

    var body: some View {
        let accent = habit.map { _ in ComparisonPalette.colors[0] } ?? StatsPalette(theme: theme).completed
        let symbols = Calendar.current.shortWeekdaySymbols
        let bestText = best.map { String(format: "stats_best_day".localized, Calendar.current.weekdaySymbols[$0.weekday - 1]) }
            ?? (rates.contains { $0.total > 0 } ? "stats_weekdays_even".localized : nil)
        let subtitle = [habit?.name, bestText].compactMap { $0 }.joined(separator: " · ")
        StatsCard(title: "stats_by_weekday".localized, subtitle: subtitle.isEmpty ? nil : subtitle) {
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
                .id("\(viewModel.selectedTimeRange)-\(habit?.taskId.uuidString ?? "")")
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
