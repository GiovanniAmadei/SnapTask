import SwiftUI

/// Compact header displayed above the Pomodoro hero timer.
///
/// Shows:
/// - the session name (task name for task-scoped sessions, or a generic
///   "focus session" label for the general Pomodoro),
/// - an optional category accent dot + subtitle (category name),
/// - a session counter pill (e.g. "2/6"),
/// - a NavigationLink to the contextual settings,
/// - an optional trailing action button (e.g. "Completed" for task sessions).
struct PomodoroScreenHeader<SettingsDestination: View>: View {
    let title: String
    let subtitle: String?
    let accent: Color?
    let sessionText: String
    let settingsDestination: () -> SettingsDestination
    let trailingAction: TrailingAction?
    
    init(
        title: String,
        subtitle: String? = nil,
        accent: Color? = nil,
        sessionText: String,
        @ViewBuilder settingsDestination: @escaping () -> SettingsDestination,
        trailingAction: TrailingAction? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.accent = accent
        self.sessionText = sessionText
        self.settingsDestination = settingsDestination
        self.trailingAction = trailingAction
    }
    
    @Environment(\.theme) private var theme
    
    struct TrailingAction {
        let title: String
        let systemImage: String?
        let tint: Color
        let action: () -> Void
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if let accent {
                    Circle()
                        .fill(accent)
                        .frame(width: 10, height: 10)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .themedPrimaryText()
                        .lineLimit(1)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(.caption, design: .rounded))
                            .themedSecondaryText()
                            .lineLimit(1)
                    }
                }
                
                Spacer(minLength: 8)
            }
            
            HStack(spacing: 8) {
                // Session counter pill
                HStack(spacing: 4) {
                    Text("session".localized)
                        .font(.system(.caption2, design: .rounded))
                        .themedSecondaryText()
                    Text(sessionText)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .themedPrimaryText()
                        .monospacedDigit()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(theme.surfaceColor)
                        .overlay(
                            Capsule()
                                .stroke(theme.borderColor.opacity(0.6), lineWidth: 1)
                        )
                )
                
                Spacer()
                
                if let trailingAction {
                    Button(action: trailingAction.action) {
                        HStack(spacing: 4) {
                            if let sys = trailingAction.systemImage {
                                Image(systemName: sys)
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            Text(trailingAction.title)
                                .font(.system(.caption, design: .rounded).weight(.semibold))
                        }
                        .foregroundColor(trailingAction.tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(trailingAction.tint.opacity(0.12))
                        )
                    }
                }
                
                NavigationLink(destination: settingsDestination()) {
                    Image(systemName: "gear")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.accentColor)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(theme.accentColor.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Small circular icon button used in the Pomodoro toolbar (close, dismiss…).
struct PomodoroCircleIconButton: View {
    let systemName: String
    let tint: Color
    let action: () -> Void
    
    @Environment(\.theme) private var theme
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(tint.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
    }
}
