import SwiftUI
import Charts

// Completamente ridisegnato per rimuovere tutti i contenitori limitanti
struct TaskConsistencyView: View {
    @ObservedObject var viewModel: StatisticsViewModel
    @State private var timeRange: TaskConsistencyChartView.TimeRange = .week
    
    var body: some View {
        // Keep the full width design but restore the original chart
        VStack(alignment: .leading, spacing: 16) {
            Text("Task Consistency")
                .font(.title3.bold())
                .padding(.horizontal, 16)
            
            if viewModel.recurringTasks.isEmpty {
                EmptyConsistencyView()
            } else {
                // Time range selector
                Picker("Time Range", selection: $timeRange) {
                    ForEach(TaskConsistencyChartView.TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                
                // Restore the original chart with full width
                GeometryReader { geometry in
                    ZStack {
                        // Background grid lines
                        VStack(spacing: geometry.size.height / 4) {
                            ForEach(0..<4) { _ in
                                Divider().background(Color.gray.opacity(0.2))
                            }
                        }
                        
                        // X-axis date labels
                        HStack(spacing: 0) {
                            ForEach(getDateLabels(for: timeRange), id: \.self) { label in
                                Text(label)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal, 10)
                        .offset(y: geometry.size.height / 2 - 10)
                        
                        // Task lines
                        ForEach(Array(viewModel.recurringTasks.enumerated()), id: \.element.id) { index, task in
                            SingleTaskLineView(
                                task: task,
                                timeRange: timeRange,
                                viewModel: viewModel,
                                width: geometry.size.width - 20,
                                height: geometry.size.height - 40,
                                taskIndex: index
                            )
                            .padding(.horizontal, 10)
                        }
                    }
                }
                .frame(height: 300)
                
                // Task legend
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.recurringTasks) { task in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(task.category.map { Color(hex: $0.color) } ?? .blue)
                                    .frame(width: 8, height: 8)
                                
                                Text(task.name)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            
            Text("Shows completion rate for recurring tasks")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
        }
        // Keep the full width layout
        .background(Color.clear)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
        .padding(0)
        .frame(width: UIScreen.main.bounds.width)
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

// Semplifichiamo la struttura rimuovendo componenti non necessari
struct EmptyConsistencyView: View {
    var body: some View {
        Text("No consistency data available")
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 300)
    }
}

// Semplifichiamo il chart view
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
        // Riduciamo il padding al minimo
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
    
    // Manteniamo le funzioni esistenti
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
