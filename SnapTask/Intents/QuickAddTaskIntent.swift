import Foundation
import AppIntents

/// Adds a new task to SnapTask without opening the app.
///
/// Entry points (the Control Center button uses `OpenQuickAddIntent` instead):
/// - Action Button (iOS 17.2+ on iPhone 15 Pro and later) via `SnapTaskAppShortcuts`.
/// - Siri ("Add task in SnapTask").
/// - Shortcuts app / Spotlight / Automations.
///
/// In interactive contexts (Siri, Action Button, Shortcuts, compatible
/// automations) the system can prompt for the task name at runtime.
///
/// Main app target only: it adds the task through `TaskManager`.
struct QuickAddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Quick Task"
    static var description = IntentDescription(
        "Quickly add a new task to your SnapTask timeline.",
        categoryName: "tasks"
    )

    /// Runs in the background: Siri just confirms the task, without opening the app.
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

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let taskName else {
            throw $taskName.requestValue("What do you want to do?")
        }

        let trimmed = taskName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw $taskName.requestValue("What do you want to do?")
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

        // Added through the app's TaskManager, like a task created in the app. Before, the
        // intent wrote the task straight into the shared container: the app, holding its own
        // copy of the tasks in memory, overwrote it at its next save, so the task vanished,
        // and it never reached iCloud either.
        let manager = TaskManager.shared
        await manager.addTask(newTask)
        guard let saved = manager.tasks.first(where: { $0.id == newTask.id }) else {
            return .result(dialog: "Could not save the task.")
        }
        // Sent to iCloud now: Siri runs this with the app in the background, which can be
        // suspended before the save that `addTask` schedules a second later.
        CloudKitService.shared.saveTask(saved)

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
