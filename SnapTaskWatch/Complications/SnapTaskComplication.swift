import WidgetKit
import SwiftUI

// MARK: - Complication Entry
struct TaskComplicationEntry: TimelineEntry {
    let date: Date
    let tasksRemaining: Int
    let tasksCompleted: Int
    let nextTask: TaskInfo?
    let currentStreak: Int
    
    struct TaskInfo {
        let name: String
        let time: Date?
        let icon: String
        let categoryColor: String?
    }
    
    static var placeholder: TaskComplicationEntry {
        TaskComplicationEntry(
            date: Date(),
            tasksRemaining: 5,
            tasksCompleted: 3,
            nextTask: TaskInfo(name: "Sample Task", time: Date(), icon: "star.fill", categoryColor: "#4F46E5"),
            currentStreak: 7
        )
    }
}

// MARK: - Timeline Provider
struct TaskComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> TaskComplicationEntry {
        .placeholder
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TaskComplicationEntry) -> Void) {
        let entry = createEntry()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TaskComplicationEntry>) -> Void) {
        let entry = createEntry()
        
        // Update every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
    
    private func createEntry() -> TaskComplicationEntry {
        let tasks = WatchSyncManager.getTasksForComplications()
        let calendar = Calendar.current
        let today = Date()
        let startOfDay = calendar.startOfDay(for: today)
        
        // Filter today's tasks
        let todaysTasks = tasks.filter { task in
            if let recurrence = task.recurrence {
                return recurrence.shouldOccurOn(date: today)
            } else {
                return calendar.isDate(task.startTime, inSameDayAs: today)
            }
        }
        
        let completedCount = todaysTasks.filter { task in
            task.completions[startOfDay]?.isCompleted == true
        }.count
        
        let remainingCount = todaysTasks.count - completedCount
        
        // Find next upcoming task
        let upcomingTasks = todaysTasks
            .filter { task in
                task.completions[startOfDay]?.isCompleted != true &&
                task.hasSpecificTime &&
                task.startTime > today
            }
            .sorted { $0.startTime < $1.startTime }
        
        let nextTask: TaskComplicationEntry.TaskInfo?
        if let next = upcomingTasks.first {
            nextTask = TaskComplicationEntry.TaskInfo(
                name: next.name,
                time: next.startTime,
                icon: next.icon,
                categoryColor: next.category?.color
            )
        } else {
            nextTask = nil
        }
        
        // Calculate streak (simplified)
        var streak = 0
        for dayOffset in 0..<365 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { break }
            let dayStart = calendar.startOfDay(for: date)
            
            let dayTasks = tasks.filter { task in
                if let recurrence = task.recurrence {
                    return recurrence.shouldOccurOn(date: date)
                } else {
                    return calendar.isDate(task.startTime, inSameDayAs: date)
                }
            }
            
            if dayTasks.isEmpty { continue }
            
            let allCompleted = dayTasks.allSatisfy { task in
                task.completions[dayStart]?.isCompleted == true
            }
            
            if allCompleted {
                streak += 1
            } else {
                break
            }
        }
        
        return TaskComplicationEntry(
            date: today,
            tasksRemaining: remainingCount,
            tasksCompleted: completedCount,
            nextTask: nextTask,
            currentStreak: streak
        )
    }
}

// MARK: - Circular Complication View
struct CircularComplicationView: View {
    let entry: TaskComplicationEntry
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            
            VStack(spacing: 0) {
                Text("\(entry.tasksRemaining)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                
                Text("left")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Rectangular Complication View
struct RectangularComplicationView: View {
    let entry: TaskComplicationEntry
    
    var body: some View {
        HStack(spacing: 8) {
            // Task count
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "checklist")
                        .font(.caption2)
                    Text("\(entry.tasksCompleted)/\(entry.tasksCompleted + entry.tasksRemaining)")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                }
                
                if let nextTask = entry.nextTask {
                    HStack(spacing: 4) {
                        if let time = nextTask.time {
                            Text(time, style: .time)
                                .font(.system(size: 10))
                        }
                        Text(nextTask.name)
                            .font(.system(size: 10))
                            .lineLimit(1)
                    }
                    .foregroundColor(.secondary)
                } else {
                    Text("No upcoming tasks")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Streak
            if entry.currentStreak > 0 {
                VStack(spacing: 0) {
                    Image(systemName: "flame.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("\(entry.currentStreak)")
                        .font(.system(size: 10, weight: .bold))
                }
            }
        }
    }
}

// MARK: - Corner Complication View
struct CornerComplicationView: View {
    let entry: TaskComplicationEntry
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            
            Image(systemName: "checklist")
                .font(.caption)
        }
        .widgetLabel {
            Text("\(entry.tasksRemaining)")
        }
    }
}

// MARK: - Inline Complication View
struct InlineComplicationView: View {
    let entry: TaskComplicationEntry
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checklist")
            Text("\(entry.tasksRemaining) tasks left")
        }
    }
}

// MARK: - Widget Configuration
struct SnapTaskComplication: Widget {
    let kind: String = "SnapTaskComplication"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TaskComplicationProvider()) { entry in
            ComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("SnapTask")
        .description("View your tasks at a glance")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryCorner,
            .accessoryInline
        ])
    }
}

struct ComplicationEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: TaskComplicationEntry
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularComplicationView(entry: entry)
        case .accessoryRectangular:
            RectangularComplicationView(entry: entry)
        case .accessoryCorner:
            CornerComplicationView(entry: entry)
        case .accessoryInline:
            InlineComplicationView(entry: entry)
        default:
            CircularComplicationView(entry: entry)
        }
    }
}

// MARK: - Preview
#Preview(as: .accessoryCircular) {
    SnapTaskComplication()
} timeline: {
    TaskComplicationEntry.placeholder
}

#Preview(as: .accessoryRectangular) {
    SnapTaskComplication()
} timeline: {
    TaskComplicationEntry.placeholder
}
