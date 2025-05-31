import SwiftUI

struct EnhancedRecurrenceSettingsView: View {
    @ObservedObject var viewModel: TaskFormViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingOrdinalPicker = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Text("Recurrence Type")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    HStack(spacing: 4) {
                        RecurrenceTypeButton(type: .daily, selectedType: viewModel.recurrenceType) {
                            viewModel.recurrenceType = .daily
                        }
                        RecurrenceTypeButton(type: .weekly, selectedType: viewModel.recurrenceType) {
                            viewModel.recurrenceType = .weekly
                        }
                        RecurrenceTypeButton(type: .monthly, selectedType: viewModel.recurrenceType) {
                            viewModel.recurrenceType = .monthly
                        }
                        RecurrenceTypeButton(type: .yearly, selectedType: viewModel.recurrenceType) {
                            viewModel.recurrenceType = .yearly
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
                            DailyRecurrenceView()
                            
                        case .weekly:
                            WeeklyRecurrenceView(viewModel: viewModel)
                            
                        case .monthly:
                            MonthlyRecurrenceView(viewModel: viewModel, showingOrdinalPicker: $showingOrdinalPicker)
                            
                        case .yearly:
                            YearlyRecurrenceView(viewModel: viewModel)
                        }
                        
                        EndDateSection(viewModel: viewModel)
                        
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
            .sheet(isPresented: $showingOrdinalPicker) {
                OrdinalPatternPickerView(selectedPatterns: $viewModel.selectedOrdinalPatterns)
            }
        }
    }
}

struct RecurrenceTypeButton: View {
    let type: RecurrenceType
    let selectedType: RecurrenceType
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                action()
            }
        }) {
            Text(type.rawValue)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(selectedType == type ? .white : .pink)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedType == type ? Color.pink : Color.clear)
                )
        }
        .buttonStyle(BorderlessButtonStyle())
    }
}

struct DailyRecurrenceView: View {
    var body: some View {
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
    }
}

struct WeeklyRecurrenceView: View {
    @ObservedObject var viewModel: TaskFormViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Recurrence")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                WeekdayRow(weekday: (2, "Monday"), viewModel: viewModel)
                WeekdayRow(weekday: (3, "Tuesday"), viewModel: viewModel)
                WeekdayRow(weekday: (4, "Wednesday"), viewModel: viewModel)
                WeekdayRow(weekday: (5, "Thursday"), viewModel: viewModel)
                WeekdayRow(weekday: (6, "Friday"), viewModel: viewModel)
                WeekdayRow(weekday: (7, "Saturday"), viewModel: viewModel)
                WeekdayRow(weekday: (1, "Sunday"), viewModel: viewModel)
            }
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal)
    }
}

struct WeekdayRow: View {
    let weekday: (Int, String)
    @ObservedObject var viewModel: TaskFormViewModel
    
    var body: some View {
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

struct MonthlyRecurrenceView: View {
    @ObservedObject var viewModel: TaskFormViewModel
    @Binding var showingOrdinalPicker: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Monthly Recurrence")
                .font(.headline)
                .padding(.horizontal)
            
            HStack(spacing: 4) {
                MonthlyTypeButton(type: .days, selectedType: viewModel.monthlySelectionType) {
                    viewModel.monthlySelectionType = .days
                }
                MonthlyTypeButton(type: .ordinal, selectedType: viewModel.monthlySelectionType) {
                    viewModel.monthlySelectionType = .ordinal
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.pink.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.pink.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal)
            
            if viewModel.monthlySelectionType == .days {
                MonthlyDaysView(viewModel: viewModel)
            } else {
                MonthlyPatternsView(viewModel: viewModel, showingOrdinalPicker: $showingOrdinalPicker)
            }
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal)
    }
}

struct MonthlyTypeButton: View {
    let type: MonthlySelectionType
    let selectedType: MonthlySelectionType
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                action()
            }
        }) {
            Text(type.rawValue)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(selectedType == type ? .white : .pink)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedType == type ? Color.pink : Color.clear)
                )
        }
        .buttonStyle(BorderlessButtonStyle())
    }
}

struct MonthlyDaysView: View {
    @ObservedObject var viewModel: TaskFormViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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
    }
}

struct MonthlyPatternsView: View {
    @ObservedObject var viewModel: TaskFormViewModel
    @Binding var showingOrdinalPicker: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select patterns like 'First Sunday' or 'Last Friday'")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button(action: {
                showingOrdinalPicker = true
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Monthly Patterns")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        if viewModel.selectedOrdinalPatterns.isEmpty {
                            Text("None selected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text(viewModel.selectedOrdinalPatterns.map { $0.displayText }.joined(separator: ", "))
                                .font(.caption)
                                .foregroundColor(.pink)
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.pink.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(BorderlessButtonStyle())
            .padding(.horizontal)
        }
    }
}

struct YearlyRecurrenceView: View {
    @ObservedObject var viewModel: TaskFormViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Yearly Recurrence")
                .font(.headline)
                .padding(.horizontal)
            
            Text("Select the day of the year when the task should repeat")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            HStack {
                Text("Repeat on")
                    .font(.subheadline)
                Spacer()
                DatePicker("", selection: $viewModel.yearlyDate, displayedComponents: [.date])
                    .labelsHidden()
            }
            .padding(.horizontal)
            
            Text("Task will repeat every year on \(formattedYearlyDate)")
                .font(.caption)
                .foregroundColor(.pink)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal)
    }
    
    private var formattedYearlyDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: viewModel.yearlyDate)
    }
}

struct EndDateSection: View {
    @ObservedObject var viewModel: TaskFormViewModel
    
    var body: some View {
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
    }
}

#Preview {
    EnhancedRecurrenceSettingsView(viewModel: TaskFormViewModel(initialDate: Date()))
}
