import Foundation
import UserNotifications

/// Schedules the daily-quote and diary notifications for the next 30 days.
///
/// iOS has no "repeat daily with different content" trigger, so each day gets its own
/// one-shot request. Calling this whenever the app becomes active keeps the 30-day
/// window rolling forward; without it the notifications would stop after 30 days
/// unless the user reopened Settings.
enum DailyReminderScheduler {
    private static let quotePrefix = "dailyQuote_"
    private static let diaryPrefix = "diary_"
    private static let daysAhead = 30

    /// Refreshes both kinds of reminders according to the saved settings.
    static func refreshAll() {
        scheduleDailyQuotes()
        scheduleDiaryReminders()
    }

    static func scheduleDailyQuotes() {
        let defaults = UserDefaults.standard
        let enabled = defaults.bool(forKey: "dailyQuoteNotificationsEnabled")
        let time = defaults.string(forKey: "dailyQuoteNotificationTime") ?? "09:00"

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyQuote"]) // legacy

        let requests = enabled ? buildRequests(prefix: quotePrefix, time: time) { day in
            let quote = QuoteService.shared.quoteFor(date: day)
            let content = UNMutableNotificationContent()
            content.title = "your_daily_motivation".localized
            content.body = String(format: "daily_quote_notification_body".localized, quote.text, quote.author)
            content.sound = .default
            return content
        } : []

        replacePending(prefix: quotePrefix, with: requests)
    }

    static func scheduleDiaryReminders() {
        let defaults = UserDefaults.standard
        let enabled = defaults.bool(forKey: "diaryNotificationsEnabled")
        let time = defaults.string(forKey: "diaryNotificationTime") ?? "20:00"

        let requests = enabled ? buildRequests(prefix: diaryPrefix, time: time) { _ in
            let content = UNMutableNotificationContent()
            content.title = "diary_reminder_title".localized
            content.body = "diary_reminder_body".localized
            content.sound = .default
            return content
        } : []

        replacePending(prefix: diaryPrefix, with: requests)
    }

    // MARK: - Helpers

    private static func buildRequests(
        prefix: String,
        time: String,
        content: (Date) -> UNNotificationContent
    ) -> [UNNotificationRequest] {
        let parts = time.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return [] }

        let calendar = Calendar.current
        let now = Date()
        let idFormatter = DateFormatter()
        idFormatter.calendar = Calendar(identifier: .gregorian)
        idFormatter.locale = Locale(identifier: "en_US_POSIX")
        idFormatter.dateFormat = "yyyy-MM-dd"

        var requests: [UNNotificationRequest] = []
        for offset in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = hour
            components.minute = minute
            guard let fireDate = calendar.date(from: components), fireDate > now else { continue }

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
                repeats: false
            )
            let identifier = prefix + idFormatter.string(from: day)
            requests.append(UNNotificationRequest(identifier: identifier, content: content(day), trigger: trigger))
        }
        return requests
    }

    /// Adds the new requests (same identifier replaces the old one) and removes only the
    /// pending ones with this prefix that are no longer wanted, so nothing is ever left
    /// briefly unscheduled.
    private static func replacePending(prefix: String, with requests: [UNNotificationRequest]) {
        let center = UNUserNotificationCenter.current()
        let wanted = Set(requests.map(\.identifier))

        center.getPendingNotificationRequests { pending in
            let stale = pending
                .map(\.identifier)
                .filter { $0.hasPrefix(prefix) && !wanted.contains($0) }
            if !stale.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: stale)
            }
            for request in requests {
                center.add(request) { error in
                    if let error {
                        print(" Error scheduling \(request.identifier): \(error)")
                    }
                }
            }
        }
    }
}
