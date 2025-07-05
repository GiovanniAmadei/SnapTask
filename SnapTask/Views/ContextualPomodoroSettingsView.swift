import SwiftUI

struct ContextualPomodoroSettingsView: View {
    let context: PomodoroContext
    @ObservedObject private var settingsManager = PomodoroSettingsManager.shared
    @State private var localSettings: PomodoroSettings
    @State private var useTimeDuration = false
    @Environment(\.dismiss) private var dismiss
    
    init(context: PomodoroContext) {
        self.context = context
        let settings = PomodoroSettingsManager.shared.getSettings(for: context)
        self._localSettings = State(initialValue: settings)
    }
    
    private var contextTitle: String {
        switch context {
        case .general:
            return "general_pomodoro_settings".localized
        case .task:
            return "task_pomodoro_settings".localized
        }
    }
    
    private var contextDescription: String {
        switch context {
        case .general:
            return "general_focus_sessions_description".localized
        case .task:
            return "task_pomodoro_sessions_description".localized
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(contextDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("about".localized)
                }
                
                Section("work_session".localized) {
                    Stepper(
                        value: Binding(
                            get: { localSettings.workDuration / 60 },
                            set: { localSettings.workDuration = $0 * 60 }
                        ),
                        in: 1...120,
                        step: 5
                    ) {
                        HStack {
                            Text("duration".localized)
                            Spacer()
                            Text("\(Int(localSettings.workDuration / 60)) " + "min_unit".localized)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("break".localized) {
                    Stepper(
                        value: Binding(
                            get: { localSettings.breakDuration / 60 },
                            set: { localSettings.breakDuration = $0 * 60 }
                        ),
                        in: 1...60,
                        step: 1
                    ) {
                        HStack {
                            Text("short_break".localized)
                            Spacer()
                            Text("\(Int(localSettings.breakDuration / 60)) " + "min_unit".localized)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Stepper(
                        value: Binding(
                            get: { localSettings.longBreakDuration / 60 },
                            set: { localSettings.longBreakDuration = $0 * 60 }
                        ),
                        in: 1...120,
                        step: 5
                    ) {
                        HStack {
                            Text("long_break".localized)
                            Spacer()
                            Text("\(Int(localSettings.longBreakDuration / 60)) " + "min_unit".localized)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Stepper(
                        value: $localSettings.sessionsUntilLongBreak,
                        in: 1...10
                    ) {
                        HStack {
                            Text("sessions_until_long_break".localized)
                            Spacer()
                            Text("\(localSettings.sessionsUntilLongBreak)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("session_configuration".localized) {
                    Picker("configure_by".localized, selection: $useTimeDuration) {
                        Text("number_of_sessions".localized).tag(false)
                        Text("total_duration".localized).tag(true)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    if useTimeDuration {
                        Stepper(
                            value: Binding(
                                get: { localSettings.totalDuration },
                                set: { newValue in
                                    localSettings.totalDuration = newValue
                                    // Update total sessions based on duration
                                    localSettings.totalSessions = localSettings.sessionsForDuration(newValue)
                                }
                            ),
                            in: 30...480,
                            step: 15
                        ) {
                            HStack {
                                Text("total_duration".localized)
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("\(Int(localSettings.totalDuration)) " + "min_unit".localized)
                                        .foregroundColor(.secondary)
                                    Text("(\(formatDuration(localSettings.totalDuration * 60)))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        HStack {
                            Text("estimated_sessions".localized)
                            Spacer()
                            Text("\(localSettings.totalSessions)")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Stepper(
                            value: Binding(
                                get: { localSettings.totalSessions },
                                set: { newValue in
                                    localSettings.totalSessions = newValue
                                    // Update duration based on sessions
                                    localSettings.totalDuration = localSettings.estimatedTotalTime / 60
                                }
                            ),
                            in: 1...20
                        ) {
                            HStack {
                                Text("total_sessions".localized)
                                Spacer()
                                Text("\(localSettings.totalSessions)")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        HStack {
                            Text("estimated_duration".localized)
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("\(Int(localSettings.estimatedTotalTime / 60)) " + "min_unit".localized)
                                    .foregroundColor(.secondary)
                                Text("(\(formatDuration(localSettings.estimatedTotalTime)))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("session_breakdown".localized)
                            .font(.subheadline.weight(.medium))
                        
                        HStack {
                            Text("work_time".localized + ":")
                            Spacer()
                            Text("\(formatDuration(Double(localSettings.totalSessions) * localSettings.workDuration))")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("break_time".localized + ":")
                            Spacer()
                            let breakTime = localSettings.estimatedTotalTime - (Double(localSettings.totalSessions) * localSettings.workDuration)
                            Text("\(formatDuration(breakTime))")
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("total_time".localized + ":")
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(formatDuration(localSettings.estimatedTotalTime))")
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                    }
                } header: {
                    Text("summary".localized)
                }
            }
            .navigationTitle(contextTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save".localized) {
                        settingsManager.updateSettings(localSettings, for: context)
                        // Notify PomodoroViewModel to apply settings immediately
                        NotificationCenter.default.post(name: .pomodoroSettingsUpdated, object: context)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                // Initialize useTimeDuration based on current settings
                useTimeDuration = localSettings.totalDuration > 0
            }
        }
    }
    
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

extension Notification.Name {
    static let pomodoroSettingsUpdated = Notification.Name("pomodoroSettingsUpdated")
}