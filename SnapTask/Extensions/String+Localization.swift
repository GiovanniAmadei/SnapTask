import Foundation
import SwiftUI

extension String {
    /// Returns the localized version of the string using dynamic language manager
    var localized: String {
        let languageCode = LanguageManager.shared.actualLanguageCode
        
        // Use Bundle's built-in localization system
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            let localizedString = NSLocalizedString(self, bundle: bundle, comment: "")
            if localizedString != self {
                return localizedString
            }
        }
        
        // Fallback to main bundle (system default)
        return NSLocalizedString(self, comment: "")
    }
    
    /// Returns the localized version of the string with format arguments
    func localized(_ arguments: CVarArg...) -> String {
        return String(format: localized, arguments: arguments)
    }
}

// MARK: - Dynamic Localized Strings
extension String {
    // Common actions - computed properties that update automatically
    static var cancel: String { "cancel".localized }
    static var save: String { "save".localized }
    static var edit: String { "edit".localized }
    static var delete: String { "delete".localized }
    static var done: String { "done".localized }
    static var add: String { "add".localized }
    
    // Main tabs - computed properties that update automatically
    static var timeline: String { "timeline".localized }
    static var focus: String { "focus".localized }
    static var rewards: String { "rewards".localized }
    static var statistics: String { "statistics".localized }
    static var settings: String { "settings".localized }
    
    // Task related
    static var task: String { "task".localized }
    static var tasks: String { "tasks".localized }
    static var newTask: String { "new_task".localized }
    static var editTask: String { "edit_task".localized }
    static var taskName: String { "task_name".localized }
    static var taskDescription: String { "task_description".localized }
    static var taskCategory: String { "task_category".localized }
    static var taskPriority: String { "task_priority".localized }
    static var taskDuration: String { "task_duration".localized }
    static var taskRecurrence: String { "task_recurrence".localized }
    static var subtasks: String { "subtasks".localized }
    static var addSubtask: String { "add_subtask".localized }
    static var noSubtasks: String { "no_subtasks".localized }
    static var taskCompleted: String { "task_completed".localized }
    static var highPriority: String { "high_priority".localized }
    static var mediumPriority: String { "medium_priority".localized }
    static var lowPriority: String { "low_priority".localized }
    static var noTasksToday: String { "no_tasks_today".localized }
    static var taskDetails: String { "task_details".localized }
    static var dueTasks: String { "due_tasks".localized }
    static var noTasksDue: String { "no_tasks_due".localized }
    static var allCaughtUp: String { "all_caught_up".localized }

    // Days of the week
    static var monday: String { "monday".localized }
    static var tuesday: String { "tuesday".localized }
    static var wednesday: String { "wednesday".localized }
    static var thursday: String { "thursday".localized }
    static var friday: String { "friday".localized }
    static var saturday: String { "saturday".localized }
    static var sunday: String { "sunday".localized }

    // Recurrence
    static var daily: String { "daily".localized }
    static var weekly: String { "weekly".localized }
    static var monthly: String { "monthly".localized }
    
    static var today: String { "today".localized }
    
    // Categories
    static var categories: String { "categories".localized }
    static var addCategory: String { "add_category".localized }
    static var editCategory: String { "edit_category".localized }
    static var newCategory: String { "new_category".localized }
    static var categoryName: String { "category_name".localized }
    static var categoryColor: String { "category_color".localized }
    static var addNewCategory: String { "add_new_category".localized }
    static var selectCategory: String { "select_category".localized }
    
    // Pomodoro
    static var pomodoro: String { "pomodoro".localized }
    static var workDuration: String { "work_duration".localized }
    static var shortBreak: String { "short_break".localized }
    static var longBreak: String { "long_break".localized }
    static var sessionsBeforeLongBreak: String { "sessions_before_long_break".localized }
    
    // Rewards
    static var availablePoints: String { "available_points".localized }
    static var redeem: String { "redeem".localized }
    
    // General UI
    static var description: String { "description".localized }
    static var color: String { "color".localized }
    static var icon: String { "icon".localized }
    static var points: String { "points".localized }

    static var searchLocation: String { "search_location".localized }
    static var searchForAPlace: String { "search_for_a_place".localized }
    static var searching: String { "searching".localized }
    static var noResultsFound: String { "no_results_found".localized }
    static var selectedLocation: String { "selected_location".localized }
    static var removeLocation: String { "remove_location".localized }
    static var selectLocation: String { "select_location".localized }
    static var pickLocation: String { "pick_location".localized }
    static var current: String { "current".localized }
    static var gettingLocationInfo: String { "getting_location_info".localized }
    static var select: String { "select".localized }
    static var loadingMap: String { "loading_map".localized }
    static var syncing: String { "syncing".localized }
    static var settingUpSync: String { "setting_up_sync".localized }
    static var loadingInspiration: String { "loading_inspiration".localized }
    static var syncTokenExpired: String { "sync_token_expired".localized }
    static var syncStateMismatch: String { "sync_state_mismatch".localized }
    static var zoneMissingRecreating: String { "zone_missing_recreating".localized }
    static var untitledTask: String { "untitled_task".localized }
    static var user: String { "user".localized }
    static var last: String { "last".localized }
    static var syncIdle: String { "sync_idle".localized }
    static var syncSuccess: String { "sync_success".localized }
    static var syncError: String { "sync_error".localized }
    static var backup: String { "backup".localized }
    static var restore: String { "restore".localized }
    static var exportAllData: String { "export_all_data".localized }
    static var exportBackup: String { "export_backup".localized }
    static var restoreFromBackup: String { "restore_from_backup".localized }
    static var willOverwriteData: String { "will_overwrite_data".localized }
    static var importBackup: String { "import_backup".localized }
    static var operationSuccess: String { "operation_success".localized }
    static var freePlanLimits: String { "free_plan_limits".localized }
    static var categoriesLimitMessage: String { "categories_limit_message".localized }
    static var errorLoadingCategories: String { "error_loading_categories".localized }
    static var errorLoadingRewards: String { "error_loading_rewards".localized }
    static var errorLoadingTasks: String { "error_loading_tasks".localized }
    static var errorLoadingTrackingSessions: String { "error_loading_tracking_sessions".localized }
    static var stop: String { "stop".localized }
}