import SwiftUI
import Charts

struct MoodTrendCard: View {
    /// Driven by the statistics screen's global period.
    let timeRange: StatisticsViewModel.TimeRange
    /// Completed/resolved tasks per finished day, to relate mood and productivity.
    var dailyCompletion: [Date: StatisticsViewModel.DayCount] = [:]

    @ObservedObject private var moodManager = MoodManager.shared
    @Environment(\.theme) private var theme
    @State private var showingMoodSelector = false
    @State private var selectedDate: Date?

    private struct MoodBucket: Identifiable, Equatable {
        var id: Date { start }
        let start: Date
        let average: Double
        let minScore: Int
        let maxScore: Int
        let count: Int
    }

    private var calendar: Calendar { Calendar.current }

    private var range: (start: Date, end: Date) {
        let end = calendar.startOfDay(for: Date())
        switch timeRange {
        case .allTime:
            return (moodManager.entries.keys.min() ?? end, end)
        case .today, .week:
            return (calendar.date(byAdding: .day, value: -6, to: end)!, end)
        default:
            return (calendar.startOfDay(for: timeRange.dateRange.start), end)
        }
    }

    private var entries: [(date: Date, type: MoodType)] {
        moodManager.entries(in: range.start...range.end)
    }

    /// Daily points for short periods, weekly/monthly averages with min–max band for long ones.
    private var unit: Calendar.Component {
        switch timeRange {
        case .today, .week, .month: return .day
        case .year: return .weekOfYear
        case .allTime:
            let days = calendar.dateComponents([.day], from: range.start, to: range.end).day ?? 0
            return days > 400 ? .month : .weekOfYear
        }
    }

    private var buckets: [MoodBucket] {
        var grouped: [Date: [Int]] = [:]
        for entry in entries {
            let key = calendar.dateInterval(of: unit, for: entry.date)?.start ?? entry.date
            grouped[key, default: []].append(entry.type.score)
        }
        return grouped.map { start, scores in
            MoodBucket(start: start,
                       average: Double(scores.reduce(0, +)) / Double(scores.count),
                       minScore: scores.min() ?? 0, maxScore: scores.max() ?? 0, count: scores.count)
        }
        .sorted { $0.start < $1.start }
    }

    private var average: Double? {
        guard !entries.isEmpty else { return nil }
        return Double(entries.reduce(0) { $0 + $1.type.score }) / Double(entries.count)
    }

    private var daysInRange: Int {
        (calendar.dateComponents([.day], from: range.start, to: range.end).day ?? 0) + 1
    }

    private func mood(for score: Double) -> MoodType {
        let rounded = min(7, max(1, Int(score.rounded())))
        return MoodType.allCases.first { $0.score == rounded } ?? .neutral
    }

    var body: some View {
        StatsCard(title: "mood_trend".localized) {
            Button { showingMoodSelector = true } label: {
                Label("add".localized, systemImage: "plus")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(Capsule().fill(theme.accentColor))
            }
            .buttonStyle(.plain)
        } content: {
            if entries.isEmpty {
                StatsEmptyState(systemImage: "face.smiling", title: "stats_no_mood_title".localized,
                                message: "add_mood_to_see_trend".localized)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    summary
                    chart.frame(height: 180)
                    distribution
                    if let insight {
                        insightRow(insight)
                    }
                }
            }
        }
        .sheet(isPresented: $showingMoodSelector) {
            MoodSelectionView(date: Date())
        }
    }

    // MARK: Summary

    private var summary: some View {
        HStack(spacing: 12) {
            if let average {
                let type = mood(for: average)
                Text(type.emoji).font(.system(size: 34))
                VStack(alignment: .leading, spacing: 1) {
                    Text(type.localizedName.capitalized)
                        .font(.headline)
                        .themedPrimaryText()
                    Text(String(format: "stats_mood_average".localized, String(format: "%.1f", average)))
                        .font(.caption)
                        .themedSecondaryText()
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(entries.count)/\(daysInRange)")
                    .font(.headline.monospacedDigit())
                    .themedPrimaryText()
                Text("stats_days_logged".localized)
                    .font(.caption)
                    .themedSecondaryText()
            }
        }
    }

    // MARK: Chart

    private var selectedBucket: MoodBucket? {
        guard let selectedDate else { return nil }
        let key = calendar.dateInterval(of: unit, for: selectedDate)?.start
        return buckets.first { $0.start == key }
    }

    private var chart: some View {
        let accent = theme.accentColor
        let daily = unit == .day
        return Chart {
            RuleMark(y: .value("neutral".localized, 4))
                .foregroundStyle(theme.secondaryTextColor.opacity(0.25))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))

            ForEach(buckets) { bucket in
                if !daily {
                    AreaMark(x: .value("date".localized, bucket.start, unit: unit),
                             yStart: .value("min", Double(bucket.minScore)),
                             yEnd: .value("max", Double(bucket.maxScore)))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(accent.opacity(0.15))
                }
                LineMark(x: .value("date".localized, bucket.start, unit: unit),
                         y: .value("mood_trend".localized, bucket.average))
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: daily ? 1.5 : 2.5, lineCap: .round))
                    .foregroundStyle(daily ? accent.opacity(0.4) : accent)
                if daily {
                    PointMark(x: .value("date".localized, bucket.start, unit: unit),
                              y: .value("mood_trend".localized, bucket.average))
                        .symbolSize(buckets.count > 14 ? 30 : 70)
                        .foregroundStyle(Color(hex: mood(for: bucket.average).colorHex))
                }
            }

            if let bucket = selectedBucket {
                RuleMark(x: .value("date".localized, bucket.start, unit: unit))
                    .foregroundStyle(theme.secondaryTextColor.opacity(0.35))
                    .annotation(position: .top, spacing: 4,
                                overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        ChartTooltip(title: tooltipTitle(bucket.start), lines: tooltipLines(bucket))
                    }
            }
        }
        .chartYScale(domain: 0.5...7.5)
        .chartXSelection(value: $selectedDate)
        .chartYAxis {
            AxisMarks(position: .leading, values: [1, 4, 7]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                    .foregroundStyle(theme.secondaryTextColor.opacity(0.15))
                AxisValueLabel {
                    Text(mood(for: value.as(Double.self) ?? 4).emoji).font(.system(size: 13))
                }
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

    private func tooltipLines(_ bucket: MoodBucket) -> [(color: Color, text: String)] {
        let type = mood(for: bucket.average)
        if unit == .day {
            return [(Color(hex: type.colorHex), "\(type.emoji) \(type.localizedName.capitalized)")]
        }
        return [
            (Color(hex: type.colorHex), "\(type.emoji) " + String(format: "stats_mood_average".localized, String(format: "%.1f", bucket.average))),
            (theme.secondaryTextColor, String(format: "stats_mood_days".localized, bucket.count))
        ]
    }

    private func axisLabel(_ date: Date) -> String {
        switch timeRange {
        case .today, .week: return date.formatted(.dateTime.weekday(.abbreviated))
        case .month: return date.formatted(.dateTime.day().month(.abbreviated))
        case .year: return date.formatted(.dateTime.month(.abbreviated))
        case .allTime: return date.formatted(.dateTime.month(.abbreviated).year(.twoDigits))
        }
    }

    private func tooltipTitle(_ date: Date) -> String {
        switch unit {
        case .day: return date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
        case .weekOfYear: return String(format: "stats_week_of".localized, date.formatted(.dateTime.day().month(.abbreviated)))
        default: return date.formatted(.dateTime.month(.wide).year())
        }
    }

    // MARK: Distribution

    private var distribution: some View {
        let counts = MoodType.allCases.map { type in (type, entries.filter { $0.type == type }.count) }
        let total = max(1, entries.count)
        return VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                HStack(spacing: 2) {
                    ForEach(counts.filter { $0.1 > 0 }, id: \.0) { type, count in
                        Rectangle()
                            .fill(Color(hex: type.colorHex))
                            .frame(width: max(3, (proxy.size.width - 12) * Double(count) / Double(total)))
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 10)
            HStack(spacing: 0) {
                ForEach(counts, id: \.0) { type, count in
                    VStack(spacing: 2) {
                        Text(type.emoji).font(.system(size: 15))
                            .opacity(count == 0 ? 0.3 : 1)
                        Text(count == 0 ? "–" : StatsFormat.percent(Double(count) / Double(total)))
                            .font(.system(size: 10, weight: .medium))
                            .monospacedDigit()
                            .themedSecondaryText()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: Insight

    /// Completion rate on good-mood days vs the other days, when both groups have enough data.
    private var insight: (good: Double, other: Double)? {
        var good = (completed: 0, total: 0, days: 0)
        var other = (completed: 0, total: 0, days: 0)
        for entry in entries {
            guard let day = dailyCompletion[calendar.startOfDay(for: entry.date)], day.total > 0 else { continue }
            if entry.type.score >= 5 {
                good.completed += day.completed; good.total += day.total; good.days += 1
            } else {
                other.completed += day.completed; other.total += day.total; other.days += 1
            }
        }
        guard good.days >= 3, other.days >= 3 else { return nil }
        return (Double(good.completed) / Double(good.total), Double(other.completed) / Double(other.total))
    }

    private func insightRow(_ value: (good: Double, other: Double)) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.yellow)
            // Below 5 points the difference is noise: say so instead of implying a link.
            Text(abs(value.good - value.other) < 0.05
                 ? String(format: "stats_mood_insight_none".localized, StatsFormat.percent(value.good))
                 : String(format: "stats_mood_insight".localized,
                          StatsFormat.percent(value.good), StatsFormat.percent(value.other)))
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
                .themedPrimaryText()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.yellow.opacity(0.1)))
    }
}
