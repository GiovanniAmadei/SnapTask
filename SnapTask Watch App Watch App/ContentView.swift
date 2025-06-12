import SwiftUI

struct ContentView: View {
    @StateObject private var taskManager = TaskManager.shared
    @StateObject private var timelineViewModel = TimelineViewModel()

    @State private var selectedView: WatchViewType = .timeline
    @State private var showingMenu = false
    
    // States for Timeline interactions
    @State private var showingTimelineDatePicker = false
    @State private var showingCreateTaskView = false
    @State private var taskToEdit: TodoTask? = nil

    var body: some View {
        // COPIO ESATTAMENTE la struttura del menu!
        NavigationStack {
            currentView
            .navigationTitle(selectedView == .timeline ? "" : selectedView.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showingMenu = true }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
                
                if selectedView == .timeline {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            self.taskToEdit = nil
                            self.showingCreateTaskView = true
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingMenu) {
            WatchMenuView(selectedView: $selectedView, showingMenu: $showingMenu)
        }
        .sheet(isPresented: $showingTimelineDatePicker) {
            WatchDatePickerView(
                selectedDate: $timelineViewModel.selectedDate,
                selectedDayOffset: $timelineViewModel.selectedDayOffset
            )
        }
        .sheet(isPresented: $showingCreateTaskView) {
            WatchTaskFormView(
                task: taskToEdit,
                initialDate: timelineViewModel.selectedDate, 
                isPresented: $showingCreateTaskView
            )
            .environmentObject(taskManager) 
            .onDisappear { taskToEdit = nil }
        }
    }

    @ViewBuilder
    private var currentView: some View {
        switch selectedView {
        case .timeline:
            WatchTimelineView(
                viewModel: timelineViewModel,
                onEditTaskFromRow: { task in 
                    self.taskToEdit = task
                    self.showingCreateTaskView = true
                },
                onDateTap: { showingTimelineDatePicker = true }
            )
        case .focus:
            WatchFocusView() 
        case .rewards:
            WatchRewardsView() 
        case .statistics:
            WatchStatisticsView() 
        case .settings:
            WatchSettingsView() 
        }
    }
    
    private var timelineDateText: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(timelineViewModel.selectedDate) {
            return "Today"
        } else if calendar.isDateInYesterday(timelineViewModel.selectedDate) {
            return "Yesterday"
        } else if calendar.isDateInTomorrow(timelineViewModel.selectedDate) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: timelineViewModel.selectedDate)
        }
    }
}

enum WatchViewType: String, CaseIterable {
    case timeline = "timeline"
    case focus = "focus"
    case rewards = "rewards"
    case statistics = "statistics"
    case settings = "settings"
    
    var title: String {
        switch self {
        case .timeline: return "Timeline"
        case .focus: return "Focus"
        case .rewards: return "Rewards"
        case .statistics: return "Stats"
        case .settings: return "Settings"
        }
    }
    
    var icon: String {
        switch self {
        case .timeline: return "calendar"
        case .focus: return "timer"
        case .rewards: return "star.fill"
        case .statistics: return "chart.bar.fill"
        case .settings: return "gear"
        }
    }
}
