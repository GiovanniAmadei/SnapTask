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

struct PerformanceWidgetTimeRangeOptionsProvider: DynamicOptionsProvider {
    @IntentParameterDependency<PerformanceWidgetIntent>(\.$content) var intent

    func results() async throws -> [PerformanceWidgetTimeRange] {
        switch intent?.content {
        case .completionRate:
            return [.week, .month, .year]
        case .timeDistribution, .none:
            return PerformanceWidgetTimeRange.allCases
        }
    }
}

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

enum PerformanceWidgetContent: String, CaseIterable, AppEnum {
    case timeDistribution = "timeDistribution"
    case completionRate = "completionRate"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: LocalizedStringResource("Performance Type"))
    }
    
    static var caseDisplayRepresentations: [PerformanceWidgetContent: DisplayRepresentation] {
        [
            .timeDistribution: DisplayRepresentation(title: LocalizedStringResource("Time Distribution"), subtitle: LocalizedStringResource("Time spent per category")),
            .completionRate: DisplayRepresentation(title: LocalizedStringResource("Task Completion Rate"), subtitle: LocalizedStringResource("Task completion statistics"))
        ]
    }
}

enum PerformanceWidgetTimeRange: String, CaseIterable, AppEnum {
    case today = "today"
    case week = "week"
    case month = "month"
    case year = "year"
    case allTime = "allTime"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: LocalizedStringResource("Time Range"))
    }
    
    static var caseDisplayRepresentations: [PerformanceWidgetTimeRange: DisplayRepresentation] {
        [
            .today: DisplayRepresentation(title: LocalizedStringResource("Today")),
            .week: DisplayRepresentation(title: LocalizedStringResource("Week")),
            .month: DisplayRepresentation(title: LocalizedStringResource("Month")),
            .year: DisplayRepresentation(title: LocalizedStringResource("Year")),
            .allTime: DisplayRepresentation(title: LocalizedStringResource("All Time"))
        ]
    }
    
    var widgetKeySuffix: String {
        rawValue
    }
    
    var headerLabel: LocalizedStringResource {
        switch self {
        case .today:
            return LocalizedStringResource("Today")
        case .week:
            return LocalizedStringResource("Week")
        case .month:
            return LocalizedStringResource("Month")
        case .year:
            return LocalizedStringResource("Year")
        case .allTime:
            return LocalizedStringResource("All Time")
        }
    }
}

struct PerformanceWidgetLargeIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("Performance Widget")
    static var description: IntentDescription = IntentDescription(LocalizedStringResource("Choose which performance time range to display"))

    @Parameter(title: LocalizedStringResource("Time Range"), default: .week)
    var timeRange: PerformanceWidgetTimeRange
}

struct PerformanceWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("Performance Widget")
    static var description: IntentDescription = IntentDescription(LocalizedStringResource("Choose which performance metric to display"))
    
    @Parameter(title: LocalizedStringResource("Content"), default: .timeDistribution)
    var content: PerformanceWidgetContent
    
    @Parameter(title: LocalizedStringResource("Time Range"), default: .week, optionsProvider: PerformanceWidgetTimeRangeOptionsProvider())
    var timeRange: PerformanceWidgetTimeRange
}

// MARK: - Timeline Entry

struct PerformanceEntry: TimelineEntry {
    let date: Date
    let content: PerformanceWidgetContent
    let timeRange: PerformanceWidgetTimeRange
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
            content: .timeDistribution,
            timeRange: .week,
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
        if let data = sharedDefaults?.data(forKey: "widgetCategoryStats_\(configuration.timeRange.widgetKeySuffix)") {
            do {
                categoryStats = try JSONDecoder().decode([CategoryStatData].self, from: data)
            } catch {
                print("Error decoding category stats: \(error)")
            }
        }
        
        // Load weekly stats for Completion Rate
        var weeklyStats: [WeeklyStatData] = []
        if let data = sharedDefaults?.data(forKey: "widgetWeeklyStats_\(configuration.timeRange.widgetKeySuffix)") {
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
            content: configuration.content,
            timeRange: configuration.timeRange,
            categoryStats: categoryStats,
            weeklyStats: weeklyStats,
            totalHours: totalHours,
            overallCompletionRate: overallCompletionRate
        )
    }
}

struct PerformanceLargeProvider: AppIntentTimelineProvider {
    typealias Entry = PerformanceEntry
    typealias Intent = PerformanceWidgetLargeIntent

    func placeholder(in context: Context) -> PerformanceEntry {
        PerformanceEntry(
            date: Date(),
            content: .timeDistribution,
            timeRange: .week,
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

    func snapshot(for configuration: PerformanceWidgetLargeIntent, in context: Context) async -> PerformanceEntry {
        await loadPerformanceData(for: configuration)
    }

    func timeline(for configuration: PerformanceWidgetLargeIntent, in context: Context) async -> Timeline<PerformanceEntry> {
        let entry = await loadPerformanceData(for: configuration)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    private func loadPerformanceData(for configuration: PerformanceWidgetLargeIntent) async -> PerformanceEntry {
        let sharedDefaults = UserDefaults(suiteName: "group.com.snapTask.shared")

        var categoryStats: [CategoryStatData] = []
        if let data = sharedDefaults?.data(forKey: "widgetCategoryStats_\(configuration.timeRange.widgetKeySuffix)") {
            do {
                categoryStats = try JSONDecoder().decode([CategoryStatData].self, from: data)
            } catch {
                print("Error decoding category stats: \(error)")
            }
        }

        var weeklyStats: [WeeklyStatData] = []
        if let data = sharedDefaults?.data(forKey: "widgetWeeklyStats_\(configuration.timeRange.widgetKeySuffix)") {
            do {
                weeklyStats = try JSONDecoder().decode([WeeklyStatData].self, from: data)
            } catch {
                print("Error decoding weekly stats: \(error)")
            }
        }

        let totalHours = categoryStats.reduce(0) { $0 + $1.hours }
        let totalCompleted = weeklyStats.reduce(0) { $0 + $1.completedTasks }
        let totalTasks = weeklyStats.reduce(0) { $0 + $1.totalTasks }
        let overallCompletionRate = totalTasks > 0 ? Double(totalCompleted) / Double(totalTasks) : 0.0

        return PerformanceEntry(
            date: Date(),
            content: .timeDistribution,
            timeRange: configuration.timeRange,
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

    private func completionLabel(for stat: WeeklyStatData, compact: Bool) -> String {
        switch entry.timeRange {
        case .week:
            return String(stat.day.prefix(1))
        case .month:
            if stat.day.hasPrefix("W") {
                return stat.day
            }
            return String(stat.day.prefix(compact ? 1 : 2))
        case .year:
            return String(stat.day.prefix(3))
        default:
            return String(stat.day.prefix(2))
        }
    }

    private func completionBarLayout(availableWidth: CGFloat, barCount: Int, preferredBarWidth: CGFloat, minBarWidth: CGFloat, minSpacing: CGFloat) -> (barWidth: CGFloat, spacing: CGFloat) {
        guard barCount > 0 else { return (preferredBarWidth, minSpacing) }

        let count = CGFloat(barCount)
        let spacing = minSpacing
        let widthWithMinSpacing = (availableWidth - spacing * (count - 1)) / count

        let barWidth = max(minBarWidth, min(preferredBarWidth, widthWithMinSpacing))
        let remaining = max(0, availableWidth - barWidth * count)
        let resolvedSpacing = count > 1 ? max(minSpacing, remaining / (count - 1)) : 0
        return (barWidth, resolvedSpacing)
    }
    
    var body: some View {
        Group {
            switch family {
            case .systemLarge:
                // Large widget always shows both charts
                largeCombinedView
            default:
                // Small and Medium respect the user's choice
                switch entry.content {
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
        GeometryReader { geo in
            let donutSize = min(70, max(54, geo.size.height * 0.42))

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
                    Spacer(minLength: 0)
                    VStack(spacing: 4) {
                        Image(systemName: "chart.pie")
                            .font(.system(size: 24))
                            .foregroundStyle(accentGradient)
                        Text(String(localized: "No data"))
                            .font(.system(size: 11))
                            .foregroundColor(secondaryTextColor)
                    }
                    Spacer(minLength: 0)
                } else {
                    HStack(alignment: .center, spacing: 10) {
                        ZStack {
                            MiniDonutChart(stats: entry.categoryStats, size: donutSize)
                        }
                        .frame(width: donutSize, height: donutSize)

                        VStack(spacing: 4) {
                            ForEach(Array(entry.categoryStats.sorted { $0.hours > $1.hours }.prefix(3)), id: \.name) { stat in
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color(hex: stat.color))
                                        .frame(width: 6, height: 6)
                                    Text(stat.name)
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(textColor)
                                        .lineLimit(1)
                                    Spacer(minLength: 4)
                                    Text(formatHours(stat.hours))
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(secondaryTextColor)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                }
            }
            .padding(12)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
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
                            DonutCenterValueText(text: formatHours(entry.totalHours), maxWidth: 80 * 0.58, textColor: textColor)
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
                ForEach(Array(entry.categoryStats.sorted { $0.hours > $1.hours }.prefix(6)), id: \.name) { stat in
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
                
                if entry.categoryStats.count > 6 {
                    Text(String(localized: "+ \(entry.categoryStats.count - 6) more"))
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
        GeometryReader { geo in
            let padding: CGFloat = 12
            let donutSize = min(132, max(108, geo.size.height * 0.34))
            let chartHeight = min(120, max(76, geo.size.height * 0.26))
            let completionChartWidth = max(0, geo.size.width - (padding * 2))

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
                    .padding(.vertical, 4)
                    .background(Capsule().fill(accentGradient))
                    
                    Spacer()
                    
                    Text(entry.timeRange.headerLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                }

                // Top section: Time Distribution
                HStack(spacing: 16) {
                    // Donut chart
                    if entry.categoryStats.isEmpty {
                        ZStack {
                            Circle()
                                .stroke(secondaryTextColor.opacity(0.2), lineWidth: 10)
                                .frame(width: donutSize, height: donutSize)
                            Image(systemName: "clock")
                                .font(.system(size: 24))
                                .foregroundColor(secondaryTextColor.opacity(0.5))
                        }
                    } else {
                        ZStack {
                            MiniDonutChart(stats: entry.categoryStats, size: donutSize)
                            VStack(spacing: 0) {
                                DonutCenterValueText(text: formatHours(entry.totalHours), maxWidth: donutSize * 0.58, textColor: textColor)
                            }
                        }
                        .frame(width: donutSize, height: donutSize)
                    }

                    // Category list
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "Time Distribution"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(primaryColor)

                        if entry.categoryStats.isEmpty {
                            Text(String(localized: "No time tracked"))
                                .font(.system(size: 11))
                                .foregroundColor(secondaryTextColor)
                        } else {
                            ForEach(Array(entry.categoryStats.sorted { $0.hours > $1.hours }.prefix(5)), id: \.name) { stat in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color(hex: stat.color))
                                        .frame(width: 8, height: 8)
                                    Text(stat.name)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(textColor)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(formatHours(stat.hours))
                                        .font(.system(size: 10))
                                        .foregroundColor(secondaryTextColor)
                                }
                            }
                            if entry.categoryStats.count > 5 {
                                Text(String(localized: "+ \(entry.categoryStats.count - 5) more"))
                                    .font(.system(size: 9))
                                    .foregroundColor(primaryColor)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()
                    .background(secondaryTextColor.opacity(0.2))

                // Bottom section: Completion Rate
                VStack(spacing: 8) {
                    HStack {
                        Text(String(localized: "Task Completion Rate"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(primaryColor)

                        Spacer()

                        Text(String(format: "%.0f%%", entry.overallCompletionRate * 100))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(textColor)
                    }

                    if entry.weeklyStats.isEmpty {
                        HStack {
                            Spacer()
                            Text(String(localized: "No data"))
                                .font(.system(size: 11))
                                .foregroundColor(secondaryTextColor)
                            Spacer()
                        }
                        .frame(height: max(72, chartHeight))
                    } else {
                        // Bar chart
                        let preferredBarWidth: CGFloat = entry.timeRange == .year ? 18 : 20
                        let minBarWidth: CGFloat = entry.timeRange == .year ? 10 : 12
                        let minSpacing: CGFloat = entry.timeRange == .year ? 4 : 6
                        let layout = completionBarLayout(
                            availableWidth: completionChartWidth,
                            barCount: entry.weeklyStats.count,
                            preferredBarWidth: preferredBarWidth,
                            minBarWidth: minBarWidth,
                            minSpacing: minSpacing
                        )

                        HStack(alignment: .bottom, spacing: layout.spacing) {
                            ForEach(entry.weeklyStats, id: \.day) { stat in
                                let totalHeight = chartHeight
                                let completedHeight = stat.totalTasks > 0 ? totalHeight * CGFloat(stat.completedTasks) / CGFloat(stat.totalTasks) : 0

                                VStack(spacing: 4) {
                                    ZStack(alignment: .bottom) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(secondaryTextColor.opacity(0.2))
                                            .frame(width: layout.barWidth, height: max(totalHeight, 2))

                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(primaryColor)
                                            .frame(width: layout.barWidth, height: completedHeight)
                                    }
                                    .frame(height: chartHeight)

                                    Text(completionLabel(for: stat, compact: true))
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(secondaryTextColor)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.6)
                                        .frame(width: layout.barWidth)
                                }
                                .frame(width: layout.barWidth)
                            }
                        }
                        .frame(width: completionChartWidth, height: chartHeight + 14, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Legend
                        HStack(spacing: 16) {
                            let totalCompleted = entry.weeklyStats.reduce(0) { $0 + $1.completedTasks }
                            let totalTasks = entry.weeklyStats.reduce(0) { $0 + $1.totalTasks }

                            HStack(spacing: 4) {
                                Circle()
                                    .fill(primaryColor)
                                    .frame(width: 8, height: 8)
                                Text("\(totalCompleted) " + String(localized: "done"))
                                    .font(.system(size: 10))
                                    .foregroundColor(secondaryTextColor)
                            }

                            HStack(spacing: 4) {
                                Circle()
                                    .fill(secondaryTextColor.opacity(0.3))
                                    .frame(width: 8, height: 8)
                                Text("\(totalTasks) " + String(localized: "total"))
                                    .font(.system(size: 10))
                                    .foregroundColor(secondaryTextColor)
                            }

                            Spacer()
                        }
                        .frame(height: 16)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .padding(padding)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
    }

    @ViewBuilder
    private var combinedCompactView: some View {
        switch family {
        case .systemSmall:
            VStack(spacing: 10) {
                timeDistributionView
                Divider().background(secondaryTextColor.opacity(0.2))
                completionRateView
            }
        default:
            HStack(spacing: 10) {
                timeDistributionView
                Divider().background(secondaryTextColor.opacity(0.2))
                completionRateView
            }
        }
    }

    private var largeTimeDistributionOnlyView: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10, weight: .semibold))
                    Text(String(localized: "Time Distribution"))
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Capsule().fill(accentGradient))
                
                Spacer()
                
                Text(entry.timeRange.headerLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(secondaryTextColor)
            }
            
            if entry.categoryStats.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "chart.pie")
                        .font(.system(size: 48))
                        .foregroundStyle(accentGradient)
                    Text(String(localized: "No time tracked"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                }
                Spacer()
            } else {
                HStack(spacing: 20) {
                    // Large donut chart
                    ZStack {
                        MiniDonutChart(stats: entry.categoryStats, size: 140)
                        VStack(spacing: 2) {
                            DonutCenterValueText(text: formatHours(entry.totalHours), maxWidth: 140 * 0.58, textColor: textColor)
                            Text(String(localized: "total"))
                                .font(.system(size: 11))
                                .foregroundColor(secondaryTextColor)
                        }
                    }
                    .frame(width: 140, height: 140)
                    
                    // Full category list
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(entry.categoryStats.sorted { $0.hours > $1.hours }.enumerated()), id: \.element.name) { index, stat in
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(hex: stat.color))
                                    .frame(width: 4, height: 28)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(stat.name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(textColor)
                                        .lineLimit(1)
                                    Text(formatHours(stat.hours))
                                        .font(.system(size: 11))
                                        .foregroundColor(secondaryTextColor)
                                }
                                
                                Spacer()
                                
                                Text(String(format: "%.0f%%", (stat.hours / max(entry.totalHours, 0.01)) * 100))
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(hex: stat.color))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(14)
    }

    private var largeCompletionRateOnlyView: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle")
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
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(primaryColor)
            }
            
            if entry.weeklyStats.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 48))
                        .foregroundStyle(accentGradient)
                    Text(String(localized: "No tasks completed"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                }
                Spacer()
            } else {
                let chartHeight: CGFloat = 140
                let barBlockHeight: CGFloat = chartHeight + 34

                GeometryReader { geo in
                    let preferredBarWidth: CGFloat = entry.timeRange == .year ? 18 : 22
                    let minBarWidth: CGFloat = entry.timeRange == .year ? 10 : 12
                    let minSpacing: CGFloat = entry.timeRange == .year ? 4 : 6
                    let layout = completionBarLayout(
                        availableWidth: geo.size.width,
                        barCount: entry.weeklyStats.count,
                        preferredBarWidth: preferredBarWidth,
                        minBarWidth: minBarWidth,
                        minSpacing: minSpacing
                    )

                    HStack(alignment: .bottom, spacing: layout.spacing) {
                        ForEach(entry.weeklyStats, id: \.day) { stat in
                            let totalHeight = chartHeight
                            let completedHeight = stat.totalTasks > 0 ? totalHeight * CGFloat(stat.completedTasks) / CGFloat(stat.totalTasks) : 0

                            VStack(spacing: 6) {
                                Text("\(stat.completedTasks)/\(stat.totalTasks)")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(secondaryTextColor)

                                ZStack(alignment: .bottom) {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(secondaryTextColor.opacity(0.2))
                                        .frame(width: layout.barWidth, height: max(totalHeight, 4))

                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(accentGradient)
                                        .frame(width: layout.barWidth, height: completedHeight)
                                }
                                .frame(height: chartHeight)

                                Text(completionLabel(for: stat, compact: true))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(textColor)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                    .frame(width: layout.barWidth)
                            }
                            .frame(width: layout.barWidth)
                        }
                    }
                    .frame(width: geo.size.width, height: barBlockHeight, alignment: .leading)
                }
                .frame(height: barBlockHeight)
                
                // Legend
                HStack(spacing: 20) {
                    let totalCompleted = entry.weeklyStats.reduce(0) { $0 + $1.completedTasks }
                    let totalTasks = entry.weeklyStats.reduce(0) { $0 + $1.totalTasks }
                    
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(accentGradient)
                            .frame(width: 16, height: 10)
                        Text("\(totalCompleted) " + String(localized: "completed"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(textColor)
                    }
                    
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(secondaryTextColor.opacity(0.3))
                            .frame(width: 16, height: 10)
                        Text("\(totalTasks) " + String(localized: "total"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(secondaryTextColor)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(14)
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
        GeometryReader { geo in
            let chartHeight = max(54, min(90, geo.size.height * 0.52))
            let barAreaWidth = max(0, geo.size.width - 24)
            let preferredBarWidth: CGFloat = entry.weeklyStats.count > 7 ? 9 : 12
            let minBarWidth: CGFloat = entry.weeklyStats.count > 7 ? 4 : 6
            let minSpacing: CGFloat = entry.weeklyStats.count > 7 ? 2 : 3
            let layout = completionBarLayout(
                availableWidth: barAreaWidth,
                barCount: entry.weeklyStats.count,
                preferredBarWidth: preferredBarWidth,
                minBarWidth: minBarWidth,
                minSpacing: minSpacing
            )

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
                    Spacer(minLength: 0)
                    VStack(spacing: 4) {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 24))
                            .foregroundStyle(accentGradient)
                        Text(String(localized: "No data"))
                            .font(.system(size: 11))
                            .foregroundColor(secondaryTextColor)
                    }
                    Spacer(minLength: 0)
                } else {
                    Spacer(minLength: 0)

                    HStack(alignment: .bottom, spacing: layout.spacing) {
                        ForEach(entry.weeklyStats, id: \.day) { stat in
                            let totalHeight = chartHeight
                            let completedHeight = stat.totalTasks > 0 ? totalHeight * CGFloat(stat.completedTasks) / CGFloat(stat.totalTasks) : 0

                            VStack(spacing: 3) {
                                ZStack(alignment: .bottom) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(secondaryTextColor.opacity(0.2))
                                        .frame(width: layout.barWidth, height: max(totalHeight, 2))
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(primaryColor)
                                        .frame(width: layout.barWidth, height: completedHeight)
                                }
                                .frame(height: chartHeight)

                                Text(completionLabel(for: stat, compact: true))
                                    .font(.system(size: 7, weight: .medium))
                                    .foregroundColor(secondaryTextColor)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .frame(width: layout.barWidth)
                            }
                            .frame(width: layout.barWidth)
                        }
                    }
                    .frame(width: barAreaWidth, height: chartHeight + 12, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

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
                        Spacer()
                    }
                }
            }
            .padding(12)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
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
                Text(String(localized: "No data"))
                    .font(.system(size: 11))
                    .foregroundColor(secondaryTextColor)
                Spacer()
            } else {
                // Bar chart
                let barAreaHeight: CGFloat = 68
                GeometryReader { geo in
                    let preferredBarWidth: CGFloat = 20
                    let minBarWidth: CGFloat = 10
                    let minSpacing: CGFloat = 4
                    let layout = completionBarLayout(
                        availableWidth: geo.size.width,
                        barCount: entry.weeklyStats.count,
                        preferredBarWidth: preferredBarWidth,
                        minBarWidth: minBarWidth,
                        minSpacing: minSpacing
                    )

                    HStack(alignment: .bottom, spacing: layout.spacing) {
                        ForEach(entry.weeklyStats, id: \.day) { stat in
                            let totalHeight = barAreaHeight
                            let completedHeight = stat.totalTasks > 0 ? totalHeight * CGFloat(stat.completedTasks) / CGFloat(stat.totalTasks) : 0

                            VStack(spacing: 4) {
                                ZStack(alignment: .bottom) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(secondaryTextColor.opacity(0.2))
                                        .frame(width: layout.barWidth, height: max(totalHeight, 2))

                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(primaryColor)
                                        .frame(width: layout.barWidth, height: completedHeight)
                                }
                                .frame(height: barAreaHeight)

                                Text(completionLabel(for: stat, compact: true))
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(secondaryTextColor)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                    .frame(width: layout.barWidth)
                            }
                            .frame(width: layout.barWidth)
                        }
                    }
                    .frame(width: geo.size.width, alignment: .leading)
                }
                .frame(height: barAreaHeight + 16)
                
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
                .padding(.top, 6)
            }
        }
        .padding(16)
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

private struct DonutCenterValueText: View {
    let text: String
    let maxWidth: CGFloat
    let textColor: Color

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(textColor)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: maxWidth)
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
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct PerformanceWidgetLarge: Widget {
    let kind: String = "PerformanceWidgetLarge"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: PerformanceWidgetLargeIntent.self, provider: PerformanceLargeProvider()) { entry in
            PerformanceWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(String(localized: "Performance"))
        .description(String(localized: "View your productivity statistics."))
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    PerformanceWidget()
} timeline: {
    PerformanceEntry(
        date: Date(),
        content: .timeDistribution,
        timeRange: .week,
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
        content: .completionRate,
        timeRange: .week,
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

#Preview(as: .systemLarge) {
    PerformanceWidget()
} timeline: {
    PerformanceEntry(
        date: Date(),
        content: .timeDistribution,
        timeRange: .week,
        categoryStats: [
            CategoryStatData(name: "Work", color: "#F59E0B", hours: 1.83),
            CategoryStatData(name: "Health", color: "#10B981", hours: 0.75),
            CategoryStatData(name: "Personal", color: "#EF4444", hours: 0.5)
        ],
        weeklyStats: [
            WeeklyStatData(day: "Thu", completedTasks: 3, totalTasks: 8, completionRate: 0.375),
            WeeklyStatData(day: "Fri", completedTasks: 2, totalTasks: 6, completionRate: 0.333),
            WeeklyStatData(day: "Sat", completedTasks: 1, totalTasks: 4, completionRate: 0.25),
            WeeklyStatData(day: "Sun", completedTasks: 0, totalTasks: 2, completionRate: 0.0),
            WeeklyStatData(day: "Mon", completedTasks: 5, totalTasks: 10, completionRate: 0.5),
            WeeklyStatData(day: "Tue", completedTasks: 4, totalTasks: 8, completionRate: 0.5),
            WeeklyStatData(day: "Wed", completedTasks: 3, totalTasks: 7, completionRate: 0.43)
        ],
        totalHours: 3.08,
        overallCompletionRate: 0.45
    )
}
