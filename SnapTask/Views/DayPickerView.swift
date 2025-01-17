import SwiftUI

struct DayPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDays: Set<Int>
    
    let weekdays = [
        (1, "Monday"),
        (2, "Tuesday"),
        (3, "Wednesday"),
        (4, "Thursday"),
        (5, "Friday"),
        (6, "Saturday"),
        (7, "Sunday")
    ]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(weekdays, id: \.0) { day in
                    Button(action: {
                        if selectedDays.contains(day.0) {
                            selectedDays.remove(day.0)
                        } else {
                            selectedDays.insert(day.0)
                        }
                    }) {
                        HStack {
                            Text(day.1)
                            Spacer()
                            if selectedDays.contains(day.0) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.pink)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("Select Days")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
} 