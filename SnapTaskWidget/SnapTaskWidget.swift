import WidgetKit
import SwiftUI
import Intents
import CoreLocation

// MARK: - Widget Models (Simplified versions)
struct WTaskCompletion: Codable, Equatable, Hashable {
    var isCompleted: Bool
    var completedSubtasks: Set<UUID>
    
    init(isCompleted: Bool = false, completedSubtasks: Set<UUID> = []) {
        self.isCompleted = isCompleted
        self.completedSubtasks = completedSubtasks
    }
}

struct WSubtask: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var isCompleted: Bool
    
    init(id: UUID = UUID(), name: String, isCompleted: Bool = false) {
        self.id = id
        self.name = name
        self.isCompleted = isCompleted
    }
}

struct WCategory: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var color: String
    var icon: String
    
    init(id: UUID = UUID(), name: String, color: String, icon: String = "folder") {
        self.id = id
        self.name = name
        self.color = color
        self.icon = icon
    }
}

enum WPriority: String, CaseIterable, Codable {
    case low
    case medium
    case high
}

struct WTodoTask: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var startTime: Date
    var hasSpecificTime: Bool = true
    var category: WCategory?
    var priority: WPriority
    var icon: String
    var completions: [Date: WTaskCompletion] = [:]
    var subtasks: [WSubtask] = []
    var hasRewardPoints: Bool = false
    var rewardPoints: Int = 0
    
    init(
        id: UUID = UUID(),
        name: String,
        startTime: Date,
        hasSpecificTime: Bool = true,
        category: WCategory? = nil,
        priority: WPriority = .medium,
        icon: String = "circle"
    ) {
        self.id = id
        self.name = name
        self.startTime = startTime
        self.hasSpecificTime = hasSpecificTime
        self.category = category
        self.priority = priority
        self.icon = icon
    }
}

struct Provider: IntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        return SimpleEntry(date: Date(), configuration: ConfigurationIntent(), tasks: sampleTasks())
    }

    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), configuration: configuration, tasks: loadTasks())
        completion(entry)
    }

    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentDate = Date()
        let tasks = loadTasks()
        let entry = SimpleEntry(date: currentDate, configuration: configuration, tasks: tasks)
        
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
    
    private func loadTasks() -> [WTodoTask] {
        guard let userDefaults = UserDefaults(suiteName: "group.com.snapTask.shared"),
              let data = userDefaults.data(forKey: "savedTasks") else {
            return []
        }
        
        do {
            guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return []
            }
            
            var widgetTasks: [WTodoTask] = []
            
            for taskDict in jsonArray {
                // Extract basic properties
                guard let idString = taskDict["id"] as? String,
                      let id = UUID(uuidString: idString),
                      let name = taskDict["name"] as? String else {
                    continue
                }
                
                // Parse startTime
                var startTime = Date()
                if let startTimeInterval = taskDict["startTime"] as? TimeInterval {
                    startTime = Date(timeIntervalSince1970: startTimeInterval)
                } else if let startTimeDouble = taskDict["startTime"] as? Double {
                    startTime = Date(timeIntervalSince1970: startTimeDouble)
                } else {
                    continue
                }
                
                
                let hasSpecificTime = taskDict["hasSpecificTime"] as? Bool ?? true
                let icon = taskDict["icon"] as? String ?? "circle"
                let priorityString = taskDict["priority"] as? String ?? "medium"
                let priority = WPriority(rawValue: priorityString) ?? .medium
                
                // Parse category
                var category: WCategory?
                if let categoryDict = taskDict["category"] as? [String: Any],
                   let catIdString = categoryDict["id"] as? String,
                   let catId = UUID(uuidString: catIdString),
                   let catName = categoryDict["name"] as? String,
                   let catColor = categoryDict["color"] as? String {
                    let catIcon = categoryDict["icon"] as? String ?? "folder"
                    category = WCategory(id: catId, name: catName, color: catColor, icon: catIcon)
                }
                
                // Create task
                var task = WTodoTask(
                    id: id,
                    name: name,
                    startTime: startTime,
                    hasSpecificTime: hasSpecificTime,
                    category: category,
                    priority: priority,
                    icon: icon
                )
                
                // Parse completions
                if let completionsDict = taskDict["completions"] as? [String: Any] {
                    var completions: [Date: WTaskCompletion] = [:]
                    for (dateKey, compValue) in completionsDict {
                        if let dateInterval = Double(dateKey),
                           let compDict = compValue as? [String: Any] {
                            let date = Date(timeIntervalSince1970: dateInterval)
                            let isCompleted = compDict["isCompleted"] as? Bool ?? false
                            completions[date] = WTaskCompletion(isCompleted: isCompleted)
                        }
                    }
                    task.completions = completions
                }
                
                // Parse subtasks
                if let subtasksArray = taskDict["subtasks"] as? [[String: Any]] {
                    var subtasks: [WSubtask] = []
                    for subtaskDict in subtasksArray {
                        if let subIdString = subtaskDict["id"] as? String,
                           let subId = UUID(uuidString: subIdString),
                           let subName = subtaskDict["name"] as? String {
                            let subCompleted = subtaskDict["isCompleted"] as? Bool ?? false
                            subtasks.append(WSubtask(id: subId, name: subName, isCompleted: subCompleted))
                        }
                    }
                    task.subtasks = subtasks
                }
                
                widgetTasks.append(task)
            }
            
            // Sort by time and return clean tasks
            return widgetTasks.sorted { $0.startTime < $1.startTime }
            
        } catch {
            return []
        }
    }
    
    private func sampleTasks() -> [WTodoTask] {
        return [
            WTodoTask(
                name: "Morning Workout",
                startTime: Date(),
                category: WCategory(name: "Health", color: "#FF6B6B", icon: "heart.fill"),
                priority: .high,
                icon: "figure.run"
            ),
            WTodoTask(
                name: "Team Meeting",
                startTime: Calendar.current.date(byAdding: .hour, value: 2, to: Date())!,
                category: WCategory(name: "Work", color: "#4ECDC4", icon: "briefcase.fill"),
                priority: .medium,
                icon: "person.3.fill"
            )
        ]
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationIntent
    let tasks: [WTodoTask]
}

struct SnapTaskWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallWidgetView(tasks: entry.tasks)
            case .systemMedium:
                MediumWidgetView(tasks: entry.tasks)
            case .systemLarge:
                LargeWidgetView(tasks: entry.tasks)
            case .systemExtraLarge:
                ExtraLargeWidgetView(tasks: entry.tasks)
            @unknown default:
                SmallWidgetView(tasks: entry.tasks)
            }
        }
        .containerBackground(Color.clear, for: .widget)
    }
}

struct SmallWidgetView: View {
    let tasks: [WTodoTask]
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                HStack {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("SnapTask")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text("Today")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(completedCount)/\(tasks.count)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.blue)
                        Text("done")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                if !tasks.isEmpty {
                    ProgressView(value: Float(completedCount), total: Float(tasks.count))
                        .progressViewStyle(.linear)
                        .scaleEffect(y: 0.8)
                        .tint(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            
            if tasks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("No tasks")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if allTasksCompleted {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                    Text("All done!")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 6) {
                    let displayTasks = Array(tasks.prefix(3))
                    ForEach(displayTasks, id: \.id) { task in
                        CompactTaskRow(task: task)
                    }
                    
                    if tasks.count > 3 {
                        HStack {
                            Text("+\(tasks.count - 3) more")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 2)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 6)
            }
        }
    }
    
    private var completedCount: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return tasks.filter { task in
            task.completions[today]?.isCompleted ?? false
        }.count
    }
    
    private var allTasksCompleted: Bool {
        return !tasks.isEmpty && completedCount == tasks.count
    }
}

struct MediumWidgetView: View {
    let tasks: [WTodoTask]
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SnapTask")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("Today's Schedule")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(completedCount)/\(tasks.count)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.blue)
                    Text("completed")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            if !tasks.isEmpty {
                ProgressView(value: Float(completedCount), total: Float(tasks.count))
                    .progressViewStyle(.linear)
                    .tint(.blue)
                    .padding(.horizontal, 16)
            }
            
            if tasks.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.6))
                    VStack(spacing: 2) {
                        Text("No tasks")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Nothing scheduled")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            } else if allTasksCompleted {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.green)
                    VStack(spacing: 2) {
                        Text("Perfect!")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("All tasks completed")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                        if index < 3 { 
                            ModernTaskRow(task: task)
                        }
                    }
                    
                    if tasks.count > 3 {
                        HStack {
                            Text("+\(tasks.count - 3) more tasks")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 8)
                
                Spacer()
            }
        }
    }
    
    private var completedCount: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return tasks.filter { task in
            task.completions[today]?.isCompleted ?? false
        }.count
    }
    
    private var allTasksCompleted: Bool {
        return !tasks.isEmpty && completedCount == tasks.count
    }
}

struct LargeWidgetView: View {
    let tasks: [WTodoTask]
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SnapTask")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text(DateFormatter.widgetDayMonth.string(from: Date()))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    StatPill(title: "Total", value: "\(tasks.count)", color: .blue)
                    StatPill(title: "Done", value: "\(completedCount)", color: .green)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            
            if !tasks.isEmpty {
                ProgressView(value: Float(completedCount), total: Float(tasks.count))
                    .progressViewStyle(.linear)
                    .scaleEffect(y: 1.2)
                    .tint(.blue)
                    .padding(.horizontal, 18)
            }
            
            if tasks.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.6))
                    VStack(spacing: 4) {
                        Text("No Tasks")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Nothing scheduled today")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            } else if allTasksCompleted {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.green)
                    VStack(spacing: 4) {
                        Text("All Done!")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Great work today!")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                        if index < 5 { 
                            DetailedTaskRow(task: task)
                        }
                    }
                    
                    if tasks.count > 5 {
                        HStack {
                            Text("+\(tasks.count - 5) more tasks")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 10)
                
                Spacer()
            }
        }
    }
    
    private var completedCount: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return tasks.filter { task in
            task.completions[today]?.isCompleted ?? false
        }.count
    }
    
    private var allTasksCompleted: Bool {
        return !tasks.isEmpty && completedCount == tasks.count
    }
}

struct ExtraLargeWidgetView: View {
    let tasks: [WTodoTask]
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                HStack {
                    HStack(spacing: 16) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SnapTask")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text(DateFormatter.widgetDate.string(from: Date()))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        StatPill(title: "Total", value: "\(tasks.count)", color: .blue)
                        StatPill(title: "Done", value: "\(completedCount)", color: .green)
                        StatPill(title: "Left", value: "\(tasks.count - completedCount)", color: .orange)
                    }
                }
                
                if !tasks.isEmpty {
                    ProgressView(value: Float(completedCount), total: Float(tasks.count))
                        .progressViewStyle(.linear)
                        .scaleEffect(y: 1.4)
                        .tint(.blue)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 18)
            
            if tasks.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary.opacity(0.6))
                    VStack(spacing: 6) {
                        Text("No Tasks")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                        Text("Nothing scheduled today")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if allTasksCompleted {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.green)
                    VStack(spacing: 6) {
                        Text("Perfect Day!")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                        Text("All tasks completed!")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(tasks, id: \.id) { task in
                            PremiumTaskRow(task: task)
                        }
                    }
                    .padding(.horizontal, 14)
                }
            }
        }
    }
    
    private var completedCount: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return tasks.filter { task in
            task.completions[today]?.isCompleted ?? false
        }.count
    }
    
    private var allTasksCompleted: Bool {
        return !tasks.isEmpty && completedCount == tasks.count
    }
}

// MARK: - Task Row Components

struct CompactTaskRow: View {
    let task: WTodoTask
    
    private var isCompleted: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return task.completions[today]?.isCompleted ?? false
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isCompleted ? .green : Color.gray.opacity(0.7))
                .font(.system(size: 16, weight: .medium))
            
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    if !task.icon.isEmpty && task.icon != "circle" {
                        Image(systemName: task.icon)
                            .foregroundColor(task.category?.color.toColor() ?? .blue)
                            .font(.system(size: 11, weight: .medium))
                    }
                    
                    Text(task.name)
                        .font(.system(size: 12, weight: .medium))
                        .strikethrough(isCompleted)
                        .foregroundColor(isCompleted ? .secondary : .primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if task.hasSpecificTime {
                        Text(DateFormatter.widgetTime.string(from: task.startTime))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                if let category = task.category {
                    Text(category.name)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(category.color.toColor().opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                )
        )
    }
}

struct ModernTaskRow: View {
    let task: WTodoTask
    
    private var isCompleted: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return task.completions[today]?.isCompleted ?? false
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isCompleted ? .green : Color.gray.opacity(0.7))
                .font(.system(size: 18, weight: .medium))
            
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    if !task.icon.isEmpty && task.icon != "circle" {
                        Image(systemName: task.icon)
                            .foregroundColor(task.category?.color.toColor() ?? .blue)
                            .font(.system(size: 13, weight: .medium))
                    }
                    
                    Text(task.name)
                        .font(.system(size: 14, weight: .medium))
                        .strikethrough(isCompleted)
                        .foregroundColor(isCompleted ? .secondary : .primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if task.priority == .high {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 12))
                    }
                }
                
                HStack(spacing: 12) {
                    if task.hasSpecificTime {
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text(DateFormatter.widgetTime.string(from: task.startTime))
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    if let category = task.category {
                        Text(category.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(category.color.toColor())
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                )
        )
    }
}

struct DetailedTaskRow: View {
    let task: WTodoTask
    
    private var isCompleted: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return task.completions[today]?.isCompleted ?? false
    }
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isCompleted ? .green : Color.gray.opacity(0.7))
                .font(.system(size: 20, weight: .medium))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if !task.icon.isEmpty && task.icon != "circle" {
                        Image(systemName: task.icon)
                            .foregroundColor(task.category?.color.toColor() ?? .blue)
                            .font(.system(size: 15, weight: .medium))
                    }
                    
                    Text(task.name)
                        .font(.system(size: 15, weight: .medium))
                        .strikethrough(isCompleted)
                        .foregroundColor(isCompleted ? .secondary : .primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if task.priority == .high {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 13))
                    }
                }
                
                HStack(spacing: 14) {
                    if task.hasSpecificTime {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                            Text(DateFormatter.widgetTime.string(from: task.startTime))
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    if let category = task.category {
                        HStack(spacing: 4) {
                            Image(systemName: category.icon)
                                .font(.system(size: 11))
                            Text(category.name)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(category.color.toColor())
                    }
                    
                    if !task.subtasks.isEmpty {
                        let completedSubtasks = task.subtasks.filter(\.isCompleted).count
                        HStack(spacing: 4) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 11))
                            Text("\(completedSubtasks)/\(task.subtasks.count)")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                )
        )
    }
}

struct PremiumTaskRow: View {
    let task: WTodoTask
    
    private var isCompleted: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return task.completions[today]?.isCompleted ?? false
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isCompleted ? .green : Color.gray.opacity(0.7))
                .font(.system(size: 22, weight: .medium))
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    if !task.icon.isEmpty && task.icon != "circle" {
                        Image(systemName: task.icon)
                            .foregroundColor(task.category?.color.toColor() ?? .blue)
                            .font(.system(size: 17, weight: .medium))
                    }
                    
                    Text(task.name)
                        .font(.system(size: 16, weight: .medium))
                        .strikethrough(isCompleted)
                        .foregroundColor(isCompleted ? .secondary : .primary)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    if task.priority == .high {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 15))
                    }
                }
                
                HStack(spacing: 16) {
                    if task.hasSpecificTime {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                            Text(DateFormatter.widgetTime.string(from: task.startTime))
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    if let category = task.category {
                        HStack(spacing: 4) {
                            Image(systemName: category.icon)
                                .font(.system(size: 12))
                            Text(category.name)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(category.color.toColor())
                    }
                    
                    if !task.subtasks.isEmpty {
                        let completedSubtasks = task.subtasks.filter(\.isCompleted).count
                        HStack(spacing: 4) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 12))
                            Text("\(completedSubtasks)/\(task.subtasks.count)")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                )
        )
    }
}

struct StatPill: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.2), lineWidth: 0.5)
                )
        )
    }
}

struct SnapTaskWidget: Widget {
    let kind: String = "SnapTaskWidget"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider()) { entry in
            SnapTaskWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("SnapTask")
        .description("View your daily tasks at a glance")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let widgetTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    static let widgetDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }()
    
    static let widgetDayMonth: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()
}

extension String {
    func toColor() -> Color {
        if hasPrefix("#") {
            let hex = String(dropFirst())
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
            
            return Color(
                .sRGB,
                red: Double(r) / 255,
                green: Double(g) / 255,
                blue:  Double(b) / 255,
                opacity: Double(a) / 255
            )
        }
        return .blue
    }
}

struct SnapTaskWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SnapTaskWidgetEntryView(entry: SimpleEntry(
                date: Date(),
                configuration: ConfigurationIntent(),
                tasks: [
                    WTodoTask(
                        name: "Morning Workout",
                        startTime: Date(),
                        category: WCategory(name: "Health", color: "#FF6B6B", icon: "heart.fill"),
                        priority: .high,
                        icon: "figure.run"
                    ),
                    WTodoTask(
                        name: "Team Meeting",
                        startTime: Calendar.current.date(byAdding: .hour, value: 2, to: Date())!,
                        category: WCategory(name: "Work", color: "#4ECDC4", icon: "briefcase.fill"),
                        priority: .medium,
                        icon: "person.3.fill"
                    )
                ]
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            
            SnapTaskWidgetEntryView(entry: SimpleEntry(
                date: Date(),
                configuration: ConfigurationIntent(),
                tasks: []
            ))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
        }
    }
}
