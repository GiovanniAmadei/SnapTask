import SwiftUI

struct DurationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var duration: TimeInterval
    @State private var selectedHours: Int
    @State private var selectedMinutes: Int
    
    init(duration: Binding<TimeInterval>) {
        self._duration = duration
        let hours = Int(duration.wrappedValue) / 3600
        let minutes = (Int(duration.wrappedValue) % 3600) / 60
        self._selectedHours = State(initialValue: hours)
        self._selectedMinutes = State(initialValue: minutes)
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    Picker("Hours", selection: $selectedHours) {
                        ForEach(0...23, id: \.self) { hour in
                            Text("\(hour)h").tag(hour)
                        }
                    }
                    .pickerStyle(.wheel)
                    
                    Picker("Minutes", selection: $selectedMinutes) {
                        ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { minute in
                            Text("\(minute)m").tag(minute)
                        }
                    }
                    .pickerStyle(.wheel)
                }
                .padding()
            }
            .navigationTitle("Set Duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        duration = TimeInterval(selectedHours * 3600 + selectedMinutes * 60)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(300)])
    }
}

#Preview {
    DurationPickerView(duration: .constant(3600))
} 