import SwiftUI

struct MonthDayPicker: View {
    @Binding var selectedDays: Set<Int>
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    private let days = Array(1...31)
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Repeat on days")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(days, id: \.self) { day in
                    Button(action: {
                        if selectedDays.contains(day) {
                            selectedDays.remove(day)
                        } else {
                            selectedDays.insert(day)
                        }
                    }) {
                        Text("\(day)")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selectedDays.contains(day) ? Color.accentColor : Color.secondary.opacity(0.2))
                            .foregroundColor(selectedDays.contains(day) ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
} 