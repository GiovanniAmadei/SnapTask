import Foundation
import EventKit

// MARK: - Calendar Integration Models
struct CalendarIntegrationSettings: Codable {
    var isEnabled: Bool = false
    var provider: CalendarProvider = .apple
    var selectedCalendarId: String?
    var selectedCalendarName: String?
    var autoSyncOnTaskCreate: Bool = true
    var autoSyncOnTaskUpdate: Bool = true
    var autoSyncOnTaskComplete: Bool = false
    var syncRecurringTasks: Bool = true
}

enum CalendarProvider: String, CaseIterable, Codable {
    case apple = "apple"
    case google = "google"
    
    var displayName: String {
        switch self {
        case .apple: return "Apple Calendar"
        case .google: return "Google Calendar"
        }
    }
    
    var iconName: String {
        switch self {
        case .apple: return "calendar"
        case .google: return "calendar.badge.clock"
        }
    }
}

// MARK: - Calendar Event Models
struct CalendarEvent: Identifiable {
    let id = UUID()
    let title: String
    let startDate: Date
    let endDate: Date
    let notes: String?
    let calendarId: String
    let isAllDay: Bool
    let recurrenceRule: String?
}

// MARK: - Google Calendar Models
struct GoogleCalendar: Identifiable, Codable {
    let id: String
    let summary: String
    let description: String?
    let backgroundColor: String?
    let foregroundColor: String?
    let accessRole: String?
}

struct GoogleCalendarEvent: Codable {
    let id: String?
    let summary: String
    let description: String?
    let start: GoogleDateTime
    let end: GoogleDateTime
    let recurrence: [String]?
}

struct GoogleDateTime: Codable {
    let date: String?
    let dateTime: String?
    let timeZone: String?
}