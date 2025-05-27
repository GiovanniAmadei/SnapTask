import SwiftUI

struct PomodoroSettingsView: View {
    @Binding var settings: PomodoroSettings
    @State private var useTimeDuration = false
    
    var body: some View {
        Form {
            Section("Work Session") {
                Stepper(
                    value: Binding(
                        get: { settings.workDuration / 60 },
                        set: { settings.workDuration = $0 * 60 }
                    ),
                    in: 1...120,
                    step: 5
                ) {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text("\(Int(settings.workDuration / 60)) min")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Break") {
                Stepper(
                    value: Binding(
                        get: { settings.breakDuration / 60 },
                        set: { settings.breakDuration = $0 * 60 }
                    ),
                    in: 1...60,
                    step: 1
                ) {
                    HStack {
                        Text("Short Break")
                        Spacer()
                        Text("\(Int(settings.breakDuration / 60)) min")
                            .foregroundColor(.secondary)
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
                        Text("Long Break")
                        Spacer()
                        Text("\(Int(settings.longBreakDuration / 60)) min")
                            .foregroundColor(.secondary)
                    }
                }
                
                Stepper(
                    value: $settings.sessionsUntilLongBreak,
                    in: 1...10
                ) {
                    HStack {
                        Text("Sessions until long break")
                        Spacer()
                        Text("\(settings.sessionsUntilLongBreak)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Session Configuration") {
                Picker("Configure by", selection: $useTimeDuration) {
                    Text("Number of Sessions").tag(false)
                    Text("Total Duration").tag(true)
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
                            Text("Total Duration")
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("\(Int(settings.totalDuration)) min")
                                    .foregroundColor(.secondary)
                                Text("(\(formatDuration(settings.totalDuration * 60)))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    HStack {
                        Text("Estimated Sessions")
                        Spacer()
                        Text("\(settings.totalSessions)")
                            .foregroundColor(.secondary)
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
                            Text("Total Sessions")
                            Spacer()
                            Text("\(settings.totalSessions)")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("Estimated Duration")
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("\(Int(settings.estimatedTotalTime / 60)) min")
                                .foregroundColor(.secondary)
                            Text("(\(formatDuration(settings.estimatedTotalTime)))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Session Breakdown")
                        .font(.subheadline.weight(.medium))
                    
                    HStack {
                        Text("Work Time:")
                        Spacer()
                        Text("\(formatDuration(Double(settings.totalSessions) * settings.workDuration))")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Break Time:")
                        Spacer()
                        let breakTime = settings.estimatedTotalTime - (Double(settings.totalSessions) * settings.workDuration)
                        Text("\(formatDuration(breakTime))")
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Total Time:")
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(formatDuration(settings.estimatedTotalTime))")
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }
            } header: {
                Text("Summary")
            }
        }
        .navigationTitle("Pomodoro Settings")
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
