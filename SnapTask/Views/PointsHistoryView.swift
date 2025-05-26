import SwiftUI

struct PointsHistoryView: View {
    @StateObject private var taskManager = TaskManager.shared
    @StateObject private var rewardManager = RewardManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingResetAlert = false
    @State private var selectedTasks = Set<UUID>()
    @State private var isEditMode = false
    @State private var showingRemoveSelectedAlert = false
    
    private var pointsEarningTasks: [(TodoTask, [Date])] {
        let allTasks = taskManager.tasks.filter { $0.hasRewardPoints }
        return allTasks.compactMap { task in
            let completionDates = task.completionDates.filter { _ in task.hasRewardPoints }
            return completionDates.isEmpty ? nil : (task, completionDates)
        }
    }
    
    private var totalPoints: Int {
        rewardManager.totalPoints()
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Total Points Header - integrated into the scroll view
                    if !pointsEarningTasks.isEmpty {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(LinearGradient(
                                    colors: [Color(hex: "5E5CE6"), Color(hex: "9747FF")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .shadow(color: Color(hex: "5E5CE6").opacity(0.3), radius: 8, x: 0, y: 4)
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Total Points Earned")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white.opacity(0.9))
                                    
                                    Text("\(totalPoints)")
                                        .font(.system(size: 32, weight: .bold))
                                        .foregroundColor(Color(hex: "FFD700"))
                                }
                                
                                Spacer()
                                
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.2))
                                        .frame(width: 50, height: 50)
                                    
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .font(.system(size: 20))
                                        .foregroundColor(Color(hex: "FFD700"))
                                }
                            }
                            .padding(20)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                    
                    if pointsEarningTasks.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(pointsEarningTasks, id: \.0.id) { task, dates in
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
                .padding(.bottom, 16)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Points History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !pointsEarningTasks.isEmpty {
                        Button(isEditMode ? "Cancel" : "Edit") {
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
                            Button("Remove Selected") {
                                showingRemoveSelectedAlert = true
                            }
                            .foregroundColor(.red)
                        }
                        
                        if !isEditMode {
                            Menu {
                                Button("Reset All Points", role: .destructive) {
                                    showingResetAlert = true
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                        
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
            .alert("Reset All Points", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    rewardManager.resetAllPoints()
                }
            } message: {
                Text("This will permanently delete all earned points. This action cannot be undone.")
            }
            .alert("Remove Selected Points", isPresented: $showingRemoveSelectedAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) {
                    for taskId in selectedTasks {
                        if let task = taskManager.tasks.first(where: { $0.id == taskId }) {
                            rewardManager.removePointsFromTask(task)
                        }
                    }
                    selectedTasks.removeAll()
                    isEditMode = false
                }
            } message: {
                Text("This will remove points earned from the selected tasks. This action cannot be undone.")
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color(hex: "5E5CE6").opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 40))
                    .foregroundColor(Color(hex: "5E5CE6"))
            }
            
            VStack(spacing: 8) {
                Text("No Points Earned Yet")
                    .font(.system(size: 18, weight: .semibold))
                
                Text("Complete tasks with reward points enabled to see your earning history here.")
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
                        
                        Text("\(task.rewardPoints) points per completion")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("+\(totalPointsEarned)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color(hex: "00C853"))
                        
                        Text("\(completionDates.count) times")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                if completionDates.count > 1 {
                    HStack {
                        Text("Recent completions:")
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
