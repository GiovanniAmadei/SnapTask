import SwiftUI
import Charts

enum ConsistencyTimeRange: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
    // Existing code...
    var displayName: String {
        switch self {
        case .week: return "week".localized
        case .month: return "month".localized
        case .year: return "year".localized
        }
    }
}

// Existing code...
struct TaskConsistencyView: View {
    @ObservedObject var viewModel: StatisticsViewModel
    @State private var timeRange: ConsistencyTimeRange = .week
    @State private var selectedTaskId: UUID? = nil
    @State private var penalizeMissedTasks: Bool = true
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HeaderSection()
            // Existing code...
            if viewModel.consistency.isEmpty {
                EmptyConsistencyView()
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    TimeRangeSection(timeRange: $timeRange)
                    PenaltyToggleSection(penalizeMissedTasks: $penalizeMissedTasks)
                }
                ModernConsistencyChart(
                    tasks: viewModel.consistency,
                    timeRange: timeRange,
                    selectedTaskId: $selectedTaskId,
                    penalizeMissedTasks: penalizeMissedTasks,
                    viewModel: viewModel
                )
                .animation(.smooth(duration: 0.8), value: timeRange)
                .animation(.smooth(duration: 0.8), value: penalizeMissedTasks)
                TaskLegendSection(
                    tasks: viewModel.consistency,
                    selectedTaskId: $selectedTaskId
                )
                HelpTextSection()
            }
        }
        .padding(.vertical, 16)
        .background(theme.surfaceColor)
        .cornerRadius(12)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }
}

private struct HeaderSection: View {
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("task_progress_over_time".localized)
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .themedPrimaryText()
            // Existing code...
            Text("track_completion_patterns".localized)
                .font(.system(.subheadline, design: .rounded))
                .themedSecondaryText()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }
}

private struct TimeRangeSection: View {
    @Binding var timeRange: ConsistencyTimeRange
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("time_period".localized)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .themedPrimaryText()
            // Existing code...
            Picker("time_range".localized, selection: $timeRange) {
                ForEach(ConsistencyTimeRange.allCases, id: \.self) { range in
                    Text(range.displayName).tag(range)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 16)
    }
}

private struct PenaltyToggleSection: View {
    @Binding var penalizeMissedTasks: Bool
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("penalize_missed_tasks".localized)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .themedPrimaryText()
                    // Existing code...
                    Text("decrease_progress_missed".localized)
                        .font(.system(.caption, design: .rounded))
                        .themedSecondaryText()
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Toggle("", isOn: $penalizeMissedTasks)
                    .labelsHidden()
                    .scaleEffect(1.1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.primaryColor.opacity(0.06),
                                theme.primaryColor.opacity(0.03)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        theme.primaryColor.opacity(0.12),
                                        theme.primaryColor.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
        .padding(.horizontal, 16)
    }
}

private struct TaskLegendSection: View {
    let tasks: [TodoTask]
    @Binding var selectedTaskId: UUID?
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("tasks".localized)
                .font(.system(.callout, design: .rounded, weight: .medium))
                .themedPrimaryText()
                .padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                        CompactLegendItem(
                            task: task,
                            taskIndex: index,
                            isSelected: selectedTaskId == nil || selectedTaskId == task.id,
                            isHighlighted: selectedTaskId == task.id
                        ) {
                            toggleTaskSelection(taskId: task.id)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private func toggleTaskSelection(taskId: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if selectedTaskId == taskId {
                selectedTaskId = nil
            } else {
                selectedTaskId = taskId
            }
        }
    }
}

private struct HelpTextSection: View {
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("how_to_read".localized)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .themedPrimaryText()
            VStack(alignment: .leading, spacing: 6) {
                HelpTextRow(
                    color: .blue,
                    text: "each_line_shows_task".localized
                )
                HelpTextRow(
                    color: .green,
                    text: "higher_points_better".localized
                )
                HelpTextRow(
                    color: .orange,
                    text: "tap_legend_highlight".localized
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

private struct ModernConsistencyChart: View {
    let tasks: [TodoTask]
    let timeRange: ConsistencyTimeRange
    @Binding var selectedTaskId: UUID?
    let penalizeMissedTasks: Bool
    @ObservedObject var viewModel: StatisticsViewModel
    @Environment(\.theme) private var theme
    
    private let distinctColors: [Color] = [
        .red, .blue, .green, .purple, .orange, .cyan,
        .pink, .yellow, .mint, .indigo, .teal, .brown
    ]
    
    var body: some View {
        VStack(spacing: 10) {
            Chart {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                    createTaskLines(for: task, at: index)
                }
            }
            .frame(height: 320)
            .chartXAxis {
                AxisMarks(position: .bottom, values: getXAxisDateValues()) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(theme.secondaryTextColor.opacity(0.2))
                    AxisValueLabel() {
                        if let dateValue = value.as(Date.self) {
                            Text(formatDateLabel(dateValue))
                                .font(.system(.caption2, design: .rounded, weight: .medium))
                                .themedSecondaryText()
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(theme.secondaryTextColor.opacity(0.2))
                    AxisValueLabel() {
                        if let intValue = value.as(Int.self) {
                            Text("\(intValue)")
                                .font(.system(.caption2, design: .rounded, weight: .medium))
                                .themedSecondaryText()
                        }
                    }
                }
            }
            .chartYScale(domain: 0...getCappedYMax())
            .chartYAxisLabel("completed_tasks".localized, position: .leading)
            .chartXAxisLabel("date".localized, position: .bottom)
            .chartPlotStyle { plotArea in
                plotArea.background(chartBackground)
            }
            .animation(.smooth(duration: 0.8), value: selectedTaskId)
            .animation(.smooth(duration: 0.8), value: timeRange)
        }
        .padding(.horizontal, 16)
    }

    // ... (rest of the code remains the same)

    private func getMaxYValue() -> Int {
        let allPoints = tasks.compactMap { task in
            getRealConsistencyPoints(for: task, timeRange: timeRange)
        }.flatMap { $0 }
        
        let maxValue = allPoints.map { $0.1 }.max() ?? 1
        return max(maxValue, 1)
    }
    
    // Expanded Y range to make lines visually less steep without changing data values
    private func getScaledMaxYValue() -> Int {
        let baseMax = Double(getMaxYValue())
        let scaled = ceil(baseMax * yScaleMultiplier())
        return max(Int(scaled), 1)
    }
    
    private func yScaleMultiplier() -> Double {
        switch timeRange {
        case .week:
            return 1.4
        case .month:
            return 2.0
        case .year:
            return 2.5
        }
    }

    private func getCappedYMax() -> Int {
        let scaled = getScaledMaxYValue()
        switch timeRange {
        case .week:
            return scaled
        case .month:
            return min(scaled, 31)
        case .year:
            return min(scaled, 365)
        }
    }

    private var chartBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(
                LinearGradient(
                    colors: [
                        theme.primaryColor.opacity(0.02),
                        theme.primaryColor.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                theme.primaryColor.opacity(0.1),
                                theme.primaryColor.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
    
    private func getXAxisDateValues() -> [Date] {
        let calendar = Calendar.current
        let today = Date()
        
        var dates: [Date] = []
        
        switch timeRange {
        case .week, .month:
            let daysToAnalyze: Int
            let interval: Int
            
            switch timeRange {
            case .week:
                daysToAnalyze = 7
                interval = 1
            case .month:
                daysToAnalyze = 30
                interval = 4
            default:
                daysToAnalyze = 0
                interval = 0
            }
            
            for dayOffset in stride(from: 1-daysToAnalyze, through: 0, by: interval) {
                if let date = calendar.date(byAdding: .day, value: dayOffset, to: today) {
                    dates.append(calendar.startOfDay(for: date))
                }
            }
            
            if !dates.contains(where: { calendar.isDate($0, inSameDayAs: today) }) {
                dates.append(calendar.startOfDay(for: today))
            }
        case .year:
            // Generate the first day of each month for the last 12 months including current
            let startOfCurrentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
            for monthsBack in stride(from: 11, through: 0, by: -1) {
                if let monthDate = calendar.date(byAdding: .month, value: -monthsBack, to: startOfCurrentMonth) {
                    dates.append(monthDate)
                }
            }
        }
        
        return dates.sorted()
    }
    
    private func formatDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        switch timeRange {
        case .week:
            formatter.dateFormat = "E dd"
        case .month:
            formatter.dateFormat = "dd MMM"
        case .year:
            // Shorter monthly label to avoid crowding
            formatter.dateFormat = "MMM"
        }
        
        return formatter.string(from: date)
    }
    
    @ChartContentBuilder
    private func createTaskLines(for task: TodoTask, at index: Int) -> some ChartContent {
        let points = getRealConsistencyPoints(for: task, timeRange: timeRange)
        let taskColor = getTaskColor(for: task, at: index)
        let isSelected = selectedTaskId == nil || selectedTaskId == task.id
        let opacity = isSelected ? 0.9 : 0.3
        let lineWidth = getLineWidth(isSelected: isSelected)
        let symbolSize = getSymbolSize(isSelected: isSelected)

        if !points.isEmpty {
            ForEach(Array(points.enumerated()), id: \.offset) { pointIndex, point in
                LineMark(
                    x: .value("date".localized, point.0),
                    y: .value("progress".localized, point.1),
                    series: .value("task".localized, task.name)
                )
                .foregroundStyle(taskColor.opacity(opacity))
                .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .symbol(.circle)
                .symbolSize(symbolSize)
                .interpolationMethod(.linear)
            }
        }
    }
    
    private func getLineWidth(isSelected: Bool) -> Double {
        switch timeRange {
        case .week:
            return isSelected ? 3.0 : 2.0
        case .month:
            return isSelected ? 2.0 : 1.5
        case .year:
            return isSelected ? 1.2 : 0.8
        }
    }
    
    private func getSymbolSize(isSelected: Bool) -> Double {
        switch timeRange {
        case .week:
            return isSelected ? 36 : 24
        case .month:
            return isSelected ? 14 : 10
        case .year:
            return isSelected ? 2 : 1
        }
    }

    private func getRealConsistencyPoints(for task: TodoTask, timeRange: ConsistencyTimeRange) -> [(Date, Int)] {
        guard let recurrence = task.recurrence else {
            return []
        }
        
        let calendar = Calendar.current
        let today = Date()
        let taskCreationDay = calendar.startOfDay(for: task.startTime)
        var points: [(Date, Int)] = []
        
        let daysToAnalyze: Int
        switch timeRange {
        case .week:
            daysToAnalyze = 7
        case .month:
            daysToAnalyze = 30
        case .year:
            daysToAnalyze = 365
        }
        
        var cumulativeProgress: Int = 0
        var foundFirstValidDay = false
        
        for dayOffset in (1-daysToAnalyze)...0 {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: today)!
            let startOfDay = calendar.startOfDay(for: date)
            
            if startOfDay < taskCreationDay {
                continue
            }
            
            if !foundFirstValidDay {
                foundFirstValidDay = true
            }
            
            if shouldTaskOccurOnDate(task: task, date: startOfDay) {
                let isCompleted = task.completions[startOfDay]?.isCompleted == true
                
                if isCompleted {
                    cumulativeProgress += 1
                } else if penalizeMissedTasks {
                    cumulativeProgress = max(0, cumulativeProgress - 1)
                }
                
                points.append((startOfDay, cumulativeProgress))
            }
        }
        
        if points.isEmpty && foundFirstValidDay {
            points.append((today, 0))
        }
        
        return points
    }
    
    private func shouldTaskOccurOnDate(task: TodoTask, date: Date) -> Bool {
        guard let recurrence = task.recurrence else { return false }
        
        let calendar = Calendar.current
        
        if date < calendar.startOfDay(for: task.startTime) {
            return false
        }
        
        if let endDate = recurrence.endDate, date > endDate {
            return false
        }
        
        switch recurrence.type {
        case .daily:
            return true
        case .weekly(let days):
            let weekday = calendar.component(.weekday, from: date)
            return days.contains(weekday)
        case .monthly(let days):
            let day = calendar.component(.day, from: date)
            return days.contains(day)
        case .monthlyOrdinal(let patterns):
            return recurrence.shouldOccurOn(date: date)
        case .yearly:
            return recurrence.shouldOccurOn(date: date)
        }
    }
    
    private func getTaskColor(for task: TodoTask, at index: Int) -> Color {
        if let categoryColor = task.category?.color {
            return Color(hex: categoryColor)
        } else {
            let colorIndex = index % distinctColors.count
            return distinctColors[colorIndex]
        }
    }
}

private struct CompactLegendItem: View {
    let task: TodoTask
    let taskIndex: Int
    let isSelected: Bool
    let isHighlighted: Bool
    let action: () -> Void
    @Environment(\.theme) private var theme
    
    private let distinctColors: [Color] = [
        .red, .blue, .green, .purple, .orange, .cyan,
        .pink, .yellow, .mint, .indigo, .teal, .brown
    ]
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                colorIndicator
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.name)
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .themedPrimaryText()
                        .lineLimit(1)
                    if let category = task.category {
                        Text(category.name)
                            .font(.system(.caption2, design: .rounded))
                            .themedSecondaryText()
                            .lineLimit(1)
                    }
                }
                if isHighlighted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(.caption2, weight: .medium))
                        .foregroundColor(theme.accentColor)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(backgroundStyle)
            .scaleEffect(isHighlighted ? 1.02 : 1.0)
            .opacity(isSelected ? 1.0 : 0.6)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isHighlighted)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    private var colorIndicator: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(taskColor)
            .frame(width: 3, height: 20)
    }
    
    private var backgroundStyle: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(backgroundFill)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(backgroundBorder, lineWidth: isHighlighted ? 1 : 0.5)
            )
    }
    
    private var backgroundFill: Color {
        isHighlighted ? theme.accentColor.opacity(0.1) : theme.primaryColor.opacity(0.05)
    }
    
    private var backgroundBorder: Color {
        isHighlighted ? theme.accentColor.opacity(0.3) : theme.primaryColor.opacity(0.1)
    }
    
    private var taskColor: Color {
        if let categoryColor = task.category?.color {
            return Color(hex: categoryColor)
        } else {
            let colorIndex = taskIndex % distinctColors.count
            return distinctColors[colorIndex]
        }
    }
}

private struct HelpTextRow: View {
    let color: Color
    let text: String
    @Environment(\.theme) private var theme
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.system(.caption, design: .rounded))
                .themedSecondaryText()
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct EmptyConsistencyView: View {
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(
                        colors: [theme.secondaryTextColor.opacity(0.6), theme.secondaryTextColor.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            VStack(spacing: 10) {
                Text("no_consistency_data".localized)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .themedPrimaryText()
                Text("complete_recurring_see_progress".localized)
                    .font(.system(.subheadline, design: .rounded))
                    .themedSecondaryText()
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}