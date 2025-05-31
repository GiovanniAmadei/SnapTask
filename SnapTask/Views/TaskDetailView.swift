import SwiftUI
import MapKit

struct TaskDetailView: View {
    let task: TodoTask
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingEditSheet = false
    @State private var showingPomodoro = false
    
    private var isCompleted: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return task.completions[today]?.isCompleted == true
    }
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    detailsSection
                }
            }
            
            VStack {
                Spacer()
                actionButtons
            }
        }
        .navigationTitle("Task Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Close") {
                    dismiss()
                }
                .foregroundColor(.pink)
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            TaskFormView(initialTask: task, onSave: { updatedTask in
                TaskManager.shared.updateTask(updatedTask)
            })
        }
        .sheet(isPresented: $showingPomodoro) {
            PomodoroView(task: task)
        }
    }
    
    private var mainContent: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    detailsSection
                }
            }
            
            VStack {
                Spacer()
                actionButtons
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                Image(systemName: task.icon)
                    .font(.system(size: 32))
                    .foregroundColor(.pink)
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .fill(Color.pink.opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.name)
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        if let category = task.category {
                            categoryInfo(category)
                        }
                        
                        priorityInfo
                    }
                }
                
                Spacer()
                
                completionStatus
            }
        }
        .padding(20)
        .background(headerBackground)
        .padding(.horizontal)
        .padding(.top, 4)
    }
    
    private func categoryInfo(_ category: Category) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(hex: category.color))
                .frame(width: 8, height: 8)
            Text(category.name)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var priorityInfo: some View {
        HStack(spacing: 4) {
            Image(systemName: task.priority.icon)
                .font(.system(size: 10))
                .foregroundColor(Color(hex: task.priority.color))
            Text(task.priority.rawValue.capitalized)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var completionStatus: some View {
        Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 24))
            .foregroundColor(isCompleted ? .green : .gray)
    }
    
    private var headerBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color(.systemBackground))
            .shadow(
                color: colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.08),
                radius: colorScheme == .dark ? 0.5 : 12,
                x: 0,
                y: colorScheme == .dark ? 1 : 4
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        colorScheme == .dark ? .white.opacity(0.15) : .clear,
                        lineWidth: colorScheme == .dark ? 1 : 0
                    )
            )
    }
    
    private var detailsSection: some View {
        VStack(spacing: 16) {
            if let description = task.description, !description.isEmpty {
                descriptionCard(description)
            }
            
            if let location = task.location {
                locationCard(location)
            }
            
            scheduleCard
            
            if let recurrence = task.recurrence {
                recurrenceCard(recurrence)
            }
            
            if !task.subtasks.isEmpty {
                subtasksCard
            }
            
            if let pomodoroSettings = task.pomodoroSettings {
                pomodoroCard(pomodoroSettings)
            }
            
            if task.hasRewardPoints {
                rewardsCard
            }
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 120)
    }
    
    private func descriptionCard(_ description: String) -> some View {
        DetailCard(icon: "doc.text", title: "Description", color: .blue) {
            Text(description)
                .font(.body)
                .foregroundColor(.primary)
        }
    }
    
    private func locationCard(_ location: TaskLocation) -> some View {
        DetailCard(icon: "location", title: "Location", color: .green) {
            Button(action: {
                openInMaps(location: location)
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(location.name)
                            .font(.body)
                            .foregroundColor(.primary)
                        if let address = location.address {
                            Text(address)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                }
            }
            .buttonStyle(BorderlessButtonStyle())
        }
    }
    
    private var scheduleCard: some View {
        DetailCard(icon: "clock", title: "Schedule", color: Color.orange) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Start Time")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(task.startTime.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                
                if task.hasDuration {
                    HStack {
                        Text("Duration")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatDuration(task.duration))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }
    
    private func recurrenceCard(_ recurrence: Recurrence) -> some View {
        DetailCard(icon: "repeat", title: "Recurrence", color: .purple) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Pattern")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(recurrenceDescription(recurrence))
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                
                if let endDate = recurrence.endDate {
                    HStack {
                        Text("Ends")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(endDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
                
                HStack {
                    Text("Current Streak")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(Color.orange)
                            .font(.system(size: 12))
                        Text("\(task.currentStreak)")
                            .font(.subheadline.bold())
                            .foregroundColor(Color.orange)
                    }
                }
            }
        }
    }
    
    private var subtasksCard: some View {
        DetailCard(icon: "checklist", title: "Subtasks", color: .indigo) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(task.subtasks) { subtask in
                    subtaskRow(subtask)
                }
            }
        }
    }
    
    private func subtaskRow(_ subtask: Subtask) -> some View {
        HStack {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let isCompleted = task.completions[today]?.completedSubtasks.contains(subtask.id) == true
            
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundColor(isCompleted ? .green : .gray)
            
            Text(subtask.name)
                .font(.body)
                .foregroundColor(.primary)
                .strikethrough(isCompleted)
            
            Spacer()
        }
    }
    
    private func pomodoroCard(_ pomodoroSettings: PomodoroSettings) -> some View {
        DetailCard(icon: "timer", title: "Pomodoro", color: .red) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Work Duration")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(pomodoroSettings.workDuration / 60)) min")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Text("Break Duration")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(pomodoroSettings.breakDuration / 60)) min")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                
                Button(action: {
                    PomodoroViewModel.shared.setActiveTask(task)
                    showingPomodoro = true
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Pomodoro")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [Color.red, Color.red.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .shadow(
                        color: Color.red.opacity(colorScheme == .dark ? 0.4 : 0.3),
                        radius: colorScheme == .dark ? 4 : 6,
                        x: 0,
                        y: colorScheme == .dark ? 2 : 3
                    )
                }
                .padding(.top, 8)
            }
        }
    }
    
    private var rewardsCard: some View {
        DetailCard(icon: "star", title: "Rewards", color: .yellow) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Points Available")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                    Text("\(task.rewardPoints) points")
                        .font(.title3.bold())
                        .foregroundColor(.yellow)
                }
                Spacer()
                Image(systemName: "star.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.yellow)
            }
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 0) {
            // Gradiente per sfumare il contenuto sopra
            LinearGradient(
                colors: [
                    Color(.systemGroupedBackground).opacity(0),
                    Color(.systemGroupedBackground).opacity(0.8),
                    Color(.systemGroupedBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 30)
            
            // Pulsanti con sfondo solido
            HStack(spacing: 12) {
                editButton
                
                completeButton
            }
            .padding(.horizontal)
            .padding(.bottom)
            .padding(.top, 8)
            .background(Color(.systemGroupedBackground))
        }
    }
    
    private var completeButton: some View {
        Button(action: {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            TaskManager.shared.toggleTaskCompletion(task.id, on: today)
        }) {
            HStack(spacing: 8) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .medium))
                Text(isCompleted ? "Incomplete" : "Complete")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: isCompleted ? [Color.orange, Color.orange.opacity(0.8)] : [Color.green, Color.green.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(16)
            .shadow(color: (isCompleted ? Color.orange.opacity(0.3) : Color.green.opacity(0.3)), radius: 8, x: 0, y: 4)
        }
    }
    
    private var editButton: some View {
        Button(action: {
            showingEditSheet = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .medium))
                Text("Edit")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.pink, Color.pink.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(16)
            .shadow(color: Color.pink.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    private func recurrenceDescription(_ recurrence: Recurrence) -> String {
        switch recurrence.type {
        case .daily:
            return "Daily"
        case .weekly(let days):
            return days.count == 7 ? "Daily" : "\(days.count) days/week"
        case .monthly(let days):
            return "\(days.count) days/month"
        case .monthlyOrdinal(let patterns):
            return patterns.isEmpty ? "Monthly Patterns" : patterns.map { $0.displayText }.joined(separator: ", ")
        case .yearly:
            return "Yearly"
        }
    }
    
    private func openInMaps(location: TaskLocation) {
        let mapItem: MKMapItem
        
        if let coordinate = location.coordinate {
            let placemark = MKPlacemark(coordinate: coordinate)
            mapItem = MKMapItem(placemark: placemark)
        } else {
            let geocoder = CLGeocoder()
            geocoder.geocodeAddressString(location.displayName) { placemarks, error in
                if let placemark = placemarks?.first,
                   let clLocation = placemark.location {
                    let mapPlacemark = MKPlacemark(coordinate: clLocation.coordinate)
                    let mapItem = MKMapItem(placemark: mapPlacemark)
                    mapItem.name = location.name
                    mapItem.openInMaps()
                }
            }
            return
        }
        
        mapItem.name = location.name
        mapItem.openInMaps()
    }
}

struct DetailCard<Content: View>: View {
    let icon: String
    let title: String
    let color: Color
    let content: Content
    @Environment(\.colorScheme) private var colorScheme
    
    init(icon: String, title: String, color: Color, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            content
        }
        .padding(20)
        .background(cardBackground)
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.systemBackground))
            .shadow(
                color: colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.08),
                radius: colorScheme == .dark ? 0.5 : 8,
                x: 0,
                y: colorScheme == .dark ? 1 : 2
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        colorScheme == .dark ? .white.opacity(0.15) : .clear,
                        lineWidth: colorScheme == .dark ? 1 : 0
                    )
            )
    }
}

#Preview {
    NavigationStack {
        TaskDetailView(task: TodoTask(
            name: "Sample Task",
            description: "This is a sample task description",
            startTime: Date(),
            duration: 3600,
            hasDuration: true
        ))
    }
}
