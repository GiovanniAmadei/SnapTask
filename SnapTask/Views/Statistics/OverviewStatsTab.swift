import SwiftUI
import Charts

struct OverviewStatsTab: View {
    @ObservedObject var viewModel: StatisticsViewModel
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                kpiGrid
                TimeDistributionChartCard(viewModel: viewModel)
                CompletionChartCard(viewModel: viewModel)
                MoodTrendCard(timeRange: viewModel.selectedTimeRange, dailyCompletion: viewModel.dailyCompletion)
                    .id(viewModel.selectedTimeRange)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 110) // clears the floating tab bar
        }
        .statsDebugScrollAnchor()
    }

    private var kpiGrid: some View {
        let overview = viewModel.overview
        let palette = StatsPalette(theme: theme)
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            StatTile(value: "\(overview.completed)",
                     label: "stats_completed".localized,
                     systemImage: "checkmark.circle.fill",
                     tint: palette.completed,
                     caption: overview.pending > 0
                        ? String(format: "stats_of_scheduled_pending".localized, overview.total, overview.pending)
                        : String(format: "stats_of_scheduled".localized, overview.total))
            StatTile(value: StatsFormat.percent(overview.rate),
                     label: "stats_completion_rate".localized,
                     systemImage: "chart.bar.fill",
                     tint: .blue,
                     caption: String(format: "stats_active_days_of".localized, overview.activeDays, overview.daysInPeriod))
            StatTile(value: StatsFormat.hours(overview.trackedHours),
                     label: "stats_time_spent".localized,
                     systemImage: "clock.fill",
                     tint: .purple,
                     caption: overview.daysInPeriod > 0
                        ? String(format: "stats_per_day_avg".localized, StatsFormat.hours(overview.trackedHours / Double(overview.daysInPeriod)))
                        : nil)
            StatTile(value: "\(viewModel.currentStreak)",
                     label: "stats_active_streak".localized,
                     systemImage: "flame.fill",
                     tint: .orange,
                     caption: String(format: "stats_record_days".localized, viewModel.bestStreak))
        }
    }
}

// MARK: - Time distribution

private struct DonutSlice: Identifiable, Equatable {
    let id: String
    let name: String
    let color: Color
    let hours: Double
    let previousHours: Double?
    let icon: String
    /// The categories behind the slice (one, or several for "Altro").
    let stats: [StatisticsViewModel.CategoryStat]
}

private struct TimeDistributionChartCard: View {
    @ObservedObject var viewModel: StatisticsViewModel
    @Environment(\.theme) private var theme
    @State private var selectedAngle: Double?
    @State private var detailSlice: DonutSlice?

    private func displayName(_ name: String) -> String {
        name == "Uncategorized" ? "uncategorized".localized : name
    }

    /// Top 5 categories, the rest grouped as "Altro" so the donut stays readable.
    private var slices: [DonutSlice] {
        let previous = viewModel.previousCategoryHours
        let hasPrevious = viewModel.hasPreviousPeriod
        let sorted = viewModel.categoryStats.sorted { $0.hours > $1.hours }
        var result = sorted.prefix(5).map { stat in
            DonutSlice(id: stat.name, name: displayName(stat.name), color: Color(hex: stat.color), hours: stat.hours,
                       previousHours: hasPrevious ? (previous[stat.name] ?? 0) : nil,
                       icon: stat.icon ?? (stat.categoryId == nil ? "questionmark.circle" : "tag.fill"), stats: [stat])
        }
        let rest = Array(sorted.dropFirst(5))
        if !rest.isEmpty {
            result.append(DonutSlice(id: "__other", name: "stats_other".localized,
                                     color: theme.secondaryTextColor.opacity(0.4),
                                     hours: rest.reduce(0) { $0 + $1.hours },
                                     previousHours: hasPrevious ? rest.reduce(0) { $0 + (previous[$1.name] ?? 0) } : nil,
                                     icon: "ellipsis.circle", stats: rest))
        }
        return result
    }

    private var total: Double { slices.reduce(0) { $0 + $1.hours } }

    private func slice(at angle: Double?) -> DonutSlice? {
        guard let angle else { return nil }
        var cumulative = 0.0
        for slice in slices {
            cumulative += slice.hours
            if angle <= cumulative { return slice }
        }
        return nil
    }

    private var selectedSlice: DonutSlice? { slice(at: selectedAngle) }

    private var previousTotal: Double? {
        guard viewModel.hasPreviousPeriod else { return nil }
        return viewModel.previousCategoryHours.values.reduce(0, +)
    }

    var body: some View {
        StatsCard(title: "time_distribution".localized,
                  subtitle: slices.isEmpty ? nil : "stats_tap_category_hint".localized) {
            if let previousTotal, !slices.isEmpty {
                DeltaBadge(current: total, previous: previousTotal)
            }
        } content: {
            if slices.isEmpty {
                StatsEmptyState(systemImage: "clock",
                                title: "stats_no_time_title".localized,
                                message: "stats_no_time_message".localized)
            } else {
                VStack(spacing: 16) {
                    donut.frame(width: 170, height: 170)
                        .id(slices.map(\.id).joined(separator: "|") + "\(viewModel.selectedTimeRange)")
                    legend
                }
            }
        }
        .sheet(item: $detailSlice) { slice in
            CategoryDetailSheet(slice: slice, viewModel: viewModel, totalHours: total)
        }
    }

    private var donut: some View {
        Chart(slices) { slice in
            SectorMark(angle: .value("hours".localized, slice.hours),
                       innerRadius: .ratio(0.64),
                       outerRadius: .ratio(selectedSlice?.id == slice.id ? 1 : 0.94),
                       angularInset: 1.5)
                .cornerRadius(4)
                .foregroundStyle(slice.color)
                .opacity(selectedSlice == nil || selectedSlice?.id == slice.id ? 1 : 0.35)
        }
        .chartAngleSelection(value: $selectedAngle)
        .chartOverlay { _ in
            // A single tap on a slice opens its detail (angle selection alone only reacts to drags).
            GeometryReader { geo in
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                        let dx = location.x - center.x, dy = location.y - center.y
                        let radius = min(geo.size.width, geo.size.height) / 2
                        let distance = hypot(dx, dy)
                        guard distance > radius * 0.55, distance < radius * 1.05, total > 0 else { return }
                        var angle = atan2(dx, -dy)  // 0 at 12 o'clock, clockwise
                        if angle < 0 { angle += 2 * .pi }
                        if let hit = slice(at: angle / (2 * .pi) * total) {
                            selectedAngle = angle / (2 * .pi) * total
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                selectedAngle = nil
                                detailSlice = hit
                            }
                        }
                    }
            }
        }
        .animation(.snappy(duration: 0.2), value: selectedSlice?.id)
        .chartBackground { _ in
            VStack(spacing: 1) {
                if let selectedSlice {
                    Image(systemName: selectedSlice.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(selectedSlice.color)
                }
                Text(StatsFormat.hours(selectedSlice?.hours ?? total))
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: 96)
                    .themedPrimaryText()
                Text(selectedSlice.map { "\($0.name) · \(StatsFormat.percent(total > 0 ? $0.hours / total : 0))" }
                     ?? "stats_total".localized)
                    .font(.caption2)
                    .lineLimit(1)
                    .frame(maxWidth: 96)
                    .themedSecondaryText()
            }
        }
    }

    private var legend: some View {
        VStack(spacing: 0) {
            ForEach(Array(slices.enumerated()), id: \.element.id) { index, slice in
                Button { detailSlice = slice } label: {
                    HStack(spacing: 10) {
                        CategoryIconTile(icon: slice.icon, color: slice.color, size: 28)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(slice.name)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(1)
                                    .themedPrimaryText()
                                Spacer(minLength: 6)
                                Text(StatsFormat.hours(slice.hours))
                                    .font(.subheadline.weight(.semibold))
                                    .monospacedDigit()
                                    .themedPrimaryText()
                            }
                            HStack(spacing: 8) {
                                GeometryReader { proxy in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(slice.color.opacity(0.15))
                                        Capsule().fill(slice.color)
                                            .frame(width: max(4, proxy.size.width * (total > 0 ? slice.hours / total : 0)))
                                    }
                                }
                                .frame(height: 5)
                                Text(StatsFormat.percent(total > 0 ? slice.hours / total : 0))
                                    .font(.caption2)
                                    .monospacedDigit()
                                    .frame(width: 32, alignment: .trailing)
                                    .themedSecondaryText()
                                if let previous = slice.previousHours {
                                    DeltaBadge(current: slice.hours, previous: previous, compact: true)
                                        .frame(minWidth: 44, alignment: .trailing)
                                }
                            }
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(theme.secondaryTextColor.opacity(0.5))
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if index < slices.count - 1 {
                    Divider().padding(.leading, 38)
                }
            }
        }
    }
}

/// "+12%" / "−8%" versus the previous period of the same length.
struct DeltaBadge: View {
    let current: Double
    let previous: Double
    var compact = false
    @Environment(\.theme) private var theme

    var body: some View {
        if previous <= 0 {
            if current > 0 {
                Text("stats_new".localized)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.blue)
            }
        } else {
            let change = (current - previous) / previous
            let rounded = Int((change * 100).rounded())
            let color: Color = rounded > 0 ? .green : (rounded < 0 ? .orange : theme.secondaryTextColor)
            HStack(spacing: 2) {
                Image(systemName: rounded > 0 ? "arrow.up" : (rounded < 0 ? "arrow.down" : "equal"))
                    .font(.system(size: compact ? 8 : 10, weight: .bold))
                Text(verbatim: abs(rounded) > 999 ? ">999%" : "\(abs(rounded))%")
                    .font((compact ? Font.caption2 : Font.caption).weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundColor(color)
            .padding(.horizontal, compact ? 0 : 7)
            .padding(.vertical, compact ? 0 : 3)
            .background {
                if !compact { Capsule().fill(color.opacity(0.12)) }
            }
            .accessibilityLabel(String(format: "stats_vs_previous".localized, "\(rounded)%"))
        }
    }
}

// MARK: - Category detail

private struct CategoryDetailSheet: View {
    let slice: DonutSlice
    @ObservedObject var viewModel: StatisticsViewModel
    let totalHours: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if slice.stats.count == 1, let stat = slice.stats.first {
                    CategoryDetailContent(stat: stat, viewModel: viewModel, totalHours: totalHours)
                } else {
                    otherList
                }
            }
            .themedBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("done".localized) { dismiss() }
                }
            }
        }
    }

    /// "Altro": list of the smaller categories, each opening its own detail.
    private var otherList: some View {
        List {
            ForEach(slice.stats) { stat in
                NavigationLink {
                    CategoryDetailContent(stat: stat, viewModel: viewModel, totalHours: totalHours)
                        .themedBackground()
                } label: {
                    HStack(spacing: 10) {
                        CategoryIconTile(icon: stat.icon ?? "tag.fill", color: Color(hex: stat.color), size: 30)
                        Text(stat.name == "Uncategorized" ? "uncategorized".localized : stat.name)
                        Spacer()
                        Text(StatsFormat.hours(stat.hours)).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("stats_other".localized)
    }
}

private struct CategoryDetailContent: View {
    let stat: StatisticsViewModel.CategoryStat
    @ObservedObject var viewModel: StatisticsViewModel
    let totalHours: Double
    @Environment(\.theme) private var theme
    @State private var selectedDate: Date?

    private var color: Color { Color(hex: stat.color) }
    private var name: String { stat.name == "Uncategorized" ? "uncategorized".localized : stat.name }
    private var detail: StatisticsViewModel.CategoryDetail? { stat.categoryId.map { viewModel.categoryDetail(for: $0) } }
    private var unit: Calendar.Component { viewModel.bucketUnit(forTrend: false).calendarComponent }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                if let detail {
                    tiles(detail)
                    trendCard(detail)
                    tasksCard(detail)
                    weekdayCard(detail)
                } else {
                    StatsCard(title: "stats_no_data_title".localized) {
                        StatsEmptyState(systemImage: "tag", title: StatsFormat.hours(stat.hours),
                                        message: "stats_uncategorized_detail".localized)
                    }
                }
            }
            .padding(16)
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            CategoryIconTile(icon: stat.icon ?? "tag.fill", color: color, size: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(name).font(.title3.weight(.bold)).themedPrimaryText()
                Text(String(format: "stats_share_of_time".localized, StatsFormat.percent(totalHours > 0 ? stat.hours / totalHours : 0)))
                    .font(.subheadline)
                    .themedSecondaryText()
            }
            Spacer()
        }
    }

    private func tiles(_ detail: StatisticsViewModel.CategoryDetail) -> some View {
        let days = max(1, viewModel.overview.daysInPeriod)
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            StatTile(value: StatsFormat.hours(detail.hours), label: "stats_time_spent".localized,
                     systemImage: "clock.fill", tint: color,
                     caption: detail.previousHours.map { previous in
                         previous > 0
                            ? String(format: "stats_previous_period".localized, StatsFormat.hours(previous))
                            : "stats_new".localized
                     })
            StatTile(value: StatsFormat.hours(detail.hours / Double(days)), label: "stats_daily_average".localized,
                     systemImage: "calendar", tint: .blue)
            StatTile(value: "\(detail.completions)", label: "stats_completed".localized,
                     systemImage: "checkmark.circle.fill", tint: .green,
                     caption: String(format: "stats_tasks_count".localized, detail.tasks.count))
            StatTile(value: StatsFormat.hours(detail.trackedSessionHours), label: "stats_tracked_sessions".localized,
                     systemImage: "stopwatch.fill", tint: .purple)
        }
    }

    private func trendCard(_ detail: StatisticsViewModel.CategoryDetail) -> some View {
        let average = detail.buckets.isEmpty ? 0 : detail.buckets.reduce(0) { $0 + $1.hours } / Double(detail.buckets.count)
        let selected = selectedDate.flatMap { date in
            detail.buckets.first { Calendar.current.isDate($0.start, equalTo: date, toGranularity: unit) }
        }
        return StatsCard(title: "stats_trend".localized,
                         subtitle: String(format: "stats_average_hours".localized, StatsFormat.hours(average))) {
            Chart {
                ForEach(detail.buckets, id: \.start) { bucket in
                    BarMark(x: .value("date".localized, bucket.start, unit: unit),
                            y: .value("hours".localized, bucket.hours))
                        .foregroundStyle(color.gradient)
                        .cornerRadius(3)
                        .opacity(selected == nil || selected?.start == bucket.start ? 1 : 0.4)
                }
                RuleMark(y: .value("average".localized, average))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(theme.textColor.opacity(0.35))
                if let selected {
                    RuleMark(x: .value("date".localized, selected.start, unit: unit))
                        .foregroundStyle(.clear)
                        .annotation(position: .top, spacing: 4,
                                    overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            ChartTooltip(title: title(for: selected.start), lines: [(color, StatsFormat.hours(selected.hours))])
                        }
                }
            }
            .chartXSelection(value: $selectedDate)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                        .foregroundStyle(theme.secondaryTextColor.opacity(0.2))
                    AxisValueLabel { Text("\(value.as(Double.self).map { Int($0) } ?? 0)h") }
                        .font(.caption2)
                        .foregroundStyle(theme.secondaryTextColor)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(StatsFormat.bucketLabel(date, unit: viewModel.bucketUnit(forTrend: false),
                                                         period: viewModel.selectedTimeRange))
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(theme.secondaryTextColor)
                }
            }
            .frame(height: 170)
        }
    }

    private func tasksCard(_ detail: StatisticsViewModel.CategoryDetail) -> some View {
        let top = detail.tasks.first?.hours ?? 1
        return StatsCard(title: "stats_tasks_in_category".localized) {
            if detail.tasks.isEmpty {
                StatsEmptyState(systemImage: "checklist", title: "stats_no_data_title".localized,
                                message: "stats_no_data_period".localized)
            } else {
                VStack(spacing: 12) {
                    ForEach(detail.tasks.prefix(10)) { task in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 8) {
                                Image(systemName: task.icon)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(color)
                                    .frame(width: 18)
                                Text(task.name).font(.subheadline).lineLimit(1).themedPrimaryText()
                                Spacer()
                                Text(String(format: "stats_times".localized, task.completions))
                                    .font(.caption2).monospacedDigit().themedSecondaryText()
                                Text(StatsFormat.hours(task.hours))
                                    .font(.subheadline.weight(.semibold)).monospacedDigit()
                                    .frame(minWidth: 56, alignment: .trailing)
                                    .themedPrimaryText()
                            }
                            GeometryReader { proxy in
                                Capsule().fill(color.opacity(0.8))
                                    .frame(width: max(4, proxy.size.width * (top > 0 ? task.hours / top : 0)))
                            }
                            .frame(height: 5)
                        }
                    }
                }
            }
        }
    }

    private func weekdayCard(_ detail: StatisticsViewModel.CategoryDetail) -> some View {
        let symbols = Calendar.current.shortWeekdaySymbols
        let best = detail.weekdayHours.max { $0.hours < $1.hours }
        return StatsCard(title: "stats_by_weekday".localized,
                         subtitle: best.flatMap { $0.hours > 0 ? String(format: "stats_most_time_on".localized,
                                                                        Calendar.current.weekdaySymbols[$0.weekday - 1]) : nil }) {
            Chart(detail.weekdayHours, id: \.weekday) { item in
                BarMark(x: .value("day".localized, symbols[item.weekday - 1]),
                        y: .value("hours".localized, item.hours))
                    .foregroundStyle(item.weekday == best?.weekday ? color : color.opacity(0.4))
                    .cornerRadius(4)
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel().font(.caption2).foregroundStyle(theme.secondaryTextColor)
                }
            }
            .frame(height: 110)
        }
    }

    private func title(for date: Date) -> String {
        switch viewModel.bucketUnit(forTrend: false) {
        case .day: return date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
        case .week: return String(format: "stats_week_of".localized, date.formatted(.dateTime.day().month(.abbreviated)))
        case .month: return date.formatted(.dateTime.month(.wide).year())
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
                  subtitle: String(format: "stats_average_per_bucket".localized,
                                   averageCompleted >= 10 ? String(Int(averageCompleted.rounded())) : String(format: "%.1f", averageCompleted),
                                   bucketName)) {
            if buckets.allSatisfy({ $0.total == 0 }) {
                StatsEmptyState(systemImage: "checklist",
                                title: "stats_no_tasks_title".localized,
                                message: "stats_no_tasks_message".localized)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    chart(palette)
                        .frame(height: 180)
                        .id(viewModel.selectedTimeRange)
                    HStack(spacing: 14) {
                        LegendDot(color: palette.completed, label: "completed".localized)
                        LegendDot(color: palette.missed, label: "stats_legend_missed".localized)
                        if buckets.contains(where: { $0.pending > 0 }) {
                            LegendDot(color: palette.completed.opacity(0.3), label: "stats_legend_todo_today".localized)
                        }
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
                if bucket.pending > 0 {
                    BarMark(x: .value("date".localized, bucket.start, unit: calendarUnit),
                            y: .value("stats_legend_todo_today".localized, bucket.pending))
                        .foregroundStyle(palette.completed.opacity(0.3))
                }
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
                        ] + (bucket.pending > 0
                             ? [(palette.completed.opacity(0.3), String(format: "stats_todo_count".localized, bucket.pending))]
                             : []))
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
