import SwiftUI

enum HistoryTimeFilter: String, CaseIterable {
    case day = "Day"
    case week = "Week" 
    case month = "Month"
    case year = "Year"
    
    var localizedName: String {
        switch self {
        case .day: return "today".localized
        case .week: return "week".localized
        case .month: return "month".localized
        case .year: return "year".localized
        }
    }
    
    var icon: String {
        switch self {
        case .day: return "sun.max.fill"
        case .week: return "calendar.badge.clock"
        case .month: return "calendar"
        case .year: return "calendar.badge.exclamationmark"
        }
    }
    
    var color: Color {
        switch self {
        case .day: return Color(hex: "FF6B6B")
        case .week: return Color(hex: "4ECDC4")
        case .month: return Color(hex: "45B7D1")
        case .year: return Color(hex: "FFD700")
        }
    }
}

struct TaskPointsHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @StateObject private var taskManager = TaskManager.shared
    @StateObject private var rewardManager = RewardManager.shared
    @State private var selectedFilter: HistoryTimeFilter = .week
    @State private var selectedTasks = Set<UUID>()
    @State private var isEditMode = false
    @State private var showingRemoveSelectedAlert = false
    
    private var filteredPointsEarningTasks: [(TodoTask, [Date])] {
        let allTasks = taskManager.tasks.filter { $0.hasRewardPoints }
        let filtered = allTasks.compactMap { task -> (TodoTask, [Date])? in
            let filteredDates = task.completionDates.filter { date in
                task.hasRewardPoints && isDateInFilter(date, filter: selectedFilter)
            }
            return filteredDates.isEmpty ? nil : (task, filteredDates)
        }
        
        return filtered.sorted { first, second in
            let firstLatest = first.1.max() ?? Date.distantPast
            let secondLatest = second.1.max() ?? Date.distantPast
            return firstLatest > secondLatest
        }
    }
    
    private var totalFilteredPoints: Int {
        filteredPointsEarningTasks.reduce(0) { total, taskData in
            let (task, dates) = taskData
            return total + (dates.count * task.rewardPoints)
        }
    }
    
    private var statsForCurrentFilter: (totalTasks: Int, totalCompletions: Int, averagePerDay: Double) {
        let totalTasks = filteredPointsEarningTasks.count
        let totalCompletions = filteredPointsEarningTasks.reduce(0) { $0 + $1.1.count }
        
        let daysDivisor: Double
        switch selectedFilter {
        case .day: daysDivisor = 1
        case .week: daysDivisor = 7
        case .month: daysDivisor = 30
        case .year: daysDivisor = 365
        }
        
        let averagePerDay = totalCompletions > 0 ? Double(totalCompletions) / daysDivisor : 0
        
        return (totalTasks, totalCompletions, averagePerDay)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter selector
                filterSelectorView
                
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Stats header for selected period
                        if !filteredPointsEarningTasks.isEmpty {
                            statsHeaderView
                        }
                        
                        if filteredPointsEarningTasks.isEmpty {
                            emptyStateView
                        } else {
                            ForEach(filteredPointsEarningTasks, id: \.0.id) { task, dates in
                                TaskPointsCard(
                                    task: task,
                                    completionDates: dates,
                                    isSelected: selectedTasks.contains(task.id),
                                    isEditMode: isEditMode,
                                    onSelectionChanged: { isSelected in
                                        if isSelected {
                                            selectedTasks.insert(task.id)
                                        } else {
                                            selectedTasks.remove(task.id)
                                        }
                                    }
                                )
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
            .themedBackground()
            .navigationTitle("points_history".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !filteredPointsEarningTasks.isEmpty {
                        Button(isEditMode ? "cancel".localized : "edit".localized) {
                            withAnimation {
                                isEditMode.toggle()
                                if !isEditMode {
                                    selectedTasks.removeAll()
                                }
                            }
                        }
                        .themedPrimary()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if isEditMode && !selectedTasks.isEmpty {
                            Button("remove_selected".localized) {
                                showingRemoveSelectedAlert = true
                            }
                            .foregroundColor(.red)
                        }
                        
                        Button("done".localized) {
                            dismiss()
                        }
                        .themedPrimary()
                    }
                }
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
    
    private var filterSelectorView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ForEach(HistoryTimeFilter.allCases, id: \.self) { filter in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter
                        }
                    }) {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(selectedFilter == filter ? filter.color : theme.surfaceColor)
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(selectedFilter == filter ? Color.clear : theme.borderColor, lineWidth: 1)
                                    )
                                
                                Image(systemName: filter.icon)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(selectedFilter == filter ? .white : theme.secondaryTextColor)
                            }
                            
                            Text(filter.localizedName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(selectedFilter == filter ? filter.color : theme.secondaryTextColor)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.surfaceColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(theme.borderColor, lineWidth: 1)
                    )
            )
            .shadow(color: theme.shadowColor, radius: 4, x: 0, y: 2)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private var statsHeaderView: some View {
        let stats = statsForCurrentFilter
        
        return VStack(spacing: 16) {
            HStack {
                Text("stats_for".localized + " \(selectedFilter.localizedName)")
                    .font(.system(size: 16, weight: .semibold))
                    .themedPrimaryText()
                
                Spacer()
                
                Text("$\(totalFilteredPoints) pts")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(selectedFilter.color)
            }
            
            HStack(spacing: 16) {
                TaskHistoryStatCard(
                    title: "tasks".localized,
                    value: "\(stats.totalTasks)",
                    icon: "list.bullet",
                    color: selectedFilter.color
                )
                
                TaskHistoryStatCard(
                    title: "completions".localized,
                    value: "\(stats.totalCompletions)",
                    icon: "checkmark.circle.fill",
                    color: selectedFilter.color
                )
                
                TaskHistoryStatCard(
                    title: "avg_day".localized,
                    value: String(format: "%.1f", stats.averagePerDay),
                    icon: "clock.fill",
                    color: selectedFilter.color
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(selectedFilter.color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(selectedFilter.color.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(selectedFilter.color.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: selectedFilter.icon)
                    .font(.system(size: 32))
                    .foregroundColor(selectedFilter.color)
            }
            
            VStack(spacing: 8) {
                Text("no_points_this".localized + " \(selectedFilter.localizedName)")
                    .font(.system(size: 18, weight: .semibold))
                    .themedPrimaryText()
                
                Text("complete_tasks_points_enabled".localized)
                    .font(.system(size: 14))
                    .themedSecondaryText()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .padding(.vertical, 60)
        .frame(maxWidth: .infinity)
    }
    
    private func isDateInFilter(_ date: Date, filter: HistoryTimeFilter) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        switch filter {
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
}

struct TaskHistoryStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .themedSecondaryText()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.surfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct TaskPointsHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        TaskPointsHistoryView()
    }
}