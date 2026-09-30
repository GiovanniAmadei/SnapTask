import SwiftUI

struct PointsHistoryView: View {
    @StateObject private var taskManager = TaskManager.shared
    @StateObject private var rewardManager = RewardManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var showingResetAlert = false
    @State private var selectedTasks = Set<UUID>()
    @State private var isEditMode = false
    @State private var showingRemoveSelectedAlert = false
    @State private var selectedTimeFilter: TimeFilter = .all
    
    enum TimeFilter: String, CaseIterable {
        case all = "All Time"
        case day = "Today"
        case week = "This Week"
        case month = "This Month"
        case year = "This Year"
        
        var icon: String {
            switch self {
            case .all: return "clock"
            case .day: return "sun.max"
            case .week: return "calendar.badge.clock"
            case .month: return "calendar"
            case .year: return "calendar.badge.plus"
            }
        }
        
        var color: Color {
            switch self {
            case .all: return Color(hex: "5E5CE6")
            case .day: return Color(hex: "FF6B6B")
            case .week: return Color(hex: "4ECDC4")
            case .month: return Color(hex: "45B7D1")
            case .year: return Color(hex: "FFD700")
            }
        }
        
        var localizedName: String {
            switch self {
            case .all: return "all_time".localized
            case .day: return "today".localized
            case .week: return "this_week".localized
            case .month: return "this_month".localized
            case .year: return "this_year".localized
            }
        }
    }
    
    private var filteredPointsEarningTasks: [(TodoTask, [Date])] {
        let allTasks = taskManager.tasks.filter { $0.hasRewardPoints }
        let filtered = allTasks.compactMap { task -> (TodoTask, [Date])? in
            let filteredDates = task.completionDates.filter { date in
                guard task.hasRewardPoints else { return false }
                return dateMatchesFilter(date, filter: selectedTimeFilter)
            }
            return filteredDates.isEmpty ? nil : (task, filteredDates)
        }
        
        // Sort by most recent completion date
        return filtered.sorted { first, second in
            let firstLatest = first.1.max() ?? Date.distantPast
            let secondLatest = second.1.max() ?? Date.distantPast
            return firstLatest > secondLatest
        }
    }
    
    private var filteredTotalPoints: Int {
        filteredPointsEarningTasks.reduce(0) { total, taskData in
            let (task, dates) = taskData
            return total + (dates.count * task.rewardPoints)
        }
    }
    
    private func dateMatchesFilter(_ date: Date, filter: TimeFilter) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        switch filter {
        case .all:
            return true
        case .day:
            return calendar.isDate(date, inSameDayAs: now)
        case .week:
            return calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear)
        case .month:
            return calendar.isDate(date, equalTo: now, toGranularity: .month)
        case .year:
            return calendar.isDate(date, equalTo: now, toGranularity: .year)
        }
    }
    
    private var shortLabel: (TimeFilter) -> String {
        { filter in
            switch filter {
            case .all: return RewardPeriodLabel.all.localized
            case .day: return RewardPeriodLabel.day.localized
            case .week: return RewardPeriodLabel.week.localized
            case .month: return RewardPeriodLabel.month.localized
            case .year: return RewardPeriodLabel.year.localized
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    StatsSegmentedControl(options: TimeFilter.allCases, selection: $selectedTimeFilter, label: shortLabel)

                    HStack(spacing: 10) {
                        StatTile(value: "+" + filteredTotalPoints.formatted(), label: "rewards_points_earned".localized,
                                 systemImage: "plus.circle.fill", tint: .green)
                        StatTile(value: filteredPointsEarningTasks.reduce(0) { $0 + $1.1.count }.formatted(),
                                 label: "stats_completed".localized, systemImage: "checkmark.circle.fill", tint: theme.primaryColor)
                    }

                    if filteredPointsEarningTasks.isEmpty {
                        StatsEmptyState(systemImage: selectedTimeFilter.icon,
                                        title: "no_points_for".localized.replacingOccurrences(of: "{period}", with: selectedTimeFilter.localizedName),
                                        message: "complete_tasks_points_enabled".localized)
                            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(theme.surfaceColor))
                    } else {
                        ForEach(filteredPointsEarningTasks, id: \.0.id) { task, dates in
                            TaskPointsCard(
                                task: task,
                                completionDates: dates,
                                isSelected: selectedTasks.contains(task.id),
                                isEditMode: isEditMode,
                                onSelectionChanged: { isSelected in
                                    if isSelected { selectedTasks.insert(task.id) } else { selectedTasks.remove(task.id) }
                                }
                            )
                        }
                    }
                }
                .padding(16)
            }
            .themedBackground()
            .navigationTitle("rewards_history_short".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // One control per side so the title never gets truncated.
                ToolbarItem(placement: .navigationBarLeading) {
                    if isEditMode {
                        Button("cancel".localized) {
                            withAnimation { isEditMode = false; selectedTasks.removeAll() }
                        }
                    } else {
                        Menu {
                            if !filteredPointsEarningTasks.isEmpty {
                                Button { withAnimation { isEditMode = true } } label: {
                                    Label("edit".localized, systemImage: "checkmark.circle")
                                }
                            }
                            Button { rewardManager.recalculatePointsFromTasks() } label: {
                                Label("recalculate_from_tasks".localized, systemImage: "arrow.clockwise")
                            }
                            Button(role: .destructive) { showingResetAlert = true } label: {
                                Label("reset_all_points".localized, systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isEditMode {
                        Button("remove".localized, role: .destructive) { showingRemoveSelectedAlert = true }
                            .foregroundColor(.red)
                            .disabled(selectedTasks.isEmpty)
                    } else {
                        Button("done".localized) { dismiss() }
                    }
                }
            }
            .alert("reset_all_points".localized, isPresented: $showingResetAlert) {
                Button("cancel".localized, role: .cancel) { }
                Button("reset".localized, role: .destructive) {
                    rewardManager.resetAllPoints()
                }
            } message: {
                Text("reset_all_points_alert".localized)
            }
            .alert("remove_selected_points".localized, isPresented: $showingRemoveSelectedAlert) {
                Button("cancel".localized, role: .cancel) { }
                Button("remove".localized, role: .destructive) {
                    for taskId in selectedTasks {
                        if let task = taskManager.tasks.first(where: { $0.id == taskId }) {
                            rewardManager.removePointsFromTask(task)
                        }
                    }
                    selectedTasks.removeAll()
                    isEditMode = false
                }
            } message: {
                Text("remove_selected_alert".localized)
            }
        }
    }
    
}

struct TaskPointsCard: View {
    let task: TodoTask
    let completionDates: [Date]
    let isSelected: Bool
    let isEditMode: Bool
    let onSelectionChanged: (Bool) -> Void
    @Environment(\.theme) private var theme

    private var tint: Color { task.category.map { Color(hex: $0.color) } ?? theme.primaryColor }
    private var icon: String {
        (task.icon.isEmpty || task.icon == "circle") ? (task.category?.icon ?? "checkmark.circle") : task.icon
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if isEditMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? theme.primaryColor : theme.secondaryTextColor.opacity(0.5))
                    .padding(.top, 10)
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    CategoryIconTile(icon: icon, color: tint, size: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(task.name)
                            .font(.headline)
                            .lineLimit(1)
                            .themedPrimaryText()
                        Text("\(task.rewardPoints) " + "points_per_completion".localized)
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .themedSecondaryText()
                    }
                    Spacer(minLength: 6)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("+" + (completionDates.count * task.rewardPoints).formatted())
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .monospacedDigit()
                            .foregroundColor(.green)
                        Text("\(completionDates.count)×")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .themedSecondaryText()
                    }
                }
                if completionDates.count > 1 {
                    DateChipsGrid(dates: completionDates.sorted(by: >), color: tint, limit: 6)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(theme.surfaceColor))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(isSelected ? theme.primaryColor : .clear, lineWidth: 2))
        .contentShape(Rectangle())
        .onTapGesture { if isEditMode { onSelectionChanged(!isSelected) } }
    }
}

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}