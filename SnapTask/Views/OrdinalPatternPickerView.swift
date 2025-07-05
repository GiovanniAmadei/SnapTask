import SwiftUI

struct OrdinalPatternPickerView: View {
    @Binding var selectedPatterns: Set<Recurrence.OrdinalPattern>
    @Environment(\.dismiss) private var dismiss
    
    private let ordinals = [
        (1, "first".localized),
        (2, "second".localized),
        (3, "third".localized),
        (4, "fourth".localized),
        (-1, "last".localized)
    ]
    
    private let weekdays = [
        (1, "sunday".localized),
        (2, "monday".localized),
        (3, "tuesday".localized),
        (4, "wednesday".localized),
        (5, "thursday".localized),
        (6, "friday".localized),
        (7, "saturday".localized)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    // Header moved inside ScrollView
                    VStack(spacing: 12) {
                        Text("select_patterns_description".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }
                    
                    ForEach(ordinals, id: \.0) { ordinal in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(ordinal.1)
                                .font(.headline)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                ForEach(weekdays, id: \.0) { weekday in
                                    let pattern = Recurrence.OrdinalPattern(ordinal: ordinal.0, weekday: weekday.0)
                                    let isSelected = selectedPatterns.contains(pattern)
                                    
                                    Button(action: {
                                        if isSelected {
                                            selectedPatterns.remove(pattern)
                                        } else {
                                            selectedPatterns.insert(pattern)
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(isSelected ? .pink : .gray)
                                                .font(.system(size: 16))
                                            
                                            Text(weekday.1)
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                            
                                            Spacer()
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(isSelected ? Color.pink.opacity(0.1) : Color(.systemGray6))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .strokeBorder(isSelected ? Color.pink.opacity(0.3) : Color.clear, lineWidth: 1)
                                                )
                                        )
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("monthly_patterns".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("clear_all".localized) {
                        selectedPatterns.removeAll()
                    }
                    .foregroundColor(.red)
                    .disabled(selectedPatterns.isEmpty)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                    .fontWeight(.medium)
                    .foregroundColor(.pink)
                }
            }
        }
    }
}

#Preview {
    OrdinalPatternPickerView(selectedPatterns: .constant([
        Recurrence.OrdinalPattern(ordinal: 1, weekday: 1),
        Recurrence.OrdinalPattern(ordinal: -1, weekday: 6)
    ]))
}