import SwiftUI
import Charts

struct WatchStatisticsView: View {
    @StateObject private var viewModel = StatisticsViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Filtro periodo
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(StatisticsViewModel.TimeRange.allCases, id: \.self) { range in
                            Button(action: {
                                withAnimation {
                                    viewModel.selectedTimeRange = range
                                }
                            }) {
                                Text(range.rawValue)
                                    .font(.system(.footnote, design: .rounded))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(viewModel.selectedTimeRange == range ? 
                                                Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .strokeBorder(
                                                        viewModel.selectedTimeRange == range ? Color.blue : Color.clear, 
                                                        lineWidth: 1
                                                    )
                                            )
                                    )
                                    .foregroundColor(viewModel.selectedTimeRange == range ? .blue : .primary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 4)
                }
                
                // Grafico a torta per le categorie
                if viewModel.categoryStats.isEmpty {
                    Text("No data for this period")
                        .foregroundColor(.secondary)
                        .frame(height: 150)
                        .frame(maxWidth: .infinity)
                } else {
                    VStack(spacing: 8) {
                        Chart(viewModel.categoryStats) { stat in
                            SectorMark(
                                angle: .value("Hours", stat.hours),
                                innerRadius: .ratio(0.5),
                                angularInset: 1.5
                            )
                            .cornerRadius(3)
                            .foregroundStyle(Color(hex: stat.color))
                        }
                        .frame(height: 150)
                        
                        // Legenda
                        VStack(spacing: 6) {
                            ForEach(viewModel.categoryStats.prefix(3)) { stat in
                                HStack {
                                    Circle()
                                        .fill(Color(hex: stat.color))
                                        .frame(width: 10, height: 10)
                                    Text(stat.name)
                                        .font(.system(size: 12))
                                        .lineLimit(1)
                                    Spacer()
                                    Text(String(format: "%.1f hrs", stat.hours))
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if viewModel.categoryStats.count > 3 {
                                Text("+ \(viewModel.categoryStats.count - 3) more")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Grafico a barre per i task completati
                VStack(alignment: .leading, spacing: 8) {
                    Text("Task Completion")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if viewModel.weeklyStats.isEmpty {
                        Text("No data for this week")
                            .foregroundColor(.secondary)
                            .frame(height: 100)
                            .frame(maxWidth: .infinity)
                    } else {
                        Chart(viewModel.weeklyStats) { stat in
                            BarMark(
                                x: .value("Day", stat.day),
                                y: .value("Tasks", stat.completedTasks)
                            )
                            .foregroundStyle(Color.pink.gradient)
                        }
                        .frame(height: 120)
                    }
                }
                
                Divider()
                
                // Streak
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(viewModel.currentStreak)")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                            Text("Current Streak")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("\(viewModel.bestStreak)")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                            Text("Best Streak")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
        }
        .onAppear {
            viewModel.refreshStats()
        }
        .refreshable {
            viewModel.refreshStats()
        }
    }
} 