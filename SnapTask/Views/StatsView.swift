import SwiftUI
import Charts

struct TaskStatisticsView: View {
    @StateObject private var viewModel = StatisticsViewModel()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 8) {
                        // Time range selector
                        timeRangeSelector
                        
                        // Category chart
                        categoryChart
                        
                        // Category legend
                        categoryLegend
                    }
                }
                
                Section {
                    // Weekly stats
                    weeklyStatsView
                }
                
                // Remove the Section wrapper completely
                TaskConsistencyView(viewModel: viewModel)
                    .listRowInsets(EdgeInsets()) // Remove all insets
                    .padding(0) // Remove all padding
                    .background(Color.clear) // Clear background
                    .listRowBackground(Color.clear) // Clear row background
                
                Section {
                    // Streak info
                    streakInfoView
                }
            }
            .listStyle(.plain)
            .navigationTitle("Statistics")
            .onAppear {
                viewModel.refreshStats()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    viewModel.refreshStats()
                }
            }
            .onChange(of: viewModel.selectedTimeRange) { _, _ in
                viewModel.refreshStats()
            }
        }
    }
    
    // Suddividiamo la vista in componenti più piccoli per evitare problemi di compilazione
    private var timeRangeSelector: some View {
        HStack(spacing: 8) {
            ForEach(StatisticsViewModel.TimeRange.allCases, id: \.self) { range in
                TimeRangeButton(
                    range: range,
                    isSelected: viewModel.selectedTimeRange == range,
                    action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectedTimeRange = range
                        }
                    }
                )
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
    
    private var categoryChart: some View {
        Chart(viewModel.categoryStats) { stat in
            SectorMark(
                angle: .value("Hours", stat.hours),
                innerRadius: .ratio(0.618),
                angularInset: 1.5
            )
            .cornerRadius(3)
            .foregroundStyle(Color(hex: stat.color))
        }
        .frame(height: 200)
    }
    
    private var categoryLegend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.categoryStats) { stat in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: stat.color))
                            .frame(width: 8, height: 8)
                        Text(stat.name)
                            .font(.caption)
                        Text(String(format: "%.1f h", stat.hours))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.1))
                    )
                }
            }
            .padding(.top, 4)
        }
    }
    
    private var weeklyStatsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Overview")
                .font(.headline)
            
            HStack(spacing: 8) {
                ForEach(viewModel.weeklyStats) { stat in
                    VStack(spacing: 4) {
                        Text(stat.day)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 30, height: 100)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.accentColor)
                                .frame(width: 30, height: stat.totalTasks > 0 ? CGFloat(stat.completedTasks) / CGFloat(stat.totalTasks) * 100 : 0)
                        }
                        
                        Text("\(stat.completedTasks)/\(stat.totalTasks)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private var streakInfoView: some View {
        HStack(spacing: 24) {
            VStack {
                Text("\(viewModel.currentStreak)")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundColor(.accentColor)
                Text("Current Streak")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
                .frame(height: 40)
            
            VStack {
                Text("\(viewModel.bestStreak)")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundColor(.accentColor)
                Text("Best Streak")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// Nuovo componente per il grafico di consistenza
struct TaskConsistencyChartView: View {
    @ObservedObject var viewModel: StatisticsViewModel
    @State private var timeRange: TimeRange = .week
    
    enum TimeRange: String, CaseIterable {
        case week = "7 Days"
        case month = "30 Days"
        case year = "Year"
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Task Consistency")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            // Integrated time range selector
            Picker("Time Range", selection: $timeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            // Chart Container
            GeometryReader { geometry in
                ZStack(alignment: .bottomLeading) {
                    // Background grid
                    VStack(spacing: 0) {
                        ForEach(0..<4) { i in
                            Spacer()
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(.gray.opacity(0.2))
                        }
                    }
                    
                    // X-axis (bottom line)
                    Rectangle()
                        .frame(height: 1.5)
                        .foregroundColor(.gray.opacity(0.4))
                        .frame(width: geometry.size.width - 20)
                        .position(x: (geometry.size.width - 20) / 2 + 10, y: geometry.size.height - 10)
                    
                    // X-axis date labels
                    HStack(spacing: 0) {
                        ForEach(getDateLabels(for: timeRange), id: \.self) { dateLabel in
                            Text(dateLabel)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: (geometry.size.width - 20) / CGFloat(getDateLabels(for: timeRange).count))
                        }
                    }
                    .padding(.horizontal, 10)
                    .position(x: geometry.size.width / 2, y: geometry.size.height - 2)
                    
                    // Draw individual task lines
                    if viewModel.recurringTasks.isEmpty {
                        Text("No recurring tasks found")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Task lines
                        ForEach(Array(viewModel.recurringTasks.enumerated()), id: \.element.id) { index, task in
                            SingleTaskLineView(
                                task: task,
                                timeRange: timeRange,
                                viewModel: viewModel,
                                width: geometry.size.width - 20,
                                height: geometry.size.height - 20,
                                taskIndex: index
                            )
                            .padding(.horizontal, 10)
                        }
                    }
                }
                .padding(.bottom, 10) // Space for X-axis labels
            }
            .frame(height: 220)
            
            // Improved task legend with scrollable grid
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
                    ForEach(Array(viewModel.recurringTasks.enumerated()), id: \.element.id) { index, task in
                        HStack(spacing: 6) {
                            let color = task.category.map { Color(hex: $0.color) } ?? 
                                      [Color.blue, .green, .orange, .purple, .pink, .yellow, .red][index % 7]
                            
                            Circle()
                                .fill(color)
                                .frame(width: 8, height: 8)
                            
                            Text(task.name)
                                .font(.caption)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: min(CGFloat(viewModel.recurringTasks.count) * 20, 80))
        }
        .padding(.vertical)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    // Helper for generating date labels (keep existing implementation)
    private func getDateLabels(for timeRange: TimeRange) -> [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        
        let shortFormatter = DateFormatter()
        shortFormatter.dateFormat = "d"
        
        let calendar = Calendar.current
        let today = Date()
        
        switch timeRange {
        case .week:
            return (-6...0).map { offset in
                let date = calendar.date(byAdding: .day, value: offset, to: today)!
                return shortFormatter.string(from: date)
            }
        case .month:
            let labels = [-30, -25, -20, -15, -10, -5, 0].map { offset in
                let date = calendar.date(byAdding: .day, value: offset, to: today)!
                return shortFormatter.string(from: date)
            }
            return labels
        case .year:
            let labels = [-12, -10, -8, -6, -4, -2, 0].map { offset in
                let date = calendar.date(byAdding: .month, value: offset, to: today)!
                return formatter.string(from: date)
            }
            return labels
        }
    }
    
    private func convertTimeRange(_ statsTimeRange: StatisticsViewModel.TimeRange) -> TaskConsistencyChartView.TimeRange {
        switch statsTimeRange {
        case .today:
            return .week // Default to week for "today" since TaskConsistencyChartView doesn't have a "today" option
        case .week:
            return .week
        case .month:
            return .month
        case .year:
            return .year
        }
    }
}

// Reimplementazione di SingleTaskLineView per renderla più pulita
struct SingleTaskLineView: View {
    let task: TodoTask
    let timeRange: TaskConsistencyChartView.TimeRange
    let viewModel: StatisticsViewModel
    let width: CGFloat
    let height: CGFloat
    let taskIndex: Int
    
    // Array of colors to use if task has no category
    private let fallbackColors: [Color] = [.blue, .green, .orange, .purple, .pink, .yellow, .red]
    
    var body: some View {
        let points = viewModel.consistencyPoints(for: task, in: timeRange)
        let taskColor = task.category.map { Color(hex: $0.color) } ?? fallbackColors[taskIndex % fallbackColors.count]
        
        // Only draw if we have points
        if !points.isEmpty {
            ZStack {
                // Draw the line
                Path { path in
                    // Start from the first point
                    let firstPoint = points[0]
                    let x = firstPoint.x * width
                    
                    // Y in base al progresso, partendo dal basso (asse X)
                    // Il valore y più grande è height (top), il più piccolo è 0 (bottom)
                    let maxProgress = points.map { $0.y }.max() ?? 1.0
                    let scale = min(height / (maxProgress + 1), 20.0) // Scale factor per point of progress
                    let y = height - (firstPoint.y * scale)
                    
                    path.move(to: CGPoint(x: x, y: y))
                    
                    // Connect all points
                    for i in 1..<points.count {
                        let point = points[i]
                        let x = point.x * width
                        let y = height - (point.y * scale)
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .stroke(
                    taskColor.opacity(0.7),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
                
                // Draw dots at each point
                ForEach(0..<points.count, id: \.self) { i in
                    let point = points[i]
                    let x = point.x * width
                    let maxProgress = points.map { $0.y }.max() ?? 1.0
                    let scale = min(height / (maxProgress + 1), 20.0)
                    let y = height - (point.y * scale)
                    
                    Circle()
                        .fill(taskColor)
                        .frame(width: 5, height: 5)
                        .position(x: x, y: y)
                }
            }
            .offset(y: CGFloat(taskIndex % 3) * 1.0) // Leggerissimo offset per distinguere linee sovrapposte
        }
    }
}

private struct TimeRangeButton: View {
    let range: StatisticsViewModel.TimeRange
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(range.rawValue)
                .font(.system(.subheadline, design: .rounded, weight: isSelected ? .semibold : .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? 
                            Color.accentColor.opacity(0.15) : 
                            Color.gray.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(
                                    isSelected ? Color.accentColor : Color.clear,
                                    lineWidth: 1.5
                                )
                        )
                )
                .foregroundColor(isSelected ? .accentColor : .primary)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
} 

