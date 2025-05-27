import SwiftUI
import Charts

struct StatisticsView: View {
    @StateObject private var viewModel = StatisticsViewModel()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 20) {
                        HStack(spacing: 8) {
                            ForEach(StatisticsViewModel.TimeRange.allCases, id: \.self) { range in
                                TimeRangeButton(
                                    range: range,
                                    isSelected: viewModel.selectedTimeRange == range,
                                    action: {
                                        withAnimation(.smooth(duration: 0.8)) {
                                            viewModel.selectedTimeRange = range
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                        
                        Chart(viewModel.categoryStats) { stat in
                            SectorMark(
                                angle: .value("Hours", stat.hours),
                                innerRadius: .ratio(0.618),
                                angularInset: 1.5
                            )
                            .cornerRadius(3)
                            .foregroundStyle(Color(hex: stat.color))
                        }
                        .frame(height: 220)
                        .animation(.smooth(duration: 0.8), value: viewModel.categoryStats)
                        .animation(.smooth(duration: 0.8), value: viewModel.selectedTimeRange)
                        
                        VStack(spacing: 16) {
                            HStack {
                                Text("Time Distribution")
                                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("Total: \(String(format: "%.1fh", viewModel.categoryStats.reduce(0) { $0 + $1.hours }))")
                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ], spacing: 12) {
                                ForEach(viewModel.categoryStats) { stat in
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color(hex: stat.color),
                                                        Color(hex: stat.color).opacity(0.8)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 18, height: 18)
                                            .shadow(color: Color(hex: stat.color).opacity(0.3), radius: 2, x: 0, y: 1)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(stat.name)
                                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                                .lineLimit(1)
                                                .foregroundColor(.primary)
                                            Text(String(format: "%.1fh", stat.hours))
                                                .font(.system(.caption2, design: .rounded, weight: .medium))
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color(hex: stat.color).opacity(0.06),
                                                        Color(hex: stat.color).opacity(0.03)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .strokeBorder(
                                                        LinearGradient(
                                                            colors: [
                                                                Color(hex: stat.color).opacity(0.15),
                                                                Color(hex: stat.color).opacity(0.08)
                                                            ],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                        lineWidth: 0.8
                                                    )
                                            )
                                    )
                                }
                            }
                            .padding(.horizontal, 4)
                            .animation(.smooth(duration: 0.8), value: viewModel.categoryStats)
                        }
                    }
                } header: {
                    Text("Time Spent \(viewModel.selectedTimeRange.rawValue)")
                }
                
                Section("Task Completion Rate") {
                    Chart(viewModel.weeklyStats) { stat in
                        BarMark(
                            x: .value("Day", stat.day),
                            y: .value("Tasks", stat.completedTasks)
                        )
                        .foregroundStyle(Color.pink.gradient)
                        .cornerRadius(4)
                    }
                    .frame(height: 200)
                    .chartXAxis {
                        AxisMarks(position: .bottom) { _ in
                            AxisValueLabel()
                                .font(.caption)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisValueLabel()
                                .font(.caption)
                        }
                    }
                }
                
                Section("Streak") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(viewModel.currentStreak)")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text("Current Streak")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(viewModel.bestStreak)")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text("Best Streak")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                    .animation(.smooth(duration: 0.8), value: viewModel.currentStreak)
                    .animation(.smooth(duration: 0.8), value: viewModel.bestStreak)
                }
                
                Section("Task Consistency") {
                    TaskConsistencyView(viewModel: viewModel)
                }
            }
            .navigationTitle("Statistics")
        }
        .onAppear {
            viewModel.refreshStats()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                viewModel.refreshStats()
            }
        }
        .refreshable {
            viewModel.refreshStats()
        }
    }
}

private struct TimeRangeSelector: View {
    @ObservedObject var viewModel: StatisticsViewModel
    
    var body: some View {
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
}

private struct PieChartView: View {
    @ObservedObject var viewModel: StatisticsViewModel
    
    var body: some View {
        Chart(viewModel.categoryStats) { stat in
            SectorMark(
                angle: .value("Hours", stat.hours),
                innerRadius: .ratio(0.618),
                angularInset: 1.5
            )
            .cornerRadius(3)
            .foregroundStyle(Color(hex: stat.color))
        }
        .frame(height: 220)
        .animation(.smooth(duration: 0.8), value: viewModel.categoryStats)
        .animation(.smooth(duration: 0.8), value: viewModel.selectedTimeRange)
    }
}

private struct LegendView: View {
    @ObservedObject var viewModel: StatisticsViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Time Distribution")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundColor(.primary)
                Spacer()
                Text("Total: \(String(format: "%.1fh", viewModel.categoryStats.reduce(0) { $0 + $1.hours }))")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(viewModel.categoryStats) { stat in
                    CategoryLegendItem(stat: stat)
                }
            }
            .padding(.horizontal, 4)
            .animation(.smooth(duration: 0.8), value: viewModel.categoryStats)
        }
    }
}

private struct TaskCompletionSection: View {
    @ObservedObject var viewModel: StatisticsViewModel
    
    var body: some View {
        Section("Task Completion Rate") {
            Chart(viewModel.weeklyStats) { stat in
                BarMark(
                    x: .value("Day", stat.day),
                    y: .value("Tasks", stat.completedTasks)
                )
                .foregroundStyle(Color.pink.gradient)
                .cornerRadius(4)
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(position: .bottom) { _ in
                    AxisValueLabel()
                        .font(.caption)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisValueLabel()
                        .font(.caption)
                }
            }
        }
    }
}

private struct StreakSection: View {
    @ObservedObject var viewModel: StatisticsViewModel
    
    var body: some View {
        Section("Streak") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(viewModel.currentStreak)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("Current Streak")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(viewModel.bestStreak)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("Best Streak")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
    }
}

private struct ConsistencySection: View {
    @ObservedObject var viewModel: StatisticsViewModel
    
    var body: some View {
        Section("Task Consistency") {
            TaskConsistencyView(viewModel: viewModel)
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
                .background(buttonBackground)
                .foregroundColor(isSelected ? .accentColor : .primary)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    private var buttonBackground: some View {
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
    }
}

private struct CategoryLegendItem: View {
    let stat: StatisticsViewModel.CategoryStat
    
    var body: some View {
        HStack(spacing: 12) {
            categoryCircle
            categoryInfo
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 10)
        .background(categoryBackground)
        .animation(.smooth(duration: 0.6), value: stat.hours)
    }
    
    private var categoryCircle: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(hex: stat.color),
                        Color(hex: stat.color).opacity(0.8)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 18, height: 18)
            .shadow(color: Color(hex: stat.color).opacity(0.3), radius: 2, x: 0, y: 1)
    }
    
    private var categoryInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(stat.name)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .lineLimit(1)
                .foregroundColor(.primary)
            Text(String(format: "%.1fh", stat.hours))
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
    
    private var categoryBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(backgroundGradient)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(borderGradient, lineWidth: 0.8)
            )
    }
    
    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: stat.color).opacity(0.06),
                Color(hex: stat.color).opacity(0.03)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: stat.color).opacity(0.15),
                Color(hex: stat.color).opacity(0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
