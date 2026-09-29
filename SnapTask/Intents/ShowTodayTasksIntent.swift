import Foundation
import AppIntents

/// Reads today's tasks from the shared App Group and speaks/presents
/// them back to the user. Designed for Siri ("What do I have today
/// on SnapTask?") but also discoverable from the Shortcuts app,
/// Spotlight, and the Action Button via `SnapTaskAppShortcuts`.
///
/// Does NOT open the app – it just returns a dialog.
struct ShowTodayTasksIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Today's Tasks"
    static var description = IntentDescription(
        LocalizedStringResource("Lists the tasks you have planned for today."),
        categoryName: "Tasks"
    )

    static var openAppWhenRun: Bool = false

    init() {}

    static var parameterSummary: some ParameterSummary {
        Summary("Show today's tasks in SnapTask")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let suite = UserDefaults(suiteName: "group.com.snapTask.shared"),
              let data = suite.data(forKey: "savedTasks") else {
            return .result(dialog: IntentDialog(
                LocalizedStringResource("You don't have any tasks yet in SnapTask.")
            ))
        }

        let tasks: [TodoTask]
        do {
            tasks = try JSONDecoder().decode([TodoTask].self, from: data)
        } catch {
            return .result(dialog: IntentDialog(
                LocalizedStringResource("Could not read your SnapTask tasks.")
            ))
        }

        let today = Date()

        // Mirror the Timeline behaviour: show tasks scoped to today
        // (either one-off with matching day or recurring occurring today).
        let todayTasks = tasks.filter { task in
            guard task.timeScope == .today else { return false }
            return task.occurs(on: today)
        }

        if todayTasks.isEmpty {
            return .result(dialog: IntentDialog(
                LocalizedStringResource("You have no tasks for today. Enjoy!")
            ))
        }

        // Split into pending and completed for today.
        let pending = todayTasks.filter { task in
            let key = task.completionKey(for: today)
            return !(task.completions[key]?.isCompleted ?? false)
        }
        let completedCount = todayTasks.count - pending.count

        if pending.isEmpty {
            let msg = String(
                format: String(localized: "All your %lld tasks for today are done. Great job!"),
                locale: Locale.current,
                todayTasks.count
            )
            return .result(dialog: IntentDialog(stringLiteral: msg))
        }

        // Build a concise list – cap at 10 entries so Siri doesn't
        // read forever; append a "+N more" summary line if needed.
        let maxEntries = 10
        let shown = Array(pending.prefix(maxEntries))
        let namesList = shown.map { "• \($0.name)" }.joined(separator: "\n")

        let header: String
        if completedCount > 0 {
            header = String(
                format: String(localized: "You have %lld tasks left for today (%lld already done):"),
                locale: Locale.current,
                pending.count,
                completedCount
            )
        } else {
            header = String(
                format: String(localized: "You have %lld tasks for today:"),
                locale: Locale.current,
                pending.count
            )
        }

        var body = "\(header)\n\(namesList)"

        if pending.count > maxEntries {
            let more = String(
                format: String(localized: "…and %lld more."),
                locale: Locale.current,
                pending.count - maxEntries
            )
            body += "\n\(more)"
        }

        return .result(dialog: IntentDialog(stringLiteral: body))
    }
}
