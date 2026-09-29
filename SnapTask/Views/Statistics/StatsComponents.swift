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
            if let caption {
                Text(caption)
                    .font(.caption2)
                    .themedSecondaryText()
                    .lineLimit(1)
            }
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
