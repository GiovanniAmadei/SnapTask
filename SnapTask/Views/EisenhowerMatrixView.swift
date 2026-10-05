import SwiftUI

/// The four Eisenhower quadrants, in reading order.
private enum EisenhowerQuadrant: Int, CaseIterable, Identifiable {
    case doNow, schedule, delegate, eliminate

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .doNow: return "eisenhower_do_now".localized
        case .schedule: return "eisenhower_schedule".localized
        case .delegate: return "eisenhower_delegate".localized
        case .eliminate: return "eisenhower_eliminate".localized
        }
    }

    var subtitle: String {
        switch self {
        case .doNow: return "eisenhower_important_urgent".localized
        case .schedule: return "eisenhower_important_not_urgent".localized
        case .delegate: return "eisenhower_not_important_urgent".localized
        case .eliminate: return "eisenhower_not_important_not_urgent".localized
        }
    }

    var color: Color {
        switch self {
        case .doNow: return Color(hex: "#EF4444")
        case .schedule: return Color(hex: "#3B82F6")
        case .delegate: return Color(hex: "#F59E0B")
        case .eliminate: return Color(hex: "#8E8E93")
        }
    }

    var icon: String {
        switch self {
        case .doNow: return "flame.fill"
        case .schedule: return "calendar"
        case .delegate: return "person.2.fill"
        case .eliminate: return "trash.fill"
        }
    }
}

struct EisenhowerMatrixView: View {
    @ObservedObject var viewModel: TimelineViewModel
    /// Urgency/importance rules live in the settings: re-sort as soon as they change.
    @ObservedObject private var settings = SettingsViewModel.shared
    @Environment(\.theme) private var theme
    @State private var expandedQuadrant: EisenhowerQuadrant?
    @State private var showingSettings = false

    /// Width of the row-axis labels; the settings button sits in the same corner column.
    private let axisColumnWidth: CGFloat = 24
    private let spacing: CGFloat = 8

    var body: some View {
        let quadrants = viewModel.eisenhowerQuadrants(viewModel.applyingStatusFilter(viewModel.tasks))
        let tasksByQuadrant: [EisenhowerQuadrant: [TodoTask]] = [
            .doNow: quadrants.0, .schedule: quadrants.1, .delegate: quadrants.2, .eliminate: quadrants.3
        ]

        VStack(spacing: 8) {
            // Corner: rules. Columns: urgency axis (hidden while a quadrant is open).
            HStack(spacing: spacing) {
                settingsButton
                if expandedQuadrant == nil {
                    axisLabel("eisenhower_axis_urgent".localized, icon: "alarm.fill")
                        .frame(maxWidth: .infinity)
                    axisLabel("eisenhower_axis_not_urgent".localized, icon: "hourglass")
                        .frame(maxWidth: .infinity)
                } else {
                    Spacer()
                }
            }

            ZStack {
                if let expanded = expandedQuadrant {
                    quadrantView(expanded, tasks: tasksByQuadrant[expanded] ?? [])
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                } else {
                    grid(tasksByQuadrant)
                        .transition(.opacity.combined(with: .scale(scale: 1.03)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                EisenhowerSettingsView(viewModel: settings)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("done".localized) { showingSettings = false }
                                .fontWeight(.semibold)
                                .foregroundColor(theme.primaryColor)
                        }
                    }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var settingsButton: some View {
        Button {
            HapticManager.shared.impact(.light)
            showingSettings = true
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.primaryColor)
                .frame(width: axisColumnWidth, height: axisColumnWidth)
                .background(Circle().fill(theme.primaryColor.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("eisenhower_settings_title".localized)
    }

    private func axisLabel(_ text: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(text.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(0.4)
                .lineLimit(1)
        }
        .foregroundColor(theme.secondaryTextColor)
        .fixedSize()
    }

    /// Vertical label for the importance axis, centered on its row.
    private func rowAxisLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .tracking(0.4)
            .foregroundColor(theme.secondaryTextColor)
            .lineLimit(1)
            .fixedSize()
            .rotationEffect(.degrees(-90))
            .frame(width: axisColumnWidth)
            .frame(maxHeight: .infinity)
    }

    private func grid(_ tasksByQuadrant: [EisenhowerQuadrant: [TodoTask]]) -> some View {
        VStack(spacing: spacing) {
            HStack(spacing: spacing) {
                rowAxisLabel("eisenhower_axis_important".localized)
                quadrantView(.doNow, tasks: tasksByQuadrant[.doNow] ?? [])
                quadrantView(.schedule, tasks: tasksByQuadrant[.schedule] ?? [])
            }
            HStack(spacing: spacing) {
                rowAxisLabel("eisenhower_axis_not_important".localized)
                quadrantView(.delegate, tasks: tasksByQuadrant[.delegate] ?? [])
                quadrantView(.eliminate, tasks: tasksByQuadrant[.eliminate] ?? [])
            }
        }
    }

    private func quadrantView(_ quadrant: EisenhowerQuadrant, tasks: [TodoTask]) -> some View {
        MatrixQuadrant(
            quadrant: quadrant,
            tasks: tasks,
            isExpanded: expandedQuadrant == quadrant,
            viewModel: viewModel,
            onToggleExpanded: {
                HapticManager.shared.impact(.light)
                withAnimation(.smooth(duration: 0.35)) {
                    expandedQuadrant = expandedQuadrant == quadrant ? nil : quadrant
                }
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct MatrixQuadrant: View {
    let quadrant: EisenhowerQuadrant
    let tasks: [TodoTask]
    let isExpanded: Bool
    @ObservedObject var viewModel: TimelineViewModel
    let onToggleExpanded: () -> Void
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    /// Open tasks first (in progress on top), completed ones at the bottom.
    private var sortedTasks: [TodoTask] {
        func rank(_ task: TodoTask) -> Int {
            switch viewModel.progressState(of: task) {
            case .inProgress: return 0
            case .todo: return 1
            case .completed: return 2
            }
        }
        return tasks.enumerated()
            .sorted { lhs, rhs in
                let l = rank(lhs.element), r = rank(rhs.element)
                return l != r ? l < r : lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private var openCount: Int {
        tasks.filter { viewModel.progressState(of: $0) != .completed }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(sortedTasks) { task in
                        MatrixTaskRow(task: task, tint: quadrant.color, viewModel: viewModel)
                    }

                    if tasks.isEmpty {
                        emptyState
                    }
                }
                .padding(.horizontal, 7)
                .padding(.top, 2)
                .padding(.bottom, 10)
                .animation(.smooth(duration: 0.3), value: sortedTasks.map(\.id))
            }
            .scrollIndicators(.hidden)
            .modifier(NoScrollEdgeEffect())
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(theme.surfaceColor)
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [quadrant.color.opacity(0.13), quadrant.color.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .shadow(color: theme.shadowColor, radius: colorScheme == .dark ? 0 : 5, x: 0, y: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        // Drawn above the content: rows scrolling under the edge never cover it.
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(quadrant.color.opacity(0.25), lineWidth: 1)
        )
    }

    /// One line: title and open count (the color and the axes say the rest). Tap to open the quadrant on the whole matrix area.
    private var header: some View {
        Button(action: onToggleExpanded) {
            VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                titleText.fixedSize()
                Spacer(minLength: 4)
                trailing
            }
            // Open, the axes above are hidden: say which ones this quadrant is.
            if isExpanded {
                Text(quadrant.subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.secondaryTextColor)
                    .lineLimit(1)
                    .transition(.opacity)
            }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var titleText: some View {
        Text(quadrant.title)
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .foregroundColor(quadrant.color)
            .lineLimit(1)
    }

    @ViewBuilder
    private var trailing: some View {
        HStack(spacing: 6) {
            Text("\(openCount)")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white)
                .padding(.horizontal, 7)
                .frame(minWidth: 22, minHeight: 20)
                .background(Capsule().fill(openCount > 0 ? quadrant.color : quadrant.color.opacity(0.35)))
            if isExpanded {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(quadrant.color)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(quadrant.color.opacity(0.14)))
            }
        }
        .fixedSize()
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: quadrant.icon)
                .font(.system(size: 18))
                .foregroundColor(quadrant.color.opacity(0.35))
            Text("empty".localized)
                .font(.caption.weight(.medium))
                .foregroundColor(theme.secondaryTextColor.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
    }
}

private struct MatrixTaskRow: View {
    let task: TodoTask
    let tint: Color
    @ObservedObject var viewModel: TimelineViewModel
    @Environment(\.theme) private var theme
    @State private var showingDetail = false

    private var state: TaskProgressState { viewModel.progressState(of: task) }
    private var isCompleted: Bool { state == .completed }

    private var categoryTint: Color {
        task.category.map { Color(hex: $0.color) } ?? theme.accentColor
    }

    /// Same fallback as the timeline cards: "circle" would read as a second checkbox.
    private var displayIcon: String {
        guard task.icon == "circle" || task.icon.isEmpty else { return task.icon }
        return task.category?.icon ?? "list.bullet"
    }

    private var completedSubtasks: Int {
        task.completions[task.completionKey(for: viewModel.progressDate(for: task))]?.completedSubtasks.count ?? 0
    }

    var body: some View {
        // Name gets the whole width (a quadrant is narrow); details and the check sit below it.
        VStack(alignment: .leading, spacing: 6) {
            Text(task.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.textColor)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 5) {
                Image(systemName: displayIcon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(categoryTint)
                    .frame(width: 20, height: 20)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(categoryTint.opacity(0.16))
                    )

                metaRow

                Spacer(minLength: 0)

                TaskStatusIcon(state: state, idleColor: tint.opacity(0.8), size: 20)
                    .frame(width: 26, height: 22)
                    .taskStatusGestures(
                        onTap: {
                            if isCompleted {
                                HapticManager.shared.impact(.light)
                            } else {
                                HapticManager.shared.notification(.success)
                            }
                            withAnimation(.smooth(duration: 0.3)) {
                                viewModel.toggleTaskCompletion(task.id)
                            }
                        },
                        onLongPress: {
                            InProgressTip.markLearned()
                            withAnimation(.smooth(duration: 0.3)) {
                                TaskManager.shared.toggleInProgress(for: task.id, on: viewModel.progressDate(for: task))
                            }
                        }
                    )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.backgroundColor.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(state == .inProgress ? Color.blue.opacity(0.6) : tint.opacity(0.12),
                              lineWidth: state == .inProgress ? 1.2 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture { showingDetail = true }
        .sheet(isPresented: $showingDetail) {
            TaskDetailView(taskId: task.id, targetDate: viewModel.progressDate(for: task))
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    /// Time and subtasks when they fit the quadrant; otherwise the subtasks step aside
    /// (never widen the row).
    @ViewBuilder
    private var metaRow: some View {
        let showsTime = task.hasSpecificTime
        let showsSubtasks = !task.subtasks.isEmpty
        if showsTime || showsSubtasks {
            ViewThatFits(in: .horizontal) {
                metaChips(time: showsTime, subtasks: showsSubtasks)
                metaChips(time: showsTime, subtasks: false)
                metaChips(time: false, subtasks: false)
            }
        }
    }

    private func metaChips(time: Bool, subtasks: Bool) -> some View {
        HStack(spacing: 4) {
            if time {
                chip(TimeFormat.time(task.startTime))
            }
            if subtasks {
                chip("\(completedSubtasks)/\(task.subtasks.count)", icon: "checklist")
            }
        }
    }

    private func chip(_ text: String, icon: String? = nil) -> some View {
        HStack(spacing: 2) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .monospacedDigit()
                .lineLimit(1)
        }
        .foregroundColor(theme.secondaryTextColor)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Capsule().fill(theme.surfaceColor))
        .fixedSize()
    }
}

/// The quadrant has its own header: no system blur/magnify on the scroll edge.
private struct NoScrollEdgeEffect: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectHidden(true, for: .all)
        } else {
            content
        }
    }
}
