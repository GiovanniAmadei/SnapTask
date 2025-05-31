import SwiftUI

struct DayTimelineView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var scrollProxy: ScrollViewProxy?
    
    private let hourHeight: CGFloat = 80
    
    private var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }
    
    private var currentMinute: Int {
        Calendar.current.component(.minute, from: Date())
    }
    
    private var timelineRange: ClosedRange<Int> {
        let tasks = viewModel.tasksForSelectedDate().filter { $0.hasSpecificTime }
        
        if tasks.isEmpty {
            // If no tasks, show around current time or reasonable default
            if viewModel.isToday {
                return max(0, currentHour - 2)...min(23, currentHour + 8)
            } else {
                return 8...20 // Default business hours
            }
        }
        
        let taskHours = tasks.map { Calendar.current.component(.hour, from: $0.startTime) }
        let minHour = taskHours.min() ?? 8
        let maxHour = taskHours.max() ?? 20
        
        // Expand range slightly for context
        let startHour = max(0, minHour - 1)
        let endHour = min(23, maxHour + 2)
        
        // If viewing today, include current hour in range
        if viewModel.isToday {
            let expandedStart = min(startHour, max(0, currentHour - 1))
            let expandedEnd = max(endHour, min(23, currentHour + 2))
            return expandedStart...expandedEnd
        }
        
        return startHour...endHour
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Date Header
                VStack(spacing: 8) {
                    Text(viewModel.monthYearString)
                        .font(.title2.bold())
                    
                    Text(viewModel.dateString)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                
                // Timeline Content
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(timelineRange), id: \.self) { hour in
                                SmartTimelineHourRow(
                                    hour: hour,
                                    tasks: tasksForHour(hour),
                                    viewModel: viewModel,
                                    isCurrentHour: viewModel.isToday && currentHour == hour,
                                    currentMinute: viewModel.isToday && currentHour == hour ? currentMinute : nil,
                                    nextTaskHour: nextTaskHour(after: hour),
                                    isLastHour: hour == timelineRange.upperBound
                                )
                                .id(hour)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .onAppear {
                        scrollProxy = proxy
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            scrollToCurrentTime()
                        }
                    }
                }
            }
            .navigationTitle("Day Timeline")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        scrollToCurrentTime()
                    }) {
                        Image(systemName: "clock")
                            .foregroundColor(.pink)
                    }
                }
            }
        }
    }
    
    private func nextTaskHour(after hour: Int) -> Int? {
        let tasks = viewModel.tasksForSelectedDate().filter { $0.hasSpecificTime }
        let futureTaskHours = tasks
            .map { Calendar.current.component(.hour, from: $0.startTime) }
            .filter { $0 > hour }
            .sorted()
        
        return futureTaskHours.first
    }
    
    private func tasksForHour(_ hour: Int) -> [TodoTask] {
        let calendar = Calendar.current
        return viewModel.tasksForSelectedDate().filter { task in
            guard task.hasSpecificTime else { return false }
            let taskHour = calendar.component(.hour, from: task.startTime)
            return taskHour == hour
        }
    }
    
    private func scrollToCurrentTime() {
        guard let proxy = scrollProxy else { return }
        
        let calendar = Calendar.current
        let tasks = viewModel.tasksForSelectedDate().filter { $0.hasSpecificTime }
        
        var targetHour: Int
        
        if viewModel.isToday {
            // For today, prioritize current time but also consider next upcoming task
            let now = Date()
            let currentHour = calendar.component(.hour, from: now)
            
            let upcomingTasks = tasks.filter { $0.startTime > now }
            if let nextTask = upcomingTasks.first {
                let nextTaskHour = calendar.component(.hour, from: nextTask.startTime)
                // If next task is within 2 hours, scroll to current time, otherwise to next task
                targetHour = (nextTaskHour - currentHour <= 2) ? currentHour : max(0, nextTaskHour - 1)
            } else {
                targetHour = currentHour
            }
        } else {
            // For other days, scroll to first task or middle of timeline
            if let firstTask = tasks.first {
                targetHour = max(timelineRange.lowerBound, calendar.component(.hour, from: firstTask.startTime) - 1)
            } else {
                targetHour = timelineRange.lowerBound + (timelineRange.count / 2)
            }
        }
        
        // Ensure target hour is within our timeline range
        targetHour = max(timelineRange.lowerBound, min(timelineRange.upperBound, targetHour))
        
        withAnimation(.easeInOut(duration: 0.8)) {
            proxy.scrollTo(targetHour, anchor: .center)
        }
    }
}
