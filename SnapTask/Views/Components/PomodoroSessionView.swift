import SwiftUI

/// Shared body of the Pomodoro screen used both by the general focus tab
/// (`PomodoroTabView`) and by the task-specific fullscreen presentation
/// (`PomodoroView.fullscreenLayout`).
///
/// Encapsulates:
/// - the hero timer ring with phase label + remaining time + percentage,
/// - the "Session overview" card (list of dots + modern timeline bar + next-up hint),
/// - the primary controls (stop / play-pause / skip),
/// - the "finishes at" foot hint.
///
/// The hosting view is responsible for the navigation chrome (toolbar,
/// title, settings entry, dismiss buttons). That keeps the header
/// flexible while the session core stays identical across contexts.
struct PomodoroSessionView<Header: View>: View {
    @ObservedObject var viewModel: PomodoroViewModel
    let focusColor: Color
    let breakColor: Color
    let onStop: () -> Void
    let onTogglePlayPause: () -> Void
    let onSkip: () -> Void
    @ViewBuilder let header: () -> Header
    
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(spacing: 0) {
            header()
                .padding(.horizontal, 20)
                .padding(.top, 8)
            
            heroTimer
                .padding(.top, 16)
                .padding(.bottom, 24)
            
            sessionOverviewCard
                .padding(.horizontal, 20)
            
            Spacer(minLength: 16)
            
            controlsFooter
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
    }
    
    // MARK: - Hero timer
    
    private var heroTimer: some View {
        ZStack {
            // Ambient outer glow that pulses gently
            Circle()
                .fill(phaseColor.opacity(0.12))
                .frame(width: 270, height: 270)
                .blur(radius: 24)
                .opacity(viewModel.state == .working || viewModel.state == .onBreak ? 1 : 0.3)
                .animation(
                    viewModel.state == .working || viewModel.state == .onBreak
                        ? .easeInOut(duration: 2.2).repeatForever(autoreverses: true)
                        : .easeInOut(duration: 0.3),
                    value: viewModel.state
                )
            
            // Soft inner plate
            Circle()
                .fill(theme.surfaceColor.opacity(0.6))
                .frame(width: 220, height: 220)
                .shadow(color: theme.shadowColor.opacity(0.5), radius: 10, x: 0, y: 4)
            
            // Track
            Circle()
                .stroke(theme.borderColor.opacity(0.3), lineWidth: 8)
                .frame(width: 224, height: 224)
            
            // Progress ring
            Circle()
                .trim(from: 0.0, to: viewModel.progress)
                .stroke(
                    LinearGradient(
                        colors: [phaseColor, phaseColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 224, height: 224)
                .rotationEffect(Angle(degrees: -90))
                .animation(.easeInOut(duration: 0.3), value: viewModel.progress)
                .shadow(color: phaseColor.opacity(0.3), radius: 4, x: 0, y: 0)
            
            VStack(spacing: 8) {
                // Phase Pill
                HStack(spacing: 6) {
                    Circle()
                        .fill(phaseColor)
                        .frame(width: 7, height: 7)
                        .shadow(color: phaseColor.opacity(0.8), radius: 3)
                    
                    Text(phaseLabel)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .themedSecondaryText()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(phaseColor.opacity(0.12))
                        .overlay(
                            Capsule()
                                .stroke(phaseColor.opacity(0.25), lineWidth: 1)
                        )
                )
                
                Text(timeString(from: viewModel.timeRemaining))
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(
                        LinearGradient(
                            colors: [phaseColor, phaseColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .contentTransition(.numericText())
                
                Text("\(Int(viewModel.progress * 100))%")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .themedSecondaryText()
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Session overview card
    
    private var sessionOverviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label {
                    Text("session_overview".localized)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .themedPrimaryText()
                } icon: {
                    Image(systemName: "timelapse")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.accentColor)
                }
                
                Spacer()
                
                Text("\(formatMinutes(viewModel.timeRemaining)) " + "left".localized)
                    .font(.system(.footnote, design: .rounded).weight(.medium))
                    .themedSecondaryText()
                    .contentTransition(.numericText())
            }
            
            ModernSessionTimeline(viewModel: viewModel)
            
            if let hint = nextUpHint {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 10, weight: .semibold))
                        .themedSecondaryText()
                    Text(hint)
                        .font(.system(.caption, design: .rounded))
                        .themedSecondaryText()
                        .lineLimit(1)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfaceColor)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(theme.borderColor.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: theme.shadowColor, radius: 8, x: 0, y: 3)
    }
    
    // MARK: - Controls footer
    
    private var controlsFooter: some View {
        VStack(spacing: 12) {
            HStack(spacing: 22) {
                ControlButton(
                    icon: "forward.fill",
                    size: .medium,
                    color: phaseColor,
                    isDisabled: viewModel.state == .notStarted || viewModel.state == .completed,
                    action: onSkip
                )
                
                ControlButton(
                    icon: playPauseIcon,
                    size: .large,
                    color: phaseColorForPrimary,
                    isPulsing: viewModel.state == .working || viewModel.state == .onBreak,
                    action: onTogglePlayPause
                )
                
                ControlButton(
                    icon: "checkmark",
                    size: .medium,
                    color: .green,
                    isDisabled: viewModel.state == .notStarted || viewModel.state == .completed,
                    action: onStop
                )
            }
            
            if viewModel.state != .notStarted && viewModel.state != .completed {
                let completionTime = Date().addingTimeInterval(viewModel.timeRemaining)
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 11, weight: .medium))
                        .themedSecondaryText()
                    Text("finishes_at".localized + " \(formatTimeOnly(completionTime))")
                        .font(.system(.footnote, design: .rounded))
                        .themedSecondaryText()
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.state)
    }
    
    // MARK: - Derived values
    
    private var phaseColor: Color {
        switch viewModel.effectivePhase {
        case .working: return focusColor
        case .onBreak: return breakColor
        case .paused, .notStarted, .completed: return focusColor
        }
    }
    
    private var phaseColorForPrimary: Color {
        if viewModel.state == .notStarted || viewModel.state == .completed {
            return theme.primaryColor
        }
        switch viewModel.effectivePhase {
        case .working: return focusColor
        case .onBreak: return breakColor
        case .paused, .notStarted, .completed: return focusColor
        }
    }
    
    private var phaseIcon: String {
        if viewModel.state == .paused {
            return "pause.circle.fill"
        }
        switch viewModel.effectivePhase {
        case .working: return "brain.head.profile"
        case .onBreak: return "cup.and.saucer.fill"
        case .paused: return "pause.circle.fill"
        case .notStarted: return "play.circle"
        case .completed: return "checkmark.circle.fill"
        }
    }
    
    private var phaseLabel: String {
        if viewModel.state == .paused {
            return "paused".localized
        }
        switch viewModel.effectivePhase {
        case .working: return "focus_time".localized
        case .onBreak: return "break_time".localized
        case .paused: return "paused".localized
        case .notStarted: return "ready_to_start".localized
        case .completed: return "completed".localized
        }
    }
    
    private var playPauseIcon: String {
        switch viewModel.state {
        case .working, .onBreak: return "pause.fill"
        default: return "play.fill"
        }
    }
    
    /// Short hint rendered under the timeline. Uses already-localized keys.
    private var nextUpHint: String? {
        let sessionsUntilLong = max(1, viewModel.settings.sessionsUntilLongBreak)
        let isLongBreakNext = viewModel.currentSession % sessionsUntilLong == 0
        let breakMinutes = Int((isLongBreakNext
                                ? viewModel.settings.longBreakDuration
                                : viewModel.settings.breakDuration) / 60)
        
        switch viewModel.effectivePhase {
        case .working:
            let label = isLongBreakNext ? "long_break".localized : "short_break".localized
            return "\(label) · \(breakMinutes) " + "min_unit".localized
        case .onBreak:
            let next = viewModel.currentSession + 1
            if next > viewModel.totalSessions {
                return "completed".localized
            }
            return "session".localized + " \(next)/\(viewModel.totalSessions)"
        case .paused:
            return "paused".localized
        case .notStarted:
            let mins = Int(viewModel.settings.workDuration / 60)
            return "focus_time".localized + " · \(mins) " + "min_unit".localized
        case .completed:
            return nil
        }
    }
    
    // MARK: - Formatters
    
    private func timeString(from interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func formatTimeOnly(_ date: Date) -> String {
        TimeFormat.time(date)
    }
    
    private func formatMinutes(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        return "\(m) " + "min_unit".localized
    }
}
