import SwiftUI

// MARK: - Quick add

/// One-line capture at the top of the Inbox: type, press return, keep typing.
struct InboxQuickAddField: View {
    @Environment(\.theme) private var theme
    @State private var text = ""
    @FocusState private var isFocused: Bool

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(theme.primaryColor)

            TextField("inbox_add_placeholder".localized, text: $text)
                .font(.body)
                .foregroundColor(theme.textColor)
                .submitLabel(.return)
                .focused($isFocused)
                .onSubmit(add)

            if !trimmed.isEmpty {
                Button(action: add) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(theme.primaryColor)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
        .background(
            RoundedRectangle(cornerRadius: TimelineTaskCard.cornerRadius, style: .continuous)
                .fill(theme.surfaceColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: TimelineTaskCard.cornerRadius, style: .continuous)
                .strokeBorder(theme.primaryColor.opacity(isFocused ? 0.6 : 0.25), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.15), value: trimmed.isEmpty)
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
    }

    private func add() {
        let name = trimmed
        guard !name.isEmpty else {
            isFocused = false
            return
        }
        text = ""
        HapticManager.shared.impact(.light)
        let item = TodoTask(name: name, startTime: Date(), icon: "note.text", timeScope: .inbox)
        Task { await TaskManager.shared.addTask(item) }
        // Return dismisses the keyboard by default: keep it up for the next note.
        DispatchQueue.main.async { isFocused = true }
    }
}

extension UIApplication {
    /// Hides the keyboard wherever the focus is (e.g. before presenting a sheet over the Inbox).
    func dismissKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Sub-items

/// Field at the bottom of an open inbox item: type a sub-item, press return, keep typing.
struct InboxSubtaskAddField: View {
    let taskId: UUID
    @Environment(\.theme) private var theme
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.primaryColor)
                .frame(width: 32, height: 32)

            TextField("inbox_add_subitem".localized, text: $text)
                .font(.subheadline)
                .foregroundColor(theme.textColor)
                .submitLabel(.return)
                .focused($isFocused)
                .onSubmit(add)
        }
        // Lines up with the sub-item rows (TimelineSubtaskRow).
        .padding(.leading, 16)
        .padding(.trailing, 12)
    }

    private func add() {
        let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            isFocused = false
            return
        }
        text = ""
        guard var task = TaskManager.shared.tasks.first(where: { $0.id == taskId }) else { return }
        task.subtasks.append(Subtask(name: name))
        task.lastModifiedDate = Date()
        HapticManager.shared.impact(.light)
        Task { await TaskManager.shared.updateTask(task) }
        // Return dismisses the keyboard by default: keep it up for the next sub-item.
        DispatchQueue.main.async { isFocused = true }
    }
}

/// Priority picker at the bottom of an open inbox item (quick notes start at medium, unmarked).
struct InboxPriorityRow: View {
    let task: TodoTask
    @Environment(\.theme) private var theme

    var body: some View {
        Menu {
            Picker("", selection: Binding(get: { task.priority }, set: set)) {
                ForEach(Priority.allCases, id: \.self) { priority in
                    Label(priority.displayName, systemImage: priority.icon)
                        .tag(priority)
                }
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "flag")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.primaryColor)
                    .frame(width: 32, height: 32)
                Text("priority".localized)
                    .font(.subheadline)
                    .foregroundColor(theme.secondaryTextColor)
                Text(task.priority.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color(hex: task.priority.color))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.secondaryTextColor)
                Spacer(minLength: 0)
            }
            .lineLimit(1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Lines up with the sub-item rows (TimelineSubtaskRow).
        .padding(.leading, 16)
        .padding(.trailing, 12)
    }

    private func set(_ priority: Priority) {
        guard priority != task.priority,
              var updated = TaskManager.shared.tasks.first(where: { $0.id == task.id }) else { return }
        updated.priority = priority
        updated.lastModifiedDate = Date()
        HapticManager.shared.selection()
        Task { await TaskManager.shared.updateTask(updated) }
    }
}

// MARK: - Header button

/// Header button next to the journal: opens the inbox from the day view and leads back from it.
/// Same style as the other header buttons; the badge counts the open items.
struct InboxHeaderButton: View {
    @ObservedObject var viewModel: TimelineViewModel
    @Environment(\.theme) private var theme

    var body: some View {
        let isActive = viewModel.selectedTimeScope == .inbox
        let openCount = viewModel.openInboxCount
        Button {
            HapticManager.shared.selection()
            viewModel.changeScope(to: isActive ? .today : .inbox)
        } label: {
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? theme.primaryColor : theme.primaryColor.opacity(0.12))
                .frame(width: 34, height: 34)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(theme.primaryColor.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: theme.shadowColor, radius: 2, x: 0, y: 1)
                .overlay(
                    Image(systemName: "tray.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isActive ? .white : theme.primaryColor)
                )
                .overlay(alignment: .topTrailing) {
                    if openCount > 0 && !isActive {
                        Text(openCount > 99 ? "99+" : "\(openCount)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(Capsule().fill(Color.red))
                            .overlay(Capsule().strokeBorder(Color(.systemBackground), lineWidth: 1.5))
                            .fixedSize()
                            .offset(x: 6, y: -6)
                    }
                }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isActive)
        .accessibilityLabel(Text("scope_inbox".localized))
    }
}

// MARK: - Empty state

struct InboxEmptyState: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 52, weight: .light))
                .foregroundColor(theme.secondaryTextColor.opacity(0.6))
                .padding(.bottom, 4)

            Text("inbox_empty_title".localized)
                .font(.title3.weight(.semibold))
                .foregroundColor(theme.textColor)
                .multilineTextAlignment(.center)

            Text("inbox_empty_subtitle".localized)
                .font(.subheadline)
                .foregroundColor(theme.secondaryTextColor)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Plan

/// Turns an inbox item into a dated task (today, tomorrow, this week or a chosen day).
struct PlanInboxItemSheet: View {
    let task: TodoTask
    /// Asks the presenter to close this sheet and open the full task form.
    var onMoreOptions: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Environment(\.locale) private var locale

    private enum Choice: Hashable { case today, tomorrow, thisWeek, custom }

    @State private var choice: Choice = .today
    @State private var date = Date()
    @State private var hasTime = false
    @State private var time = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(task.name)
                        .font(.headline)
                        .foregroundColor(theme.textColor)
                        .lineLimit(3)

                    quickChoices

                    if choice == .custom {
                        DatePicker("", selection: $date, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                            .tint(theme.primaryColor)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(theme.surfaceColor))
                            .transition(.opacity)
                    }

                    if choice != .thisWeek {
                        VStack(spacing: 0) {
                            Toggle(isOn: $hasTime.animation(.easeInOut(duration: 0.2))) {
                                Label("specific_time".localized, systemImage: "clock")
                                    .foregroundColor(theme.textColor)
                            }
                            .tint(theme.primaryColor)

                            if hasTime {
                                DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.wheel)
                                    .labelsHidden()
                                    .frame(maxHeight: 150)
                                    .clipped()
                            }
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(theme.surfaceColor))
                    }

                    // Everything a normal task has (period, recurrence, reminders, category...).
                    Button {
                        onMoreOptions()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(theme.primaryColor)
                            Text("inbox_plan_more_options".localized)
                                .foregroundColor(theme.textColor)
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(theme.secondaryTextColor)
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(theme.surfaceColor))
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
            }
            .themedBackground()
            .navigationTitle("inbox_plan".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("done".localized) { plan() }
                        .fontWeight(.semibold)
                }
            }
        }
        .timeFormatLocale()
        .presentationDetents([.medium, .large])
    }

    /// The item as a plain task for today, so the full form opens on the normal options.
    static func fullFormDraft(from task: TodoTask) -> TodoTask {
        var draft = task
        draft.timeScope = .today
        draft.scopeStartDate = nil
        draft.scopeEndDate = nil
        // Today at the next half hour, so turning on "specific time" starts from a sensible time.
        let now = Date()
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: now)
        let next = calendar.date(byAdding: .minute, value: minute < 30 ? 30 - minute : 60 - minute, to: now) ?? now
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: next)
        draft.startTime = calendar.date(from: parts) ?? next
        draft.hasSpecificDay = true
        draft.hasSpecificTime = false
        draft.completions = [:]
        return draft
    }

    private var quickChoices: some View {
        let options: [(Choice, String, String)] = [
            (.today, "today".localized, "star.fill"),
            (.tomorrow, "tomorrow".localized, "sunrise.fill"),
            (.thisWeek, "this_week".localized, "target"),
            (.custom, "select_date".localized, "calendar")
        ]
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(options, id: \.0) { option in
                let isSelected = choice == option.0
                Button {
                    HapticManager.shared.selection()
                    withAnimation(.easeInOut(duration: 0.2)) { choice = option.0 }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: option.2)
                            .font(.system(size: 14, weight: .semibold))
                        Text(option.1)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundColor(isSelected ? .white : theme.primaryColor)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isSelected ? theme.primaryColor : theme.primaryColor.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func plan() {
        let calendar = Calendar.current
        var updated = task
        updated.completions = [:]
        updated.lastModifiedDate = Date()

        if choice == .thisWeek {
            let weekStart = calendar.startOfWeek(for: Date())
            updated.timeScope = .week
            updated.scopeStartDate = weekStart
            updated.scopeEndDate = calendar.date(byAdding: .day, value: 6, to: weekStart)
            updated.startTime = weekStart
            updated.hasSpecificDay = false
            updated.hasSpecificTime = false
        } else {
            let day: Date
            switch choice {
            case .tomorrow: day = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
            case .custom: day = calendar.startOfDay(for: date)
            default: day = calendar.startOfDay(for: Date())
            }
            updated.timeScope = .today
            updated.scopeStartDate = nil
            updated.scopeEndDate = nil
            updated.hasSpecificDay = true
            if hasTime {
                let parts = calendar.dateComponents([.hour, .minute], from: time)
                updated.startTime = calendar.date(bySettingHour: parts.hour ?? 9, minute: parts.minute ?? 0, second: 0, of: day) ?? day
                updated.hasSpecificTime = true
            } else {
                updated.startTime = day
                updated.hasSpecificTime = false
            }
        }

        HapticManager.shared.notification(.success)
        Task { await TaskManager.shared.updateTask(updated) }
        dismiss()
    }
}
