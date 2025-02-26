import SwiftUI
import Charts

struct TaskConsistencyView: View {
    @ObservedObject var viewModel: StatisticsViewModel
    
    var body: some View {
        ConsistencyContentView(viewModel: viewModel)
    }
}

// Breaking down the view into smaller components
struct ConsistencyContentView: View {
    @ObservedObject var viewModel: StatisticsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Task Consistency")
                .font(.headline)
                .padding(.horizontal)
            
            // Break down the complex expression
            if viewModel.recurringTasks.isEmpty {
                EmptyConsistencyView()
            } else {
                TaskConsistencyChartContent(tasks: viewModel.recurringTasks)
            }
            
            Text("Shows completion rate for recurring tasks")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .padding(.vertical)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .padding(.horizontal, 8)
    }
}

// Empty state view
struct EmptyConsistencyView: View {
    var body: some View {
        Text("No consistency data available")
            .foregroundColor(.secondary)
            .frame(width: UIScreen.main.bounds.width * 0.9, height: 250)
            .padding(.horizontal)
    }
}

// Chart content view - Fixed the frame height issue
struct TaskConsistencyChartContent: View {
    let tasks: [TodoTask]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            // Fixed: Remove the height parameter from the frame modifier
            ChartView(tasks: tasks)
                .frame(minWidth: UIScreen.main.bounds.width * 0.9)
                .frame(height: 250) // Separate height modifier
                .padding(.horizontal)
        }
        .padding(.horizontal, 4)
    }
}

// Renamed from ChartContainer to ChartView to avoid confusion
struct ChartView: View {
    let tasks: [TodoTask]
    
    var body: some View {
        // Fixed: Use explicit Chart content instead of ForEach with ViewBuilder function
        Chart {
            ForEach(tasks) { task in
                let completionRate = calculateCompletionRate(for: task)
                
                BarMark(
                    x: .value("Task", task.name),
                    y: .value("Completion Rate", completionRate)
                )
                .foregroundStyle(Color.pink.gradient)
                .annotation(position: .top) {
                    Text("\(Int(completionRate * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // Helper function to calculate completion rate
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
            TaskConsistencyChartContent(tasks: consistencyData)
        }
    }
}
