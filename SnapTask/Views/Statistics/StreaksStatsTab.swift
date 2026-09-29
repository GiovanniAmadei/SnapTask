import SwiftUI
import Charts

struct StreaksStatsTab: View {
    @ObservedObject var viewModel: StatisticsViewModel
    @AppStorage("statsHabitSort") private var sortRaw = HabitSort.currentStreak.rawValue
    @State private var selectedHabit: StatisticsViewModel.HabitSummary?
    @Environment(\.theme) private var theme

    enum HabitSort: String, CaseIterable {
        case currentStreak, bestStreak, rate, name

        var title: String {
            switch self {
            case .currentStreak: return "stats_sort_current".localized
            case .bestStreak: return "stats_sort_best".localized
            case .rate: return "stats_sort_rate".localized
            case .name: return "stats_sort_name".localized
            }
        }
    }

    private var sort: HabitSort { HabitSort(rawValue: sortRaw) ?? .currentStreak }

    private var habits: [StatisticsViewModel.HabitSummary] {
        let list = viewModel.habitSummaries
        switch sort {
        case .currentStreak: return list.sorted { ($0.currentStreak, $0.bestStreak) > ($1.currentStreak, $1.bestStreak) }
        case .bestStreak: return list.sorted { ($0.bestStreak, $0.currentStreak) > ($1.bestStreak, $1.currentStreak) }
        case .rate: return list.sorted { $0.periodRate > $1.periodRate }
        case .name: return list.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if habits.isEmpty {
                    StatsCard(title: "streaks".localized) {
                        StatsEmptyState(systemImage: "flame",
                                        title: "stats_no_habits_title".localized,
                                        message: "stats_no_habits_message".localized)
                    }
                } else {
                    header
                    ForEach(habits) { habit in
                        Button { selectedHabit = habit } label: {
                            HabitRow(habit: habit)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .sheet(item: $selectedHabit) { habit in
            HabitDetailView(habit: habit, viewModel: viewModel)
        }
    }

    private var header: some View {
        HStack {
            Text(String(format: "stats_habits_count".localized, habits.count))
                .font(.footnote.weight(.medium))
                .themedSecondaryText()
            Spacer()
            Menu {
                Picker("stats_sort_by".localized, selection: $sortRaw) {
                    ForEach(HabitSort.allCases, id: \.rawValue) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                    Text(sort.title)
                }
                .font(.footnote.weight(.semibold))
                .foregroundColor(theme.accentColor)
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Row

private struct HabitRow: View {
    let habit: StatisticsViewModel.HabitSummary
    @Environment(\.theme) private var theme

    var body: some View {
        let color = Color(hex: habit.color)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                CategoryIconTile(icon: habit.icon, color: color, size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(habit.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .themedPrimaryText()
                    if let category = habit.categoryName {
                        Text(category)
                            .font(.caption2)
                            .lineLimit(1)
                            .themedSecondaryText()
                    }
                }
                Spacer(minLength: 6)
                HStack(spacing: 12) {
                    metric(icon: "flame.fill", tint: .orange, value: "\(habit.currentStreak)")
                    metric(icon: "trophy.fill", tint: .yellow, value: "\(habit.bestStreak)")
                    Text(StatsFormat.percent(habit.periodRate))
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .frame(minWidth: 40, alignment: .trailing)
                        .themedPrimaryText()
                }
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(theme.secondaryTextColor.opacity(0.5))
            }
            HabitHeatmap(days: habit.days, color: color, cellSize: 9, spacing: 2, showsLabels: false)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.surfaceColor)
        )
        .contentShape(Rectangle())
    }

    private func metric(icon: String, tint: Color, value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(tint)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .themedPrimaryText()
        }
    }
}

// MARK: - Detail

struct HabitDetailView: View {
    let habit: StatisticsViewModel.HabitSummary
    @ObservedObject var viewModel: StatisticsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var selectedDate: Date?

    private var color: Color { Color(hex: habit.color) }

    private var periodDays: [StatisticsViewModel.HabitDay] {
        let range = viewModel.periodDays
        return habit.days.filter { $0.date >= range.start && $0.date <= range.end }
    }

    private struct RateBucket: Identifiable, Equatable {
        var id: Date { start }
        let start: Date
        let completed: Int
        let total: Int
        var rate: Double { total > 0 ? Double(completed) / Double(total) : 0 }
    }

    private var bucketComponent: Calendar.Component {
        switch viewModel.selectedTimeRange {
        case .today, .week, .month: return .weekOfYear
        case .year, .allTime: return .month
        }
    }

    private var rateBuckets: [RateBucket] {
        let calendar = Calendar.current
        var grouped: [Date: (Int, Int)] = [:]
        for day in periodDays where day.state == .done || day.state == .missed {
            let key = calendar.dateInterval(of: bucketComponent, for: day.date)?.start ?? day.date
            grouped[key, default: (0, 0)].1 += 1
            if day.state == .done { grouped[key, default: (0, 0)].0 += 1 }
        }
        return grouped.map { RateBucket(start: $0.key, completed: $0.value.0, total: $0.value.1) }
            .sorted { $0.start < $1.start }
    }

    private var weekdayRates: [(weekday: Int, rate: Double, total: Int)] {
        let calendar = Calendar.current
        var grouped: [Int: (Int, Int)] = [:]
        for day in periodDays where day.state == .done || day.state == .missed {
            let weekday = calendar.component(.weekday, from: day.date)
            grouped[weekday, default: (0, 0)].1 += 1
            if day.state == .done { grouped[weekday, default: (0, 0)].0 += 1 }
        }
        return (0..<7).compactMap { offset in
            let weekday = (calendar.firstWeekday - 1 + offset) % 7 + 1
            guard let value = grouped[weekday] else { return nil }
            return (weekday, Double(value.0) / Double(value.1), value.1)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header
                    tiles
                    StatsCard(title: "stats_calendar".localized) {
                        VStack(alignment: .leading, spacing: 10) {
                            HabitHeatmap(days: habit.days, color: color, cellSize: 14, spacing: 3, scrollable: true)
                            HabitHeatmapLegend(color: color)
                        }
                    }
                    trendCard
                    weekdayCard
                }
                .padding(16)
            }
            .themedBackground()
            .navigationTitle(habit.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("done".localized) { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            CategoryIconTile(icon: habit.icon, color: color, size: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(habit.name)
                    .font(.title3.weight(.bold))
                    .themedPrimaryText()
                if let category = habit.categoryName {
                    Text(category)
                        .font(.subheadline)
                        .themedSecondaryText()
                }
            }
            Spacer()
        }
    }

    private var tiles: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            StatTile(value: "\(habit.currentStreak)", label: "current".localized, systemImage: "flame.fill", tint: .orange)
            StatTile(value: "\(habit.bestStreak)", label: "best".localized, systemImage: "trophy.fill", tint: .yellow)
            StatTile(value: StatsFormat.percent(habit.periodRate), label: "stats_completion_rate".localized,
                     systemImage: "chart.bar.fill", tint: color)
            StatTile(value: "\(habit.periodCompleted)/\(habit.periodTotal)", label: "completed".localized,
                     systemImage: "checkmark.circle.fill", tint: .green)
        }
    }

    private var trendCard: some View {
        StatsCard(title: "stats_trend".localized,
                  subtitle: bucketComponent == .month ? "stats_rate_per_month".localized : "stats_rate_per_week".localized) {
            if rateBuckets.isEmpty {
                StatsEmptyState(systemImage: "chart.bar", title: "stats_no_data_title".localized,
                                message: "stats_no_data_period".localized)
            } else {
                Chart(rateBuckets) { bucket in
                    BarMark(x: .value("date".localized, bucket.start, unit: bucketComponent),
                            y: .value("stats_completion_rate".localized, bucket.rate * 100))
                        .foregroundStyle(color.gradient)
                        .cornerRadius(3)
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                            .foregroundStyle(theme.secondaryTextColor.opacity(0.2))
                        AxisValueLabel { Text("\(value.as(Int.self) ?? 0)%") }
                            .font(.caption2)
                            .foregroundStyle(theme.secondaryTextColor)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 6)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(bucketComponent == .month
                                     ? date.formatted(.dateTime.month(.abbreviated))
                                     : date.formatted(.dateTime.day().month(.abbreviated)))
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(theme.secondaryTextColor)
                    }
                }
                .frame(height: 150)
            }
        }
    }

    private var weekdayCard: some View {
        let symbols = Calendar.current.shortWeekdaySymbols
        return StatsCard(title: "stats_by_weekday".localized) {
            if weekdayRates.isEmpty {
                StatsEmptyState(systemImage: "calendar", title: "stats_no_data_title".localized,
                                message: "stats_no_data_period".localized)
            } else {
                VStack(spacing: 8) {
                    ForEach(weekdayRates, id: \.weekday) { item in
                        HStack(spacing: 10) {
                            Text(symbols[item.weekday - 1])
                                .font(.caption.weight(.medium))
                                .frame(width: 34, alignment: .leading)
                                .themedSecondaryText()
                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(color.opacity(0.15))
                                    Capsule().fill(color)
                                        .frame(width: max(6, proxy.size.width * item.rate))
                                }
                            }
                            .frame(height: 8)
                            Text(StatsFormat.percent(item.rate))
                                .font(.caption.weight(.semibold))
                                .monospacedDigit()
                                .frame(width: 40, alignment: .trailing)
                                .themedPrimaryText()
                        }
                    }
                }
            }
        }
    }
}
