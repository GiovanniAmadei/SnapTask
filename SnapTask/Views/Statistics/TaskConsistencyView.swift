import SwiftUI
import Charts

enum ConsistencyTimeRange: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
}

struct TaskConsistencyView: View {
    @ObservedObject var viewModel: StatisticsViewModel
    @State private var timeRange: ConsistencyTimeRange = .week
    @State private var selectedTaskId: UUID? = nil
    @State private var penalizeMissedTasks: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HeaderSection()
            
            if viewModel.consistency.isEmpty {
                EmptyConsistencyView()
            } else {
                VStack(alignment: .leading, spacing: 16) {
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
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }
}

private struct HeaderSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Task Progress Over Time")
                .font(.system(.title3, design: .rounded, weight: .semibold))
            
            Text("Track completion patterns and consistency trends")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary)
        }
    }
}

private struct TimeRangeSection: View {
    @Binding var timeRange: ConsistencyTimeRange
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time Period")
                .font(.system(.headline, design: .rounded, weight: .medium))
                .foregroundColor(.primary)
            
            Picker("Time Range", selection: $timeRange) {
                ForEach(ConsistencyTimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

private struct PenaltyToggleSection: View {
    @Binding var penalizeMissedTasks: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Penalize Missed Tasks")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text("Decrease progress when recurring tasks are not completed")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $penalizeMissedTasks)
                    .labelsHidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.gray.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
}

private struct TaskLegendSection: View {
    let tasks: [TodoTask]
    @Binding var selectedTaskId: UUID?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tasks")
                .font(.system(.headline, design: .rounded, weight: .medium))
                .foregroundColor(.primary)
            
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                    ModernLegendItem(
                        task: task,
                        taskIndex: index,
                        isSelected: selectedTaskId == nil || selectedTaskId == task.id,
                        isHighlighted: selectedTaskId == task.id
                    ) {
                        toggleTaskSelection(taskId: task.id)
                    }
                }
            }
        }
    }
    
    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 12)]
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
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How to Read")
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 4) {
                HelpTextRow(
                    color: .blue,
                    text: "Each line shows a task's completion progress over time"
                )
                
                HelpTextRow(
                    color: .green,
                    text: "Higher points indicate better consistency"
                )
                
                HelpTextRow(
                    color: .orange,
                    text: "Tap legend items to highlight specific tasks"
                )
            }
        }
        .padding(.top, 8)
    }
}

private struct HelpTextRow: View {
    let color: Color
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            
            Text(text)
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.secondary)
        }
    }
}

private struct ModernConsistencyChart: View {
    let tasks: [TodoTask]
    let timeRange: ConsistencyTimeRange
    @Binding var selectedTaskId: UUID?
    let penalizeMissedTasks: Bool
    @ObservedObject var viewModel: StatisticsViewModel
    
    private let distinctColors: [Color] = [
        .red, .blue, .green, .purple, .orange, .cyan,
        .pink, .yellow, .mint, .indigo, .teal, .brown
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            Chart {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                    createTaskLines(for: task, at: index)
                }
            }
            .frame(height: 320)
            .chartXAxis {
                AxisMarks(position: .bottom, values: getXAxisDateValues()) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.gray.opacity(0.2))
                    AxisValueLabel() {
                        if let dateValue = value.as(Date.self) {
                            Text(formatDateLabel(dateValue))
                                .font(.system(.caption2, design: .rounded, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.gray.opacity(0.2))
                    AxisValueLabel() {
                        if let intValue = value.as(Int.self) {
                            Text("\(intValue)")
                                .font(.system(.caption2, design: .rounded, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .chartYAxisLabel("Completed Tasks", position: .leading)
            .chartXAxisLabel("Date", position: .bottom)
            .chartPlotStyle { plotArea in
                plotArea.background(chartBackground)
            }
            .animation(.smooth(duration: 0.8), value: selectedTaskId)
            .animation(.smooth(duration: 0.8), value: timeRange)
            .padding(.horizontal, 8)
        }
    }
    
    private var chartBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    colors: [
                        Color.gray.opacity(0.02),
                        Color.gray.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.gray.opacity(0.1),
                                Color.gray.opacity(0.05)
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
        
        let daysToAnalyze: Int
        let interval: Int
        
        switch timeRange {
        case .week:
            daysToAnalyze = 7
            interval = 1
        case .month:
            daysToAnalyze = 30
            interval = 4
        case .year:
            daysToAnalyze = 365
            interval = 30
        }
        
        var dates: [Date] = []
        
        for dayOffset in stride(from: 1-daysToAnalyze, through: 0, by: interval) {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: today) {
                dates.append(calendar.startOfDay(for: date))
            }
        }
        
        if !dates.contains(where: { calendar.isDate($0, inSameDayAs: today) }) {
            dates.append(calendar.startOfDay(for: today))
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
            formatter.dateFormat = "MMM yyyy"
        }
        
        return formatter.string(from: date)
    }
    
    @ChartContentBuilder
    private func createTaskLines(for task: TodoTask, at index: Int) -> some ChartContent {
        let points = getRealConsistencyPoints(for: task, timeRange: timeRange)
        let taskColor = getTaskColor(for: task, at: index)
        let isSelected = selectedTaskId == nil || selectedTaskId == task.id
        let opacity = isSelected ? 0.9 : 0.3
        let lineWidth: Double = isSelected ? 3.5 : 2
        let symbolSize: Double = isSelected ? 80 : 50
        
        if !points.isEmpty {
            ForEach(Array(points.enumerated()), id: \.offset) { pointIndex, point in
                LineMark(
                    x: .value("Date", point.0),
                    y: .value("Progress", point.1),
                    series: .value("Task", task.name)
                )
                .foregroundStyle(taskColor.opacity(opacity))
                .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .symbol(.circle)
                .symbolSize(symbolSize)
                .interpolationMethod(.linear)
            }
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
                points.append((startOfDay, 0))
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
        
        if points.count == 1 {
            points.append((today, points[0].1))
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

private struct ModernLegendItem: View {
    let task: TodoTask
    let taskIndex: Int
    let isSelected: Bool
    let isHighlighted: Bool
    let action: () -> Void
    
    private let distinctColors: [Color] = [
        .red, .blue, .green, .purple, .orange, .cyan,
        .pink, .yellow, .mint, .indigo, .teal, .brown
    ]
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                colorIndicator
                taskInfo
                Spacer(minLength: 0)
                highlightIcon
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(backgroundStyle)
            .scaleEffect(isHighlighted ? 1.03 : 1.0)
            .opacity(isSelected ? 1.0 : 0.5)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHighlighted)
        .animation(.easeInOut(duration: 0.25), value: isSelected)
    }
    
    private var colorIndicator: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(
                LinearGradient(
                    colors: [
                        taskColor,
                        taskColor.opacity(0.8)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 6, height: 28)
            .shadow(color: taskColor.opacity(0.3), radius: 2, x: 0, y: 1)
    }
    
    private var taskInfo: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(task.name)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            if let category = task.category {
                Text(category.name)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
    
    @ViewBuilder
    private var highlightIcon: some View {
        if isHighlighted {
            Image(systemName: "eye.fill")
                .font(.system(.caption, weight: .semibold))
                .foregroundColor(.accentColor)
                .scaleEffect(1.1)
        }
    }
    
    private var backgroundStyle: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(backgroundFill)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(backgroundBorder, lineWidth: isHighlighted ? 1.5 : 0.5)
            )
            .shadow(
                color: isHighlighted ? Color.accentColor.opacity(0.15) : Color.black.opacity(0.05),
                radius: isHighlighted ? 4 : 2,
                x: 0,
                y: isHighlighted ? 2 : 1
            )
    }
    
    private var backgroundFill: some ShapeStyle {
        LinearGradient(
            colors: isHighlighted ? [
                Color.accentColor.opacity(0.12),
                Color.accentColor.opacity(0.08)
            ] : [
                Color.gray.opacity(0.06),
                Color.gray.opacity(0.03)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var backgroundBorder: some ShapeStyle {
        LinearGradient(
            colors: isHighlighted ? [
                Color.accentColor.opacity(0.4),
                Color.accentColor.opacity(0.2)
            ] : [
                Color.gray.opacity(0.1),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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

struct EmptyConsistencyView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.secondary.opacity(0.6), .secondary.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 10) {
                Text("No Consistency Data")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Complete some recurring tasks to see your progress patterns and consistency trends over time")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
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
