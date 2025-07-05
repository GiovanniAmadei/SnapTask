import SwiftUI

struct DayPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDays: Set<Int>
    
    let weekdays = [
        (1, "monday".localized),
        (2, "tuesday".localized),
        (3, "wednesday".localized),
        (4, "thursday".localized),
        (5, "friday".localized),
        (6, "saturday".localized),
        (7, "sunday".localized)
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
            .navigationTitle("select_days".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}