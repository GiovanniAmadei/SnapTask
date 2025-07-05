import SwiftUI

struct EnhancedRecurrenceSettingsView: View {
    @ObservedObject var viewModel: TaskFormViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingOrdinalPicker = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Text("recurrence_type".localized)
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    HStack(spacing: 2) {
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
            .navigationTitle("recurrence_settings".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
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
            Text(type.localizedString)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(selectedType == type ? .white : .pink)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
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
            Text("daily_recurrence".localized)
                .font(.headline)
                .padding(.horizontal)
            
            Text("task_repeat_every_day".localized)
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
            Text("weekly_recurrence".localized)
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                WeekdayRow(weekday: (2, "monday".localized), viewModel: viewModel)
                WeekdayRow(weekday: (3, "tuesday".localized), viewModel: viewModel)
                WeekdayRow(weekday: (4, "wednesday".localized), viewModel: viewModel)
                WeekdayRow(weekday: (5, "thursday".localized), viewModel: viewModel)
                WeekdayRow(weekday: (6, "friday".localized), viewModel: viewModel)
                WeekdayRow(weekday: (7, "saturday".localized), viewModel: viewModel)
                WeekdayRow(weekday: (1, "sunday".localized), viewModel: viewModel)
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
            Text("monthly_recurrence".localized)
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
            Text(type.localizedString)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(selectedType == type ? .white : .pink)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
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
            Text("select_days_of_month".localized)
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
            Text("select_patterns_ordinal".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button(action: {
                showingOrdinalPicker = true
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("monthly_patterns".localized)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        if viewModel.selectedOrdinalPatterns.isEmpty {
                            Text("none_selected".localized)
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
            Text("yearly_recurrence".localized)
                .font(.headline)
                .padding(.horizontal)
            
            Text("select_day_of_year".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            HStack {
                Text("repeat_on".localized)
                    .font(.subheadline)
                Spacer()
                DatePicker("", selection: $viewModel.yearlyDate, displayedComponents: [.date])
                    .labelsHidden()
            }
            .padding(.horizontal)
            
            Text("task_repeat_yearly_on".localized + " \(formattedYearlyDate)")
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
            Text("end_date".localized)
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                HStack {
                    Text("set_end_date".localized)
                        .font(.subheadline)
                    Spacer()
                    Toggle("", isOn: $viewModel.hasRecurrenceEndDate)
                        .toggleStyle(SwitchToggleStyle(tint: .pink))
                }
                .padding(.horizontal)
                
                if viewModel.hasRecurrenceEndDate {
                    HStack {
                        Text("end_date".localized)
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