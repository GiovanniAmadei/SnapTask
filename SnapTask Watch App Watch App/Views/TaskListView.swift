import SwiftUI

struct TaskListView: View {
    @ObservedObject private var taskManager = TaskManager.shared
    @State private var date = Date()
    @State private var isShowingCreateTask = false
    @State private var showTaskDetail: TodoTask? = nil
    @State private var editingTask: TodoTask? = nil
    @State private var hapticEngine = WKHapticType.click
    @State private var selectedTask: TodoTask? = nil
    @State private var showingActionSheet = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                if todaysTasks.isEmpty {
                    Text("No tasks for today (Simplified View)")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    Text("Tasks (Simplified View):")
                        .font(.headline)
                        .padding(.bottom, 5)
                    
                    ForEach(todaysTasks) { taskItem in
                        TaskRowView(
                            task: taskItem,
                            onTap: {
                                showTaskDetail = taskItem
                                WKInterfaceDevice.current().play(hapticEngine)
                            },
                            onLongPress: {
                                selectedTask = taskItem
                                showingActionSheet = true
                                WKInterfaceDevice.current().play(hapticEngine)
                            }
                        )
                        Divider()
                    }
                }
            }
        }
        .navigationTitle("Tasks (Simplified)")
        .sheet(isPresented: $isShowingCreateTask) {
            WatchTaskFormView(
                task: editingTask,
                initialDate: date,
                isPresented: $isShowingCreateTask
            )
            .onDisappear {
                editingTask = nil
            }
        }
        .sheet(item: $showTaskDetail) { task in
            WatchTaskDetailView(task: task, selectedDate: date)
        }
        .sheet(isPresented: $showingActionSheet) {
            if let task = selectedTask {
                ActionSheetView(
                    task: task,
                    onEdit: {
                        editingTask = task
                        isShowingCreateTask = true
                        showingActionSheet = false
                    },
                    onDelete: {
                        taskManager.removeTask(task)
                        showingActionSheet = false
                    }
                )
            }
        }
    }
    
    private var todaysTasks: [TodoTask] {
        let startOfDay = Calendar.current.startOfDay(for: date)
        return taskManager.tasks.filter { task in
            let taskDate = Calendar.current.startOfDay(for: task.startTime)
            
            if taskDate == startOfDay {
                return true
            }
            
            if let recurrence = task.recurrence, recurrence.isActiveOn(date: date) {
                return true
            }
            
            return false
        }
        .sorted { $0.startTime < $1.startTime }
    }
}

struct TaskRowView: View {
    let task: TodoTask
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: task.completions[Calendar.current.startOfDay(for: Date())]?.isCompleted ?? false ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.completions[Calendar.current.startOfDay(for: Date())]?.isCompleted ?? false ? .green : .gray)
                    .font(.system(size: 20))
                
                Text(task.name)
                    .padding(.vertical, 4)
                
                Spacer()
            }
            .padding(.horizontal)
        }
        .buttonStyle(PlainButtonStyle())
        .gesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    onLongPress()
                }
        )
    }
}

struct ActionSheetView: View {
    let task: TodoTask
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        List {
            Button(action: onEdit) {
                Label("Edit Task", systemImage: "pencil")
                    .foregroundColor(.orange)
            }
            
            Button(role: .destructive, action: onDelete) {
                Label("Delete Task", systemImage: "trash")
            }
        }
        .listStyle(EllipticalListStyle())
    }
}

struct WatchTaskRow: View {
    @ObservedObject var taskManager: TaskManager
    let taskId: UUID
    @State private var showTaskDetail = false

    private var task: TodoTask? {
        taskManager.tasks.first { $0.id == taskId }
    }

    private var isCompletedToday: Bool {
        guard let currentTask = task else { return false }
        return currentTask.completions[Calendar.current.startOfDay(for: Date())]?.isCompleted ?? false
    }

    var body: some View {
        if let currentTask = task {
            HStack {
                // Check button
                Button(action: {
                    taskManager.toggleTaskCompletion(taskId, on: Date())
                }) {
                    Image(systemName: isCompletedToday ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isCompletedToday ? .green : .gray)
                        .font(.system(size: 20))
                }
                .buttonStyle(PlainButtonStyle())

                // Rest of the card is tappable for task details
                Button(action: {
                    showTaskDetail = true
                }) {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(currentTask.category != nil ? Color(hex: currentTask.category!.color) : Color.gray)
                                .frame(width: 30, height: 30)

                            Image(systemName: currentTask.icon)
                                .foregroundColor(.white)
                                .font(.system(size: 14))
                        }
                        .padding(.leading, 5)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(currentTask.name)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(isCompletedToday ? .secondary : .primary)
                                .strikethrough(isCompletedToday, color: .secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.vertical, 2)
            .sheet(isPresented: $showTaskDetail) {
                WatchTaskDetailView(task: currentTask, selectedDate: Date())
            }
        } else {
            Text("Task not found")
                .foregroundColor(.red)
        }
    }
}

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
