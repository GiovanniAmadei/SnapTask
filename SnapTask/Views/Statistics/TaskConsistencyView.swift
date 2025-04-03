import SwiftUI
import Charts

// Completamente ridisegnato per rimuovere tutti i contenitori limitanti
struct TaskConsistencyView: View {
    @ObservedObject var viewModel: StatisticsViewModel
    @State private var timeRange: TaskConsistencyChartView.TimeRange = .week
    @State private var selectedTaskId: UUID? = nil
    
    var body: some View {
        // Break down the complex view into smaller components
        ConsistencyContentView(
            viewModel: viewModel,
            timeRange: $timeRange,
            selectedTaskId: $selectedTaskId
        )
        .background(Color.clear)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
        .padding(0)
        .frame(width: UIScreen.main.bounds.width)
    }
}

// Extracted content view to simplify the main view
private struct ConsistencyContentView: View {
    @ObservedObject var viewModel: StatisticsViewModel
    @Binding var timeRange: TaskConsistencyChartView.TimeRange
    @Binding var selectedTaskId: UUID?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Task Consistency")
                .font(.title3.bold())
                .padding(.horizontal, 16)
            
            if viewModel.recurringTasks.isEmpty {
                EmptyConsistencyView()
            } else {
                // Time range selector
                ConsistencyTimeRangeSelector(timeRange: $timeRange)
                
                // Chart with task lines
                ConsistencyChartContainer(
                    viewModel: viewModel,
                    timeRange: timeRange,
                    selectedTaskId: $selectedTaskId
                )
                
                // Task legend
                ConsistencyLegendGrid(
                    tasks: viewModel.recurringTasks,
                    selectedTaskId: $selectedTaskId
                )
            }
            
            Text("Shows completion rate for recurring tasks")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
        }
    }
}

// Time range selector component
private struct ConsistencyTimeRangeSelector: View {
    @Binding var timeRange: TaskConsistencyChartView.TimeRange
    
    var body: some View {
        Picker("Time Range", selection: $timeRange) {
            ForEach(TaskConsistencyChartView.TimeRange.allCases, id: \.self) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
    }
}

// Chart container component
private struct ConsistencyChartContainer: View {
    @ObservedObject var viewModel: StatisticsViewModel
    let timeRange: TaskConsistencyChartView.TimeRange
    @Binding var selectedTaskId: UUID?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background grid lines
                VStack(spacing: geometry.size.height / 4) {
                    ForEach(0..<4) { _ in
                        Divider().background(Color.gray.opacity(0.2))
                    }
                }
                
                // X-axis date labels
                DateLabelsView(
                    timeRange: timeRange,
                    width: geometry.size.width,
                    height: geometry.size.height
                )
                
                // Task lines
                TaskLinesContainer(
                    tasks: viewModel.recurringTasks,
                    timeRange: timeRange,
                    viewModel: viewModel,
                    width: geometry.size.width - 20,
                    height: geometry.size.height - 40,
                    selectedTaskId: selectedTaskId
                )
            }
        }
        .frame(height: 300)
    }
}

// Date labels component
private struct DateLabelsView: View {
    let timeRange: TaskConsistencyChartView.TimeRange
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(getDateLabels(for: timeRange), id: \.self) { label in
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 10)
        .offset(y: height / 2 - 10)
    }
    
    // Helper for generating date labels
    private func getDateLabels(for timeRange: TaskConsistencyChartView.TimeRange) -> [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        
        let calendar = Calendar.current
        let today = Date()
        
        switch timeRange {
        case .week:
            return (-6...0).map { offset in
                let date = calendar.date(byAdding: .day, value: offset, to: today)!
                return formatter.string(from: date)
            }
        case .month:
            let labels = [-30, -25, -20, -15, -10, -5, 0].map { offset in
                let date = calendar.date(byAdding: .day, value: offset, to: today)!
                return formatter.string(from: date)
            }
            return labels
        case .year:
            formatter.dateFormat = "MMM"
            let labels = [-12, -10, -8, -6, -4, -2, 0].map { offset in
                let date = calendar.date(byAdding: .month, value: offset, to: today)!
                return formatter.string(from: date)
            }
            return labels
        }
    }
}

// Task lines container
private struct TaskLinesContainer: View {
    let tasks: [TodoTask]
    let timeRange: TaskConsistencyChartView.TimeRange
    let viewModel: StatisticsViewModel
    let width: CGFloat
    let height: CGFloat
    let selectedTaskId: UUID?
    
    var body: some View {
        ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
            let isSelected = selectedTaskId == nil || selectedTaskId == task.id
            
            TaskLineView(
                task: task,
                timeRange: timeRange,
                viewModel: viewModel,
                width: width,
                height: height,
                taskIndex: index,
                isSelected: isSelected
            )
            .padding(.horizontal, 10)
            .opacity(isSelected ? 1.0 : 0.3)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
    }
}

// Rename this to avoid the redeclaration
struct TaskLineView: View {
    let task: TodoTask
    let timeRange: TaskConsistencyChartView.TimeRange
    let viewModel: StatisticsViewModel
    let width: CGFloat
    let height: CGFloat
    let taskIndex: Int
    let isSelected: Bool
    
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
                    
                    let maxProgress = points.map { $0.y }.max() ?? 1.0
                    let scale = min(height / (maxProgress + 1), 20.0)
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
                    taskColor.opacity(isSelected ? 0.9 : 0.5),
                    style: StrokeStyle(
                        lineWidth: isSelected ? 3 : 2,
                        lineCap: .round,
                        lineJoin: .round
                    )
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
                        .frame(width: isSelected ? 8 : 5, height: isSelected ? 8 : 5)
                        .position(x: x, y: y)
                }
            }
            .offset(y: CGFloat(taskIndex % 3) * 1.0)
        }
    }
}

// Legend grid component
private struct ConsistencyLegendGrid: View {
    let tasks: [TodoTask]
    @Binding var selectedTaskId: UUID?
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 8)
        ], spacing: 8) {
            ForEach(tasks) { task in
                LegendButton(
                    task: task,
                    isSelected: selectedTaskId == task.id,
                    action: {
                        withAnimation {
                            if selectedTaskId == task.id {
                                selectedTaskId = nil
                            } else {
                                selectedTaskId = task.id
                            }
                        }
                    }
                )
            }
        }
        .padding(.horizontal, 16)
    }
}

// Individual legend button
private struct LegendButton: View {
    let task: TodoTask
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(task.category.map { Color(hex: $0.color) } ?? .blue)
                    .frame(width: 8, height: 8)
                
                Text(task.name)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? 
                          Color.accentColor.opacity(0.15) : 
                          Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                isSelected ? Color.accentColor : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Semplifichiamo la struttura rimuovendo componenti non necessari
struct EmptyConsistencyView: View {
    var body: some View {
        Text("No consistency data available")
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 300)
    }
}

// Simplified chart view
struct SimpleChartView: View {
    let tasks: [TodoTask]
    @Binding var selectedTaskId: UUID?
    
    var body: some View {
        Chart {
            ForEach(tasks) { task in
                let completionRate = calculateCompletionRate(for: task)
                let isSelected = selectedTaskId == task.id || selectedTaskId == nil
                
                BarMark(
                    x: .value("Task", task.name),
                    y: .value("Completion Rate", completionRate)
                )
                .foregroundStyle(
                    isSelected 
                        ? Color.pink.gradient 
                        : Color.pink.opacity(0.3).gradient
                )
                .annotation(position: .top) {
                    Text("\(Int(completionRate * 100))%")
                        .font(.caption)
                        .foregroundColor(isSelected ? .secondary : .secondary.opacity(0.5))
                }
                .opacity(isSelected ? 1.0 : 0.6)
            }
        }
        .chartLegend(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartXAxis {
            AxisMarks(position: .bottom)
        }
        .padding(4)
        .animation(.easeInOut, value: selectedTaskId)
        .overlay(
            GeometryReader { geometry in
                Color.clear.contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                handleTap(at: value.location, in: geometry.size, tasks: tasks)
                            }
                    )
            }
        )
    }
    
    private func handleTap(at location: CGPoint, in size: CGSize, tasks: [TodoTask]) {
        let barWidth = size.width / CGFloat(tasks.count)
        let index = Int(location.x / barWidth)
        
        if index >= 0 && index < tasks.count {
            withAnimation {
                let tappedTaskId = tasks[index].id
                if selectedTaskId == tappedTaskId {
                    selectedTaskId = nil
                } else {
                    selectedTaskId = tappedTaskId
                }
            }
        }
    }
    
    private func calculateCompletionRate(for task: TodoTask) -> Double {
        let completions = task.completions.values
        if completions.isEmpty {
            return 0.0
        }
        
        let completedCount = completions.filter { $0.isCompleted }.count
        return Double(completedCount) / Double(completions.count)
    }
}

// Keep the original ConsistencyChartView for backward compatibility
struct ConsistencyChartView: View {
    let consistencyData: [TodoTask]
    
    var body: some View {
        if consistencyData.isEmpty {
            EmptyConsistencyView()
        } else {
            SimpleChartView(tasks: consistencyData, selectedTaskId: .constant(nil))
                .frame(height: 300)
        }
    }
}
