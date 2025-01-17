import SwiftUI

struct RecurrenceSettingsView: View {
    @Binding var isDailyRecurrence: Bool
    @Binding var selectedDays: Set<Int>
    
    private let weekdays = [
        (1, "Monday"),
        (2, "Tuesday"),
        (3, "Wednesday"),
        (4, "Thursday"),
        (5, "Friday"),
        (6, "Saturday"),
        (7, "Sunday")
    ]
    
    var body: some View {
        Form {
            Section {
                Toggle("Daily", isOn: $isDailyRecurrence)
                
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
                    }
                }
            }
        }
        .navigationTitle("Repeat Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
} 