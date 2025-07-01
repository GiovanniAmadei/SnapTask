import SwiftUI

struct WatchTimelineView: View {
    @ObservedObject var viewModel: TimelineViewModel // Now passed from ContentView
    var onEditTaskFromRow: (TodoTask) -> Void   // Closure to request editing a task
    var onDateTap: () -> Void

    @StateObject private var taskManager = TaskManager.shared // Can remain for local operations like delete
    @State private var selectedTask: TodoTask? // For showing detail view locally

    var body: some View {
        // COPIO ESATTAMENTE la struttura del WatchMenuView!
        ScrollView {
            VStack(spacing: 6) {
                // Date selector come prima riga - IDENTICO al menu
                Button(action: onDateTap) {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        Text(timelineDateText)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Task rows - DESIGN MIGLIORATO simile a iOS
                if viewModel.tasksForSelectedDate().isEmpty {
                    WatchEmptyState()
                } else {
                    ForEach(viewModel.tasksForSelectedDate()) { task in
                        WatchTimelineTaskCard(
                            task: task,
                            selectedDate: viewModel.selectedDate,
                            onTap: { selectedTask = task }, 
                            onEdit: { onEditTaskFromRow(task) }, 
                            onDelete: { taskManager.removeTask(task) }, 
                            onToggleComplete: { 
                                taskManager.toggleTaskCompletion(task.id, on: viewModel.selectedDate)
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 8) // IDENTICO al menu
            .padding(.vertical, 8)   // IDENTICO al menu
        }
        .sheet(item: $selectedTask) { task in 
            WatchTaskDetailView(task: task, selectedDate: viewModel.selectedDate)
                .environmentObject(taskManager)
        }
    }
    
    private var timelineDateText: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(viewModel.selectedDate) {
            return "Today"
        } else if calendar.isDateInYesterday(viewModel.selectedDate) {
            return "Yesterday"
        } else if calendar.isDateInTomorrow(viewModel.selectedDate) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: viewModel.selectedDate)
        }
    }
}

struct WatchTimelineTaskCard: View {
    let task: TodoTask
    let selectedDate: Date
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleComplete: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Main content - NOME CENTRATO VERTICALMENTE
                VStack {
                    Spacer()
                    
                    HStack {
                        Text(task.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(isCompleted ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        
                        Spacer()
                        
                        // Info aggiuntive - SOLO orario, streak e priorità
                        HStack(spacing: 6) {
                            // Time - SULLA STESSA LINEA
                            if task.hasDuration {
                                Text("\(formatTime(task.startTime))")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            
                            // Streak reale - SOLO se c'è una streak attiva
                            if currentStreak > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 9))
                                        .foregroundColor(.orange)
                                    Text("\(currentStreak)")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(.orange)
                                }
                            }
                            
                            // Priority
                            if task.priority != .medium {
                                Image(systemName: task.priority.icon)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(Color(hex: task.priority.color))
                            }
                        }
                    }
                    
                    Spacer()
                }
                
                // Right side: Check button
                Button(action: onToggleComplete) {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isCompleted ? .green : .gray)
                }
                .buttonStyle(.plain)
            }
            .frame(height: 44) // ALTEZZA FISSA
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(enhancedBorderColor, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .onLongPressGesture {
            // Use long press instead of deprecated contextMenu
            // You could implement a custom action sheet here
        }
    }
    
    // MARK: - Computed Properties
    
    private var isCompleted: Bool {
        if let completion = task.completions[selectedDate.startOfDay] {
            return completion.isCompleted
        }
        return false
    }
    
    private var cardBackground: Color {
        if isCompleted {
            return colorScheme == .dark ? Color.secondary.opacity(0.05) : Color.gray.opacity(0.05)
        } else {
            return colorScheme == .dark ? Color.secondary.opacity(0.08) : Color.white
        }
    }
    
    private var enhancedBorderColor: Color {
        if isCompleted {
            return .clear
        } else if let category = task.category {
            let baseColor = Color(hex: category.color)
            return baseColor.opacity(0.6)
        }
        return Color.secondary.opacity(0.1)
    }
    
    // CALCOLO STREAK REALE - CORRETTO
    private var currentStreak: Int {
        guard let recurrence = task.recurrence else { return 0 }
        
        let calendar = Calendar.current
        var streak = 0
        var currentDate = selectedDate
        
        // Controlla fino a 30 giorni indietro per calcolare la streak
        for _ in 0..<30 {
            // Verifica se la task doveva essere completata in questa data
            if recurrence.shouldOccurOn(date: currentDate) {
                let dayKey = calendar.startOfDay(for: currentDate)
                if let completion = task.completions[dayKey], completion.isCompleted {
                    streak += 1
                } else {
                    // Se non è completata, la streak si interrompe
                    break
                }
            }
            
            // Vai al giorno precedente
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        }
        
        return streak
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Estensione per corner radius personalizzato
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

struct WatchEmptyState: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 20))
                .foregroundColor(.secondary)
            
            Text("No tasks today")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
            
            Text("Tap + to add your first task")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }
}