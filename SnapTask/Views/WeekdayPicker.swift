import SwiftUI

struct WeekdayPicker: View {
    @Binding var selectedDays: Set<Int>
    
    private let weekdays = [
        (1, "Sun"), (2, "Mon"), (3, "Tue"),
        (4, "Wed"), (5, "Thu"), (6, "Fri"), (7, "Sat")
    ]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Repeat on")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                ForEach(weekdays, id: \.0) { day, name in
                    Button(action: {
                        if selectedDays.contains(day) {
                            selectedDays.remove(day)
                        } else {
                            selectedDays.insert(day)
                        }
                    }) {
                        Text(name)
                            .font(.caption)
                            .padding(8)
                            .background(selectedDays.contains(day) ? Color.accentColor : Color.secondary.opacity(0.2))
                            .foregroundColor(selectedDays.contains(day) ? .white : .primary)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
} 