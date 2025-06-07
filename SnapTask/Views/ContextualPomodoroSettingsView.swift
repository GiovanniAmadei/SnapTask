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
            return "General Pomodoro Settings"
        case .task:
            return "Task Pomodoro Settings"
        }
    }
    
    private var contextDescription: String {
        switch context {
        case .general:
            return "These settings apply to general focus sessions started from the Focus tab."
        case .task:
            return "These settings apply to Pomodoro sessions started from specific tasks."
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
                    Text("About")
                }
                
                Section("Work Session") {
                    Stepper(
                        value: Binding(
                            get: { localSettings.workDuration / 60 },
                            set: { localSettings.workDuration = $0 * 60 }
                        ),
                        in: 1...120,
                        step: 5
                    ) {
                        HStack {
                            Text("Duration")
                            Spacer()
                            Text("\(Int(localSettings.workDuration / 60)) min")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Break") {
                    Stepper(
                        value: Binding(
                            get: { localSettings.breakDuration / 60 },
                            set: { localSettings.breakDuration = $0 * 60 }
                        ),
                        in: 1...60,
                        step: 1
                    ) {
                        HStack {
                            Text("Short Break")
                            Spacer()
                            Text("\(Int(localSettings.breakDuration / 60)) min")
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
                            Text("Long Break")
                            Spacer()
                            Text("\(Int(localSettings.longBreakDuration / 60)) min")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Stepper(
                        value: $localSettings.sessionsUntilLongBreak,
                        in: 1...10
                    ) {
                        HStack {
                            Text("Sessions until long break")
                            Spacer()
                            Text("\(localSettings.sessionsUntilLongBreak)")
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
                                Text("Total Duration")
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("\(Int(localSettings.totalDuration)) min")
                                        .foregroundColor(.secondary)
                                    Text("(\(formatDuration(localSettings.totalDuration * 60)))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        HStack {
                            Text("Estimated Sessions")
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
                                Text("Total Sessions")
                                Spacer()
                                Text("\(localSettings.totalSessions)")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        HStack {
                            Text("Estimated Duration")
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("\(Int(localSettings.estimatedTotalTime / 60)) min")
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
                        Text("Session Breakdown")
                            .font(.subheadline.weight(.medium))
                        
                        HStack {
                            Text("Work Time:")
                            Spacer()
                            Text("\(formatDuration(Double(localSettings.totalSessions) * localSettings.workDuration))")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Break Time:")
                            Spacer()
                            let breakTime = localSettings.estimatedTotalTime - (Double(localSettings.totalSessions) * localSettings.workDuration)
                            Text("\(formatDuration(breakTime))")
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Total Time:")
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(formatDuration(localSettings.estimatedTotalTime))")
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                    }
                } header: {
                    Text("Summary")
                }
            }
            .navigationTitle(contextTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
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
