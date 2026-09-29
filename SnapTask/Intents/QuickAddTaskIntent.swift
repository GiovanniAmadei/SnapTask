import Foundation
import AppIntents
import WidgetKit

/// Adds a new task to SnapTask without opening the app.
///
/// Entry points:
/// - Control Center / Lock Screen / Action Button via `ControlWidgetButton`.
/// - Action Button (iOS 17.2+ on iPhone 15 Pro and later) via `SnapTaskAppShortcuts`.
/// - Siri ("Add task in SnapTask").
/// - Shortcuts app / Spotlight / Automations.
///
/// In interactive contexts (Siri, Action Button, Shortcuts, compatible
/// automations) the system can prompt for the task name at runtime.
struct QuickAddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Quick Task"
    static var description = IntentDescription(
        "Quickly add a new task to your SnapTask timeline.",
        categoryName: "Tasks"
    )

    /// Don't pop the app; we just write to the App Group and reload widgets.
    static var openAppWhenRun: Bool = false

    @Parameter(
        title: "Task",
        description: "What do you want to do?",
        requestValueDialog: IntentDialog("What do you want to do?")
    )
    var taskName: String?

    init() {}

    init(taskName: String) {
        self.taskName = taskName
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Add task to SnapTask")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let taskName else {
            throw $taskName.requestValue("What do you want to do?")
        }

        let trimmed = taskName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw $taskName.requestValue("What do you want to do?")
        }

        guard let suite = UserDefaults(suiteName: "group.com.snapTask.shared") else {
            return .result(dialog: "Could not access SnapTask data.")
        }

        let key = "savedTasks"

        // Load existing tasks (may be empty if this is the first run).
        var tasks: [TodoTask] = []
        if let data = suite.data(forKey: key) {
            do {
                tasks = try JSONDecoder().decode([TodoTask].self, from: data)
            } catch {
                // If decoding fails we continue with an empty array rather
                // than losing the quick capture attempt.
                tasks = []
            }
        }

        // Build a minimal task scoped to "today" with no specific time.
        let now = Date()
        let newTask = TodoTask(
            id: UUID(),
            name: trimmed,
            description: nil,
            location: nil,
            startTime: now,
            hasSpecificDay: true,
            hasSpecificTime: false,
            duration: 0,
            hasDuration: false,
            category: nil,
            priority: .medium,
            icon: "circle",
            recurrence: nil,
            pomodoroSettings: nil,
            subtasks: [],
            hasRewardPoints: false,
            rewardPoints: 0,
            hasNotification: false,
            notificationId: nil,
            timeScope: .today,
            scopeStartDate: nil,
            scopeEndDate: nil,
            photoPath: nil,
            photoThumbnailPath: nil,
            photos: [],
            voiceMemos: [],
            notificationLeadTimeMinutes: 0,
            autoCarryOver: false,
            domainId: nil,
            goalId: nil
        )

        tasks.append(newTask)

        do {
            let data = try JSONEncoder().encode(tasks)
            suite.set(data, forKey: key)
            suite.synchronize()

            // Drop a marker the app can read on next foreground to refresh.
            suite.set(Date().timeIntervalSince1970, forKey: "lastQuickAddTimestamp")

            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            return .result(dialog: "Could not save the task.")
        }

        let successMessage = String(
            format: String(localized: "Added \"%@\" to SnapTask."),
            locale: Locale.current,
            trimmed
        )

        return .result(
            dialog: IntentDialog(stringLiteral: successMessage)
        )
    }
}
