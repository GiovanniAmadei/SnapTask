//
//  PerformanceWidget.swift
//  SnapTaskWidget
//
//  Created by giovanni amadei on 03/12/24.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Performance Widget Data Models

struct CategoryStatData: Codable, Identifiable {
    var id: String { name }
    let name: String
    let color: String
    let hours: Double
}

struct WeeklyStatData: Codable, Identifiable {
    var id: String { day }
    let day: String
    let completedTasks: Int
    let totalTasks: Int
    let completionRate: Double
}

// MARK: - Widget Configuration Intent

enum PerformanceWidgetType: String, CaseIterable, AppEnum {
    case timeDistribution = "timeDistribution"
    case completionRate = "completionRate"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Performance Type")
    }
    
    static var caseDisplayRepresentations: [PerformanceWidgetType: DisplayRepresentation] {
        [
            .timeDistribution: DisplayRepresentation(title: "Time Distribution", subtitle: "Time spent per category"),
            .completionRate: DisplayRepresentation(title: "Task Completion Rate", subtitle: "Weekly completion statistics")
        ]
    }
}

struct PerformanceWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Performance Widget"
    static var description: IntentDescription = IntentDescription("Choose which performance metric to display")
    
    @Parameter(title: "Performance Type", default: .timeDistribution)
    var performanceType: PerformanceWidgetType
}

// MARK: - Timeline Entry

struct PerformanceEntry: TimelineEntry {
    let date: Date
    let performanceType: PerformanceWidgetType
    let categoryStats: [CategoryStatData]
    let weeklyStats: [WeeklyStatData]
    let totalHours: Double
    let overallCompletionRate: Double
}

// MARK: - Timeline Provider

struct PerformanceProvider: AppIntentTimelineProvider {
    typealias Entry = PerformanceEntry
    typealias Intent = PerformanceWidgetIntent
    
    func placeholder(in context: Context) -> PerformanceEntry {
        PerformanceEntry(
            date: Date(),
            performanceType: .timeDistribution,
            categoryStats: [
                CategoryStatData(name: "Work", color: "#F59E0B", hours: 1.83),
                CategoryStatData(name: "Health", color: "#10B981", hours: 0.75),
                CategoryStatData(name: "Personal", color: "#EF4444", hours: 0.5)
            ],
            weeklyStats: [],
            totalHours: 3.08,
            overallCompletionRate: 0.0
        )
    }
    
    func snapshot(for configuration: PerformanceWidgetIntent, in context: Context) async -> PerformanceEntry {
        await loadPerformanceData(for: configuration)
    }
    
    func timeline(for configuration: PerformanceWidgetIntent, in context: Context) async -> Timeline<PerformanceEntry> {
        let entry = await loadPerformanceData(for: configuration)
        
        // Update every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
    
    private func loadPerformanceData(for configuration: PerformanceWidgetIntent) async -> PerformanceEntry {
        let sharedDefaults = UserDefaults(suiteName: "group.com.snapTask.shared")
        
        // Load category stats for Time Distribution
        var categoryStats: [CategoryStatData] = []
        if let data = sharedDefaults?.data(forKey: "widgetCategoryStats") {
            do {
                categoryStats = try JSONDecoder().decode([CategoryStatData].self, from: data)
            } catch {
                print("Error decoding category stats: \(error)")
            }
        }
        
        // Load weekly stats for Completion Rate
        var weeklyStats: [WeeklyStatData] = []
        if let data = sharedDefaults?.data(forKey: "widgetWeeklyStats") {
            do {
                weeklyStats = try JSONDecoder().decode([WeeklyStatData].self, from: data)
            } catch {
                print("Error decoding weekly stats: \(error)")
            }
        }
        
        // Calculate totals
        let totalHours = categoryStats.reduce(0) { $0 + $1.hours }
        let totalCompleted = weeklyStats.reduce(0) { $0 + $1.completedTasks }
        let totalTasks = weeklyStats.reduce(0) { $0 + $1.totalTasks }
        let overallCompletionRate = totalTasks > 0 ? Double(totalCompleted) / Double(totalTasks) : 0.0
        
        return PerformanceEntry(
            date: Date(),
            performanceType: configuration.performanceType,
            categoryStats: categoryStats,
            weeklyStats: weeklyStats,
            totalHours: totalHours,
            overallCompletionRate: overallCompletionRate
        )
    }
}

// MARK: - Widget View

struct PerformanceWidgetEntryView: View {
    var entry: PerformanceEntry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme
    
    // Theme colors
    var backgroundColor: Color {
        colorScheme == .dark ? Color(red: 0.08, green: 0.08, blue: 0.1) : Color(red: 0.98, green: 0.98, blue: 0.99)
    }
    
    var surfaceColor: Color {
        colorScheme == .dark ? Color(red: 0.12, green: 0.12, blue: 0.14) : Color.white
    }
    
    var primaryColor: Color {
        Color.orange
    }
    
    var secondaryColor: Color {
        Color.pink
    }
    
    var textColor: Color {
        colorScheme == .dark ? .white : Color(red: 0.1, green: 0.1, blue: 0.15)
    }
    
    var secondaryTextColor: Color {
        colorScheme == .dark ? Color(red: 0.65, green: 0.65, blue: 0.7) : Color(red: 0.45, green: 0.45, blue: 0.5)
    }
    
    var accentGradient: LinearGradient {
        LinearGradient(
            colors: [primaryColor, secondaryColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        Group {
            switch family {
            case .systemLarge:
                // Large widget always shows both stats
                largeCombinedView
            default:
                // Small and Medium respect the user's choice
                switch entry.performanceType {
                case .timeDistribution:
                    timeDistributionView
                case .completionRate:
                    completionRateView
                }
            }
        }
        .containerBackground(for: .widget) {
            backgroundColor
        }
        .widgetURL(URL(string: "snaptask://statistics"))
    }
    
    // MARK: - Time Distribution View
    
    @ViewBuilder
    private var timeDistributionView: some View {
        switch family {
        case .systemSmall:
            smallTimeDistributionView
        default:
            mediumTimeDistributionView
        }
    }
    
    private var smallTimeDistributionView: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                Text(String(localized: "Time"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(primaryColor)
                Spacer()
                Text(formatHours(entry.totalHours))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(textColor)
            }
            
            if entry.categoryStats.isEmpty {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "chart.pie")
                        .font(.system(size: 24))
                        .foregroundStyle(accentGradient)
                    Text(String(localized: "No data"))
                        .font(.system(size: 11))
                        .foregroundColor(secondaryTextColor)
                }
                Spacer()
            } else {
                // Mini donut chart
                GeometryReader { geo in
                    let size = min(geo.size.width, geo.size.height) - 10
                    ZStack {
                        MiniDonutChart(stats: entry.categoryStats, size: size)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // Top 2 categories
                VStack(spacing: 3) {
                    ForEach(Array(entry.categoryStats.sorted { $0.hours > $1.hours }.prefix(2)), id: \.name) { stat in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: stat.color))
                                .frame(width: 6, height: 6)
                            Text(stat.name)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(textColor)
                                .lineLimit(1)
                            Spacer()
                            Text(formatHours(stat.hours))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(secondaryTextColor)
                        }
                    }
                }
            }
        }
        .padding(12)
    }
    
    private var mediumTimeDistributionView: some View {
        HStack(spacing: 16) {
            // Donut chart
            VStack(spacing: 8) {
                Text(String(localized: "Time Distribution"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(primaryColor)
                
                if entry.categoryStats.isEmpty {
                    ZStack {
                        Circle()
                            .stroke(secondaryTextColor.opacity(0.2), lineWidth: 12)
                            .frame(width: 80, height: 80)
                        Text(String(localized: "No data"))
                            .font(.system(size: 9))
                            .foregroundColor(secondaryTextColor)
                    }
                } else {
                    ZStack {
                        MiniDonutChart(stats: entry.categoryStats, size: 80)
                        VStack(spacing: 0) {
                            Text(formatHours(entry.totalHours))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(textColor)
                            Text(String(localized: "total"))
                                .font(.system(size: 8))
                                .foregroundColor(secondaryTextColor)
                        }
                    }
                }
            }
            .frame(width: 100)
            
            // Category list
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(entry.categoryStats.sorted { $0.hours > $1.hours }.prefix(4)), id: \.name) { stat in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: stat.color))
                            .frame(width: 3, height: 20)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(stat.name)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(textColor)
                                .lineLimit(1)
                            Text(formatHours(stat.hours))
                                .font(.system(size: 9))
                                .foregroundColor(secondaryTextColor)
                        }
                        
                        Spacer()
                        
                        // Percentage
                        Text(String(format: "%.0f%%", (stat.hours / max(entry.totalHours, 0.01)) * 100))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(hex: stat.color))
                    }
                }
                
                if entry.categoryStats.count > 4 {
                    Text(String(localized: "+ \(entry.categoryStats.count - 4) more"))
                        .font(.system(size: 9))
                        .foregroundColor(primaryColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
    }
    
    // MARK: - Large Combined View (Both Stats)
    
    private var largeCombinedView: some View {
        VStack(spacing: 10) {
            // Header
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 10, weight: .semibold))
                    Text(String(localized: "Performance"))
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Capsule().fill(accentGradient))
                
                Spacer()
                
                Text(String(localized: "7 Days"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(secondaryTextColor)
            }
            
            // Top section: Time Distribution
            HStack(spacing: 12) {
                // Donut chart
                if entry.categoryStats.isEmpty {
                    ZStack {
                        Circle()
                            .stroke(secondaryTextColor.opacity(0.2), lineWidth: 8)
                            .frame(width: 70, height: 70)
                        Image(systemName: "clock")
                            .font(.system(size: 20))
                            .foregroundColor(secondaryTextColor.opacity(0.5))
                    }
                } else {
                    ZStack {
                        MiniDonutChart(stats: entry.categoryStats, size: 70)
                        VStack(spacing: 0) {
                            Text(formatHours(entry.totalHours))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(textColor)
                        }
                    }
                    .frame(width: 70, height: 70)
                }
                
                // Category list (top 4)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Time Distribution"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(primaryColor)
                    
                    if entry.categoryStats.isEmpty {
                        Text(String(localized: "No time tracked"))
                            .font(.system(size: 10))
                            .foregroundColor(secondaryTextColor)
                    } else {
                        ForEach(Array(entry.categoryStats.sorted { $0.hours > $1.hours }.prefix(3)), id: \.name) { stat in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color(hex: stat.color))
                                    .frame(width: 6, height: 6)
                                Text(stat.name)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(textColor)
                                    .lineLimit(1)
                                Spacer()
                                Text(formatHours(stat.hours))
                                    .font(.system(size: 9))
                                    .foregroundColor(secondaryTextColor)
                            }
                        }
                        if entry.categoryStats.count > 3 {
                            Text(String(localized: "+ \(entry.categoryStats.count - 3) more"))
                                .font(.system(size: 8))
                                .foregroundColor(primaryColor)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Divider()
                .background(secondaryTextColor.opacity(0.2))
            
            // Bottom section: Completion Rate
            VStack(spacing: 6) {
                HStack {
                    Text(String(localized: "Task Completion Rate"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(primaryColor)
                    
                    Spacer()
                    
                    Text(String(format: "%.0f%%", entry.overallCompletionRate * 100))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(textColor)
                }
                
                if entry.weeklyStats.isEmpty {
                    HStack {
                        Spacer()
                        Text(String(localized: "No tasks this week"))
                            .font(.system(size: 10))
                            .foregroundColor(secondaryTextColor)
                        Spacer()
                    }
                    .frame(height: 50)
                } else {
                    // Bar chart
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(entry.weeklyStats, id: \.day) { stat in
                            VStack(spacing: 2) {
                                // Stacked bar
                                GeometryReader { geo in
                                    let maxHeight = geo.size.height
                                    let maxTasks = entry.weeklyStats.map { $0.totalTasks }.max() ?? 1
                                    let totalHeight = maxTasks > 0 ? maxHeight * CGFloat(stat.totalTasks) / CGFloat(max(maxTasks, 1)) : 0
                                    let completedHeight = stat.totalTasks > 0 ? totalHeight * CGFloat(stat.completedTasks) / CGFloat(stat.totalTasks) : 0
                                    
                                    VStack(spacing: 0) {
                                        Spacer(minLength: 0)
                                        
                                        ZStack(alignment: .bottom) {
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(secondaryTextColor.opacity(0.2))
                                                .frame(height: max(totalHeight, 3))
                                            
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(primaryColor)
                                                .frame(height: completedHeight)
                                        }
                                    }
                                }
                                
                                Text(String(stat.day.prefix(1)))
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(secondaryTextColor)
                            }
                        }
                    }
                    .frame(height: 55)
                    
                    // Legend
                    HStack(spacing: 12) {
                        let totalCompleted = entry.weeklyStats.reduce(0) { $0 + $1.completedTasks }
                        let totalTasks = entry.weeklyStats.reduce(0) { $0 + $1.totalTasks }
                        
                        HStack(spacing: 3) {
                            Circle()
                                .fill(primaryColor)
                                .frame(width: 6, height: 6)
                            Text("\(totalCompleted) " + String(localized: "done"))
                                .font(.system(size: 9))
                                .foregroundColor(secondaryTextColor)
                        }
                        
                        HStack(spacing: 3) {
                            Circle()
                                .fill(secondaryTextColor.opacity(0.3))
                                .frame(width: 6, height: 6)
                            Text("\(totalTasks) " + String(localized: "total"))
                                .font(.system(size: 9))
                                .foregroundColor(secondaryTextColor)
                        }
                        
                        Spacer()
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(12)
    }
    
    // MARK: - Completion Rate View
    
    @ViewBuilder
    private var completionRateView: some View {
        switch family {
        case .systemSmall:
            smallCompletionRateView
        default:
            mediumCompletionRateView
        }
    }
    
    private var smallCompletionRateView: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                Text(String(localized: "Completion"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(primaryColor)
                Spacer()
                Text(String(format: "%.0f%%", entry.overallCompletionRate * 100))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(textColor)
            }
            
            if entry.weeklyStats.isEmpty {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 24))
                        .foregroundStyle(accentGradient)
                    Text(String(localized: "No data"))
                        .font(.system(size: 11))
                        .foregroundColor(secondaryTextColor)
                }
                Spacer()
            } else {
                // Mini bar chart
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(entry.weeklyStats, id: \.day) { stat in
                        VStack(spacing: 2) {
                            MiniBar(
                                completed: stat.completedTasks,
                                total: stat.totalTasks,
                                primaryColor: primaryColor,
                                secondaryTextColor: secondaryTextColor
                            )
                            
                            Text(String(stat.day.prefix(1)))
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(secondaryTextColor)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                
                // Legend
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(primaryColor)
                            .frame(width: 5, height: 5)
                        Text(String(localized: "Done"))
                            .font(.system(size: 8))
                            .foregroundColor(secondaryTextColor)
                    }
                    HStack(spacing: 3) {
                        Circle()
                            .fill(secondaryTextColor.opacity(0.3))
                            .frame(width: 5, height: 5)
                        Text(String(localized: "Total"))
                            .font(.system(size: 8))
                            .foregroundColor(secondaryTextColor)
                    }
                }
            }
        }
        .padding(12)
    }
    
    private var mediumCompletionRateView: some View {
        VStack(spacing: 10) {
            // Header
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text(String(localized: "Task Completion Rate"))
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Capsule().fill(accentGradient))
                
                Spacer()
                
                Text(String(format: "%.0f%%", entry.overallCompletionRate * 100))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(primaryColor)
            }
            
            if entry.weeklyStats.isEmpty {
                Spacer()
                Text(String(localized: "No tasks this week"))
                    .font(.system(size: 11))
                    .foregroundColor(secondaryTextColor)
                Spacer()
            } else {
                // Bar chart
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(entry.weeklyStats, id: \.day) { stat in
                        VStack(spacing: 4) {
                            // Stacked bar
                            GeometryReader { geo in
                                let maxHeight = geo.size.height
                                let totalHeight = stat.totalTasks > 0 ? maxHeight : 0
                                let completedHeight = stat.totalTasks > 0 ? maxHeight * CGFloat(stat.completedTasks) / CGFloat(stat.totalTasks) : 0
                                
                                VStack(spacing: 0) {
                                    Spacer(minLength: 0)
                                    
                                    ZStack(alignment: .bottom) {
                                        // Total bar (background)
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(secondaryTextColor.opacity(0.2))
                                            .frame(width: 24, height: totalHeight)
                                        
                                        // Completed bar (foreground)
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(primaryColor)
                                            .frame(width: 24, height: completedHeight)
                                    }
                                }
                            }
                            
                            // Day label
                            Text(stat.day)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(secondaryTextColor)
                        }
                    }
                }
                .frame(maxHeight: 60)
                
                // Legend
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(primaryColor)
                            .frame(width: 12, height: 8)
                        Text(String(localized: "Completed"))
                            .font(.system(size: 9))
                            .foregroundColor(secondaryTextColor)
                    }
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(secondaryTextColor.opacity(0.2))
                            .frame(width: 12, height: 8)
                        Text(String(localized: "Total"))
                            .font(.system(size: 9))
                            .foregroundColor(secondaryTextColor)
                    }
                    Spacer()
                }
            }
        }
        .padding(14)
    }
    
    // MARK: - Helpers
    
    private func formatHours(_ hours: Double) -> String {
        if hours < 1 {
            return String(format: "%.0fm", hours * 60)
        } else {
            let h = Int(hours)
            let m = Int((hours - Double(h)) * 60)
            if m > 0 {
                return "\(h)h \(m)m"
            } else {
                return "\(h)h"
            }
        }
    }
}

// MARK: - Mini Donut Chart

struct MiniDonutChart: View {
    let stats: [CategoryStatData]
    let size: CGFloat
    
    var body: some View {
        let total = stats.reduce(0) { $0 + $1.hours }
        let sortedStats = stats.sorted { $0.hours > $1.hours }
        
        ZStack {
            ForEach(Array(sortedStats.enumerated()), id: \.element.name) { index, stat in
                let startAngle = angleFor(index: index, in: sortedStats, total: total)
                let endAngle = angleFor(index: index + 1, in: sortedStats, total: total)
                
                DonutSlice(
                    startAngle: startAngle,
                    endAngle: endAngle,
                    color: Color(hex: stat.color)
                )
            }
        }
        .frame(width: size, height: size)
    }
    
    private func angleFor(index: Int, in stats: [CategoryStatData], total: Double) -> Angle {
        guard total > 0 else { return .degrees(-90) }
        
        let sum = stats.prefix(index).reduce(0) { $0 + $1.hours }
        return .degrees((sum / total) * 360 - 90)
    }
}

struct DonutSlice: View {
    let startAngle: Angle
    let endAngle: Angle
    let color: Color
    
    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2
            let innerRadius = radius * 0.6
            
            Path { path in
                path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
                path.addArc(center: center, radius: innerRadius, startAngle: endAngle, endAngle: startAngle, clockwise: true)
                path.closeSubpath()
            }
            .fill(color)
        }
    }
}

// MARK: - Mini Bar

struct MiniBar: View {
    let completed: Int
    let total: Int
    let primaryColor: Color
    let secondaryTextColor: Color
    
    var body: some View {
        GeometryReader { geo in
            let maxHeight = geo.size.height
            let height = total > 0 ? maxHeight : 4
            let completedHeight = total > 0 ? maxHeight * CGFloat(completed) / CGFloat(total) : 0
            
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(secondaryTextColor.opacity(0.2))
                        .frame(width: 14, height: height)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(primaryColor)
                        .frame(width: 14, height: completedHeight)
                }
            }
        }
    }
}

// MARK: - Widget Definition

struct PerformanceWidget: Widget {
    let kind: String = "PerformanceWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: PerformanceWidgetIntent.self, provider: PerformanceProvider()) { entry in
            PerformanceWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(String(localized: "Performance"))
        .description(String(localized: "View your productivity statistics. Hold the widget to choose between Time Distribution or Completion Rate."))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    PerformanceWidget()
} timeline: {
    PerformanceEntry(
        date: Date(),
        performanceType: .timeDistribution,
        categoryStats: [
            CategoryStatData(name: "Work", color: "#F59E0B", hours: 1.83),
            CategoryStatData(name: "Health", color: "#10B981", hours: 0.75),
            CategoryStatData(name: "Personal", color: "#EF4444", hours: 0.5)
        ],
        weeklyStats: [],
        totalHours: 3.08,
        overallCompletionRate: 0.0
    )
}

#Preview(as: .systemMedium) {
    PerformanceWidget()
} timeline: {
    PerformanceEntry(
        date: Date(),
        performanceType: .completionRate,
        categoryStats: [],
        weeklyStats: [
            WeeklyStatData(day: "Thu", completedTasks: 3, totalTasks: 8, completionRate: 0.375),
            WeeklyStatData(day: "Fri", completedTasks: 2, totalTasks: 6, completionRate: 0.333),
            WeeklyStatData(day: "Sat", completedTasks: 1, totalTasks: 4, completionRate: 0.25),
            WeeklyStatData(day: "Sun", completedTasks: 0, totalTasks: 2, completionRate: 0.0),
            WeeklyStatData(day: "Mon", completedTasks: 5, totalTasks: 10, completionRate: 0.5),
            WeeklyStatData(day: "Tue", completedTasks: 4, totalTasks: 8, completionRate: 0.5),
            WeeklyStatData(day: "Wed", completedTasks: 3, totalTasks: 7, completionRate: 0.43)
        ],
        totalHours: 0,
        overallCompletionRate: 0.15
    )
}
