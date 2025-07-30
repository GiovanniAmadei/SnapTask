import Foundation
import SwiftUI

extension String {
    /// Returns the localized version of the string
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    /// Returns the localized version of the string with format arguments
    func localized(_ arguments: CVarArg...) -> String {
        return String(format: localized, arguments: arguments)
    }
}

// MARK: - Common Localized Strings for Watch App
extension String {
    // Common actions
    static var cancel: String { "cancel".localized }
    static var save: String { "save".localized }
    static var edit: String { "edit".localized }
    static var delete: String { "delete".localized }
    static var done: String { "done".localized }
    static var add: String { "add".localized }
    static var close: String { "close".localized }
    
    // Common UI elements
    static var today: String { "today".localized }
    static var focus: String { "focus".localized }
    static var break: String { "break".localized }
    static var session: String { "session".localized }
    static var complete: String { "complete".localized }
    static var start: String { "start".localized }
    static var pause: String { "pause".localized }
    static var resume: String { "resume".localized }
    static var stop: String { "stop".localized }
    static var reset: String { "reset".localized }
    
    // Time and dates
    static var selectDate: String { "select_date".localized }
    static var yesterday: String { "yesterday".localized }
    static var tomorrow: String { "tomorrow".localized }
    
    // Tasks and categories
    static var tasks: String { "tasks".localized }
    static var categories: String { "categories".localized }
    static var category: String { "category".localized }
    static var priority: String { "priority".localized }
    static var taskName: String { "task_name".localized }
    
    // Statistics and progress
    static var stats: String { "stats".localized }
    static var statistics: String { "statistics".localized }
    static var progress: String { "progress".localized }
    static var points: String { "points".localized }
    
    // Pomodoro
    static var pomodoro: String { "pomodoro".localized }
    static var focusTime: String { "focus_time".localized }
    static var breakTime: String { "break_time".localized }
    static var sessionOverview: String { "session_overview".localized }
    
    // Watch specific
    static var generalTimer: String { "general_timer".localized }
    static var simpleTimer: String { "simple_timer".localized }
    static var selectTask: String { "select_task".localized }
    static var taskNotFound: String { "task_not_found".localized }
}