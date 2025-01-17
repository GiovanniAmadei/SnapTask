import SwiftUI

struct PomodoroSettingsView: View {
    @Binding var settings: PomodoroSettings
    
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
            }
            
            Section("Sessions") {
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
        }
        .navigationTitle("Pomodoro Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
} 