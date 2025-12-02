import Foundation
import AppIntents
import WidgetKit

struct ToggleTaskCompletionIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Task Completion"
    static var description = IntentDescription("Completa o annulla il completamento di una task per oggi")

    @Parameter(title: "Task ID")
    var taskIdString: String

    init() {}
    init(taskId: String) { self.taskIdString = taskId }

    func perform() async throws -> some IntentResult {
        guard let taskId = UUID(uuidString: taskIdString) else { return .result() }
        let suite = UserDefaults(suiteName: "group.com.snapTask.shared")
        let key = "savedTasks"
        guard let data = suite?.data(forKey: key) else { return .result() }
        do {
            var tasks = try JSONDecoder().decode([TodoTask].self, from: data)
            if let idx = tasks.firstIndex(where: { $0.id == taskId }) {
                var task = tasks[idx]
                let today = Date()
                let completionDate = task.completionKey(for: today)
                var completion = task.completions[completionDate] ?? TaskCompletion(isCompleted: false, completedSubtasks: [])
                completion.isCompleted.toggle()
                task.completions[completionDate] = completion
                if completion.isCompleted {
                    if !task.completionDates.contains(completionDate) { task.completionDates.append(completionDate) }
                } else {
                    task.completionDates.removeAll { $0 == completionDate }
                }
                tasks[idx] = task
                let newData = try JSONEncoder().encode(tasks)
                suite?.set(newData, forKey: key)
                suite?.synchronize()
                WidgetCenter.shared.reloadAllTimelines()
            }
        } catch {
            // Ignore errors in intent context
        }
        return .result()
    }
}
