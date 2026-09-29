import SwiftUI

/// Calendar heatmap with fixed-size cells: it never stretches cells to fill the width.
/// Instead it shows as many weeks as fit (compact) or all history in a horizontal scroll anchored on today.
struct HabitHeatmap: View {
    let days: [StatisticsViewModel.HabitDay]
    let color: Color
    var cellSize: CGFloat = 13
    var spacing: CGFloat = 3
    var showsLabels = true
    var scrollable = false
    @Environment(\.theme) private var theme

    private typealias Column = [StatisticsViewModel.HabitDay?]

    private var monthLabelHeight: CGFloat { showsLabels ? 16 : 0 }
    private var weekdayLabelWidth: CGFloat { showsLabels ? 26 : 0 }
    private var gridHeight: CGFloat { cellSize * 7 + spacing * 6 }
    private var calendar: Calendar { Calendar.current }

    var body: some View {
        GeometryReader { proxy in
            let available = proxy.size.width - weekdayLabelWidth
            let fitting = max(1, Int((available + spacing) / (cellSize + spacing)))
            let all = columns
            let shown = paddedColumns(scrollable ? all : Array(all.suffix(fitting)), minimum: fitting)

            HStack(alignment: .top, spacing: 0) {
                if showsLabels {
                    weekdayLabels
                        .frame(width: weekdayLabelWidth, alignment: .leading)
                }
                if scrollable {
                    ScrollView(.horizontal, showsIndicators: false) {
                        grid(shown)
                    }
                    .defaultScrollAnchor(.trailing)
                } else {
                    grid(shown)
                }
            }
        }
        .frame(height: monthLabelHeight + gridHeight)
    }

    // MARK: Drawing

    private func grid(_ columns: [Column]) -> some View {
        let width = CGFloat(columns.count) * (cellSize + spacing) - spacing
        let offColor = theme.secondaryTextColor.opacity(0.08)
        let missedColor = color.opacity(0.2)
        let labelColor = theme.secondaryTextColor
        let radius = cellSize * 0.28

        return Canvas { context, _ in
            var lastLabelX: CGFloat = -100
            for (columnIndex, column) in columns.enumerated() {
                let x = CGFloat(columnIndex) * (cellSize + spacing)

                if showsLabels,
                   let firstOfMonth = column.compactMap({ $0 }).first(where: { calendar.component(.day, from: $0.date) == 1 })
                    ?? (columnIndex == 0 ? column.compactMap({ $0 }).first : nil),
                   x - lastLabelX > 28 {
                    let text = Text(firstOfMonth.date.formatted(.dateTime.month(.abbreviated)))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(labelColor)
                    context.draw(text, at: CGPoint(x: x, y: 0), anchor: .topLeading)
                    lastLabelX = x
                }

                for (rowIndex, day) in column.enumerated() {
                    guard let day else { continue }
                    let rect = CGRect(x: x,
                                      y: monthLabelHeight + CGFloat(rowIndex) * (cellSize + spacing),
                                      width: cellSize, height: cellSize)
                    let path = Path(roundedRect: rect, cornerRadius: radius)
                    switch day.state {
                    case .done:
                        context.fill(path, with: .color(color))
                    case .missed:
                        context.fill(path, with: .color(missedColor))
                    case .pending:
                        context.fill(path, with: .color(offColor))
                        context.stroke(Path(roundedRect: rect.insetBy(dx: 0.75, dy: 0.75), cornerRadius: radius),
                                       with: .color(color), lineWidth: 1.5)
                    case .off:
                        context.fill(path, with: .color(offColor))
                    }
                }
            }
        }
        .frame(width: max(width, 0), height: monthLabelHeight + gridHeight)
    }

    private var weekdayLabels: some View {
        let symbols = calendar.shortWeekdaySymbols
        return VStack(alignment: .leading, spacing: spacing) {
            Color.clear.frame(height: monthLabelHeight - spacing)
            ForEach(0..<7, id: \.self) { row in
                let weekday = (calendar.firstWeekday - 1 + row) % 7
                Text(row.isMultiple(of: 2) ? symbols[weekday] : "")
                    .font(.system(size: 9, weight: .medium))
                    .themedSecondaryText()
                    .frame(height: cellSize)
            }
        }
    }

    // MARK: Layout

    /// Week columns aligned to the calendar's first weekday; empty slots before the first day and after today.
    private var columns: [Column] {
        guard let first = days.first else { return [] }
        let leading = (calendar.component(.weekday, from: first.date) - calendar.firstWeekday + 7) % 7
        var slots: [StatisticsViewModel.HabitDay?] = Array(repeating: nil, count: leading) + days
        let trailing = (7 - slots.count % 7) % 7
        slots += Array(repeating: nil, count: trailing)
        return stride(from: 0, to: slots.count, by: 7).map { Array(slots[$0..<$0 + 7]) }
    }

    /// Short histories are padded on the left with empty weeks so the grid always spans the full width.
    private func paddedColumns(_ columns: [Column], minimum: Int) -> [Column] {
        guard columns.count < minimum else { return columns }
        let emptyWeek: Column = Array(repeating: nil, count: 7)
        return Array(repeating: emptyWeek, count: minimum - columns.count) + columns
    }
}

struct HabitHeatmapLegend: View {
    let color: Color
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            LegendDot(color: color, label: "stats_legend_done".localized)
            LegendDot(color: color.opacity(0.2), label: "stats_legend_missed".localized)
            LegendDot(color: theme.secondaryTextColor.opacity(0.08), label: "stats_legend_not_scheduled".localized)
        }
    }
}
