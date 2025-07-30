import SwiftUI

struct WeekdayPicker: View {
    @Binding var selectedDays: Set<Int>
    
    private let weekdays: [(Int, String)] = [
        (1, NSLocalizedString("sunday_short", comment: "Sun")),
        (2, NSLocalizedString("monday_short", comment: "Mon")),
        (3, NSLocalizedString("tuesday_short", comment: "Tue")),
        (4, NSLocalizedString("wednesday_short", comment: "Wed")),
        (5, NSLocalizedString("thursday_short", comment: "Thu")),
        (6, NSLocalizedString("friday_short", comment: "Fri")),
        (7, NSLocalizedString("saturday_short", comment: "Sat"))
    ]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("repeat_on".localized)
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