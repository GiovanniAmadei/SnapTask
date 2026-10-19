import SwiftUI

/// The day's Apple Calendar events above the task list, each with "+" to add it as a task.
struct CalendarEventsSection: View {
    @ObservedObject var feed: CalendarEventsFeed
    let onAdd: (CalendarFeedEvent) -> Void
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
                CalendarEventRow(
                    event: event,
                    isAdded: feed.addedEventIds.contains(event.id),
                    onAdd: { onAdd(event) }
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfaceColor)
        .cornerRadius(14)
    }
}

/// One Apple Calendar event with "+" to add it as a task, or a checkmark once its task exists.
/// Used in the day list and, more compact, in the hourly timeline.
struct CalendarEventRow: View {
    let event: CalendarFeedEvent
    let isAdded: Bool
    var compact = false
    let onAdd: () -> Void
    /// Re-render when the 12/24h preference changes (it is injected as the locale).
    @Environment(\.locale) private var locale
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: compact ? 10 : 12) {
            ZStack {
                Circle()
                    .fill(event.color.opacity(0.15))
                    .frame(width: compact ? 26 : 34, height: compact ? 26 : 34)
                Image(systemName: event.isBirthday ? "gift.fill" : "calendar")
                    .font(.system(size: compact ? 11 : 14, weight: .semibold))
                    .foregroundColor(event.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(compact ? .system(size: 14, weight: .medium) : .subheadline.weight(.semibold))
                    .themedPrimaryText()
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.caption)
                    .themedSecondaryText()
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if isAdded {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: compact ? 22 : 24))
                    .foregroundColor(theme.primaryColor)
                    .accessibilityLabel("calendar_event_added".localized)
            } else {
                Button {
                    HapticManager.shared.impact(.light)
                    onAdd()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: compact ? 22 : 24))
                        .foregroundColor(theme.primaryColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("calendar_event_add_as_task".localized)
            }
        }
    }

    private var subtitle: String {
        let when: String
        if event.isAllDay {
            when = "all_day".localized
        } else {
            // TimeFormat follows the app's 12/24h preference; `formatted` would not.
            let start = TimeFormat.time(event.startDate)
            let end = TimeFormat.time(event.endDate)
            when = "\(start) – \(end)"
        }
        return "\(when) · \(event.calendarTitle)"
    }
}
