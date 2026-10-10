import SwiftUI

/// The day's Apple Calendar events above the task list, each with "+" to add it as a task.
struct CalendarEventsSection: View {
    @ObservedObject var feed: CalendarEventsFeed
    let onAdd: (CalendarFeedEvent) -> Void
    /// Re-render when the 12/24h preference changes (it is injected as the locale).
    @Environment(\.locale) private var locale
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 13, weight: .semibold))
                Text("calendar_events_section_title".localized)
                    .font(.subheadline.bold())
            }
            .foregroundColor(theme.secondaryTextColor)

            ForEach(feed.events) { event in
                eventRow(event)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfaceColor)
        .cornerRadius(14)
    }

    private func eventRow(_ event: CalendarFeedEvent) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(event.color.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: event.isBirthday ? "gift.fill" : "calendar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(event.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                    .themedPrimaryText()
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle(for: event))
                    .font(.caption)
                    .themedSecondaryText()
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if feed.addedEventIds.contains(event.id) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(theme.primaryColor)
                    .accessibilityLabel("calendar_event_added".localized)
            } else {
                Button {
                    HapticManager.shared.impact(.light)
                    onAdd(event)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(theme.primaryColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("calendar_event_add_as_task".localized)
            }
        }
    }

    private func subtitle(for event: CalendarFeedEvent) -> String {
        let when: String
        if event.isAllDay {
            when = "all_day".localized
        } else {
            let start = event.startDate.formatted(date: .omitted, time: .shortened)
            let end = event.endDate.formatted(date: .omitted, time: .shortened)
            when = "\(start) – \(end)"
        }
        return "\(when) · \(event.calendarTitle)"
    }
}
