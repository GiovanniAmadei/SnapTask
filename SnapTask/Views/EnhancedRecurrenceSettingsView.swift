import SwiftUI

struct EnhancedRecurrenceSettingsView: View {
    @ObservedObject var viewModel: TaskFormViewModel
    @Environment(\.dismiss) private var dismiss
    
    private let weekdays = [
        (2, "Monday"),
        (3, "Tuesday"), 
        (4, "Wednesday"),
        (5, "Thursday"),
        (6, "Friday"),
        (7, "Saturday"),
        (1, "Sunday")
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom Picker instead of segmented
                VStack(spacing: 16) {
                    Text("Recurrence Type")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    VStack(spacing: 8) {
                        ForEach(RecurrenceType.allCases, id: \.self) { type in
                            Button(action: {
                                viewModel.recurrenceType = type
                            }) {
                                HStack {
                                    Text(type.rawValue)
                                        .font(.body)
                                        .foregroundColor(viewModel.recurrenceType == type ? .white : .primary)
                                    Spacer()
                                    if viewModel.recurrenceType == type {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(viewModel.recurrenceType == type ? Color.pink : Color(.systemGray6))
                                )
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top)
                
                Form {
                    switch viewModel.recurrenceType {
                    case .daily:
                        Section("Daily Recurrence") {
                            Text("Task will repeat every day")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        
                    case .weekly:
                        Section("Weekly Recurrence") {
                            ForEach(weekdays, id: \.0) { weekday in
                                HStack {
                                    Text(weekday.1)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    if viewModel.selectedDays.contains(weekday.0) {
                                        DatePicker("", selection: Binding(
                                            get: { 
                                                viewModel.weeklyTimes[weekday.0] ?? viewModel.startDate
                                            },
                                            set: { newTime in
                                                viewModel.weeklyTimes[weekday.0] = newTime
                                            }
                                        ), displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                        .frame(width: 80)
                                    }
                                    
                                    Toggle("", isOn: Binding(
                                        get: { viewModel.selectedDays.contains(weekday.0) },
                                        set: { isSelected in
                                            if isSelected {
                                                viewModel.selectedDays.insert(weekday.0)
                                            } else {
                                                viewModel.selectedDays.remove(weekday.0)
                                            }
                                        }
                                    ))
                                    .toggleStyle(SwitchToggleStyle(tint: .pink))
                                    .frame(width: 50)
                                }
                            }
                        }
                        
                    case .monthly:
                        Section("Monthly Recurrence") {
                            Text("Select days of the month")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                                ForEach(1...31, id: \.self) { day in
                                    Button(action: {
                                        if viewModel.selectedMonthlyDays.contains(day) {
                                            viewModel.selectedMonthlyDays.remove(day)
                                        } else {
                                            viewModel.selectedMonthlyDays.insert(day)
                                        }
                                    }) {
                                        Text("\(day)")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(viewModel.selectedMonthlyDays.contains(day) ? .white : .primary)
                                            .frame(width: 32, height: 32)
                                            .background(
                                                Circle()
                                                    .fill(viewModel.selectedMonthlyDays.contains(day) ? Color.pink : Color.gray.opacity(0.1))
                                            )
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    
                    Section("End Date") {
                        Toggle("Set end date", isOn: $viewModel.hasRecurrenceEndDate)
                            .toggleStyle(SwitchToggleStyle(tint: .pink))
                        
                        if viewModel.hasRecurrenceEndDate {
                            DatePicker("End Date", selection: $viewModel.recurrenceEndDate, displayedComponents: .date)
                        }
                    }
                }
            }
            .navigationTitle("Recurrence Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.medium)
                }
            }
        }
    }
}

#Preview {
    EnhancedRecurrenceSettingsView(viewModel: TaskFormViewModel(initialDate: Date()))
}
