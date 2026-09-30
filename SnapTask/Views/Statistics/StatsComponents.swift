import SwiftUI
import Charts

// MARK: - Palette

/// Fixed meaning for colors across every statistics chart.
struct StatsPalette {
    let theme: Theme

    var completed: Color { theme.accentColor }
    var missed: Color { theme.secondaryTextColor.opacity(0.22) }
    var grid: Color { theme.secondaryTextColor.opacity(0.15) }
    var quality: Color { Color(hex: "F5B400") }
    var difficulty: Color { Color(hex: "FF6B3D") }
}

extension View {
    /// Axis styling shared by all statistics charts.
    func statsAxisStyle(_ theme: Theme) -> some View {
        self
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                        .foregroundStyle(theme.secondaryTextColor.opacity(0.2))
                    AxisValueLabel()
                        .font(.caption2)
                        .foregroundStyle(theme.secondaryTextColor)
                }
            }
    }
}

// MARK: - Formatting

enum StatsFormat {
    static func hours(_ hours: Double) -> String {
        let totalMinutes = Int((hours * 60).rounded())
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if h == 0 { return "\(m)m" }
        if h >= 100 { return "\(Int(hours.rounded()))h" }
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    /// Short label for a bucket start date, depending on how data is grouped.
    static func bucketLabel(_ date: Date, unit: StatisticsViewModel.BucketUnit, period: StatisticsViewModel.TimeRange) -> String {
        switch unit {
        case .day:
            return period == .week
                ? date.formatted(.dateTime.weekday(.abbreviated))
                : date.formatted(.dateTime.day())
        case .week:
            return date.formatted(.dateTime.day().month(.abbreviated))
        case .month:
            return period == .allTime
                ? date.formatted(.dateTime.month(.abbreviated).year(.twoDigits))
                : date.formatted(.dateTime.month(.abbreviated))
        }
    }

    /// Full description of a bucket for tooltips ("12 set", "8–14 set", "settembre 2026").
    static func bucketTitle(_ bucket: StatisticsViewModel.CompletionBucket, unit: StatisticsViewModel.BucketUnit) -> String {
        switch unit {
        case .day:
            return bucket.start.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
        case .week:
            let formatter = DateIntervalFormatter()
            formatter.dateTemplate = "dMMM"
            return formatter.string(from: bucket.start, to: bucket.end)
        case .month:
            return bucket.start.formatted(.dateTime.month(.wide).year())
        }
    }
}

// MARK: - Containers

struct StatsCard<Content: View, Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content
    @Environment(\.theme) private var theme

    init(title: String, subtitle: String? = nil,
         @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() },
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .themedPrimaryText()
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .themedSecondaryText()
                    }
                }
                Spacer(minLength: 8)
                trailing()
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(theme.surfaceColor)
        )
    }
}

struct StatTile: View {
    let value: String
    let label: String
    let systemImage: String
    let tint: Color
    var caption: String? = nil
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(tint)
                Text(label)
                    .font(.caption.weight(.medium))
                    .themedSecondaryText()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .monospacedDigit()
                .themedPrimaryText()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            // Always reserve the caption line so tiles in the same row share the same height.
            Text(caption ?? " ")
                .font(.caption2)
                .themedSecondaryText()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.surfaceColor)
        )
    }
}

struct StatsEmptyState: View {
    let systemImage: String
    let title: String
    let message: String
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(theme.secondaryTextColor.opacity(0.5))
            Text(title)
                .font(.subheadline.weight(.semibold))
                .themedPrimaryText()
            Text(message)
                .font(.caption)
                .multilineTextAlignment(.center)
                .themedSecondaryText()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

/// Small bubble shown above a selected chart value.
struct ChartTooltip: View {
    let title: String
    let lines: [(color: Color, text: String)]
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .themedSecondaryText()
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                HStack(spacing: 5) {
                    Circle().fill(line.color).frame(width: 6, height: 6)
                    Text(line.text)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .themedPrimaryText()
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.backgroundColor)
                .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        )
    }
}

struct LegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(label).font(.caption2).themedSecondaryText()
        }
    }
}

// MARK: - Segmented controls

/// Capsule segmented control used for the tab bar and the period selector.
struct StatsSegmentedControl<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let label: (Value) -> String
    var icon: ((Value) -> String?)? = nil
    var isLocked: (Value) -> Bool = { _ in false }
    var onLockedTap: ((Value) -> Void)? = nil
    @Environment(\.theme) private var theme
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let selected = option == selection
                Button {
                    if isLocked(option) {
                        onLockedTap?(option)
                    } else {
                        withAnimation(.snappy(duration: 0.25)) { selection = option }
                    }
                } label: {
                    HStack(spacing: 4) {
                        if let name = icon?(option) {
                            Image(systemName: name).font(.system(size: 11, weight: .semibold))
                        }
                        Text(label(option))
                            .font(.footnote.weight(selected ? .semibold : .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        if isLocked(option) {
                            Image(systemName: "lock.fill").font(.system(size: 9, weight: .bold))
                        }
                    }
                    .foregroundColor(selected ? theme.textColor : theme.secondaryTextColor.opacity(isLocked(option) ? 0.6 : 1))
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background {
                        if selected {
                            Capsule()
                                .fill(theme.backgroundColor)
                                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                                .matchedGeometryEffect(id: "segment", in: namespace)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(theme.surfaceColor))
    }
}

// MARK: - Comparison (single items vs the overall reference)

struct ComparisonSeries: Identifiable, Equatable {
    let id: String
    let name: String
    let color: Color
    let points: [ComparisonPoint]
}

struct ComparisonPoint: Equatable {
    let date: Date
    let value: Double
}

enum ComparisonPalette {
    /// Distinct colors by selection order: category colors could repeat (same category, same color).
    static let colors: [Color] = [Color(hex: "3B82F6"), Color(hex: "EC4899"), Color(hex: "10B981")]
    static let maxSelection = 3
}

/// Line chart that shows up to three selected items plus an optional dashed "overall" reference.
struct ComparisonLineChart: View {
    let series: [ComparisonSeries]
    let reference: ComparisonSeries?
    let unit: Calendar.Component
    let yDomain: ClosedRange<Double>
    let yTicks: [Double]
    let format: (Double) -> String
    let axisLabel: (Date) -> String
    let tooltipTitle: (Date) -> String
    @Environment(\.theme) private var theme
    @State private var selectedDate: Date?

    private var selectedBucket: Date? {
        guard let selectedDate else { return nil }
        return Calendar.current.dateInterval(of: unit, for: selectedDate)?.start
    }

    /// With nothing selected the overall line is the main (solid) series.
    private var overallIsMain: Bool { series.isEmpty }

    var body: some View {
        let accent = StatsPalette(theme: theme).completed
        Chart {
            if let reference {
                ForEach(reference.points, id: \.date) { point in
                    LineMark(x: .value("date".localized, point.date, unit: unit),
                             y: .value("value", point.value),
                             series: .value("series", reference.id))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(overallIsMain ? accent : theme.secondaryTextColor.opacity(0.55))
                        .lineStyle(overallIsMain
                                   ? StrokeStyle(lineWidth: 2.5, lineCap: .round)
                                   : StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 3]))
                    if overallIsMain {
                        AreaMark(x: .value("date".localized, point.date, unit: unit),
                                 y: .value("value", point.value))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(LinearGradient(colors: [accent.opacity(0.25), accent.opacity(0.02)],
                                                            startPoint: .top, endPoint: .bottom))
                    }
                }
            }
            ForEach(series) { item in
                ForEach(item.points, id: \.date) { point in
                    LineMark(x: .value("date".localized, point.date, unit: unit),
                             y: .value("value", point.value),
                             series: .value("series", item.id))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(item.color)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .symbol {
                            if item.points.count <= 14 {
                                Circle().fill(item.color).frame(width: 5, height: 5)
                            }
                        }
                }
            }
            if let bucket = selectedBucket {
                RuleMark(x: .value("date".localized, bucket, unit: unit))
                    .foregroundStyle(theme.secondaryTextColor.opacity(0.35))
                    .annotation(position: .top, spacing: 4,
                                overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        ChartTooltip(title: tooltipTitle(bucket), lines: tooltipLines(at: bucket, accent: accent))
                    }
            }
        }
        .chartYScale(domain: yDomain)
        .chartXSelection(value: $selectedDate)
        .chartYAxis {
            AxisMarks(position: .leading, values: yTicks) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                    .foregroundStyle(theme.secondaryTextColor.opacity(0.2))
                AxisValueLabel { Text(format(value.as(Double.self) ?? 0)) }
                    .font(.caption2)
                    .foregroundStyle(theme.secondaryTextColor)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) { Text(axisLabel(date)) }
                }
                .font(.caption2)
                .foregroundStyle(theme.secondaryTextColor)
            }
        }
    }

    private func tooltipLines(at bucket: Date, accent: Color) -> [(color: Color, text: String)] {
        var lines: [(color: Color, text: String)] = []
        for item in series {
            if let point = item.points.first(where: { $0.date == bucket }) {
                lines.append((item.color, "\(item.name): \(format(point.value))"))
            }
        }
        if let reference, let point = reference.points.first(where: { $0.date == bucket }) {
            lines.append((overallIsMain ? accent : theme.secondaryTextColor, "\(reference.name): \(format(point.value))"))
        }
        return lines
    }
}

/// Horizontal pills to pick up to three items to compare; selected pills take the series color and move to the front.
struct ComparisonChips: View {
    struct Item: Identifiable {
        let id: String
        let name: String
        let icon: String
        var color: Color = .gray
        var group: String? = nil
        var detail: String? = nil
    }

    let items: [Item]
    @Binding var selection: [String]
    @Environment(\.theme) private var theme

    /// Selected first (in selection order), then the rest in their original order.
    private var ordered: [Item] {
        let selected = selection.compactMap { id in items.first { $0.id == id } }
        return selected + items.filter { !selection.contains($0.id) }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    chip(title: "stats_overall".localized, icon: "sum", isSelected: selection.isEmpty, color: theme.accentColor) {
                        withAnimation(.snappy) { selection.removeAll() }
                    }
                    .id("__overall")
                    ForEach(ordered) { item in
                        let index = selection.firstIndex(of: item.id)
                        chip(title: item.name, icon: item.icon, isSelected: index != nil,
                             color: index.map { ComparisonPalette.colors[$0 % ComparisonPalette.colors.count] } ?? theme.accentColor) {
                            withAnimation(.snappy) {
                                toggle(item.id)
                                proxy.scrollTo("__overall", anchor: .leading)
                            }
                        }
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }

    private func toggle(_ id: String) {
        if let index = selection.firstIndex(of: id) {
            selection.remove(at: index)
        } else {
            if selection.count >= ComparisonPalette.maxSelection { selection.removeFirst() }
            selection.append(id)
        }
    }

    private func chip(title: String, icon: String, isSelected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold))
                Text(title).font(.caption.weight(.medium)).lineLimit(1)
            }
            .foregroundColor(isSelected ? .white : theme.textColor)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Capsule().fill(isSelected ? color : theme.textColor.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }
}

enum RollingRate {
    /// Rate per bucket computed over the last `window` buckets (sum of done / sum of scheduled):
    /// a single habit has few occurrences per bucket, so raw rates jump between 0 and 100%.
    static func points(_ buckets: [(date: Date, done: Int, total: Int)], window: Int) -> [ComparisonPoint] {
        let sorted = buckets.sorted { $0.date < $1.date }
        return sorted.indices.compactMap { index in
            let slice = sorted[max(0, index - window + 1)...index]
            let done = slice.reduce(0) { $0 + $1.done }
            let total = slice.reduce(0) { $0 + $1.total }
            guard sorted[index].total > 0, total > 0 else { return nil }
            return ComparisonPoint(date: sorted[index].date, value: Double(done) / Double(total) * 100)
        }
    }

    /// 7 days for daily buckets over a month, 4 weeks for weekly buckets, none otherwise.
    static func window(unit: Calendar.Component, period: StatisticsViewModel.TimeRange) -> Int {
        switch (unit, period) {
        case (.day, .month): return 7
        case (.weekOfYear, _): return 4
        default: return 1
        }
    }
}

extension StatisticsViewModel.HabitSummary {
    /// Completion rate per calendar bucket between `start` and `end` (rolling over `window` buckets).
    func rateSeries(unit: Calendar.Component, from start: Date, to end: Date, window: Int = 1) -> [ComparisonPoint] {
        let calendar = Calendar.current
        if cadence != .day {
            // One point per period, placed at the bucket containing its start.
            let resolved = periods.filter { $0.date <= end && $0.state != .pending &&
                calendar.date(byAdding: cadence.component, value: 1, to: $0.date)! > start }
            var grouped: [Date: (done: Int, total: Int)] = [:]
            for period in resolved {
                let key = calendar.dateInterval(of: unit, for: max(period.date, start))?.start ?? period.date
                grouped[key, default: (0, 0)].total += 1
                if period.state == .done { grouped[key, default: (0, 0)].done += 1 }
            }
            let buckets = grouped.map { ($0.key, $0.value.done, $0.value.total) }
            return RollingRate.points(buckets, window: 1)
        }
        var grouped: [Date: (done: Int, total: Int)] = [:]
        // Every bucket of the period is present (also empty ones) so the rolling window spans real time.
        var cursor = calendar.dateInterval(of: unit, for: start)?.start ?? start
        while cursor <= end {
            grouped[cursor] = (0, 0)
            cursor = calendar.date(byAdding: unit, value: 1, to: cursor)!
        }
        for day in days where day.date >= start && day.date <= end && (day.state == .done || day.state == .missed) {
            let key = calendar.dateInterval(of: unit, for: day.date)?.start ?? day.date
            grouped[key, default: (0, 0)].total += 1
            if day.state == .done { grouped[key, default: (0, 0)].done += 1 }
        }
        return RollingRate.points(grouped.map { ($0.key, $0.value.done, $0.value.total) }, window: window)
    }
}

extension View {
    /// Debug only: `-statsAnchor center|bottom` opens statistics scrolled there (screenshots without tapping).
    @ViewBuilder
    func statsDebugScrollAnchor() -> some View {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "statsAnchor") {
        case "center": self.defaultScrollAnchor(.center)
        case "bottom": self.defaultScrollAnchor(.bottom)
        default: self
        }
        #else
        self
        #endif
    }
}
