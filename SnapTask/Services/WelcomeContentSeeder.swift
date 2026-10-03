import Foundation

/// First-launch content: three starter categories and two "learn by doing" tasks.
///
/// Runs once, when the welcome screen is completed on a fresh install, and only if the user has
/// no tasks and no categories after the first iCloud sync (someone reinstalling gets their own
/// data back instead). Fixed identifiers keep two devices from creating duplicates.
@MainActor
enum WelcomeContentSeeder {
    private static let seededKey = "welcomeContentSeeded"

    static let workCategoryId = UUID(uuidString: "5E1C0A7E-0001-4A11-9C0D-57A27E0C0001")!
    static let personalCategoryId = UUID(uuidString: "5E1C0A7E-0002-4A11-9C0D-57A27E0C0002")!
    static let healthCategoryId = UUID(uuidString: "5E1C0A7E-0003-4A11-9C0D-57A27E0C0003")!
    static let firstTaskId = UUID(uuidString: "5E1C0A7E-1001-4A11-9C0D-57A27E0C1001")!
    static let secondTaskId = UUID(uuidString: "5E1C0A7E-1002-4A11-9C0D-57A27E0C1002")!

    /// Called when the onboarding finishes.
    static func seedIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: seededKey) else { return }
        defaults.set(true, forKey: seededKey)

        Task { @MainActor in
            await waitForFirstSync()
            let taskManager = TaskManager.shared
            let categoryManager = CategoryManager.shared
            // Existing data (e.g. restored from iCloud): leave it untouched.
            guard taskManager.tasks.isEmpty, categoryManager.categories.isEmpty else { return }

            let categories = starterCategories
            for category in categories {
                categoryManager.addCategory(category)
            }
            let personal = categories.first { $0.id == personalCategoryId }

            let first = firstTask(category: personal)
            let second = secondTask()
            await taskManager.addTask(first)
            await taskManager.addTask(second)

            // The guide comes first in the day's default order.
            if let listKey = TaskOrderManager.listKey(scope: .today, date: Date()) {
                TaskOrderManager.shared.setOrder([first.id, second.id], listKey: listKey)
            }
        }
    }

    /// Gives iCloud a few seconds to bring back an existing account's data.
    private static func waitForFirstSync() async {
        let cloud = CloudKitService.shared
        guard cloud.isCloudKitEnabled else { return }
        for _ in 0..<16 {
            if cloud.syncStatus == .success || cloud.syncStatus.description.contains("error") { return }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }

    private static var starterCategories: [Category] {
        [
            Category(id: workCategoryId, name: "starter_category_work".localized, color: "#3B82F6", icon: "briefcase.fill"),
            Category(id: personalCategoryId, name: "starter_category_personal".localized, color: "#F97316", icon: "person.fill"),
            Category(id: healthCategoryId, name: "starter_category_health".localized, color: "#10B981", icon: "heart.fill")
        ]
    }

    /// How to use a task: states, detail (photo, audio), swipe actions, reordering, points.
    private static func firstTask(category: Category?) -> TodoTask {
        let calendar = Calendar.current
        let now = Date()
        let minute = calendar.component(.minute, from: now)
        let next = calendar.date(byAdding: .minute, value: minute < 30 ? 30 - minute : 60 - minute, to: now) ?? now
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: next)
        let start = calendar.date(from: parts) ?? next

        let steps = (1...6).map { Subtask(name: "welcome_task1_step\($0)".localized) }
        return TodoTask(
            id: firstTaskId,
            name: "welcome_task1_title".localized,
            description: "welcome_task1_description".localized,
            startTime: start,
            hasSpecificDay: true,
            hasSpecificTime: true,
            duration: 15 * 60,
            hasDuration: true,
            category: category,
            priority: .high,
            icon: "hand.wave.fill",
            subtasks: steps,
            hasRewardPoints: true,
            rewardPoints: 10,
            timeScope: .today
        )
    }

    /// How to move around the app: scopes, inbox, journal, calendar, views, categories, creating.
    private static func secondTask() -> TodoTask {
        let steps = (1...7).map { Subtask(name: "welcome_task2_step\($0)".localized) }
        return TodoTask(
            id: secondTaskId,
            name: "welcome_task2_title".localized,
            description: "welcome_task2_description".localized,
            startTime: Calendar.current.startOfDay(for: Date()),
            hasSpecificDay: true,
            hasSpecificTime: false,
            priority: .medium,
            icon: "map.fill",
            subtasks: steps,
            timeScope: .today
        )
    }
}
