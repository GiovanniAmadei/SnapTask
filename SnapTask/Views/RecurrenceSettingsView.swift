import SwiftUI

struct RecurrenceSettingsView: View {
    @Binding var isDailyRecurrence: Bool
    @Binding var selectedDays: Set<Int>
    @Environment(\.theme) private var theme
    
    private let weekdays = [
        (1, "monday".localized),
        (2, "tuesday".localized),
        (3, "wednesday".localized),
        (4, "thursday".localized),
        (5, "friday".localized),
        (6, "saturday".localized),
        (7, "sunday".localized)
    ]
    
    var body: some View {
        Form {
            Section {
                Toggle("daily".localized, isOn: $isDailyRecurrence)
                    .themedPrimaryText()
                    .toggleStyle(SwitchToggleStyle(tint: theme.accentColor))
                    .listRowBackground(theme.surfaceColor)
                
                if !isDailyRecurrence {
                    ForEach(weekdays, id: \.0) { day in
                        Toggle(day.1, isOn: Binding(
                            get: { selectedDays.contains(day.0) },
                            set: { isSelected in
                                if isSelected {
                                    selectedDays.insert(day.0)
                                } else {
                                    selectedDays.remove(day.0)
                                }
                            }
                        ))
                        .themedPrimaryText()
                        .toggleStyle(SwitchToggleStyle(tint: theme.accentColor))
                        .listRowBackground(theme.surfaceColor)
                    }
                }
            }
        }
        .themedBackground()
        .scrollContentBackground(.hidden)
        .navigationTitle("repeat_settings".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}