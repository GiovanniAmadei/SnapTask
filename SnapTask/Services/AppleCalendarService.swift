import Foundation
import EventKit
import Combine
import SwiftUI
import UIKit

@MainActor
class AppleCalendarService: ObservableObject {
    static let shared = AppleCalendarService()
    
    private let eventStore = EKEventStore()
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var availableCalendars: [EKCalendar] = []
    
    private init() {
        checkAuthorizationStatus()
    }
    
    func checkAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        print("📅 Calendar authorization status: \(authorizationStatus.rawValue) (\(authorizationStatusString))")
        if authorizationStatus == .authorized || authorizationStatus == .fullAccess || authorizationStatus == .writeOnly {
            loadCalendars()
        }
    }
    
    private var authorizationStatusString: String {
        switch authorizationStatus {
        case .notDetermined: return "Not Determined"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorized: return "Authorized"
        case .fullAccess: return "Full Access"
        case .writeOnly: return "Write Only"
        @unknown default: return "Unknown"
        }
    }
    
    func requestAccess() async -> Bool {
        let currentStatus = EKEventStore.authorizationStatus(for: .event)
        print("📅 Current status before request: \(currentStatus.rawValue)")
        
        // If already authorized, just return true
        if currentStatus == .authorized || currentStatus == .fullAccess || currentStatus == .writeOnly {
            await MainActor.run {
                self.authorizationStatus = currentStatus
                self.loadCalendars()
            }
            return true
        }
        
        if #available(iOS 17.0, *) {
            return await withCheckedContinuation { continuation in
                eventStore.requestFullAccessToEvents { granted, error in
                    Task { @MainActor in
                        let newStatus = EKEventStore.authorizationStatus(for: .event)
                        print("📅 New status after request: \(newStatus.rawValue), granted: \(granted)")
                        
                        self.authorizationStatus = newStatus
                        if (granted && error == nil) || newStatus == .writeOnly {
                            self.loadCalendars()
                            continuation.resume(returning: true)
                        } else {
                            print("❌ Calendar access denied: \(error?.localizedDescription ?? "Unknown error")")
                            continuation.resume(returning: false)
                        }
                    }
                }
            }
        } else {
            return await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, error in
                    Task { @MainActor in
                        let newStatus = EKEventStore.authorizationStatus(for: .event)
                        print("📅 New status after request: \(newStatus.rawValue), granted: \(granted)")
                        
                        self.authorizationStatus = newStatus
                        if granted && error == nil {
                            self.loadCalendars()
                            continuation.resume(returning: true)
                        } else {
                            print("❌ Calendar access denied: \(error?.localizedDescription ?? "Unknown error")")
                            continuation.resume(returning: false)
                        }
                    }
                }
            }
        }
    }
    
    private func loadCalendars() {
        availableCalendars = eventStore.calendars(for: .event)
            .filter { $0.allowsContentModifications }
    }

    // MARK: - Reading events

    /// Reading events needs full access; write-only access is not enough.
    var canReadEvents: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        return status == .fullAccess || status == .authorized
    }

    /// Asks for full access (also upgrades a write-only permission).
    func requestFullAccess() async -> Bool {
        if canReadEvents { return true }
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = (try? await eventStore.requestFullAccessToEvents()) ?? false
        } else {
            granted = (try? await eventStore.requestAccess(to: .event)) ?? false
        }
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        if granted { loadCalendars() }
        return granted && canReadEvents
    }

    /// Every calendar the user can see, read-only ones included (Birthdays, Holidays, subscriptions).
    func allEventCalendars() -> [EKCalendar] {
        guard canReadEvents else { return [] }
        return eventStore.calendars(for: .event)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    /// The events of one day in the given calendars.
    func events(on day: Date, in calendars: [EKCalendar]) -> [EKEvent] {
        guard canReadEvents, !calendars.isEmpty else { return [] }
        let start = Calendar.current.startOfDay(for: day)
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return [] }
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: calendars)
        return eventStore.events(matching: predicate)
    }

    func createEvent(from task: TodoTask, in calendarId: String) async throws -> String? {
        guard authorizationStatus == .authorized || authorizationStatus == .fullAccess || authorizationStatus == .writeOnly else {
            print("❌ Current authorization status: \(authorizationStatus.rawValue) (\(authorizationStatusString))")
            throw CalendarError.notAuthorized
        }
        
        guard let calendar = availableCalendars.first(where: { $0.calendarIdentifier == calendarId }) else {
            print("❌ Calendar not found with ID: \(calendarId)")
            print("📅 Available calendars: \(availableCalendars.map { "\($0.title) (\($0.calendarIdentifier))" })")
            throw CalendarError.calendarNotFound
        }
        
        print("📅 Creating event for task: \(task.name) in calendar: \(calendar.title)")
        
        let event = EKEvent(eventStore: eventStore)
        event.title = task.name
        event.calendar = calendar
        
        var notes = task.description ?? ""
        if let category = task.category {
            if !notes.isEmpty {
                notes += "\n\n"
            }
            notes += "📁 Category: \(category.name)"
            notes += " 🎨"
        }
        event.notes = notes.isEmpty ? nil : notes
        
        if task.hasSpecificTime {
            event.isAllDay = false
            event.startDate = task.startTime
            if task.hasDuration && task.duration > 0 {
                event.endDate = task.startTime.addingTimeInterval(task.duration)
            } else {
                event.endDate = task.startTime.addingTimeInterval(3600)
            }
        } else {
            event.isAllDay = true
            event.startDate = Calendar.current.startOfDay(for: task.startTime)
            event.endDate = Calendar.current.startOfDay(for: task.startTime)
        }
        
        if let recurrence = task.recurrence {
            event.recurrenceRules = [createRecurrenceRule(from: recurrence)]
        }
        
        do {
            let span: EKSpan = task.recurrence != nil ? .futureEvents : .thisEvent
            try eventStore.save(event, span: span)
            print("✅ Event created successfully with ID: \(event.eventIdentifier ?? "unknown")")
            return event.eventIdentifier
        } catch {
            print("❌ Failed to save event: \(error.localizedDescription)")
            throw CalendarError.failedToCreateEvent(error.localizedDescription)
        }
    }
    
    func updateEvent(eventId: String, with task: TodoTask) async throws {
        guard authorizationStatus == .authorized || authorizationStatus == .fullAccess || authorizationStatus == .writeOnly else {
            throw CalendarError.notAuthorized
        }
        
        guard let event = eventStore.event(withIdentifier: eventId) else {
            throw CalendarError.eventNotFound
        }
        
        event.title = task.name
        var notes = task.description ?? ""
        if let category = task.category {
            if !notes.isEmpty {
                notes += "\n\n"
            }
            notes += "📁 Category: \(category.name)"
        }
        event.notes = notes.isEmpty ? nil : notes
        
        if task.hasSpecificTime {
            event.isAllDay = false
            event.startDate = task.startTime
            if task.hasDuration && task.duration > 0 {
                event.endDate = task.startTime.addingTimeInterval(task.duration)
            } else {
                event.endDate = task.startTime.addingTimeInterval(3600)
            }
        } else {
            event.isAllDay = true
            event.startDate = Calendar.current.startOfDay(for: task.startTime)
            event.endDate = Calendar.current.startOfDay(for: task.startTime)
        }
        
        if let recurrence = task.recurrence {
            event.recurrenceRules = [createRecurrenceRule(from: recurrence)]
        } else {
            event.recurrenceRules = nil
        }
        
        do {
            let span: EKSpan = task.recurrence != nil ? .futureEvents : .thisEvent
            try eventStore.save(event, span: span)
        } catch {
            throw CalendarError.failedToUpdateEvent(error.localizedDescription)
        }
    }
    
    func deleteEvent(eventId: String, isRecurring: Bool = false) async throws {
        guard authorizationStatus == .authorized || authorizationStatus == .fullAccess || authorizationStatus == .writeOnly else {
            throw CalendarError.notAuthorized
        }
        
        guard let event = eventStore.event(withIdentifier: eventId) else {
            throw CalendarError.eventNotFound
        }
        
        do {
            let span: EKSpan = isRecurring ? .futureEvents : .thisEvent
            try eventStore.remove(event, span: span)
            print("✅ Successfully deleted event: \(eventId)")
        } catch {
            print("❌ Failed to delete event \(eventId): \(error.localizedDescription)")
            throw CalendarError.failedToDeleteEvent(error.localizedDescription)
        }
    }
    
    func eventExists(eventId: String) -> Bool {
        return eventStore.event(withIdentifier: eventId) != nil
    }
    
    private func createRecurrenceRule(from recurrence: Recurrence) -> EKRecurrenceRule {
        let frequency: EKRecurrenceFrequency
        var interval = 1
        var daysOfWeek: [EKRecurrenceDayOfWeek]?
        var daysOfMonth: [NSNumber]?
        
        switch recurrence.type {
        case .daily:
            frequency = .daily
            if let dayInterval = recurrence.dayInterval, dayInterval > 1 {
                interval = dayInterval
            }
        case .weekly(let days):
            frequency = .weekly
            if let weekInterval = recurrence.weekInterval, weekInterval > 1 {
                interval = weekInterval
            }
            if !days.isEmpty {
                daysOfWeek = days.compactMap { weekday in
                    switch weekday {
                    case 1: return EKRecurrenceDayOfWeek(.sunday)
                    case 2: return EKRecurrenceDayOfWeek(.monday)
                    case 3: return EKRecurrenceDayOfWeek(.tuesday)
                    case 4: return EKRecurrenceDayOfWeek(.wednesday)
                    case 5: return EKRecurrenceDayOfWeek(.thursday)
                    case 6: return EKRecurrenceDayOfWeek(.friday)
                    case 7: return EKRecurrenceDayOfWeek(.saturday)
                    default: return nil
                    }
                }
            }
        case .monthly(let days):
            frequency = .monthly
            if let monthInterval = recurrence.monthInterval, monthInterval > 1 {
                interval = monthInterval
            }
            if !days.isEmpty {
                daysOfMonth = days.map { NSNumber(value: $0) }
            }
        case .monthlyOrdinal(let patterns):
            frequency = .monthly
            if let monthInterval = recurrence.monthInterval, monthInterval > 1 {
                interval = monthInterval
            }
            let sortedPatterns = patterns.sorted { $0.weekday < $1.weekday }
            daysOfWeek = sortedPatterns.compactMap { pattern in
                let ekWeekday: EKWeekday
                switch pattern.weekday {
                case 1: ekWeekday = .sunday
                case 2: ekWeekday = .monday
                case 3: ekWeekday = .tuesday
                case 4: ekWeekday = .wednesday
                case 5: ekWeekday = .thursday
                case 6: ekWeekday = .friday
                case 7: ekWeekday = .saturday
                default: return nil
                }
                return EKRecurrenceDayOfWeek(ekWeekday, weekNumber: pattern.ordinal)
            }
        case .yearly:
            frequency = .yearly
            if let yearInterval = recurrence.yearInterval, yearInterval > 1 {
                interval = yearInterval
            }
        }
        
        var end: EKRecurrenceEnd?
        if let endDate = recurrence.endDate {
            end = EKRecurrenceEnd(end: endDate)
        }
        
        return EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: interval,
            daysOfTheWeek: daysOfWeek,
            daysOfTheMonth: daysOfMonth,
            monthsOfTheYear: nil,
            weeksOfTheYear: nil,
            daysOfTheYear: nil,
            setPositions: nil,
            end: end
        )
    }
    
    func shouldShowSettingsAlert() -> Bool {
        return authorizationStatus == .denied
    }
    
    func openCalendarSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            Task { @MainActor in
                UIApplication.shared.open(settingsURL)
            }
        }
    }
}

enum CalendarError: LocalizedError {
    case notAuthorized
    case calendarNotFound
    case eventNotFound
    case failedToCreateEvent(String)
    case failedToUpdateEvent(String)
    case failedToDeleteEvent(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Calendar access not authorized"
        case .calendarNotFound:
            return "Selected calendar not found"
        case .eventNotFound:
            return "Calendar event not found"
        case .failedToCreateEvent(let error):
            return "Failed to create calendar event: \(error)"
        case .failedToUpdateEvent(let error):
            return "Failed to update calendar event: \(error)"
        case .failedToDeleteEvent(let error):
            return "Failed to delete calendar event: \(error)"
        }
    }
}