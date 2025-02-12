import SwiftUI
import Charts

struct StatisticsView: View {
    @StateObject private var viewModel = StatisticsViewModel()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            ForEach(StatisticsViewModel.TimeRange.allCases, id: \.self) { range in
                                TimeRangeButton(
                                    range: range,
                                    isSelected: viewModel.selectedTimeRange == range,
                                    action: {
                                        withAnimation {
                                            viewModel.selectedTimeRange = range
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.vertical, 4)
                        
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
                        
                        ForEach(viewModel.categoryStats) { stat in
                            HStack {
                                Circle()
                                    .fill(Color(hex: stat.color))
                                    .frame(width: 12, height: 12)
                                Text(stat.name)
                                Spacer()
                                Text(String(format: "%.1f hrs", stat.hours))
                                    .foregroundColor(.secondary)
                            }
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
                    }
                    .frame(height: 200)
                }
                
                Section("Streak") {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(viewModel.currentStreak)")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                            Text("Current Streak")
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("\(viewModel.bestStreak)")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                            Text("Best Streak")
                                .foregroundColor(.secondary)
                        }
                    }
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

private struct TimeRangeButton: View {
    let range: StatisticsViewModel.TimeRange
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(range.rawValue)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.accentColor : Color.clear)
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
} 