import SwiftUI

struct PomodoroSettingsView: View {
    @Binding var settings: PomodoroSettings
    @State private var useTimeDuration = false
    @Environment(\.theme) private var theme
    
    var body: some View {
        Form {
            Section("work_session".localized) {
                Stepper(
                    value: Binding(
                        get: { settings.workDuration / 60 },
                        set: { settings.workDuration = $0 * 60 }
                    ),
                    in: 1...120,
                    step: 5
                ) {
                    HStack {
                        Text("duration".localized)
                        Spacer()
                        Text("\(Int(settings.workDuration / 60)) " + "min_unit".localized)
                            .themedSecondaryText()
                    }
                }
            }
            
            Section("break".localized) {
                Stepper(
                    value: Binding(
                        get: { settings.breakDuration / 60 },
                        set: { settings.breakDuration = $0 * 60 }
                    ),
                    in: 1...60,
                    step: 1
                ) {
                    HStack {
                        Text("short_break".localized)
                        Spacer()
                        Text("\(Int(settings.breakDuration / 60)) " + "min_unit".localized)
                            .themedSecondaryText()
                    }
                }
                
                Stepper(
                    value: Binding(
                        get: { settings.longBreakDuration / 60 },
                        set: { settings.longBreakDuration = $0 * 60 }
                    ),
                    in: 1...120,
                    step: 5
                ) {
                    HStack {
                        Text("long_break".localized)
                        Spacer()
                        Text("\(Int(settings.longBreakDuration / 60)) " + "min_unit".localized)
                            .themedSecondaryText()
                    }
                }
                
                Stepper(
                    value: $settings.sessionsUntilLongBreak,
                    in: 1...10
                ) {
                    HStack {
                        Text("sessions_until_long_break".localized)
                        Spacer()
                        Text("\(settings.sessionsUntilLongBreak)")
                            .themedSecondaryText()
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
                            get: { settings.totalDuration },
                            set: { newValue in
                                settings.totalDuration = newValue
                                // Update total sessions based on duration
                                settings.totalSessions = settings.sessionsForDuration(newValue)
                            }
                        ),
                        in: 30...480,
                        step: 15
                    ) {
                        HStack {
                            Text("total_duration".localized)
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("\(Int(settings.totalDuration)) " + "min_unit".localized)
                                    .themedSecondaryText()
                                Text("(\(formatDuration(settings.totalDuration * 60)))")
                                    .font(.caption)
                                    .themedSecondaryText()
                            }
                        }
                    }
                    
                    HStack {
                        Text("estimated_sessions".localized)
                        Spacer()
                        Text("\(settings.totalSessions)")
                            .themedSecondaryText()
                    }
                } else {
                    Stepper(
                        value: Binding(
                            get: { settings.totalSessions },
                            set: { newValue in
                                settings.totalSessions = newValue
                                // Update duration based on sessions
                                settings.totalDuration = settings.estimatedTotalTime / 60
                            }
                        ),
                        in: 1...20
                    ) {
                        HStack {
                            Text("total_sessions".localized)
                            Spacer()
                            Text("\(settings.totalSessions)")
                                .themedSecondaryText()
                        }
                    }
                    
                    HStack {
                        Text("estimated_duration".localized)
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("\(Int(settings.estimatedTotalTime / 60)) " + "min_unit".localized)
                                .themedSecondaryText()
                            Text("(\(formatDuration(settings.estimatedTotalTime)))")
                                .font(.caption)
                                .themedSecondaryText()
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
                        Text("\(formatDuration(Double(settings.totalSessions) * settings.workDuration))")
                            .themedSecondaryText()
                    }
                    
                    HStack {
                        Text("break_time".localized + ":")
                        Spacer()
                        let breakTime = settings.estimatedTotalTime - (Double(settings.totalSessions) * settings.workDuration)
                        Text("\(formatDuration(breakTime))")
                            .themedSecondaryText()
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("total_time".localized + ":")
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(formatDuration(settings.estimatedTotalTime))")
                            .fontWeight(.medium)
                            .themedPrimaryText()
                    }
                }
            } header: {
                Text("summary".localized)
            }
        }
        .themedBackground()
        .navigationTitle("pomodoro_settings".localized)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Initialize useTimeDuration based on current settings
            useTimeDuration = settings.totalDuration > 0
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