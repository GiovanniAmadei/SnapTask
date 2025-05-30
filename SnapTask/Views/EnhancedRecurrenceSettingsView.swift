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
                VStack(spacing: 12) {
                    Text("Recurrence Type")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    // Horizontal segmented-style picker
                    HStack(spacing: 4) {
                        ForEach(RecurrenceType.allCases, id: \.self) { type in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.recurrenceType = type
                                }
                            }) {
                                Text(type.rawValue)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(viewModel.recurrenceType == type ? .white : .pink)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(viewModel.recurrenceType == type ? Color.pink : Color.clear)
                                    )
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.pink.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(Color.pink.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal)
                }
                .padding(.top, 16)
                .padding(.bottom, 8)
                
                ScrollView {
                    VStack(spacing: 20) {
                        switch viewModel.recurrenceType {
                        case .daily:
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Daily Recurrence")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                Text("Task will repeat every day")
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)
                                    .padding(.horizontal)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                            )
                            .padding(.horizontal)
                            
                        case .weekly:
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Weekly Recurrence")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                VStack(spacing: 12) {
                                    ForEach(weekdays, id: \.0) { weekday in
                                        HStack {
                                            Text(weekday.1)
                                                .font(.subheadline)
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
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                            )
                            .padding(.horizontal)
                            
                        case .monthly:
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Monthly Recurrence")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                Text("Select days of the month")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                
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
                                .padding(.horizontal)
                            }
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                            )
                            .padding(.horizontal)
                        }
                        
                        // End Date Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("End Date")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                HStack {
                                    Text("Set end date")
                                        .font(.subheadline)
                                    Spacer()
                                    Toggle("", isOn: $viewModel.hasRecurrenceEndDate)
                                        .toggleStyle(SwitchToggleStyle(tint: .pink))
                                }
                                .padding(.horizontal)
                                
                                if viewModel.hasRecurrenceEndDate {
                                    HStack {
                                        Text("End Date")
                                            .font(.subheadline)
                                        Spacer()
                                        DatePicker("", selection: $viewModel.recurrenceEndDate, displayedComponents: .date)
                                            .labelsHidden()
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                        .padding(.horizontal)
                        
                        Spacer()
                            .frame(height: 50)
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
                    .foregroundColor(.pink)
                }
            }
        }
    }
}

#Preview {
    EnhancedRecurrenceSettingsView(viewModel: TaskFormViewModel(initialDate: Date()))
}
