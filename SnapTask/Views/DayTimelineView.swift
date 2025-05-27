import SwiftUI

struct DayTimelineView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var scrollProxy: ScrollViewProxy?
    
    private let hourHeight: CGFloat = 80
    
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
                            ForEach(viewModel.effectiveStartHour...viewModel.effectiveEndHour, id: \.self) { hour in
                                TimelineHourRow(
                                    hour: hour,
                                    tasks: tasksForHour(hour),
                                    viewModel: viewModel
                                )
                                .id(hour)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .onAppear {
                        scrollProxy = proxy
                        // Scroll to current hour or first task
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            scrollToRelevantTime()
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
                        scrollToRelevantTime()
                    }) {
                        Image(systemName: "clock")
                    }
                }
            }
        }
    }
    
    private func tasksForHour(_ hour: Int) -> [TodoTask] {
        let calendar = Calendar.current
        return viewModel.tasksForSelectedDate().filter { task in
            let taskHour = calendar.component(.hour, from: task.startTime)
            return taskHour == hour
        }
    }
    
    private func scrollToRelevantTime() {
        guard let proxy = scrollProxy else { return }
        
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: Date())
        
        // If viewing today, scroll to current hour
        if viewModel.isToday {
            withAnimation(.easeInOut(duration: 0.5)) {
                proxy.scrollTo(currentHour, anchor: .top)
            }
        } else {
            // Otherwise scroll to first task
            let tasks = viewModel.tasksForSelectedDate()
            if let firstTask = tasks.first {
                let firstTaskHour = calendar.component(.hour, from: firstTask.startTime)
                withAnimation(.easeInOut(duration: 0.5)) {
                    proxy.scrollTo(firstTaskHour, anchor: .top)
                }
            }
        }
    }
}

struct TimelineHourRow: View {
    let hour: Int
    let tasks: [TodoTask]
    @ObservedObject var viewModel: TimelineViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    private var isCurrentHour: Bool {
        viewModel.isToday && Calendar.current.component(.hour, from: Date()) == hour
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time Label
            VStack(spacing: 4) {
                Text(hourString)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundColor(isCurrentHour ? .pink : .secondary)
                
                if isCurrentHour {
                    Circle()
                        .fill(Color.pink)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: 50)
            
            // Timeline Line
            VStack(spacing: 0) {
                Rectangle()
                    .fill(isCurrentHour ? Color.pink.opacity(0.3) : Color.gray.opacity(0.2))
                    .frame(width: 2, height: tasks.isEmpty ? 60 : CGFloat(max(60, tasks.count * 80)))
            }
            
            // Tasks for this hour
            VStack(alignment: .leading, spacing: 8) {
                if tasks.isEmpty {
                    // Empty hour placeholder
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.clear)
                        .frame(height: 60)
                } else {
                    ForEach(tasks, id: \.id) { task in
                        TimelineTaskView(task: task, viewModel: viewModel)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
    
    private var hourString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
}

struct TimelineTaskView: View {
    let task: TodoTask
    @ObservedObject var viewModel: TimelineViewModel
    @State private var showingPomodoro = false
    @State private var showingEditSheet = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var isCompleted: Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: viewModel.selectedDate)
        if let completion = task.completions[startOfDay] {
            return completion.isCompleted
        }
        return false
    }
    
    private var taskTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: task.startTime)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Task completion button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.toggleTaskCompletion(task.id)
                }
            }) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isCompleted ? .green : .gray)
                    .font(.title3)
            }
            .buttonStyle(BorderlessButtonStyle())
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    // Category indicator
                    if let category = task.category {
                        Circle()
                            .fill(Color(hex: category.color))
                            .frame(width: 8, height: 8)
                    }
                    
                    Text(task.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .strikethrough(isCompleted)
                    
                    Spacer()
                    
                    // Priority indicator
                    Image(systemName: task.priority.icon)
                        .foregroundColor(Color(hex: task.priority.color))
                        .font(.system(size: 12))
                    
                    // Time display
                    Text(taskTime)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                }
                
                if let description = task.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                if task.hasDuration && task.duration > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(task.duration.formatted())
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 8) {
                if task.pomodoroSettings != nil {
                    Button(action: { 
                        PomodoroViewModel.shared.setActiveTask(task)
                        showingPomodoro = true
                    }) {
                        Image(systemName: "timer")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.pink)
                            .clipShape(Circle())
                    }
                }
                
                Button(action: {
                    showingEditSheet = true
                }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(.systemGray6) : .white)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .opacity(isCompleted ? 0.6 : 1.0)
        .sheet(isPresented: $showingEditSheet) {
            TaskFormView(initialTask: task, onSave: { updatedTask in
                TaskManager.shared.updateTask(updatedTask)
            })
        }
        .sheet(isPresented: $showingPomodoro) {
            PomodoroView(task: task)
        }
    }
}
