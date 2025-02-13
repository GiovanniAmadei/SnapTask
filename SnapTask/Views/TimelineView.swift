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
                                    ForEach(-365...365, id: \.self) { offset in
                                        DayCell(
                                            date: Calendar.current.date(
                                                byAdding: .day,
                                                value: offset,
                                                to: Date()
                                            ) ?? Date(),
                                            isSelected: offset == selectedDayOffset,
                                            offset: offset
                                        ) { _ in
                                            withAnimation {
                                                selectedDayOffset = offset
                                                viewModel.selectDate(offset)
                                                proxy.scrollTo(offset, anchor: .center)
                                            }
                                        }
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
                        List {
                            ForEach(viewModel.tasksForSelectedDate(), id: \.id) { task in
                                TaskCard(task: task,
                                       onToggleComplete: { viewModel.toggleTaskCompletion(task.id) },
                                       onToggleSubtask: { subtaskId in
                                           viewModel.toggleSubtask(taskId: task.id, subtaskId: subtaskId)
                                       },
                                       viewModel: viewModel)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                                .listRowBackground(Color.clear)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 4)
                        
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
                                withAnimation {
                                    selectedDayOffset = daysDiff
                                    viewModel.selectDate(daysDiff)
                                    scrollProxy?.scrollTo(daysDiff, anchor: .center)
                                }
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
}

// Day Cell Component
private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let offset: Int
    let action: (Int) -> Void
    
    // Explicit initializer to handle closure parameter
    init(date: Date, isSelected: Bool, offset: Int, action: @escaping (Int) -> Void) {
        self.date = date
        self.isSelected = isSelected
        self.offset = offset
        self.action = action
    }

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
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isSelected ? Color.clear : Color.gray.opacity(0.2), 
                            lineWidth: 1)
        )
        .onTapGesture {
            action(offset)
        }
    }
    
    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).lowercased()
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
    @State private var showingPomodoro = false
    @State private var isExpanded = false
    @State private var showingEditSheet = false
    @ObservedObject var viewModel: TimelineViewModel
    
    private var isCompleted: Bool {
        let startOfDay = viewModel.selectedDate.startOfDay
        if let completion = task.completions[startOfDay] {
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
    
    private var subtaskCountText: String {
        if task.subtasks.isEmpty { return "" }
        let completedCount = completedSubtasks.count
        let totalCount = task.subtasks.count
        return "\(completedCount)/\(totalCount)"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .center) {
                        Text(task.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        // Streak indicator migliorato
                        if let recurrence = task.recurrence {
                            HStack(spacing: 2) {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 12))
                                Text("\(task.currentStreak)")
                                    .font(.system(.caption, design: .rounded).bold())
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.orange.opacity(0.15))
                            )
                        }
                        
                        Spacer()
                        
                        // Freccia per espandere se ci sono subtask
                        if !task.subtasks.isEmpty {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let description = task.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                if task.hasDuration && task.duration > 0 {
                    Text(task.duration.formatted())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if task.pomodoroSettings != nil {
                    Button(action: { showingPomodoro = true }) {
                        Image(systemName: "timer")
                            .foregroundColor(task.category.map { Color(hex: $0.color) } ?? .gray)
                    }
                }
                
                Button(action: onToggleComplete) {
                    ZStack {
                        // Background circle
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                            .frame(width: 32, height: 32)
                        
                        // Progress circle
                        if !task.subtasks.isEmpty {
                            Circle()
                                .trim(from: 0, to: completionProgress)
                                .stroke(Color.pink, lineWidth: 3)
                                .frame(width: 32, height: 32)
                                .rotationEffect(.degrees(-90))
                                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: completionProgress)
                        }
                        
                        // Checkmark
                        Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isCompleted ? .green : .gray)
                            .font(.title2)
                    }
                }
                .frame(width: 44, height: 44)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            // Subtasks (mostrati solo se espanso)
            if isExpanded && !task.subtasks.isEmpty {
                VStack(spacing: 8) {
                    ForEach(task.subtasks) { subtask in
                        HStack {
                            Button(action: { onToggleSubtask(subtask.id) }) {
                                SubtaskCheckmark(isCompleted: completedSubtasks.contains(subtask.id))
                                    .scaleEffect(0.8)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            
                            Text(subtask.name)
                                .font(.subheadline)
                                .foregroundColor(isCompleted ? .secondary : .primary)
                            
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .padding(.horizontal, 12)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 60)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(colorScheme == .dark ? Color(.systemGray6) : .white)
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                TaskManager.shared.removeTask(task)
            } label: {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 32, weight: .regular))
                    .foregroundStyle(.red)
                    .padding(.trailing, -24)
            }
            .tint(.clear)
            
            Button {
                showingEditSheet = true
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 32, weight: .regular))
                    .foregroundStyle(.blue)
                    .padding(.leading, -24)
            }
            .tint(.clear)
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                TaskFormView(initialTask: task)
            }
        }
        .onTapGesture {
            if !task.subtasks.isEmpty {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
        }
        .sheet(isPresented: $showingPomodoro) {
            PomodoroView(task: task)
        }
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
            Button(action: {
                // Disable implicit animations
                withAnimation(.none) {
                    onToggle()
                }
            }) {
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
