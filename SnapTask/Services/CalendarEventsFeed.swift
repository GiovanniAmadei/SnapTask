import Foundation
import EventKit
import SwiftUI
import Combine

/// An Apple Calendar event shown in the day list.
struct CalendarFeedEvent: Identifiable, Equatable {
    /// Event + occurrence start, so each occurrence of a recurring event is its own item.
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarTitle: String
    let color: Color
    let isBirthday: Bool
}

/// Shows the events of the user's Apple calendars (birthdays, holidays, appointments) in the
/// day list, so they can be added to SnapTask as tasks. Read only: SnapTask never edits them.
/// Its preferences are stored apart from CalendarIntegrationSettings, which only covers
/// writing tasks to the calendar.
@MainActor
final class CalendarEventsFeed: ObservableObject {
    static let shared = CalendarEventsFeed()

    @Published var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Keys.enabled)
            reload()
        }
    }
    /// Calendars the user switched off; new calendars are shown by default.
    @Published var hiddenCalendarIds: Set<String> {
        didSet {
            defaults.set(Array(hiddenCalendarIds), forKey: Keys.hiddenCalendars)
            reload()
        }
    }
    @Published private(set) var events: [CalendarFeedEvent] = []
    /// Events already added as tasks: their row shows a checkmark instead of "+".
    @Published private(set) var addedEventIds: Set<String>

    private let appleService = AppleCalendarService.shared
    private let defaults = UserDefaults.standard
    private var day = Date()
    private var cancellables = Set<AnyCancellable>()

    private enum Keys {
        static let enabled = "calendar_events_feed_enabled"
        static let hiddenCalendars = "calendar_events_feed_hidden_calendars"
        static let addedEvents = "calendar_events_feed_added_events"
    }

    private init() {
        isEnabled = defaults.bool(forKey: Keys.enabled)
        hiddenCalendarIds = Set(defaults.stringArray(forKey: Keys.hiddenCalendars) ?? [])
        addedEventIds = Set(defaults.stringArray(forKey: Keys.addedEvents) ?? [])

        // Events changed in the Calendar app, or the permission changed in Settings.
        NotificationCenter.default.publisher(for: .EKEventStoreChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reload() }
            .store(in: &cancellables)
    }

    func load(for day: Date) {
        self.day = day
        reload()
    }

    func markAdded(_ event: CalendarFeedEvent) {
        addedEventIds.insert(event.id)
        defaults.set(Array(addedEventIds), forKey: Keys.addedEvents)
    }

    private func reload() {
        guard isEnabled else {
            if !events.isEmpty { events = [] }
            return
        }
        let calendars = appleService.allEventCalendars()
            .filter { !hiddenCalendarIds.contains($0.calendarIdentifier) }
        let loaded = appleService.events(on: day, in: calendars)
            .map { event in
                CalendarFeedEvent(
                    id: "\(event.calendarItemIdentifier)_\(Int(event.startDate.timeIntervalSince1970))",
                    title: event.title ?? "",
                    startDate: event.startDate,
                    endDate: event.endDate,
                    isAllDay: event.isAllDay,
                    calendarTitle: event.calendar.title,
                    color: Color(cgColor: event.calendar.cgColor),
                    isBirthday: event.calendar.type == .birthday
                )
            }
            .sorted { lhs, rhs in
                // All-day events (birthdays, holidays) first, then by time.
                if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
                if lhs.startDate != rhs.startDate { return lhs.startDate < rhs.startDate }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        if loaded != events { events = loaded }
    }
}
