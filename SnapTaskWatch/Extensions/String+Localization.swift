import Foundation

// MARK: - String Localization Extension for Watch
// Simplified version without LanguageManager dependency
extension String {
    
    private static let watchFallbackStrings: [String: String] = [
        // Priority
        "low_priority": "Low",
        "medium_priority": "Medium",
        "high_priority": "High",
        "priority": "Priority",
        // Task
        "task_name": "Task Name",
        "task_description": "Description",
        "task_category": "Category",
        "task_priority": "Priority",
        "task_duration": "Duration",
        "task_recurrence": "Recurrence",
        "subtasks": "Subtasks",
        "add_subtask": "Add Subtask",
        "no_subtasks": "No Subtasks",
        "task_completed": "Task Completed",
        // General
        "delete": "Delete",
        "cancel": "Cancel",
        "save": "Save",
        "edit": "Edit",
        "done": "Done",
        "add": "Add",
        "none": "None",
        "daily": "Daily",
        "weekly": "Weekly",
        "monthly": "Monthly",
        "yearly": "Yearly",
        "points": "Points",
        "no_tasks": "No tasks",
        "no_rewards": "No rewards",
        "start_timer": "Start Timer",
        "icon": "Icon",
        "time": "Time",
        "name": "Name",
        "category": "Category",
    ]
    
    var localized: String {
        let result = NSLocalizedString(self, comment: "")
        // If NSLocalizedString returns the key itself, use fallback
        if result == self, let fallback = String.watchFallbackStrings[self] {
            return fallback
        }
        return result
    }
    
    func localized(with arguments: CVarArg...) -> String {
        return String(format: self.localized, arguments: arguments)
    }
}
