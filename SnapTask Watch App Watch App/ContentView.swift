import SwiftUI

struct ContentView: View {
    @StateObject private var taskManager = TaskManager.shared
    @StateObject private var timelineViewModel = TimelineViewModel() // Shared for header and view

    @State private var selectedView: WatchViewType = .timeline
    @State private var showingMenu = false
    
    // States for sheets presented from ContentView (for Timeline interactions)
    @State private var showingTimelineDatePicker = false
    @State private var showingCreateTaskView = false
    @State private var taskToEdit: TodoTask? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Custom Fixed Header Bar - Simulates watchOS status bar area
            HStack {
                // Left: Menu Button
                Button(action: { showingMenu = true }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.blue)
                }
                .frame(width: 36, height: 36) // Increased tap target
                .buttonStyle(PlainButtonStyle())
                .padding(.leading, 4) // Add small padding to bring it slightly from the edge

                Spacer()

                // Center: Conditional Content (Timeline Date / View Title)
                if selectedView == .timeline {
                    Button(action: { showingTimelineDatePicker = true }) {
                        HStack(spacing: 4) {
                            Text(timelineDateText)
                                .font(.system(size: 15, weight: .semibold))
                            Image(systemName: "chevron.down.circle.fill") // Filled, more visible
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.accentColor) // Use accent color for interactivity
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Text(selectedView.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary) // Primary should be visible on dark backgrounds
                }

                Spacer()

                // Right: Conditional Content (Timeline Add / Placeholder)
                if selectedView == .timeline {
                    Button(action: {
                        self.taskToEdit = nil // New task
                        self.showingCreateTaskView = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    .frame(width: 36, height: 36) // Increased tap target
                    .buttonStyle(PlainButtonStyle())
                    .padding(.trailing, 4) // Add small padding to bring it slightly from the edge
                } else {
                    Color.clear.frame(width: 36, height: 36) // Placeholder for alignment
                }
            }
            .padding(.horizontal, 2) // Reduced overall horizontal padding slightly
            .frame(height: 40)       
            .background(Color.black.opacity(0.05)) // Dark gray with opacity for better visibility

            // Content Area - Each view handles its own scrolling
            currentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(selectedView) 
        }
        // The padding on the HStack should handle the safe area now. Let watchOS manage the very top.
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
                }
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
