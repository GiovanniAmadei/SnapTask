import SwiftUI

struct ContextualPomodoroSettingsView: View {
    let context: PomodoroContext
    /// When true the view wraps its content in a NavigationStack so the
    /// Save/Cancel toolbar is rendered. Set to false when the view is
    /// pushed via a NavigationLink (the parent stack already provides
    /// the navigation chrome); otherwise you end up with nested
    /// NavigationStacks and `dismiss()` targets the wrong env, causing
    /// a freeze after Save.
    let presentedAsSheet: Bool
    @ObservedObject private var settingsManager = PomodoroSettingsManager.shared
    @State private var localSettings: PomodoroSettings
    @State private var useTimeDuration = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @AppStorage("pomodoroFocusColor") private var focusColorHex = "#4F46E5"
    @AppStorage("pomodoroBreakColor") private var breakColorHex = "#059669"
    
    private var focusColor: Color { Color(hex: focusColorHex) }
    private var breakColor: Color { Color(hex: breakColorHex) }
    
    init(context: PomodoroContext, presentedAsSheet: Bool = true) {
        self.context = context
        self.presentedAsSheet = presentedAsSheet
        let settings = PomodoroSettingsManager.shared.getSettings(for: context)
        self._localSettings = State(initialValue: settings)
    }
    
    private var contextTitle: String {
        switch context {
        case .general: return "general_pomodoro_settings".localized
        case .task:    return "task_pomodoro_settings".localized
        }
    }
    
    private var contextDescription: String {
        switch context {
        case .general: return "general_focus_sessions_description".localized
        case .task:    return "task_pomodoro_sessions_description".localized
        }
    }
    
    var body: some View {
        Group {
            if presentedAsSheet {
                NavigationStack { content }
            } else {
                content
            }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(spacing: 16) {
                aboutCard
                presetsCard
                durationsCard
                sessionsCard
                summaryCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .themedBackground()
        .scrollContentBackground(.hidden)
        .navigationTitle(contextTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: presentedAsSheet ? .navigationBarLeading : .cancellationAction) {
                Button("cancel".localized) { dismiss() }
                    .themedSecondaryText()
            }
            ToolbarItem(placement: presentedAsSheet ? .navigationBarTrailing : .confirmationAction) {
                Button("save".localized) { saveAndDismiss() }
                    .fontWeight(.semibold)
                    .themedPrimary()
            }
        }
        .onAppear {
            useTimeDuration = localSettings.totalDuration > 0
        }
    }
    
    // MARK: - About
    
    private var aboutCard: some View {
        SettingsSectionCard(
            icon: "info.circle.fill",
            iconTint: theme.accentColor,
            title: "about".localized
        ) {
            Text(contextDescription)
                .font(.system(.footnote, design: .rounded))
                .themedSecondaryText()
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // MARK: - Presets
    
    fileprivate struct Preset: Identifiable, Equatable {
        let id: String
        let name: String
        let subtitle: String
        let icon: String
        let work: Int          // minutes
        let shortBreak: Int
        let longBreak: Int
        let sessions: Int
        let sessionsUntilLong: Int
    }
    
    private let presets: [Preset] = [
        Preset(id: "classic", name: "Classic", subtitle: "25 · 5 · 4",
               icon: "circle.grid.2x2.fill",
               work: 25, shortBreak: 5, longBreak: 15, sessions: 4, sessionsUntilLong: 4),
        Preset(id: "deep", name: "Deep",  subtitle: "50 · 10 · 3",
               icon: "brain.head.profile",
               work: 50, shortBreak: 10, longBreak: 20, sessions: 3, sessionsUntilLong: 3),
        Preset(id: "sprint", name: "Sprint", subtitle: "15 · 3 · 6",
               icon: "bolt.fill",
               work: 15, shortBreak: 3, longBreak: 10, sessions: 6, sessionsUntilLong: 4),
    ]
    
    private var matchingPresetId: String? {
        presets.first { p in
            Int(localSettings.workDuration / 60) == p.work &&
            Int(localSettings.breakDuration / 60) == p.shortBreak &&
            Int(localSettings.longBreakDuration / 60) == p.longBreak &&
            localSettings.totalSessions == p.sessions &&
            localSettings.sessionsUntilLongBreak == p.sessionsUntilLong
        }?.id
    }
    
    private var presetsCard: some View {
        SettingsSectionCard(
            icon: "wand.and.stars",
            iconTint: focusColor,
            title: "presets".localized
        ) {
            HStack(spacing: 8) {
                ForEach(presets) { preset in
                    PresetChip(
                        preset: preset,
                        isSelected: matchingPresetId == preset.id,
                        focusColor: focusColor,
                        action: { apply(preset) }
                    )
                }
            }
        }
    }
    
    private func apply(_ preset: Preset) {
        withAnimation(.easeInOut(duration: 0.2)) {
            localSettings.workDuration = Double(preset.work) * 60
            localSettings.breakDuration = Double(preset.shortBreak) * 60
            localSettings.longBreakDuration = Double(preset.longBreak) * 60
            localSettings.totalSessions = preset.sessions
            localSettings.sessionsUntilLongBreak = preset.sessionsUntilLong
            localSettings.totalDuration = localSettings.estimatedTotalTime / 60
        }
        HapticManager.shared.impact(.light)
    }
    
    // MARK: - Durations
    
    private var durationsCard: some View {
        SettingsSectionCard(
            icon: "timer",
            iconTint: focusColor,
            title: "work_session".localized + " & " + "break".localized
        ) {
            VStack(spacing: 14) {
                DurationStepperRow(
                    icon: "brain.head.profile",
                    iconTint: focusColor,
                    title: "duration".localized,
                    value: Binding(
                        get: { Int(localSettings.workDuration / 60) },
                        set: { localSettings.workDuration = Double($0) * 60 }
                    ),
                    range: 1...120,
                    step: 5,
                    unit: "min_unit".localized
                )
                
                Divider().background(theme.borderColor.opacity(0.5))
                
                DurationStepperRow(
                    icon: "cup.and.saucer.fill",
                    iconTint: breakColor,
                    title: "short_break".localized,
                    value: Binding(
                        get: { Int(localSettings.breakDuration / 60) },
                        set: { localSettings.breakDuration = Double($0) * 60 }
                    ),
                    range: 1...60,
                    step: 1,
                    unit: "min_unit".localized
                )
                
                Divider().background(theme.borderColor.opacity(0.5))
                
                DurationStepperRow(
                    icon: "moon.zzz.fill",
                    iconTint: breakColor,
                    title: "long_break".localized,
                    value: Binding(
                        get: { Int(localSettings.longBreakDuration / 60) },
                        set: { localSettings.longBreakDuration = Double($0) * 60 }
                    ),
                    range: 1...120,
                    step: 5,
                    unit: "min_unit".localized
                )
            }
        }
    }
    
    // MARK: - Sessions
    
    private var sessionsCard: some View {
        SettingsSectionCard(
            icon: "square.stack.3d.up.fill",
            iconTint: theme.accentColor,
            title: "session_configuration".localized
        ) {
            VStack(spacing: 14) {
                // Configuration mode toggle
                ThemedSegmentedPicker(
                    selection: $useTimeDuration,
                    options: [false, true]
                ) { opt in
                    Text(opt ? "total_duration".localized : "number_of_sessions".localized)
                }
                
                if useTimeDuration {
                    DurationStepperRow(
                        icon: "clock.fill",
                        iconTint: theme.accentColor,
                        title: "total_duration".localized,
                        value: Binding(
                            get: { Int(localSettings.totalDuration) },
                            set: { newValue in
                                localSettings.totalDuration = Double(newValue)
                                localSettings.totalSessions = localSettings.sessionsForDuration(Double(newValue))
                            }
                        ),
                        range: 30...480,
                        step: 15,
                        unit: "min_unit".localized
                    )
                    
                    infoRow(label: "estimated_sessions".localized,
                            value: "\(localSettings.totalSessions)")
                } else {
                    DurationStepperRow(
                        icon: "number",
                        iconTint: theme.accentColor,
                        title: "total_sessions".localized,
                        value: Binding(
                            get: { localSettings.totalSessions },
                            set: { newValue in
                                localSettings.totalSessions = newValue
                                localSettings.totalDuration = localSettings.estimatedTotalTime / 60
                            }
                        ),
                        range: 1...20,
                        step: 1,
                        unit: ""
                    )
                    
                    infoRow(label: "estimated_duration".localized,
                            value: formatDuration(localSettings.estimatedTotalTime))
                }
                
                Divider().background(theme.borderColor.opacity(0.5))
                
                DurationStepperRow(
                    icon: "arrow.triangle.2.circlepath",
                    iconTint: breakColor,
                    title: "sessions_until_long_break".localized,
                    value: $localSettings.sessionsUntilLongBreak,
                    range: 1...10,
                    step: 1,
                    unit: ""
                )
            }
        }
    }
    
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(.footnote, design: .rounded))
                .themedSecondaryText()
            Spacer()
            Text(value)
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .themedPrimaryText()
                .contentTransition(.numericText())
        }
    }
    
    // MARK: - Summary
    
    private var summaryCard: some View {
        let workSeconds = Double(localSettings.totalSessions) * localSettings.workDuration
        let totalSeconds = localSettings.estimatedTotalTime
        let breakSeconds = max(0, totalSeconds - workSeconds)
        let workRatio = totalSeconds > 0 ? workSeconds / totalSeconds : 0
        
        return SettingsSectionCard(
            icon: "chart.pie.fill",
            iconTint: theme.accentColor,
            title: "summary".localized
        ) {
            VStack(spacing: 14) {
                // Ratio bar: work vs break
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(
                                colors: [focusColor, focusColor.opacity(0.7)],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: max(0, geo.size.width * workRatio - 1))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(
                                colors: [breakColor, breakColor.opacity(0.7)],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: max(0, geo.size.width * (1 - workRatio) - 1))
                    }
                }
                .frame(height: 10)
                
                HStack(spacing: 14) {
                    summaryLegend(color: focusColor,
                                  label: "work_time".localized,
                                  value: formatDuration(workSeconds))
                    summaryLegend(color: breakColor,
                                  label: "break_time".localized,
                                  value: formatDuration(breakSeconds))
                }
                
                Divider().background(theme.borderColor.opacity(0.5))
                
                HStack {
                    Text("total_time".localized)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .themedPrimaryText()
                    Spacer()
                    Text(formatDuration(totalSeconds))
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(
                            LinearGradient(colors: [focusColor, breakColor],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                }
            }
        }
    }
    
    private func summaryLegend(color: Color, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(.caption2, design: .rounded))
                    .themedSecondaryText()
                Text(value)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .themedPrimaryText()
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Save
    
    /// Persists the settings, notifies observers and dismisses the view.
    private func saveAndDismiss() {
        settingsManager.updateSettings(localSettings, for: context)
        NotificationCenter.default.post(name: .pomodoroSettingsUpdated, object: context)
        HapticManager.shared.notification(.success)
        // Dismiss on the next run-loop tick so the publish + layout pass
        // triggered by the setting update completes before we pop/sheet-dismiss.
        DispatchQueue.main.async {
            self.dismiss()
        }
    }
    
    // MARK: - Formatters
    
    private func formatDuration(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) / 60 % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Supporting components

/// Generic themed card section with a titled header.
private struct SettingsSectionCard<Content: View>: View {
    let icon: String
    let iconTint: Color
    let title: String
    @ViewBuilder var content: () -> Content
    
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconTint)
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .themedPrimaryText()
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }
}

/// Row that shows a title + value with stepper-like controls (– value +).
private struct DurationStepperRow: View {
    let icon: String
    let iconTint: Color
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let unit: String
    
    @Environment(\.theme) private var theme
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(iconTint)
                .frame(width: 22, height: 22)
                .background(
                    Circle().fill(iconTint.opacity(0.14))
                )
            
            Text(title)
                .font(.system(.subheadline, design: .rounded))
                .themedPrimaryText()
            
            Spacer()
            
            HStack(spacing: 2) {
                stepperButton(systemName: "minus") {
                    let next = max(range.lowerBound, value - step)
                    if next != value {
                        value = next
                        HapticManager.shared.impact(.light)
                    }
                }
                .disabled(value <= range.lowerBound)
                .opacity(value <= range.lowerBound ? 0.4 : 1)
                
                Text(unit.isEmpty ? "\(value)" : "\(value) \(unit)")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .themedPrimaryText()
                    .contentTransition(.numericText())
                    .frame(minWidth: 54)
                    .multilineTextAlignment(.center)
                
                stepperButton(systemName: "plus") {
                    let next = min(range.upperBound, value + step)
                    if next != value {
                        value = next
                        HapticManager.shared.impact(.light)
                    }
                }
                .disabled(value >= range.upperBound)
                .opacity(value >= range.upperBound ? 0.4 : 1)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(
                Capsule().fill(theme.surfaceColor)
            )
            .overlay(
                Capsule().stroke(theme.borderColor.opacity(0.6), lineWidth: 1)
            )
        }
    }
    
    private func stepperButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(theme.primaryColor)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Chip for a Pomodoro preset (Classic / Deep / Sprint…).
private struct PresetChip: View {
    let preset: ContextualPomodoroSettingsView.Preset
    let isSelected: Bool
    let focusColor: Color
    let action: () -> Void
    
    @Environment(\.theme) private var theme
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: preset.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isSelected ? .white : focusColor)
                Text(preset.name)
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundColor(isSelected ? .white : theme.textColor)
                Text(preset.subtitle)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(isSelected ? .white.opacity(0.85) : theme.secondaryTextColor)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected
                          ? AnyShapeStyle(LinearGradient(colors: [focusColor, focusColor.opacity(0.8)],
                                                        startPoint: .top, endPoint: .bottom))
                          : AnyShapeStyle(theme.surfaceColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? focusColor : theme.borderColor.opacity(0.6),
                            lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: isSelected ? focusColor.opacity(0.25) : .clear,
                    radius: 5, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.18), value: isSelected)
    }
}

extension Notification.Name {
    static let pomodoroSettingsUpdated = Notification.Name("pomodoroSettingsUpdated")
}
