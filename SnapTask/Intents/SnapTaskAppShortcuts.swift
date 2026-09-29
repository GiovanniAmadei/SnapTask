import AppIntents

/// Exposes SnapTask's App Intents to the system so they appear in:
/// - Settings → Action Button → Shortcut (iPhone 15 Pro and later)
/// - Shortcuts app
/// - Siri ("Add task in SnapTask")
/// - Spotlight search
///
/// NOTE: Phrases MUST include `\(.applicationName)` at least once per
/// entry, otherwise Siri will silently refuse to register them.
struct SnapTaskAppShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor { .purple }

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickAddTaskIntent(),
            phrases: [
                "Add task to \(.applicationName)",
                "Add a task in \(.applicationName)",
                "Quick add in \(.applicationName)",
                "New task in \(.applicationName)",
                "Capture task in \(.applicationName)"
            ],
            shortTitle: "Quick Add Task",
            systemImageName: "plus.circle.fill"
        )

        AppShortcut(
            intent: ShowTodayTasksIntent(),
            phrases: [
                "Show today's tasks in \(.applicationName)",
                "What do I have today in \(.applicationName)",
                "Today's tasks from \(.applicationName)",
                "What's on my \(.applicationName) today",
                "List today's tasks in \(.applicationName)",
                "What do I have to do today in \(.applicationName)",
                "What are my tasks for today in \(.applicationName)",
                "Read today's tasks from \(.applicationName)",
                "My \(.applicationName) tasks for today",
                "\(.applicationName) tasks today"
            ],
            shortTitle: "Today's Tasks",
            systemImageName: "list.bullet.rectangle"
        )
    }
}
