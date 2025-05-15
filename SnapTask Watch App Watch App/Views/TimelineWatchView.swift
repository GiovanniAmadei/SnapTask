import SwiftUI

struct TimelineWatchView: View {
    @StateObject private var viewModel = TimelineViewModel()
    @StateObject private var taskManager = TaskManager.shared
    @State private var isShowingCreateTask = false
    @State private var isShowingCalendarPicker = false
    @State private var showTaskDetail: TodoTask? = nil
    @State private var editingTask: TodoTask? = nil
    
    var body: some View {
        VStack(spacing: 4) {
            // Add some padding at the top to prevent clipping
            Color.clear.frame(height: 2)
            
            // Header di navigazione date
            DateNavigationHeader(
                viewModel: viewModel,
                isShowingCalendarPicker: $isShowingCalendarPicker
            )
            .padding(.top, 6) // Add padding to push content down
            
            // Add Task Button
            Button(action: {
                isShowingCreateTask = true
            }) {
                Label("Add Task", systemImage: "plus")
                    .font(.footnote)
            }
            .padding(.vertical, 4)
            .buttonStyle(.borderless)
            
            // Task List
            taskList
        }
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: 0)
        }
        .ignoresSafeArea(.container, edges: .top)
        .sheet(isPresented: $isShowingCreateTask) {
            WatchTaskFormView(
                viewModel: editingTask != nil ? TaskFormViewModel(task: editingTask!, initialDate: viewModel.selectedDate) : TaskFormViewModel(initialDate: viewModel.selectedDate),
                isPresented: $isShowingCreateTask
            )
            .onDisappear {
                editingTask = nil
            }
        }
        .sheet(item: $showTaskDetail) { task in
            WatchTaskDetailView(task: task, date: viewModel.selectedDate)
        }
        .sheet(isPresented: $isShowingCalendarPicker) {
            VStack {
                Text("Select Date")
                    .font(.headline)
                    .padding(.top)
                
                WatchCalendarPicker(selectedDate: $viewModel.selectedDate, selectedDayOffset: $viewModel.selectedDayOffset)
                    .frame(maxHeight: 200)
                
                Button("Done") {
                    isShowingCalendarPicker = false
                }
                .padding(.bottom)
            }
            .presentationDetents([.height(250)])
        }
    }
    
    // Extracted task list view with improved list style
    private var taskList: some View {
        Group {
            if viewModel.tasksForSelectedDate().isEmpty {
                // Empty state (no tasks)
                VStack {
                    Spacer()
                    Text("No tasks for this day")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
            } else {
                // Tasks list
                List {
                    ForEach(viewModel.tasksForSelectedDate()) { task in
                        taskRow(task: task)
                            .listRowInsets(EdgeInsets(top: 1, leading: 4, bottom: 1, trailing: 4))
                    }
                }
                .listStyle(CarouselListStyle())
                .scrollDisabled(false)
                .scrollIndicators(.hidden)
            }
        }
    }
    
    // Completely rebuilt task row view for better clickability
    private func taskRow(task: TodoTask) -> some View {
        Button {
            showTaskDetail = task
        } label: {
            HStack(spacing: 8) {
                // Left side - Category bar and indicator
                if let category = task.category {
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color(hex: category.color))
                            .frame(width: 4)
                            .cornerRadius(2)
                    }
                    .frame(maxHeight: .infinity)
                    .padding(.vertical, 2)
                }
                
                // Center - Task info with time
                VStack(alignment: .leading, spacing: 2) {
                    // Task name
                    Text(task.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    // Time if available
                    if task.hasDuration {
                        Text(formatTime(task.startTime))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Right side - Completion button
                Button {
                    taskManager.toggleTaskCompletion(task.id, on: viewModel.selectedDate)
                } label: {
                    Image(systemName: isCompleted(task) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundColor(isCompleted(task) ? .green : .gray)
                        .contentShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .contextMenu {
            Button(action: {
                showTaskDetail = task
            }) {
                Label("View Details", systemImage: "info.circle")
            }
            
            Button(action: {
                editingTask = task
                isShowingCreateTask = true 
            }) {
                Label("Edit Task", systemImage: "pencil")
            }
            
            Button(role: .destructive, action: {
                taskManager.removeTask(task)
            }) {
                Label("Delete Task", systemImage: "trash")
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func isCompleted(_ task: TodoTask) -> Bool {
        if let completion = task.completions[viewModel.selectedDate.startOfDay] {
            return completion.isCompleted
        }
        return false
    }
}

struct DateNavigationHeader: View {
    @ObservedObject var viewModel: TimelineViewModel
    @Binding var isShowingCalendarPicker: Bool
    
    var body: some View {
        HStack {
            // Previous Day Button
            Button(action: {
                withAnimation {
                    viewModel.selectDate(viewModel.selectedDayOffset - 1)
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18))
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 30)
            
            // Calendar Icon Button
            Button(action: {
                isShowingCalendarPicker = true
            }) {
                HStack(spacing: 4) {
                    Text(formattedDate)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                }
            }
            .buttonStyle(PlainButtonStyle())
            .frame(maxWidth: .infinity)
            
            // Next Day Button
            Button(action: {
                withAnimation {
                    viewModel.selectDate(viewModel.selectedDayOffset + 1)
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18))
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 30)
        }
        .padding(.horizontal, 6)
        .frame(height: 28)
    }
    
    private var formattedDate: String {
        if viewModel.selectedDayOffset == 0 {
            return "Today"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "E, MMM d" // Compact date format
            return formatter.string(from: viewModel.selectedDate)
        }
    }
}

struct WatchCalendarPicker: View {
    @Binding var selectedDate: Date
    @Binding var selectedDayOffset: Int
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(-7...7, id: \.self) { dayOffset in
                    let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: Date()) ?? Date()
                    DayButton(
                        day: date,
                        isSelected: dayOffset == selectedDayOffset,
                        action: {
                            selectedDate = date
                            selectedDayOffset = dayOffset
                        }
                    )
                }
            }
            .padding()
        }
    }
}

struct DayButton: View {
    let day: Date
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(dayName)
                    .font(.system(size: 12))
                    .foregroundColor(textColor)
                
                Text(dayNumber)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textColor)
            }
            .frame(width: 36, height: 36)
            .background(
                Circle()
                    .fill(isSelected ? Color.blue : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: day)
    }
    
    private var dayNumber: String {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: day)
        return "\(day)"
    }
    
    private var textColor: Color {
        if isSelected {
            return .white
        } else {
            return .primary
        }
    }
} 