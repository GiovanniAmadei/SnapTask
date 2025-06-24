import SwiftUI

struct WatchDatePickerView: View {
    @Binding var selectedDate: Date
    @Binding var selectedDayOffset: Int
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Select Date")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                
                Button("Done") {
                    // Calculate the day offset from today
                    let calendar = Calendar.current
                    let today = calendar.startOfDay(for: Date())
                    let selected = calendar.startOfDay(for: selectedDate)
                    selectedDayOffset = calendar.dateComponents([.day], from: today, to: selected).day ?? 0
                    dismiss()
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(8)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
}

#Preview {
    WatchDatePickerView(
        selectedDate: .constant(Date()),
        selectedDayOffset: .constant(0)
    )
}