import SwiftUI

struct TimelineView: View {
    @StateObject var viewModel: TimelineViewModel
    @State private var showingNewTask = false
    @State private var selectedDayOffset = 0
    @State private var showingCalendarPicker = false
    @State private var scrollProxy: ScrollViewProxy?
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Fixed Month and Date Selector
                    VStack(spacing: 4) {
                        HStack {
                            Text(viewModel.monthYearString)
                                .font(.title2.bold())
                            Spacer()
                            Button(action: { showingCalendarPicker = true }) {
                                Image(systemName: "calendar")
                                    .foregroundColor(.pink)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        // Date Selector
                        ScrollViewReader { proxy in
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(-365...365, id: \.self) { offset in // Extended to full year range
                                        DayCell(
                                            date: Calendar.current.date(
                                                byAdding: .day,
                                                value: offset,
                                                to: Date()
                                            ) ?? Date(),
                                            isSelected: offset == selectedDayOffset,
                                            onTap: {
                                                selectDay(offset, proxy: proxy)
                                            }
                                        )
                                        .id(offset)
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .onAppear {
                                scrollProxy = proxy
                                proxy.scrollTo(selectedDayOffset, anchor: .center)
                            }
                        }
                    }
                    .background(Color(.systemBackground))
                    .zIndex(1)
                    
                    // Task List and Add Button
                    ZStack {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(viewModel.tasksForSelectedDate()) { task in
                                    TaskCard(task: task,
                                           onToggleComplete: { viewModel.toggleTaskCompletion(task.id) },
                                           onToggleSubtask: { subtaskId in
                                               viewModel.toggleSubtask(taskId: task.id, subtaskId: subtaskId)
                                           },
                                           viewModel: viewModel)
                                }
                            }
                            .padding()
                            .padding(.bottom, 100)
                        }
                        
                        // Centered Add Button
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                AddTaskButton(isShowingTaskForm: $showingNewTask)
                                Spacer()
                            }
                            .padding(.bottom, 16)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingNewTask) {
                TaskFormView(
                    viewModel: TaskFormViewModel(initialDate: viewModel.selectedDate),
                    onSave: { task in
                        viewModel.addTask(task)
                    }
                )
            }
            .sheet(isPresented: $showingCalendarPicker) {
                NavigationStack {
                    VStack {
                        DatePicker("",
                                  selection: $viewModel.selectedDate,
                                  displayedComponents: [.date])
                            .datePickerStyle(.graphical)
                            .padding()
                        
                        Button("Done") {
                            let calendar = Calendar.current
                            let today = Date()
                            if let daysDiff = calendar.dateComponents([.day], from: today, to: viewModel.selectedDate).day {
                                selectDay(daysDiff, proxy: scrollProxy)
                            }
                            showingCalendarPicker = false
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.bottom)
                    }
                    .navigationBarHidden(true)
                    .presentationDetents([.height(500)])
                    .presentationDragIndicator(.visible)
                }
            }
        }
    }
    
    private func selectDay(_ offset: Int, proxy: ScrollViewProxy?) {
        withAnimation {
            selectedDayOffset = offset
            viewModel.selectedDate = Calendar.current.date(
                byAdding: .day,
                value: offset,
                to: Date()
            ) ?? Date()
            
            // Ensure the day cell is visible
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    proxy?.scrollTo(offset, anchor: .center)
                }
            }
        }
    }
}

// Day Cell Component
private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 4) {
            Text(dayName)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .secondary)
            
            Text(dayNumber)
                .font(.callout)
                .fontWeight(.bold)
                .foregroundColor(isSelected ? .white : .primary)
        }
        .frame(width: 45, height: 60)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? 
                    AnyShapeStyle(
                        LinearGradient(
                            colors: [.pink, .pink.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    ) :
                    AnyShapeStyle(Color.clear))
                .shadow(color: isSelected ? .pink.opacity(0.3) : .clear, 
                       radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isSelected ? Color.clear : Color.gray.opacity(0.2), 
                            lineWidth: 1)
        )
        .onTapGesture(perform: onTap)
    }
    
    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}

// Enhanced Task Card
private struct TaskCard: View {
    let task: TodoTask
    let onToggleComplete: () -> Void
    let onToggleSubtask: (UUID) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var taskManager = TaskManager.shared
    @State private var showingPomodoro = false
    @ObservedObject var viewModel: TimelineViewModel
    
    private var isCompleted: Bool {
        if let completion = task.completions[viewModel.selectedDate.startOfDay] {
            return completion.isCompleted
        }
        return false
    }
    
    private var completionProgress: Double {
        guard !task.subtasks.isEmpty else { return isCompleted ? 1.0 : 0.0 }
        let completion = task.completions[viewModel.selectedDate.startOfDay]
        let completedCount = completion?.completedSubtasks.count ?? 0
        return Double(completedCount) / Double(task.subtasks.count)
    }
    
    private var completedSubtasks: Set<UUID> {
        task.completions[viewModel.selectedDate.startOfDay]?.completedSubtasks ?? []
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let description = task.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                if task.hasDuration && task.duration > 0 {
                    Text(formatDuration(task.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                }
                
                if task.pomodoroSettings != nil {
                    Button(action: { showingPomodoro = true }) {
                        Image(systemName: "timer")
                            .foregroundColor(.pink)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                
                Button(action: onToggleComplete) {
                    ZStack {
                        if !task.subtasks.isEmpty {
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                                .frame(width: 32, height: 32)
                            
                            Circle()
                                .trim(from: 0, to: completionProgress)
                                .stroke(.pink, lineWidth: 2)
                                .frame(width: 32, height: 32)
                                .rotationEffect(.degrees(-90))
                                .animation(
                                    .spring(
                                        response: 0.6,
                                        dampingFraction: 0.7,
                                        blendDuration: 0.5
                                    ),
                                    value: completionProgress
                                )
                        }
                        
                        Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundColor(isCompleted ? .green : .gray)
                            .animation(.spring(response: 0.3), value: isCompleted)
                    }
                }
                .buttonStyle(BorderlessButtonStyle())
                .contentShape(Rectangle())
                .frame(width: 44, height: 44)
            }
            
            if !task.subtasks.isEmpty {
                VStack(spacing: 4) {
                    ForEach(task.subtasks) { subtask in
                        SubtaskRow(
                            subtask: subtask,
                            isCompleted: completedSubtasks.contains(subtask.id),
                            onToggle: {
                                withAnimation(.spring(response: 0.3)) {
                                    onToggleSubtask(subtask.id)
                                }
                            }
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.white)
                        .opacity(colorScheme == .dark ? 0.1 : 0)
                )
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08),
                    radius: 15,
                    x: 0,
                    y: 5
                )
        )
        .sheet(isPresented: $showingPomodoro) {
            PomodoroView(task: task)
        }
        .onChange(of: task.completions) { oldValue, newValue in
            taskManager.updateTask(task)
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) / 60 % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// Add Task Button
private struct AddTaskButton: View {
    @Binding var isShowingTaskForm: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: { isShowingTaskForm = true }) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.pink, Color.pink.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        Circle()
                            .fill(Color.pink.opacity(0.3))
                            .blur(radius: 8)
                            .scaleEffect(1.2)
                        
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.pink, Color.pink.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .shadow(
                        color: Color.pink.opacity(0.3),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                )
        }
        .padding(.horizontal, 20)
    }
}

private struct SubtaskRow: View {
    let subtask: Subtask
    let isCompleted: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onToggle) {
                SubtaskCheckmark(isCompleted: isCompleted)
            }
            .buttonStyle(BorderlessButtonStyle())
            .contentShape(Rectangle())
            .frame(width: 32, height: 32)
            
            Text(subtask.name)
                .font(.subheadline)
                .foregroundColor(isCompleted ? .secondary : .primary)
                .strikethrough(isCompleted)
            
            Spacer()
        }
    }
} 
