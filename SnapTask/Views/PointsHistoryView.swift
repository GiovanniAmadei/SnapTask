import SwiftUI

struct PointsHistoryView: View {
    @StateObject private var taskManager = TaskManager.shared
    @StateObject private var rewardManager = RewardManager.shared
    @Environment(\.dismiss) private var dismiss
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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Time Filter Section
                timeFilterSection
                
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Total Points Header - integrated into the scroll view
                        if !filteredPointsEarningTasks.isEmpty {
                            filteredPointsHeader
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
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
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
                        
                        if !isEditMode {
                            Menu {
                                Button("reset_all_points".localized, role: .destructive) {
                                    showingResetAlert = true
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                        
                        Button("done".localized) {
                            dismiss()
                        }
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
    
    private var timeFilterSection: some View {
        VStack(spacing: 16) {
            // Header with title and count
            HStack {
                Text("points_history".localized)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(filteredPointsEarningTasks.count) \(filteredPointsEarningTasks.count == 1 ? "entry".localized : "entries".localized)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.tertiarySystemGroupedBackground))
                    )
            }
            
            // Single row - NO GRID, NO VSTACK
            HStack(spacing: 6) {
                TimeFilterChip(filter: .all, isSelected: selectedTimeFilter == .all) {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTimeFilter = .all }
                }
                TimeFilterChip(filter: .day, isSelected: selectedTimeFilter == .day) {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTimeFilter = .day }
                }
                TimeFilterChip(filter: .week, isSelected: selectedTimeFilter == .week) {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTimeFilter = .week }
                }
                TimeFilterChip(filter: .month, isSelected: selectedTimeFilter == .month) {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTimeFilter = .month }
                }
                TimeFilterChip(filter: .year, isSelected: selectedTimeFilter == .year) {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTimeFilter = .year }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private var filteredPointsHeader: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(
                    colors: [selectedTimeFilter.color, selectedTimeFilter.color.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .shadow(color: selectedTimeFilter.color.opacity(0.3), radius: 8, x: 0, y: 4)
            
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(selectedTimeFilter.localizedName) " + "points".localized)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text("\(filteredTotalPoints)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: selectedTimeFilter.icon)
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
            }
            .padding(20)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(selectedTimeFilter.color.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: selectedTimeFilter.icon)
                    .font(.system(size: 40))
                    .foregroundColor(selectedTimeFilter.color)
            }
            
            VStack(spacing: 8) {
                Text("no_points_for".localized.replacingOccurrences(of: "{period}", with: selectedTimeFilter.localizedName))
                    .font(.system(size: 18, weight: .semibold))
                
                Text("complete_tasks_points_enabled".localized)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct TimeFilterChip: View {
    let filter: PointsHistoryView.TimeFilter
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(compactTitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? filter.color : Color(UIColor.tertiarySystemGroupedBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    isSelected ? Color.clear : filter.color.opacity(0.3),
                                    lineWidth: 1
                                )
                        )
                )
                .shadow(color: isSelected ? filter.color.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 2)
                .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
    
    private var compactTitle: String {
        switch filter {
        case .all: return "sempre".localized
        case .day: return "today".localized
        case .week: return "settimana".localized
        case .month: return "mese".localized 
        case .year: return "anno".localized
        }
    }
}

struct TaskPointsCard: View {
    let task: TodoTask
    let completionDates: [Date]
    let isSelected: Bool
    let isEditMode: Bool
    let onSelectionChanged: (Bool) -> Void
    
    private var totalPointsEarned: Int {
        completionDates.count * task.rewardPoints
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection circle in edit mode
            if isEditMode {
                Button(action: {
                    onSelectionChanged(!isSelected)
                }) {
                    ZStack {
                        Circle()
                            .strokeBorder(isSelected ? Color(hex: "5E5CE6") : Color.gray.opacity(0.3), lineWidth: 2)
                            .frame(width: 24, height: 24)
                        
                        if isSelected {
                            Circle()
                                .fill(Color(hex: "5E5CE6"))
                                .frame(width: 16, height: 16)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color(hex: "5E5CE6"), Color(hex: "9747FF")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: task.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.name)
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text("\(task.rewardPoints) " + "points_per_completion".localized)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("+\(totalPointsEarned)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color(hex: "00C853"))
                        
                        Text("\(completionDates.count) " + "times".localized)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                if completionDates.count > 1 {
                    HStack {
                        Text("recent_completions".localized)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(completionDates.prefix(6), id: \.self) { date in
                            Text(DateFormatter.shortDate.string(from: date))
                                .font(.system(size: 11))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(hex: "5E5CE6").opacity(0.1))
                                .foregroundColor(Color(hex: "5E5CE6"))
                                .cornerRadius(8)
                        }
                        
                        if completionDates.count > 6 {
                            Text("+\(completionDates.count - 6)")
                                .font(.system(size: 11))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.1))
                                .foregroundColor(.secondary)
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            isSelected ? Color(hex: "5E5CE6").opacity(0.5) : Color.clear,
                            lineWidth: 2
                        )
                )
        )
        .scaleEffect(isSelected ? 0.98 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onTapGesture {
            if isEditMode {
                onSelectionChanged(!isSelected)
            }
        }
    }
}

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}