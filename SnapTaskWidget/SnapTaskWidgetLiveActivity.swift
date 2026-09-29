//
//  SnapTaskWidgetLiveActivity.swift
//  SnapTaskWidget
//
//  Live Activity for the Pomodoro timer (Lock Screen + Dynamic Island).
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Live Activity Widget

struct SnapTaskWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroActivityAttributes.self) { context in
            // Lock Screen / banner UI
            PomodoroLockScreenView(
                attributes: context.attributes,
                state: context.state
            )
            .activityBackgroundTint(Color.black.opacity(0.2))
            .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PomodoroExpandedLeading(state: context.state, attributes: context.attributes)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    PomodoroExpandedTrailing(state: context.state)
                }
                DynamicIslandExpandedRegion(.center) {
                    PomodoroExpandedCenter(state: context.state, attributes: context.attributes)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    PomodoroExpandedBottom(state: context.state, attributes: context.attributes)
                }
            } compactLeading: {
                PomodoroCompactLeading(state: context.state, attributes: context.attributes)
            } compactTrailing: {
                PomodoroCompactTrailing(state: context.state)
            } minimal: {
                PomodoroMinimal(state: context.state, attributes: context.attributes)
            }
            .widgetURL(URL(string: context.state.phase == .simpleTimer ? "snaptask://timetracker" : "snaptask://pomodoro"))
            .keylineTint(phaseColor(context.state.phase, attributes: context.attributes))
        }
    }
}

// MARK: - Lock Screen

private struct PomodoroLockScreenView: View {
    let attributes: PomodoroActivityAttributes
    let state: PomodoroActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: phaseIcon(state.phase))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(phaseColor(state.phase, attributes: attributes))

                VStack(alignment: .leading, spacing: 1) {
                    Text(attributes.taskName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(phaseLabel(state.phase))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(phaseColor(state.phase, attributes: attributes))

                        if state.phase != .simpleTimer {
                            Text("·")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                            Text("\(state.currentSession)/\(state.totalSessions)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                timerText
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(phaseColor(state.phase, attributes: attributes))
            }

            // Session progress bar (only for Pomodoro)
            if state.phase != .simpleTimer {
                SessionProgressBar(
                    state: state,
                    current: state.currentSession,
                    total: state.totalSessions,
                    color: phaseColor(state.phase, attributes: attributes)
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var timerText: some View {
        if state.phase == .paused, let remaining = state.pausedTimeRemaining {
            Text(formatTime(remaining))
        } else if state.phase == .simpleTimer {
            if let paused = state.pausedTimeRemaining {
                Text(formatTime(paused))
            } else {
                Text(state.endDate, style: .timer)
                    .multilineTextAlignment(.trailing)
            }
        } else {
            Text(timerInterval: Date()...state.endDate, countsDown: true)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Dynamic Island regions

private struct PomodoroExpandedLeading: View {
    let state: PomodoroActivityAttributes.ContentState
    let attributes: PomodoroActivityAttributes

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: phaseIcon(state.phase))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(phaseColor(state.phase, attributes: attributes))
            Text(phaseLabel(state.phase))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .padding(.leading, 4)
    }
}

private struct PomodoroExpandedTrailing: View {
    let state: PomodoroActivityAttributes.ContentState

    var body: some View {
        if state.phase == .simpleTimer {
            if let paused = state.pausedTimeRemaining {
                Text(formatTime(paused))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.trailing, 4)
            } else {
                Text(state.endDate, style: .timer)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: 44, alignment: .trailing)
            }
        } else {
            Text("\(state.currentSession)/\(state.totalSessions)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.secondary)
                .padding(.trailing, 4)
        }
    }
}

private struct PomodoroExpandedCenter: View {
    let state: PomodoroActivityAttributes.ContentState
    let attributes: PomodoroActivityAttributes

    var body: some View {
        EmptyView()
    }
}

private struct PomodoroExpandedBottom: View {
    let state: PomodoroActivityAttributes.ContentState
    let attributes: PomodoroActivityAttributes

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(attributes.taskName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let category = attributes.categoryName, !category.isEmpty {
                    Text(category.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(Color.secondary.opacity(0.15))
                        )
                        .padding(.leading, 4)
                }

                Spacer(minLength: 8)

                if state.phase == .paused, let remaining = state.pausedTimeRemaining {
                    Text(formatTime(remaining))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(phaseColor(state.phase, attributes: attributes))
                } else if state.phase == .simpleTimer {
                    if let paused = state.pausedTimeRemaining {
                        Text(formatTime(paused))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(phaseColor(state.phase, attributes: attributes))
                    } else {
                        Text(state.endDate, style: .timer)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(phaseColor(state.phase, attributes: attributes))
                            .multilineTextAlignment(.trailing)
                    }
                } else {
                    Text(timerInterval: Date()...state.endDate, countsDown: true)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(phaseColor(state.phase, attributes: attributes))
                        .multilineTextAlignment(.trailing)
                }
            }

            if state.phase != .simpleTimer {
                SessionProgressBar(
                    state: state,
                    current: state.currentSession,
                    total: state.totalSessions,
                    color: phaseColor(state.phase, attributes: attributes)
                )
            }
        }
    }
}

private struct PomodoroCompactLeading: View {
    let state: PomodoroActivityAttributes.ContentState
    let attributes: PomodoroActivityAttributes

    var body: some View {
        Image(systemName: phaseIcon(state.phase))
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(phaseColor(state.phase, attributes: attributes))
    }
}

private struct PomodoroCompactTrailing: View {
    let state: PomodoroActivityAttributes.ContentState

    var body: some View {
        if state.phase == .simpleTimer {
            if let paused = state.pausedTimeRemaining {
                Text(formatTime(paused))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.primary)
            } else {
                Text(state.endDate, style: .timer)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.primary)
                    .frame(maxWidth: 40, alignment: .trailing)
            }
        } else {
            Text("\(state.currentSession)/\(state.totalSessions)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.primary)
        }
    }
}

private struct PomodoroMinimal: View {
    let state: PomodoroActivityAttributes.ContentState
    let attributes: PomodoroActivityAttributes

    var body: some View {
        Image(systemName: phaseIcon(state.phase))
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(phaseColor(state.phase, attributes: attributes))
    }
}

// MARK: - Session Progress Bar

private struct SessionProgressBar: View {
    let state: PomodoroActivityAttributes.ContentState
    let current: Int
    let total: Int
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 4
            let count = max(1, total)
            let segmentWidth = (geo.size.width - spacing * CGFloat(count - 1)) / CGFloat(count)

            HStack(spacing: spacing) {
                ForEach(0..<count, id: \.self) { idx in
                    let isDone = idx < current - 1
                    let isCurrent = idx == current - 1

                    segment(
                        width: segmentWidth,
                        isDone: isDone,
                        isCurrent: isCurrent
                    )
                }
            }
        }
        .frame(height: 4)
    }

    @ViewBuilder
    private func segment(width: CGFloat, isDone: Bool, isCurrent: Bool) -> some View {
        if isDone {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: width, height: 4)
        } else if isCurrent {
            activeSegment(width: width)
        } else {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.25))
                .frame(width: width, height: 4)
        }
    }

    @ViewBuilder
    private func activeSegment(width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.25))

            if state.phase == .paused {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(0.55))
                    .frame(width: width * staticProgress)
            } else {
                // ActivityKit animates ProgressView(timerInterval:)
                // smoothly inside a Live Activity, so the bar fills
                // second-by-second without extra updates.
                ProgressView(
                    timerInterval: phaseStartDate...state.endDate,
                    countsDown: false,
                    label: { EmptyView() },
                    currentValueLabel: { EmptyView() }
                )
                .progressViewStyle(.linear)
                .tint(color.opacity(0.55))
                .labelsHidden()
            }
        }
        .frame(width: width, height: 4)
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }

    private var phaseStartDate: Date {
        state.endDate.addingTimeInterval(-max(1, state.phaseTotalDuration))
    }

    private var staticProgress: CGFloat {
        let remaining = state.pausedTimeRemaining ?? max(0, state.endDate.timeIntervalSinceNow)
        let total = max(1, state.phaseTotalDuration)
        return CGFloat(min(max(1 - (remaining / total), 0), 1))
    }
}

// MARK: - Helpers (file-private so they don't collide with the main widget)

private func phaseIcon(_ phase: PomodoroActivityAttributes.ContentState.Phase) -> String {
    switch phase {
    case .working: return "timer"
    case .onBreak: return "cup.and.saucer.fill"
    case .paused:  return "pause.circle.fill"
    case .simpleTimer: return "stopwatch.fill"
    }
}

private func phaseLabel(_ phase: PomodoroActivityAttributes.ContentState.Phase) -> String {
    switch phase {
    case .working: return String(localized: "Focus")
    case .onBreak: return String(localized: "Break")
    case .paused:  return String(localized: "Paused")
    case .simpleTimer: return String(localized: "Timer")
    }
}

private func phaseColor(
    _ phase: PomodoroActivityAttributes.ContentState.Phase,
    attributes: PomodoroActivityAttributes
) -> Color {
    // Prefer category color when available (except for pause which reads as "muted")
    if phase != .paused, let hex = attributes.categoryColorHex, !hex.isEmpty {
        return Color(hex: hex)
    }
    switch phase {
    case .working: return .red
    case .onBreak: return .green
    case .paused:  return .gray
    case .simpleTimer: return .orange
    }
}

private func currentPhaseProgress(
    _ state: PomodoroActivityAttributes.ContentState,
    now: Date = .now
) -> CGFloat {
    let total = max(1, state.phaseTotalDuration)

    let remaining: TimeInterval
    if state.phase == .paused, let pausedTimeRemaining = state.pausedTimeRemaining {
        remaining = pausedTimeRemaining
    } else {
        remaining = max(0, state.endDate.timeIntervalSince(now))
    }

    let progress = 1 - (remaining / total)
    return CGFloat(min(max(progress, 0), 1))
}

private func formatTime(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds))
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let secs = total % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, secs)
    } else {
        return String(format: "%02d:%02d", minutes, secs)
    }
}

// MARK: - Previews

extension PomodoroActivityAttributes {
    fileprivate static var preview: PomodoroActivityAttributes {
        PomodoroActivityAttributes(
            taskName: "Write article draft",
            categoryColorHex: "#EF4444",
            categoryName: "Writing"
        )
    }
}

extension PomodoroActivityAttributes.ContentState {
    fileprivate static var working: PomodoroActivityAttributes.ContentState {
        PomodoroActivityAttributes.ContentState(
            phase: .working,
            endDate: Date().addingTimeInterval(25 * 60),
            phaseTotalDuration: 25 * 60,
            pausedTimeRemaining: nil,
            currentSession: 2,
            totalSessions: 4
        )
    }

    fileprivate static var onBreak: PomodoroActivityAttributes.ContentState {
        PomodoroActivityAttributes.ContentState(
            phase: .onBreak,
            endDate: Date().addingTimeInterval(5 * 60),
            phaseTotalDuration: 5 * 60,
            pausedTimeRemaining: nil,
            currentSession: 2,
            totalSessions: 4
        )
    }

    fileprivate static var paused: PomodoroActivityAttributes.ContentState {
        PomodoroActivityAttributes.ContentState(
            phase: .paused,
            endDate: Date().addingTimeInterval(17 * 60),
            phaseTotalDuration: 25 * 60,
            pausedTimeRemaining: 17 * 60,
            currentSession: 2,
            totalSessions: 4
        )
    }
}

#Preview("Lock Screen", as: .content, using: PomodoroActivityAttributes.preview) {
    SnapTaskWidgetLiveActivity()
} contentStates: {
    PomodoroActivityAttributes.ContentState.working
    PomodoroActivityAttributes.ContentState.onBreak
    PomodoroActivityAttributes.ContentState.paused
}
