import SwiftUI
import Charts

struct MoodTrendCard: View {
    @ObservedObject private var moodManager = MoodManager.shared
    @Environment(\.theme) private var theme
    @State private var showingMoodSelector = false
    @State private var selectedTimeRange: StatisticsViewModel.TimeRange = .week

    struct MoodPoint: Identifiable, Equatable {
        let id = UUID()
        let date: Date
        let score: Int
    }

    var body: some View {
        let points = actualMoodPoints
        let changes = changePoints

        return VStack(spacing: 16) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("mood_trend".localized)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .themedPrimaryText()
                    
                    if let avg = averageScore {
                        Text("average".localized + ": \(String(format: "%.1f", avg)) \(averageEmoji)")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .themedSecondaryText()
                    }
                }
                
                Spacer()
                
                Button(action: { showingMoodSelector = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("add".localized)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(theme.accentColor)
                    )
                }
                .sheet(isPresented: $showingMoodSelector) {
                    MoodSelectionView(date: Date())
                }
            }
            
            // Time Range Selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    TimeRangeButton(title: "week".localized, isSelected: selectedTimeRange == .week) {
                        selectedTimeRange = .week
                    }
                    TimeRangeButton(title: "month".localized, isSelected: selectedTimeRange == .month) {
                        selectedTimeRange = .month
                    }
                    TimeRangeButton(title: "year".localized, isSelected: selectedTimeRange == .year) {
                        selectedTimeRange = .year
                    }
                    TimeRangeButton(title: "all_time".localized, isSelected: selectedTimeRange == .allTime) {
                        selectedTimeRange = .allTime
                    }
                }
            }

            // Chart or empty state
            if points.count >= 1 {
                VStack(spacing: 12) {
                    // Aumentiamo l'altezza del grafico per evitare il taglio delle emoji
                    MoodChart(points: points, changes: changes, timeRange: selectedTimeRange)
                        .frame(height: 280)
                        .padding(.top, 20)
                    
                    // Info bar compatta
                    HStack {
                        if let last = lastInRange {
                            HStack(spacing: 4) {
                                Text(last.emoji)
                                    .font(.system(size: 14))
                                Text("last".localized + ": \(last.italianName)")
                                    .font(.system(.caption2, design: .rounded, weight: .medium))
                                    .themedSecondaryText()
                            }
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                                .themedSecondaryText()
                            Text("\(recordedDaysCount) " + "days".localized)
                                .font(.system(.caption2, design: .rounded, weight: .medium))
                                .themedSecondaryText()
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 32))
                        .themedSecondaryText()
                        .padding(.top, 20)
                    
                    Text("add_mood_to_see_trend".localized)
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .themedSecondaryText()
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                    
                    Spacer()
                }
                .frame(height: 160) // Altezza fissa per l'empty state
            }
        }
        .padding(16) // Ridotto da 18 a 16 per dare più spazio interno
        .background(cardBackground)
        .onAppear {
            // Debug info
            print("🔍 MoodTrendCard Debug:")
            print("   Selected range: \(selectedTimeRange.rawValue)")
            print("   Mood range dates: \(moodRange.start) to \(moodRange.end)")
            print("   Total entries in manager: \(moodManager.entries.count)")
            print("   Entries in range: \(recordedDaysCount)")
            print("   Actual points: \(points.count)")
            for point in points {
                print("     Point: \(point.date) - Score: \(point.score)")
            }
        }
    }

    private var range: (start: Date, end: Date) {
        selectedTimeRange.dateRange
    }

    private var moodRange: (start: Date, end: Date) {
        selectedTimeRange.dateRange
    }

    // Use the mood range instead of the general range
    private var actualMoodPoints: [MoodPoint] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: moodRange.start)
        let end = cal.startOfDay(for: moodRange.end)
        
        return moodManager.entries
            .filter { $0.key >= start && $0.key <= end }
            .map { MoodPoint(date: $0.key, score: $0.value.type.score) }
            .sorted { $0.date < $1.date }
    }

    private var dailyDates: [Date] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: range.start)
        let end = cal.startOfDay(for: range.end)
        var dates: [Date] = []
        var current = start
        while current <= end {
            dates.append(current)
            guard let next = cal.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
            if dates.count > 1000 { break }
        }
        return dates
    }

    private var dailyPoints: [MoodPoint] {
        let cal = Calendar.current
        var points: [MoodPoint] = []
        var lastKnown: MoodType? = lastKnownMood(beforeOrEqual: cal.startOfDay(for: range.start))

        for day in dailyDates {
            if let todayType = moodManager.entries[day]?.type {
                lastKnown = todayType
            }
            if let lastKnown {
                points.append(MoodPoint(date: day, score: lastKnown.score))
            }
        }
        return points
    }

    private var changePoints: [MoodPoint] {
        let points = actualMoodPoints
        guard !points.isEmpty else { return [] }
        var result: [MoodPoint] = []
        for i in 1..<points.count {
            if points[i].score != points[i-1].score {
                result.append(points[i])
            }
        }
        if result.isEmpty, let first = points.first {
            return [first]
        }
        return result
    }

    private var averageScore: Double? {
        let points = actualMoodPoints
        guard !points.isEmpty else { return nil }
        let sum = points.reduce(0) { $0 + $1.score }
        return Double(sum) / Double(points.count)
    }

    private var averageEmoji: String {
        guard let avg = averageScore else { return "🙂" }
        let rounded = Int(round(avg))
        switch rounded {
        case 1: return "😫"
        case 2: return "😕"
        case 3: return "🙁"
        case 4: return "😐"
        case 5: return "🙂"
        case 6: return "😄"
        default: return "🤩"
        }
    }

    private var recordedDaysCount: Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: moodRange.start)
        let end = cal.startOfDay(for: moodRange.end)
        return moodManager.entries.filter { $0.key >= start && $0.key <= end }.count
    }

    private var lastInRange: MoodType? {
        let cal = Calendar.current
        let start = cal.startOfDay(for: moodRange.start)
        let end = cal.startOfDay(for: moodRange.end)
        let items = moodManager.entries
            .filter { $0.key >= start && $0.key <= end }
            .sorted(by: { $0.key < $1.key })
        return items.last?.value.type
    }

    private var firstEntryInRange: MoodEntry? {
        let cal = Calendar.current
        let start = cal.startOfDay(for: range.start)
        let end = cal.startOfDay(for: range.end)
        return moodManager.entries
            .filter { $0.key >= start && $0.key <= end }
            .sorted(by: { $0.key < $1.key })
            .first?.value
    }

    private func lastKnownMood(beforeOrEqual date: Date) -> MoodType? {
        let items = moodManager.entries
            .filter { $0.key <= date }
            .sorted(by: { $0.key < $1.key })
        return items.last?.value.type
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(theme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(theme.borderColor, lineWidth: 1)
            )
            .shadow(color: theme.shadowColor, radius: 4, x: 0, y: 2)
    }
}

private struct MoodChart: View {
    let points: [MoodTrendCard.MoodPoint]
    let changes: [MoodTrendCard.MoodPoint]
    let timeRange: StatisticsViewModel.TimeRange
    @Environment(\.theme) private var theme

    var body: some View {
        // Add a bit of headroom so annotations at the top aren't clipped
        let maxY = (points.map { Double($0.score) }.max() ?? 7.0) + 0.6
        let minY = 0.8

        Chart {
            // Neutral guideline
            RuleMark(y: .value("neutral".localized, 4.0))
                .foregroundStyle(theme.secondaryTextColor.opacity(0.2))
                .lineStyle(.init(lineWidth: 1, dash: [5, 3]))

            // Area fill under the line (same interpolation and aligned base)
            ForEach(points) { p in
                AreaMark(
                    x: .value("Data", p.date),
                    yStart: .value("Base", minY),
                    yEnd: .value("Umore", Double(p.score))
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            theme.accentColor.opacity(0.45),
                            theme.accentColor.opacity(0.08)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            // Main line
            ForEach(points) { p in
                LineMark(
                    x: .value("Data", p.date),
                    y: .value("Umore", Double(p.score))
                )
                .lineStyle(.init(lineWidth: 3, lineCap: .round))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(theme.accentColor)
            }

            // Points with emoji annotations
            ForEach(changes.prefix(5)) { p in
                PointMark(
                    x: .value("Data", p.date),
                    y: .value("Umore", Double(p.score))
                )
                .symbol(.circle)
                .symbolSize(60)
                .foregroundStyle(theme.accentColor)
                .annotation(position: .top, spacing: 8) {
                    Text(emoji(for: p.score))
                        .font(.system(size: 16))
                        .background(
                            Circle()
                                .fill(theme.cardBackground)
                                .frame(width: 24, height: 24)
                        )
                }
            }
        }
        .chartYScale(domain: minY...maxY)
        .chartXAxis {
            AxisMarks(values: xAxisValues(for: timeRange)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(theme.borderColor.opacity(0.2))
                AxisValueLabel() {
                    if let d = value.as(Date.self) {
                        Text(formatDateForChart(d, range: timeRange))
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                            .themedSecondaryText()
                    }
                }
            }
        }
        .chartYAxis(.hidden) // Nascondiamo l'asse Y che non serve
        .chartPlotStyle { plotArea in
            plotArea
                .background(theme.surfaceColor.opacity(0.3))
        }
    }

    private func emoji(for score: Int) -> String {
        switch score {
        case 1: return "😫"
        case 2: return "😕"
        case 3: return "🙁"
        case 4: return "😐"
        case 5: return "🙂"
        case 6: return "😄"
        default: return "🤩"
        }
    }

    private func xAxisValues(for range: StatisticsViewModel.TimeRange) -> AxisMarkValues {
        switch range {
        case .today: return .automatic(desiredCount: 1)
        case .week: return .automatic(desiredCount: 4) // 4 date per la settimana
        case .month: return .stride(by: .day, count: 7)
        case .year: return .stride(by: .month, count: 2)
        case .allTime: return .stride(by: .month, count: 3) // Mostra ogni 3 mesi
        }
    }

    private func formatDateForChart(_ date: Date, range: StatisticsViewModel.TimeRange) -> String {
        let formatter = DateFormatter()
        switch range {
        case .today, .week: 
            formatter.dateFormat = "dd/MM" // Formato corto e dritto
        case .month: 
            formatter.dateFormat = "dd MMM"
        case .year: 
            formatter.dateFormat = "MMM"
        case .allTime:
            formatter.dateFormat = "MMM yy" // Mese e anno abbreviato
        }
        return formatter.string(from: date)
    }
}

private struct ChipView: View {
    let icon: String
    let text: String
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 4) {
            Text(icon)
                .font(.system(size: 12))
            Text(text)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .themedPrimaryText()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(theme.surfaceColor)
                .overlay(
                    Capsule()
                        .stroke(theme.borderColor, lineWidth: 1)
                )
        )
    }
}

private struct TimeRangeButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.theme) private var theme
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundColor(isSelected ? .white : theme.primaryColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? theme.accentColor : theme.surfaceColor)
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? Color.clear : theme.borderColor, lineWidth: 1)
                        )
                )
        }
    }
}
